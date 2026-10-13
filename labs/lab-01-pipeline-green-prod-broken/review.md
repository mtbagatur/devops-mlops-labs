# Review — Lab 01

> Mod: guided (her adımda çoktan seçmeli karar). Seçenekler önüne konduğu için bu puan, açık uçlu bir cevaptan biraz daha az kanıt sayılır; aynı konular ileride açık uçlu sorularla tekrar ölçülecek.

## Puan: 8/10

| Rubrik maddesi | Puan | Not |
|---|---|---|
| Sıralı teşhis (status → journal → unit → env file → neden değişti) | 2/2 | `ss -tlnp` → `status` + `journalctl` → `systemctl cat` + `cut` + `stat` → journal/crontab. Katman katman, salt okunur, doğru sırada |
| Secret sızdırmadan acil düzeltme | 2/2 | Ayrı 0600 dosya, Key Vault'tan pipe, drop-in `EnvironmentFile=`, `reset-failed` |
| Kök neden: secret tasarım gereği hiç taşınmıyor + dosya üzerine yazılıyor | 2/2 | Configuration drift (ansible-pull) ve "deploy hatayı yaratmadı, görünür kıldı" tespiti |
| Pipeline yeniden tasarımı (Key Vault, açık env mapping, 0600 dosya) | 1/2 | Secret'ı IaC'e (Ansible + Key Vault) taşımayı seçtin, doğru. Ama Azure DevOps tarafında secret değişkenlerin script'e **açıkça `env:` ile map edilmesi** gerektiği konusu senin seçimlerinle hiç sınanmadı |
| Dürüst health gate (`--fail`, retry, rollback) | 1/1 | `curl -fsS --retry` + `condition: failed()` rollback |
| Bonus risk | 1/1 | `$(Build.ArtifactStagingDirectory)` symlink'i ve stop→swap→restart kesintisi |
| Kesinti: secret ifşa alışkanlığı (CLAUDE.md kural 6) | −1 | Adım 5'te ilk tercih `systemctl show -p Environment` oldu |

## Doğru yaptıkların
- **Önce gözle, sonra dokun** kuralına baştan sona uydun: `restart`, `start`, `reboot` seçeneklerinin hiçbirini almadın.
- `--no-pager`, `cut -d= -f1`, `stat` gibi küçük ama profesyonel alışkanlıkları doğru yerde kullandın.
- Pipeline rollback'inin bu olayda **işe yaramayacağını** (env dosyası release'in parçası değil) gördün; çoğu kişi buraya düşer.
- Doğrulamada `curl -fsS` ile içeriden dışarıya katman katman gittin ve birkaç dakika izledin.
- Önlemde `StartLimitBurst` tuzağına düşmedin; belirtiyi gizleyen "düzeltme"yi ayırt ettin.

## Eksikler ve hatalar
1. **Adım 5 — `sudo systemctl show pricing-api -p Environment`.** İki sorun: (a) `Environment=` satırlarını değerleriyle basar; bir secret orada olsaydı terminale, ekran paylaşımına ve oturum loglarına düşerdi. (b) `EnvironmentFile=` içeriğini göstermez, bu yüzden bu olayda hiçbir şey kanıtlamadı. Doğrusu: `systemctl cat` + `sudo cut -d= -f1 <file>`.
2. **Azure DevOps secret mapping.** Kök neden maddesinde "secret değişkenler script'e otomatik geçmez" yazıyor ama bunun pipeline'da nasıl yapıldığını (aşağıda) kendin kurmadın.
3. **Etki adımında karar zamanı.** Adım 6'da kaynak araması için zaman sınırı (2–3 dk) ben söyledim; bunu ilk adımda kendin koymalısın: "Prod kapalı; X dakikada bulamazsam önce mitigation."

## Doğru yaklaşım
```bash
sudo ss -tlnp | grep 8080                                   # 502'nin nedeni: dinleyen yok
systemctl status pricing-api --no-pager                     # failed + start-limit-hit
sudo journalctl -u pricing-api -n 50 --no-pager             # DATABASE_URL is not set
systemctl cat pricing-api                                   # EnvironmentFile=/etc/pricing-api/pricing.env
sudo cut -d= -f1 /etc/pricing-api/pricing.env               # sadece anahtarlar
sudo stat -c '%y %U' /etc/pricing-api/pricing.env           # 29 Eyl 23:10, root
sudo journalctl --since '2026-09-29 23:05' --until '2026-09-29 23:15' --no-pager | grep -iE 'ansible|cron'
# mitigation
sudo install -m 600 -o root -g root /dev/null /etc/pricing-api/secrets.env
az keyvault secret show --vault-name <vault> -n database-url --query value -o tsv \
  | sed 's/^/DATABASE_URL=/' | sudo tee /etc/pricing-api/secrets.env >/dev/null
sudo systemctl edit pricing-api        # EnvironmentFile=/etc/pricing-api/secrets.env
sudo systemctl daemon-reload && sudo systemctl reset-failed pricing-api && sudo systemctl start pricing-api
# verify
curl -fsS http://127.0.0.1:8080/health && curl -fsS https://pricing.internal/health
```

Azure DevOps'ta secret değişkenin script'e güvenli geçişi (eksik kalan parça):
```yaml
- script: |
    set -euo pipefail
    printf 'DATABASE_URL=%s\n' "$DATABASE_URL" | ssh deploy@prod-api-01 'sudo tee /etc/pricing-api/secrets.env >/dev/null'
  env:
    DATABASE_URL: $(DATABASE_URL)   # secret değişkenler ancak böyle açıkça map edilince görünür
```
Daha iyisi: pipeline secret'a hiç dokunmasın; sunucu managed identity ile Key Vault'tan kendisi çeksin (Ansible rolü).

## Production / güvenlik notları
- Secret'ı komut satırı argümanı olarak vermek (`--value '...'`, `echo ...`) onu `ps` çıktısına ve shell geçmişine yazar; her zaman pipe veya dosya kullan.
- `/etc/systemd/system/*.service` ve drop-in'ler 0644'tür; içlerine secret yazılmaz.
- Elle yapılan production değişikliği, otomasyonun sahip olduğu bir dosyadaysa bir sonraki çalıştırmada kaybolur. Mitigation'ı otomasyonun dokunmadığı bir yere koy, kalıcı çözümü IaC'e taşı.
- Bu olayda MTTR ~13.5 dk; algılama pipeline değil monitoring ile oldu. Postmortem'de "neden pipeline yakalamadı" ayrı bir aksiyon maddesi olmalı.

## Bir sonraki labda tekrar edilecek
- Secret hijyeni: config/Secret incelerken değer değil anahtar listeleme (Lab 03'te Kubernetes Secret ile tekrar).
- Azure DevOps secret değişkenlerinin açık `env:` mapping'i ve Helm'e taşınması (Lab 03).
- Etki adımında zaman sınırı ve mitigation-önce kararı.
