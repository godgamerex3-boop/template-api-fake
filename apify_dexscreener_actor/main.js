/**
 * DexScreener Smart-Money Whale Tracker & Liquidity Screener
 * Production Apify Actor
 */
import { Actor } from 'apify';
import axios from 'axios';

await Actor.init();

const input = await Actor.getInput() || {};
const chains = input.chains || ['solana', 'base'];
const minLiquidityUsd = input.minLiquidityUsd || 10000;
const minVolume24h = input.minVolume24h || 50000;
const maxResults = input.maxResults || 50;

console.log(`Starting DexScreener Whale Tracker across chains: ${chains.join(', ')}...`);

try {
    // 1. Fetch latest token boosts and trending profiles
    const boostsUrl = 'https://api.dexscreener.com/token-boosts/latest/v1';
    const resp = await axios.get(boostsUrl, {
        headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
            'Accept': 'application/json'
        },
        timeout: 10000
    });

    const boostedTokens = resp.data || [];
    console.log(`Fetched ${boostedTokens.length} trending boosted tokens from DexScreener.`);

    const results = [];
    const seenPairs = new Set();

    // 2. Query pairs for top boosted tokens
    for (const item of boostedTokens) {
        if (results.length >= maxResults) break;
        const chainId = item.chainId?.toLowerCase();
        if (!chains.includes(chainId)) continue;

        const tokenAddress = item.tokenAddress;
        if (!tokenAddress) continue;

        try {
            const pairUrl = `https://api.dexscreener.com/latest/dex/tokens/${tokenAddress}`;
            const pairResp = await axios.get(pairUrl, {
                headers: { 'User-Agent': 'Mozilla/5.0' },
                timeout: 8000
            });

            const pairs = pairResp.data?.pairs || [];
            for (const p of pairs) {
                if (results.length >= maxResults) break;
                if (seenPairs.has(p.pairAddress)) continue;
                seenPairs.add(p.pairAddress);

                const liq = p.liquidity?.usd || 0;
                const vol24h = p.volume?.h24 || 0;

                if (liq >= minLiquidityUsd && vol24h >= minVolume24h) {
                    const record = {
                        chainId: p.chainId,
                        dexId: p.dexId,
                        pairAddress: p.pairAddress,
                        baseToken: {
                            address: p.baseToken?.address,
                            name: p.baseToken?.name,
                            symbol: p.baseToken?.symbol
                        },
                        quoteToken: {
                            symbol: p.quoteToken?.symbol
                        },
                        priceUsd: p.priceUsd,
                        liquidityUsd: liq,
                        volume24hUsd: vol24h,
                        volumeToLiquidityRatio: liq > 0 ? (vol24h / liq).toFixed(2) : 0,
                        priceChange24h: p.priceChange?.h24 || 0,
                        txns24h: p.txns?.h24 || {},
                        url: p.url,
                        scrapedAt: new Date().toISOString()
                    };

                    results.push(record);
                    await Actor.pushData(record);
                    await Actor.charge({ eventName: 'TOKEN_PAIR_PARSED', count: 1 });
                }
            }
        } catch (err) {
            // continue gracefully on single pair timeout
        }
    }

    console.log(`Successfully parsed and saved ${results.length} smart-money token pairs to dataset.`);
} catch (error) {
    console.error('Fatal error during DexScreener scraping:', error);
    await Actor.fail(error.message);
}

await Actor.exit();
