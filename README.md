# 📊 Quantitative Prediction & On-Chain Derivatives Analytics

Production-grade quantitative modeling, statistical research artifacts, and empirical market telemetry for Solana decentralized prediction and perpetual protocols.

---

## 🔬 Featured Research Deliverables

### 1. ⚽ [Premier League Prediction Mechanics & 3x Leverage Convexity Matrix](./WORM_EPL_500_USDC_PREDICTION_PLAYBOOK.md)
* **Mathematical Model**: Dixon-Coles bivariate Poisson formulation with low-score correlation adjustment ($	au_{\lambda,\mu}(x,y)$) and asymmetric home-advantage parameters.
* **Empirical Edge**: Quantifies +9.4% EV on Manchester City and +6.0% EV on Tottenham Hotspur against live orderbook odds on [Worm.wtf](https://www.worm.wtf).
* **Convexity Analysis**: Evaluates 3× leverage payout profiles, margin buffer isolation, and capital growth velocity.
* **Deterministic Engine**: [compute_dixon_coles_epl.py](./compute_dixon_coles_epl.py) | Telemetry: [worm_epl_dixon_coles_analysis.json](./worm_epl_dixon_coles_analysis.json)
* **Visual Telemetry**: [worm_epl_market_screenshot.png](./worm_epl_market_screenshot.png), [worm_cry_liv_screenshot.png](./worm_cry_liv_screenshot.png)

### 2. 🦅 [RaptorX REX AI 5.0 Dialectic Research Challenge (JUP / SOL)](./raptorx_submission_entry.md)
* **Protocol Target**: Jupiter Exchange (JUP) on Solana & JLP Liquidity Pool.
* **Analytical Inquiries**: 
  1. Volume/Price divergence and institutional delta-neutral hedging vs organic accumulation.
  2. JLP pool solvency stress-testing ( TVL, 65% volatile crypto backing) against perpetual liquidation cascades.
  3. Real yield retention vs 7.4× FDV overhang.
* **Visual Proof**: [
aptorx_proof_screenshot.png](./raptorx_proof_screenshot.png)

---

## 🚀 Local Reproduction

Run the Dixon-Coles Poisson engine locally:
`ash
python compute_dixon_coles_epl.py
`

---

## 📜 License
MIT License. Open research for the Solana quantitative trading community.
