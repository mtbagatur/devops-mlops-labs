# Review — Lab 02

> Mod: guided (her adımda çoktan seçmeli karar). 7 adımın 7'sinde ilk seçim doğruydu. Seçenekler önüne konduğu için bu puan, açık uçlu bir cevaptan biraz daha az kanıt sayılır.

## Puan: 9/10

| Rubrik maddesi | Puan | Not |
|---|---|---|
| Katmanlı yaklaşım (app → DNS → Service/Endpoints → network → policy → config) | 2/2 | Önce kendi taraf, sonra sunucu tarafı, sonra yol — tam sırasıyla |
| Pod içinden timeout / refused / NXDOMAIN ayrımı yapan komutlar | 2/2 | `kubectl debug --target` + `nslookup` + `nc -zv -w3`, ayrıca pod IP testi |
| NetworkPolicy / namespace label kök nedeni | 2/2 | İki yönü de (egress + ingress) ve `--show-labels`'ı seçtin |
| Service port/targetPort/endpoints ve URL/port konfigürasyonu | 1/1 | Service, EndpointSlice, Ready podlar ve `ml-platform` içinden test |
| Kapasiteyi koruma (pause/rollback kararı) | 1/1 | Ölç → pause → 10 dk zaman sınırı → rollback |
| `maxSurge: 0 / maxUnavailable: 50%` tasarım hatası | 1/1 | Önlemde doğru strateji seçildi |
| Uçtan uca doğrulama | 0/1 | Planındaki "helm rollback ile 4 replikaya dön" adımı tek başına çalışmazdı: deployment 1. adımda `pause` edilmişti; `resume` olmadan rollback "success" der ama hiçbir pod değişmez. Bunu ben gösterdim |

## Doğru yaptıkların
- **Lab 01'in zayıf alanını kapattın:** ölçmeden rollback yapmadın, ama zaman sınırı koydun ve süre bitince kök nedeni bilmene rağmen rollback'e uydun. Bu, olgun bir on-call kararı.
- Minimal production imajını yeniden build etmek yerine **ephemeral debug container** kullandın.
- `timed out` ile `refused` farkını doğru yorumladın ve suçu kanıtsız başka ekibe atmadın.
- Başka ekibin güvenlik sınırını delmedin; least-privilege değişikliği sahibine PR olarak götürdün.
- Readiness probe'u kaldırma tuzağına düşmedin; probe'un aslında işini yaptığını gördün.

## Eksikler ve hatalar
1. **Mitigation sırasında yaptığın değişiklikleri takip etmek.** `kubectl rollout pause` ile başladın ama rollback planında `resume` yoktu. Kural: olay sırasında yaptığın her geçici değişikliği (pause, scale, cordon, silence) bir listeye yaz ve kapanışta tek tek geri al.
2. **NetworkPolicy `from` semantiği.** Doğru policy'yi seçtin ama `namespaceSelector` + `podSelector` aynı öğede = **VE**, ayrı öğelerde = **VEYA** ayrımını kendin kurmadın; bunu ileride bir policy yazarken açık uçlu soracağım.
3. Kapasite kararında HPA olmadığını gördün ama önleme listesine "HPA / kapasite payı" eklenmedi; eski podlar CPU limitinin %87'sindeydi.

## Doğru yaklaşım
```bash
kubectl top pods -n production -l app=recommendation-api; kubectl get hpa -n production   # kapasite
kubectl rollout pause deploy/recommendation-api -n production                            # + zaman sınırı
kubectl debug -it <new-pod> -n production --image=nicolaka/netshoot --target=recommendation-api -- sh
  nslookup feature-store.ml-platform.svc.cluster.local      # DNS
  nc -zv -w3 feature-store.ml-platform.svc.cluster.local 9000   # timeout → filtre
kubectl get svc,endpointslices,pods -n ml-platform -l app=feature-store
kubectl run nettest --rm -it --restart=Never -n ml-platform --image=nicolaka/netshoot -- curl -fsS --max-time 3 http://feature-store:9000/health
kubectl get networkpolicy -A; kubectl describe networkpolicy -n ml-platform; kubectl get ns --show-labels
helm rollback recommendation-api -n production --wait && kubectl rollout resume deploy/recommendation-api -n production
kubectl rollout status deploy/recommendation-api -n production
# fix: sahibin IaC reposunda least-privilege ingress kuralı → merge → yeniden deploy → rollout status, old RS 0, p95
```

## Production / güvenlik notları
- `kubectl debug` ile açılan ephemeral container pod silinene kadar spec'te kalır; işin bitince podu yeniden başlatmak gerekmez ama audit loguna düştüğünü bil.
- Namespace label'ları NetworkPolicy'de **yetki** anlamına gelir; label ekleme yetkisi (RBAC) bu yüzden kısıtlı olmalı.
- `kubernetes.io/metadata.name` label'ı Kubernetes tarafından otomatik ve değiştirilemez şekilde konur; namespace'i isimle seçmek için en güvenli yol budur.
- Readiness probe dış bağımlılığa bağlıysa, bağımlılık çöktüğünde **tüm** podlar aynı anda NotReady olabilir (cascading failure). Kritik olmayan bağımlılıklar için degraded mode tasarla.

## Bir sonraki labda tekrar edilecek
- Mitigation sırasında yapılan geçici değişikliklerin listesi ve kapanışta geri alınması.
- NetworkPolicy `from` VE/VEYA semantiği (açık uçlu sorulacak).
- Lab 01'den hâlâ açık: secret hijyeni ve Azure DevOps secret `env:` mapping (Lab 03).
