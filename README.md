# KuCoin Screener — app Android

Screener mercati futures KuCoin + grafico candele. **Standalone**: l'app
chiama direttamente le API pubbliche KuCoin e CoinGecko, nessun server.

## Schermate

- **Mercati**: lista 700+ contratti con mark price, 24h%, 7d%, funding,
  turnover, OI, market cap, leva. Filtri: ricerca, turnover, |24h|,
  market cap, leva, funding, OI, categoria, preferiti ★. Sort per
  colonna. Refresh automatico 30s.
- **Grafico** (tap su una coin): candlestick + volume, intervalli
  1m/5m/15m/30m/1h/2h/4h/1d/1w, auto-refresh 30s.

## Build

L'APK viene compilata da GitHub Actions (`.github/workflows/build-apk.yml`)
ad ogni push su `main`, oppure manualmente da Actions → Build APK →
Run workflow. Artifact: `kucoin-screener-apk` (apk per-abi: arm64 è
quella giusta per quasi tutti i telefoni).

Build locale alternativa:

```
flutter create --platforms=android --org it.vinsc \
  --project-name kucoin_screener .
flutter pub get
flutter build apk --release
```

## Note dati

- Contratti/klines/7d: `api-futures.kucoin.com` (pagine kline da 190,
  cap API ~200)
- Categorie + market cap: CoinGecko `/coins/markets` per categoria,
  cache 72h su device, refresh 12h con back-off su 429
- `XBT` mostrato come `BTC` solo in UI
