# Polymarket Real-Time Odds, Arbitrage & Whale Volume Scanner 🚀

A high-speed, institutional-grade Apify Actor that monitors active **Polymarket** prediction markets in real-time, calculates exact implied probabilities, detects pricing misalignments and arbitrage opportunities, and tracks whale betting volume (>$1,000,000 USD).

---

## ⚡ Key Capabilities

- **Institutional Speed**: Queries Polymarket Gamma API with sub-second execution (~600ms latency).
- **Implied Probability Engine**: Automatically decodes outcome prices ($p_i$) into calibrated market probabilities ($p_i \times 100\%$).
- **Arbitrage & Mispricing Detection**: Automatically flags markets where the sum of outcome token prices deviates significantly from parity ($|\sum p_i - 1.00| > 1.5\%$).
- **Whale Volume Filtering**: Instantly isolates massive prediction pools exceeding **$1,000,000 USD** in 24h trading volume.
- **Category & Tag Filters**: Seamlessly filter for Politics, Crypto, Federal Reserve, Tech, and Macro events.

---

## 💰 Monetization & Pay-Per-Event (PPE) Pricing

This Actor operates under Apify's **Pay-Per-Event (PPE)** pricing model:
- **$0.01 USD per 1,000 market records** scanned.
- Generous free allotment included for trial scans.

---

## 📥 Input Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `limit` | Integer | `50` | Maximum number of active Polymarket events to retrieve (5 to 500). |
| `minVolumeUsd` | Integer | `10000` | Filter out illiquid markets below this threshold. |
| `detectArbitrage` | Boolean | `true` | Flag markets where total outcome token pricing deviates from $1.00. |
| `tagFilter` | String | `""` | Filter by category (e.g. `'Politics'`, `'Crypto'`, `'Fed'`). |

---

## 📤 Output Format

```json
{
  "eventId": "12345",
  "marketId": "67890",
  "title": "Fed Interest Rate Cut by November 2026?",
  "question": "Will the Fed cut rates by 25bps?",
  "category": "Economy",
  "volumeUsd": 4520100.50,
  "liquidityUsd": 850230.10,
  "outcomes": [
    {
      "outcome": "Yes",
      "impliedProbabilityPct": "78.40%",
      "priceUsd": 0.784
    },
    {
      "outcome": "No",
      "impliedProbabilityPct": "21.60%",
      "priceUsd": 0.216
    }
  ],
  "sumProbability": 1.0000,
  "isArbitrageOpportunity": false,
  "spreadDeviationPct": "0.00%",
  "isWhaleMarket": true,
  "polymarketUrl": "https://polymarket.com/event/fed-rate-cut",
  "scannedAt": "2026-10-26T15:50:00.000Z"
}
```

---

## 🛠️ Standalone Verification

Run offline without Apify credentials:
```bash
node test_standalone.js
```
All dependencies use native Node.js standard libraries (`node:assert`, `fetch`).
