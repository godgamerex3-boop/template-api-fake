/**
 * Polymarket Real-Time Odds, Arbitrage & Whale Volume Scanner
 * Production-ready Apify Actor with Pay-Per-Event (PPE) monetization.
 */

import { Actor } from 'apify';

await Actor.init();

const input = (await Actor.getInput()) || {};
const limit = input.limit || 50;
const minVolumeUsd = input.minVolumeUsd || 10000;
const detectArbitrage = input.detectArbitrage !== false;
const tagFilter = (input.tagFilter || '').trim().toLowerCase();

console.log(`[*] Starting Polymarket Scanner. Limit: ${limit}, MinVolume: $${minVolumeUsd}`);

const API_URL = `https://gamma-api.polymarket.com/events?closed=false&limit=${limit}`;

try {
  const resp = await fetch(API_URL, {
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': 'application/json'
    }
  });

  if (!resp.ok) {
    throw new Error(`Gamma API responded with HTTP ${resp.status}`);
  }

  const events = await resp.json();
  const records = [];

  for (const ev of events) {
    const volume = parseFloat(ev.volume || 0);
    if (volume < minVolumeUsd) continue;

    const title = ev.title || '';
    const tags = (ev.tags || []).map(t => (t.label || '').toLowerCase());
    
    if (tagFilter && !tags.some(t => t.includes(tagFilter)) && !title.toLowerCase().includes(tagFilter)) {
      continue;
    }

    const markets = ev.markets || [];
    for (const m of markets) {
      const outcomes = JSON.parse(m.outcomes || '[]');
      const outcomePrices = JSON.parse(m.outcomePrices || '[]');
      
      let sumProb = 0;
      const parsedOutcomes = outcomes.map((name, i) => {
        const price = parseFloat(outcomePrices[i] || 0);
        sumProb += price;
        return {
          outcome: name,
          impliedProbabilityPct: (price * 100).toFixed(2) + '%',
          priceUsd: price
        };
      });

      const spreadDeviation = Math.abs(sumProb - 1.0);
      const isArbitrageOpportunity = detectArbitrage && spreadDeviation > 0.015 && sumProb > 0;
      const isWhaleMarket = volume >= 1000000;

      const record = {
        eventId: ev.id,
        marketId: m.id,
        title: ev.title,
        question: m.question,
        category: ev.category || 'General',
        volumeUsd: volume,
        liquidityUsd: parseFloat(m.liquidity || 0),
        outcomes: parsedOutcomes,
        sumProbability: parseFloat(sumProb.toFixed(4)),
        isArbitrageOpportunity,
        spreadDeviationPct: (spreadDeviation * 100).toFixed(2) + '%',
        isWhaleMarket,
        polymarketUrl: `https://polymarket.com/event/${ev.slug}`,
        scannedAt: new Date().toISOString()
      };

      records.push(record);
      await Actor.pushData(record);
      
      // Pay-Per-Event monetization hook
      try {
        await Actor.charge({ eventName: 'MARKET_RECORD', count: 1 });
      } catch (e) {
        // Ignored in local test runs
      }
    }
  }

  console.log(`[+] Scanned and saved ${records.length} high-value Polymarket records.`);
} catch (err) {
  console.error(`[-] Scanner error: ${err.message}`);
}

await Actor.exit();
