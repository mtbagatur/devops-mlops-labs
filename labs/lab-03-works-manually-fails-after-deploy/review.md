# Review — Lab 03

> Mod: guided (her adımda çoktan seçmeli karar). 6 adımın 4'ünde ilk seçim doğruydu; 2. adımda iki deneme de secret'ı ifşa etti.

## Puan: 6/10

| Rubrik maddesi | Puan | Not |
|---|---|---|
| Çökme nedeninin loglardan kanıtı | 1/1 | `logs --previous` + Deployment env → `secretKeyRef` |
| Anahtarın varlığını değer basmadan kanıtlama | 0/1 | Seçimlerin `jsonpath \| base64 -d` ve `-o yaml` oldu; doğru komutu (`describe secret`) ben gösterdim |
| Değerin boş olduğunu decode etmeden kanıtlama | 0/2 | `base64 -d` tam olarak kuralın yasakladığı şey; boş çıktı şans eseri sızıntıyı engelledi |
| Helm sahipliği / history / values | 1/1 | `helm history` + revizyon manifest karşılaştırması + kullanıcı değerleri |
| Azure DevOps secret mapping açıklaması | 1/1 | Secret değişkenlerin task'lara otomatik geçmediğini doğru seçtin |
| Eski RS'e dokunmadan onarım + eski pod restart riski | 1/1 | Riski 1. adımda gördün; `--set` yolu da eski RS'e dokunmazdı |
| Kalıcı tasarım (Key Vault + ESO/CSI, `required`, `--set` yok) | 2/2 | 3/3 doğru, kalıcı `--set` tuzağını reddettin |
| Helm değerlerinin nerede saklandığı (release Secret, loglar) | 0/1 | 5. adımda `--set` ile onarımı seçtin; bunun anahtarı `sh.helm.release.v1.*` kaydına ve `helm get values`'a yazacağını öngörmedin |

## Doğru yaptıkların
- **Gizli riski gördün:** eski podların sağlıklı görünmesine rağmen aynı Secret'ı okudukları için tek bir restart'la çökeceklerini tespit ettin. Bu labın en önemli kararıydı.
- `helm rollback` seçeneğini almadın. Bu senaryoda rollback Secret'ı silerdi.
- Azure DevOps değişken grubu ↔ task arasındaki boşluğu doğru açıkladın (Lab 01'deki zayıf alanda ilk iyi cevap).
- Kalıcı çözümde secret'ı chart'tan tamamen çıkaran mimariyi seçtin.

## Eksikler ve hatalar
1. **`kubectl get secret ... -o jsonpath='{.data.ml-model-api-key}' | base64 -d`** — değeri decode edip ekrana basar. Senaryonun açık kuralını çiğniyor.
2. **`kubectl get secret ... -o yaml`** — base64 şifreleme değil, kodlamadır; değer ifşa edilmiş sayılır. Bu, Lab 01'deki `systemctl show -p Environment` ile aynı hata ailesi: **değer gösteren komutu "inceleme" sanmak.**
3. **`--set secrets.mlModelApiKey=$(ML_MODEL_API_KEY)` ile onarım** — çalışır ama anahtar Helm release Secret'ında, `helm get values` çıktısında ve agent process argümanlarında kalır; ayrıca tam bir pipeline turu sürer. Acil durumda değer Key Vault'tan pipe ile doğrudan Secret'a yazılır.

## Doğru yaklaşım
```bash
kubectl logs <new-pod> -n fraud-prod --previous                          # ML_MODEL_API_KEY is empty
kubectl get deploy fraud-api -n fraud-prod -o jsonpath='{.spec.template.spec.containers[0].env}' | jq
kubectl describe secret fraud-api-secrets -n fraud-prod                  # ml-model-api-key: 0 bytes, managed-by=Helm
helm history fraud-api -n fraud-prod
for r in 40 41; do helm get manifest fraud-api -n fraud-prod --revision $r | grep -c 'name: fraud-api-secrets'; done
helm get values fraud-api -n fraud-prod                                  # user-supplied only
# mitigation — değer hiçbir yerde görünmez
az keyvault secret show --vault-name <vault> -n ml-model-api-key --query value -o tsv \
  | kubectl create secret generic fraud-api-secrets -n fraud-prod --from-file=ml-model-api-key=/dev/stdin --dry-run=client -o yaml \
  | kubectl apply -f -
kubectl describe secret fraud-api-secrets -n fraud-prod                  # 40 bytes
kubectl rollout status deploy/fraud-api -n fraud-prod
# pipeline'ı chart düzelene kadar durdur; kalıcı: ExternalSecret + existingSecret + required
```

## Production / güvenlik notları
- `secretKeyRef` ve `envFrom` değerleri container başlarken okunur; Secret değişikliği çalışan podları etkilemez ama ilk restart'ta etkiler. Secret'ı değiştiren her deploy, eski podlar için de bir risk taşır.
- Helm, sahiplendiği (adopt ettiği) bir kaynağı chart'tan çıkarırsan ya da o kaynağı içermeyen bir revizyona rollback yaparsan **siler**. Kalması gereken Secret'lara `helm.sh/resource-policy: keep` koy.
- Kubernetes Secret'ları etcd'de varsayılan olarak sadece base64'tür; etcd encryption-at-rest ve Secret okuma RBAC'ı ayrı ayrı kontrol edilmeli.
- Ekran paylaşımında, olay kanalında veya terminal kaydında bir kez görünen secret **rotate edilmelidir**. "Kimse görmedi" bir güvenlik kontrolü değildir.

## Bir sonraki labda tekrar edilecek
- **Secret hijyeni (öncelik 1):** Lab 01 ve 03'te toplam 3 kez değer gösteren komut seçildi. Bir sonraki labda Secret/ConfigMap incelemesi açık uçlu sorulacak.
- Helm'in değerleri nerede sakladığı (`sh.helm.release.v1.*`, `helm get values`) ve `--set` ile secret geçmenin riski.
- `helm rollback`'in neyi geri aldığını ve neyi sildiğini önceden söyleyebilmek.
