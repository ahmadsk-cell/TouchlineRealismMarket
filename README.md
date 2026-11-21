# TouchlineRealismMarket — Standalone Transfer Realism for SP Football Life 26 & 27

**TouchlineRealismMarket** is a single-file Sider Lua module that overhauls Master League's AI transfer market, club spending identities, squad building, and player valuations — completely standalone, with no external apps or `.exe` edits required.

---

## Features

1. **AI Transfer Rulebook Overhaul (18 in-memory rule tables)**
   Fixes unrealistic AI transfer behavior, dead-rubber transfer windows, and erratic player valuations across Master League.
2. **Club Transfer Profiles (51 clubs + 20 MLS ceilings + live world-ranking caps)**
   - Gives 51 major European, Saudi Pro League, and Brazilian clubs realistic fee ceilings, age-mix recruitment targets, transfer policies, and partner/rival club links.
   - Applies realistic fee ceilings to 20 MLS clubs, reads the live worldwide club ranking table to cap smaller clubs proportionally, fills blank club ceilings, and caps AI youth-target shares at 45%.
   - Cleanly restores original club fields if you switch back to `mode = realistic` or `mode = off`.
3. **Goalkeeper Hoarding Cap**
   Stops AI clubs from hoarding 6–8 goalkeepers (default max: **5 GKs per AI club**; configurable or disableable).
4. **Club Nationality Policies**
   Enforces club nationality rules on AI transfers — ships pre-configured with **Athletic Club (ID 258) → Spain (ID 236)** and supports any custom `team_id:nationality_id` list. Automatically excludes whichever club you are currently managing so your own transfers are never blocked.
5. **Older-Player Value Decay**
   Prevents aging veterans from retaining unrealistic transfer fees by smoothly decaying market values past your chosen age threshold (default: **age 31**).
6. **Optional Market Valuation Era Multiplier**
   Scale the entire Master League transfer economy up or down (`100` = `0.10x` to `5000` = `5.00x`, with automatic club ceiling sync) to play in a **Modern (`2.20x`)**, **Hyper (`3.00x`)**, or **Retro (`0.50x`–`0.75x`)** transfer market.

---

## Compatibility

- **Games:** SP Football Life 2026 (v1.4) & SP Football Life 2027 (via Sider 7)
- **Zero disk edits:** Everything runs purely in RAM through Sider. Your game `.exe` is never modified.
- **Compatible with:** `DR_ML_Budget` and verified relocated layouts (such as FL Mod Studio / Carabao Cup). If a layout cannot be verified safely, club profile writes are skipped automatically with zero risk of corruption.
- **Do NOT combine with:** Touchline Companion's `MLTransferRealism.lua` (both hook the same game addresses — use one or the other).

---

## Installation (3 Steps)

### Step 1 — Download
Click the green **Code** button above → **Download ZIP**, then extract it.

### Step 2 — Copy `modules\` into `SiderAddons`
Copy both files from the extracted `modules` folder into your Football Life `SiderAddons\modules` folder:

```text
SiderAddons\
└── modules\
    ├── TouchlineRealismMarket.lua
    └── TouchlineRealismMarket.ini
```

### Step 3 — Enable in `SiderAddons\sider.ini`
Open `sider.ini` in Notepad and add this line under your `lua.module` section:

```ini
lua.module = "TouchlineRealismMarket.lua"
```

Save `sider.ini`, launch Football Life through Sider, and load your Master League save.

### Verify It's Running
Press **Spacebar** in-game to open the Sider overlay, then press **1** to cycle modules until you see **`TouchlineRealismMarket v1.0.0`**. You'll see live status for every system (Rulebook, Club profiles, Goalkeepers, Nationalities, Older values, Market era, and live veto/decay counters).

---

## Configuration (`modules\TouchlineRealismMarket.ini`)

Open `SiderAddons\modules\TouchlineRealismMarket.ini` in any text editor. **Changes hot-reload automatically within ~2 seconds** while playing — no game restart needed.

### Default Settings

```ini
mode              = profiles   ; profiles | realistic | off
gk_cap            = 5          ; Max GKs per AI club (0 = off)
older_value_age   = 31         ; Age where veteran value decay begins (0 = off)
nationality_rules = 258:236    ; team_id:nationality_id pairs (blank = off)
multiplier        = 1000       ; 1000 = 1.00x (vanilla values), range 100..5000
ceilings          = 1          ; 1 = scale club fee ceilings with multiplier, 0 = off
```

### Option Reference

| Option | Values | What It Controls |
| --- | --- | --- |
| `mode` | `profiles`, `realistic`, `off` | `profiles` = full rulebook + 51 club profiles & caps (recommended). `realistic` = rulebook only (restores club profiles). `off` = restores everything to stock. |
| `gk_cap` | `0`–`9` | Maximum goalkeepers an AI club may hold before new GK signings are vetoed. `0` disables the cap. |
| `older_value_age` | `0` or `25`–`40` | Age at which veteran market values begin decaying. `0` disables decay. |
| `nationality_rules` | `team:nat, ...` | Comma-separated `team_id:nationality_id` rules (up to 8). Example: `258:236` (Athletic Club → Spain). Leave blank to disable. Your managed club is always exempt. |
| `multiplier` | `100`–`5000` | Global market value multiplier in thousandths (`1000` = `1.00x`). |
| `ceilings` | `1` or `0` | Scales club fee ceilings along with `multiplier` so AI clubs can still afford signings in higher-multiplier eras. |

### Popular Market Era Presets

Copy any of these `multiplier` values into `TouchlineRealismMarket.ini`:

- **Vanilla values (default):** `multiplier = 1000` (`1.00x`)
- **Modern Market:** `multiplier = 2200` (`2.20x`)
- **Hyper / Saudi-era Market:** `multiplier = 3000` (`3.00x`)
- **2010s Market:** `multiplier = 750` (`0.75x`)
- **2000s Retro Market:** `multiplier = 500` (`0.50x`)

---

## Troubleshooting & Uninstall

- **Overlay shows `Club profiles: waiting for career`:** Normal on the main menu — it activates automatically once you load into a Master League save.
- **Check logs:** Search `SiderAddons\sider.log` for `TouchlineRealismMarket:` to see exact hook and profile counts.
- **Clean uninstall:**
  1. *(Optional)* If you want to revert modified club profile values inside an existing Master League save before removing the mod, set `mode = off` in `TouchlineRealismMarket.ini` while your career is loaded, let it restore (check the overlay), and save your career.
  2. Remove `lua.module = "TouchlineRealismMarket.lua"` from `sider.ini`.
  3. Delete `TouchlineRealismMarket.lua`, `TouchlineRealismMarket.ini`, and (if present) `TouchlineRealismMarket.caves` from `SiderAddons\modules\`.
