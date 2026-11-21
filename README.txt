========================================================================
TouchlineRealismMarket -- Standalone Sider Module for FL26 & FL27
========================================================================

WHAT IT DOES
Pure Sider Lua overhaul for Master League's AI transfer market -- no external
apps, no DLLs, and no .exe edits on disk. Everything runs cleanly in RAM:

1. AI Transfer Rulebook Overhaul (18 in-memory rule tables)
   Fixes unrealistic AI transfer decisions and erratic valuations.
2. Club Transfer Profiles (51 major European/Saudi/Brazilian clubs,
   20 MLS ceilings, live world-ranking caps, blank-ceiling fixes,
   45% youth target cap, and clean restore on mode off).
3. Goalkeeper Hoarding Cap (default: max 5 GKs per AI club).
4. Club Nationality Policies (default: Athletic Club 258 -> Spain 236;
   automatically excludes whichever club you are currently managing).
5. Older-Player Value Decay (default: from age 31).
6. Optional Market Valuation Era Multiplier (0.10x to 5.00x, with
   automatic club ceiling sync).

COMPATIBILITY
- SP Football Life 2026 (v1.4) & SP Football Life 2027 (Sider 7)
- Works alongside DR_ML_Budget and verified FL Mod Studio / Carabao Cup layouts.
- Do NOT run alongside Touchline Companion's MLTransferRealism.lua.

INSTALLATION
1. Copy the "modules" folder into your SiderAddons folder:
     SiderAddons\modules\TouchlineRealismMarket.lua
     SiderAddons\modules\TouchlineRealismMarket.ini

2. Open SiderAddons\sider.ini and add:
     lua.module = "TouchlineRealismMarket.lua"

3. Launch Football Life via Sider. Press Spacebar in-game, then press 1 to
   cycle to "TouchlineRealismMarket v1.0.0" in the overlay to verify status.

CONFIGURATION
Open SiderAddons\modules\TouchlineRealismMarket.ini in any text editor.
Changes hot-reload automatically within ~2 seconds while playing:

  mode              = profiles   (profiles | realistic | off)
  gk_cap            = 5          (max GKs per AI club; 0 = off)
  older_value_age   = 31         (veteran decay age; 0 = off)
  nationality_rules = 258:236    (team_id:nationality_id pairs; blank = off)
  multiplier        = 1000       (1000 = 1.00x; Modern = 2200; 2000s = 500)
  ceilings          = 1          (scale club fee ceilings with multiplier)

UNINSTALL
1. (Optional) To revert club profile fields inside an existing save first,
   set mode = off while your career is loaded, verify in the overlay, and save.
2. Remove lua.module = "TouchlineRealismMarket.lua" from sider.ini.
3. Delete TouchlineRealismMarket.lua, TouchlineRealismMarket.ini, and
   TouchlineRealismMarket.caves (if present) from SiderAddons\modules\.

LICENSE
PolyForm Noncommercial License 1.0.0 (see LICENSE file).
- Free to use and modify for personal / private noncommercial use.
- If you include, redistribute, or modify this mod in a public release or
  mod pack, you must credit and link to Touchline
  (https://github.com/ahmadsk-cell/Touchline) and keep the LICENSE and
  Required Notice line intact.
- Commercial use is not permitted.
