import math
import json
import sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

# 1. Dixon-Coles Bivariate Poisson Model Implementation
def tau_factor(x, y, lambda_param, mu_param, rho):
    if x == 0 and y == 0:
        return 1.0 - lambda_param * mu_param * rho
    elif x == 0 and y == 1:
        return 1.0 + lambda_param * rho
    elif x == 1 and y == 0:
        return 1.0 + mu_param * rho
    elif x == 1 and y == 1:
        return 1.0 - rho
    else:
        return 1.0

def poisson_prob(k, lmbda):
    return (lmbda ** k) * math.exp(-lmbda) / math.factorial(k)

def match_probabilities(lambda_home, mu_away, rho=-0.08, max_goals=8):
    home_win = 0.0
    draw = 0.0
    away_win = 0.0
    score_matrix = {}

    for x in range(max_goals + 1):
        for y in range(max_goals + 1):
            p_indep = poisson_prob(x, lambda_home) * poisson_prob(y, mu_away)
            factor = tau_factor(x, y, lambda_home, mu_away, rho)
            p = max(0.0, p_indep * factor)
            score_matrix[(x, y)] = p

    # Normalize
    total_p = sum(score_matrix.values())
    for (x, y), p in score_matrix.items():
        norm_p = p / total_p
        if x > y:
            home_win += norm_p
        elif x == y:
            draw += norm_p
        else:
            away_win += norm_p

    return home_win, draw, away_win

# 2. Live Fixtures on Worm.wtf
fixtures = [
    {
        "home": "Everton", "away": "Coventry City", "date": "Nov 7",
        "lambda": 1.72, "mu": 0.88,
        "worm_home": 0.57, "worm_away": 0.20, "worm_draw": 0.23,
        "volume": "$693.1K"
    },
    {
        "home": "Leeds United", "away": "Tottenham Hotspur", "date": "Nov 7",
        "lambda": 1.25, "mu": 1.35,
        "worm_home": 0.37, "worm_away": 0.36, "worm_draw": 0.27,
        "volume": "$511.2K"
    },
    {
        "home": "Arsenal", "away": "Hull City", "date": "Nov 7",
        "lambda": 2.65, "mu": 0.42,
        "worm_home": 0.85, "worm_away": 0.05, "worm_draw": 0.10,
        "volume": "$434.6K"
    },
    {
        "home": "Fulham", "away": "Newcastle United", "date": "Nov 7",
        "lambda": 1.48, "mu": 1.18,
        "worm_home": 0.47, "worm_away": 0.28, "worm_draw": 0.25,
        "volume": "$554.7K"
    },
    {
        "home": "Nottingham Forest", "away": "Manchester City", "date": "Nov 8",
        "lambda": 0.85, "mu": 1.95,
        "worm_home": 0.20, "worm_away": 0.57, "worm_draw": 0.23,
        "volume": "$408.4K"
    },
    {
        "home": "Crystal Palace", "away": "Liverpool", "date": "Nov 8",
        "lambda": 0.92, "mu": 2.15,
        "worm_home": 0.18, "worm_away": 0.62, "worm_draw": 0.20,
        "volume": "$272.3K"
    },
    {
        "home": "Manchester United", "away": "Aston Villa", "date": "Nov 8",
        "lambda": 1.55, "mu": 1.30,
        "worm_home": 0.45, "worm_away": 0.30, "worm_draw": 0.25,
        "volume": "$262.2K"
    }
]

print("="*80)
print(f"{'FIXTURE':<32} | {'MODEL (H/D/A)':<18} | {'WORM ODDS':<18} | {'EDGE (EV)':<10}")
print("="*80)

results = []
for f in fixtures:
    hw, d, aw = match_probabilities(f["lambda"], f["mu"])
    
    # Calculate Expected Value on Worm price:
    # EV = (Model Prob - Worm Price) / Worm Price
    ev_home = (hw - f["worm_home"]) / f["worm_home"]
    ev_away = (aw - f["worm_away"]) / f["worm_away"]
    
    # Best edge
    if ev_home > ev_away:
        best_pick = f"Home ({f['home']})"
        best_ev = ev_home
    else:
        best_pick = f"Away ({f['away']})"
        best_ev = ev_away
        
    print(f"{f['home']} vs {f['away']:<16} | {hw*100:4.1f}% / {d*100:4.1f}% / {aw*100:4.1f}% | {f['worm_home']*100:4.1f}% / {f['worm_draw']*100:4.1f}% / {f['worm_away']*100:4.1f}% | {best_ev*100:+5.1f}% on {best_pick}")
    
    results.append({
        "fixture": f"{f['home']} vs {f['away']}",
        "date": f["date"],
        "volume": f["volume"],
        "dixon_coles": {"home": round(hw, 4), "draw": round(d, 4), "away": round(aw, 4)},
        "worm_odds": {"home": f["worm_home"], "draw": f["worm_draw"], "away": f["worm_away"]},
        "best_pick": best_pick,
        "ev": round(best_ev * 100, 2)
    })

with open(r'worm_epl_dixon_coles_analysis.json', 'w', encoding='utf-8') as out:
    json.dump(results, out, indent=2)
print("\nResults successfully saved to worm_epl_dixon_coles_analysis.json")
