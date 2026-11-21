local m = { version = "1.0.0" }

-- TouchlineRealismMarket for Football Life 2026 v1.4 & Football Life 2027.
--
-- Everything runs natively inside Sider with no external companion app:
--
--   1. AI Transfer Rulebook Retune (18 patches):
--      - Clubs buy to their level instead of cheap depth well below it.
--      - Default search ages shift from 15-63 to 17-35; target score rewards
--        prime players (22-29) instead of teenagers; five age-rule windows are
--        tightened to realistic bands.
--      - Free-agent veto lifted and prospect rule searches free agents first.
--
--   2. Deal-Check Cave (TLN2):
--      - Caps AI clubs at 5 goalkeepers (configurable via gk_cap).
--      - Enforces club nationality policies (e.g. Athletic Club = Spanish
--        players only) in profiles mode, never limiting the user's own club.
--
--   3. Older-Player Value Decay Cave (TLV1):
--      - From age 31 (configurable via older_value_age), a player with a
--        database value anchor is worth the lower of that anchor and the
--        game's own age-aware (27/age)^2 formula.
--
--   4. Club Transfer Profiles (live 0x690 team table, in profiles mode):
--      - Sets realistic fee ceilings, size tiers, selling/loan-developer
--        policies, target age mixes, multi-club partners and rivalries for
--        51 major clubs (35 European & Saudi, 16 Brazilian).
--      - Sets realistic ceilings for all 20 MLS clubs.
--      - Caps other ranked clubs' fee ceilings and size tiers by live world
--        ranking, fixes blank (0 = unlimited) fee ceilings, and caps youth
--        squad targets at 45%.
--      - Keeps an in-session journal of every replaced field and restores the
--        game's bytes if mode is switched back to realistic or off.
--      - Supports stock FL26/FL27 and verified relocated (FL Mod Studio /
--        Carabao Cup) team tables; refuses unverified layouts cleanly.
--
--   5. Market Valuation Era Cave (TLM1, optional via [market_value]):
--      - Scales every player value, fee, AI ceiling and season fixed budget by
--        one era multiplier (e.g. 1990s x0.3, 2000s x0.5, 2010s x0.75,
--        Game 2020 x1.0, Modern 2026 x2.2, or any custom 100..5000).
--
-- Config: modules\TouchlineRealismMarket.ini (hot-reloaded every ~2 seconds).
--
-- Safety rules for FL26/FL27 Sider Lua:
--   - No pcall (FL26's Lua environment disables it).
--   - No tonumber(s, 16) on multi-digit hex (LuaJIT saturates at 0xFFFFFFFF).
--   - Never read unmapped memory: image reads are checked with in_image(),
--     and hooked sites are adopted ONLY if they jump into a cave we recorded.

local CONFIG_REL = "modules\\TouchlineRealismMarket.ini"
local CAVES_REL  = "modules\\TouchlineRealismMarket.caves"

-- Module-base anchors. If another mod (e.g. DR_ML_Budget) hooks 0xEA4C58,
-- we fall back to checking the four NAT_CALLEES signatures at 0x140000000.
local BUDGET_BYTES = "\x8B\x87\xF4\xCB\x6E\x01\x89\x45\xC4\x48\x8D\x55\xC4\x48\x8D\x4D\xD0"
local ANCHOR_RVA = 0x00EA4C58
local EXPECTED_MODULE_BASE = 0x140000000

-- ── 1. AI Transfer Rulebook Patches (18 sites) ──────────────────────────────
local PATCHES = {
    { name = "default_ages", rva = 0xF2814F, original = "\x66\xC7\x44\x24\x08\x0F\x3F", realistic = "\x66\xC7\x44\x24\x08\x11\x23" },
    { name = "score_age_cap", rva = 0xFB4FFB, original = "\x3C\x1B", realistic = "\x3C\x1D" },
    { name = "score_prime", rva = 0xFB5002, original = "\x3C\x13\x77\x09", realistic = "\x3C\x15\x76\x09" },
    { name = "prospect_rating", rva = 0xFB1E24, original = "\x41\xB8\x41\x00\x00\x00", realistic = "\x41\xB8\x46\x00\x00\x00" },
    { name = "prospect_ages", rva = 0xFB1E90, original = "\x66\xC7\x80\xC2\x06\x00\x00\x0F\x13", realistic = "\x66\xC7\x80\xC2\x06\x00\x00\x10\x13" },
    { name = "rejuvenate_ages", rva = 0xFB1D48, original = "\x66\xC7\x80\xC2\x06\x00\x00\x0F\x1B", realistic = "\x66\xC7\x80\xC2\x06\x00\x00\x15\x1C" },
    { name = "successor_ages", rva = 0xFB1F42, original = "\x66\xC7\x80\xC2\x06\x00\x00\x0F\x20", realistic = "\x66\xC7\x80\xC2\x06\x00\x00\x14\x1F" },
    { name = "young_star_ages", rva = 0xFB2684, original = "\x66\xC7\x80\xC2\x06\x00\x00\x0F\x17", realistic = "\x66\xC7\x80\xC2\x06\x00\x00\x13\x1B" },
    { name = "age_band_young", rva = 0xFB3DFD, original = "\x66\xC7\x80\xC2\x06\x00\x00\x0F\x17", realistic = "\x66\xC7\x80\xC2\x06\x00\x00\x11\x17" },
    { name = "score_level_floor", rva = 0xFB4F2F, original = "\x41\x83\xC4\xFB", realistic = "\x41\x83\xC4\xFE" },
    { name = "score_level_test", rva = 0xFB4FCF, original = "\x7C\x03", realistic = "\x7F\x03" },
    { name = "upgrade_floor", rva = 0xFB1C7C, original = "\x41\x80\xE8\x05", realistic = "\x41\x80\xE8\x02" },
    { name = "successor_floor", rva = 0xFB1F79, original = "\x45\x8D\x42\xFB", realistic = "\x45\x8D\x42\xFD" },
    { name = "rule11_pools", rva = 0xFB1DDB, original = "\x48\x8D\x15\x7E\xB6\x84\x01", realistic = "\x48\x8D\x15\x5E\xB6\x84\x01" },
    { name = "prospect_pool_list", rva = 0x27FD460, original = "\x01\x00\x00\x00\x04\x00\x00\x00\x06\x00\x00\x00\x00\x00\x00\x00", realistic = "\x02\x00\x00\x00\x01\x00\x00\x00\x03\x00\x00\x00\x06\x00\x00\x00" },
    { name = "prospect_pools", rva = 0xFB1EE3, original = "\x48\x8D\x15\x66\xB5\x84\x01", realistic = "\x48\x8D\x15\x76\xB5\x84\x01" },
    { name = "prospect_pool_count", rva = 0xFB1ED7, original = "\x41\xB8\x03\x00\x00\x00", realistic = "\x41\xB8\x04\x00\x00\x00" },
    { name = "free_agent_veto", rva = 0xF2D689, original = "\x75\x22", realistic = "\xEB\x22" },
}

-- ── 2. AI Deal-Check Cave (Nationality Policies + GK Cap, TLN2) ─────────────
local NAT_SITE_RVA = 0xF2CFA0
local NAT_SITE_BYTES = "\x48\x8B\xC4\x44\x89\x48\x20\x4C\x89\x40\x18\x89\x50\x10"
local NAT_CALLEES = {
    { name = "world", rva = 0x14B6A60, bytes = "\x48\x8B\x05\xA9\xF3\x24\x02\xC3" },
    { name = "player", rva = 0x14BB2A0, bytes = "\x48\x89\x54\x24\x10\x53\x48\x83" },
    { name = "club context", rva = 0xF2B670, bytes = "\x89\x54\x24\x10\x4C\x8B\xDC\x57" },
    { name = "position list", rva = 0xF5D4F0, bytes = "\x41\x56\x41\x57\x48\x83\xEC\x28" },
}
local NAT_DATA = {
    { at = 0x000, rva = 0x14B6A60 },
    { at = 0x008, rva = 0x14BB2A0 },
    { at = 0x010, rva = 0xF2CFAE },
    { at = 0x100, rva = 0xF2B670 },
    { at = 0x108, rva = 0xF5D4F0 },
}
local NAT_CAVE_SIZE = 0x400
local NAT_MAGIC_AT, NAT_MAGIC = 0x018, "TLN2"
local NAT_ARMED, NAT_COUNT, NAT_VETOES, NAT_CHECKS = 0x01C, 0x020, 0x024, 0x028
local NAT_TABLE, NAT_MAX_CLUBS, NAT_CODE = 0x040, 24, 0x140
local NAT_GK_CAP, NAT_GK_CHECKS, NAT_GK_VETOES = 0x110, 0x114, 0x118
local NAT_DEFAULT_GK_LIMIT = 5
local NAT_CODE_HEX =
    "4D31D2833DD2FEFFFF010F854A00000089D0C1E80E4C8D15E4FEFFFF448B1DBDFEFFFF4183FB180F" ..
    "872A0000004585DB0F842100000066413B020F840C0000004983C20841FFCBE9E1FFFFFFFF0596FE" ..
    "FFFFE9100000004D31D2833D6FFFFFFF000F84E600000051524150415141524883EC20FF1547FEFF" ..
    "FF488B4848488B542430FF1540FEFFFF4C8B5424204D85D20F84330000000FB7884401000066413B" ..
    "4A020F842100000066413B4A040F841600000066413B4A060F840B000000FF0520FEFFFFE9690000" ..
    "00833D00FFFFFF000F846B0000000FB64807C1E9040F855E000000FF05EBFEFFFF488B4C24408B54" ..
    "2438FF15C8FEFFFF4885C00F84400000004889C131D2FF15BCFEFFFF4885C00F842C000000488B48" ..
    "08482B0848C1F9033B0DAAFEFFFF0F8215000000FF05A6FEFFFF4883C420415A415941585A59B001" ..
    "C34883C420415A415941585A59488BC4448948204C894018895010FF256FFDFFFF"

-- ── 3. Older-Player Market Value Decay Cave (TLV1) ──────────────────────────
local VAL_SITES = {
    { name = "anchored value", rva = 0x15691A8, code_at = 0x040,
      bytes = "\x66\x0F\x6E\xCE\x0F\x5B\xC9\xF3\x0F\x59\xC1\xF3\x0F\x2C\xC8" },
    { name = "formula value", rva = 0x1569223, code_at = 0x100,
      bytes = "\xF3\x0F\x59\xF1\xF3\x0F\x59\xC6\x0F\x28\x74\x24\x20\xF3\x0F\x2C\xC8" },
}
local VAL_DATA = {
    { at = 0x000, rva = 0x15691B7 },
    { at = 0x008, rva = 0x15691BC },
    { at = 0x010, rva = 0x1569234 },
}
local VAL_CAVE_SIZE = 0x200
local VAL_MAGIC_AT, VAL_MAGIC = 0x018, "TLV1"
local VAL_ARMED, VAL_AGE, VAL_CHECKED, VAL_LOWERED = 0x01C, 0x020, 0x024, 0x028
local VAL_DEFAULT_AGE_FROM = 31
local VAL_CODE_HEX = {
    "660F6ECE0F5BC9F30F59C1F30F2CC8833DC6FFFFFF01752883F9647E230FB64424703B05B8FFFFFF" ..
    "7216F30F11442478897C247CFF05AAFFFFFFFF2588FFFFFFFF257AFFFFFF",
    "F30F59F1F30F59C60F28742420F30F2CC8397C247C751CC744247C00000000F30F2C4424783BC87D" ..
    "08FF05F9FEFFFFEB028BC8FF25D7FEFFFF",
}
local ABS_JUMP = "\xFF\x25\x00\x00\x00\x00"

-- ── 4. Market Valuation Era Cave (TLM1) ─────────────────────────────────────
local MKT_SITES = {
    { name = "value exit", rva = 0x1569249, code_at = 0x080, bytes = "\x4C\x8B\x74\x24\x30\x48\x8B\x6C\x24\x68\x48\x83\xC4\x38" },
    { name = "fee ceiling", rva = 0xEEC338, code_at = 0x180, bytes = "\x8B\x8D\x98\x05\x00\x00\x85\xC9\x7E\x1D\x3B\xD9\x7C\x19" },
    { name = "bidder ceiling", rva = 0xF63A33, code_at = 0x200, bytes = "\x8B\x88\x48\x06\x00\x00\x85\xC9\x7E\x05\x41\x3B\xCD\x7C\x0E" },
    { name = "deal veto", rva = 0xF2D3C6, code_at = 0x280, bytes = "\x44\x8B\x61\x0C\x41\x81\xFC\x00\xD4\x30\x00\x7E\x27\x48\x8D\x4C\x24\x28" },
    { name = "season budget", rva = 0x1566867, code_at = 0x300, bytes = "\x48\x8B\x45\x07\x8B\x80\x44\x06\x00\x00\x85\xC0\x7F\x67" },
}
local MKT_DATA = {
    { at = 0x000, rva = 0x1569257 },
    { at = 0x008, rva = 0xEEC346 },
    { at = 0x010, rva = 0xEEC35F },
    { at = 0x018, rva = 0xF63A42 },
    { at = 0x020, rva = 0xF63A50 },
    { at = 0x028, rva = 0xF2D3D8 },
    { at = 0x030, rva = 0xF2D3FA },
    { at = 0x060, rva = 0x15668DC },
    { at = 0x068, rva = 0x1566875 },
}
local MKT_CODE_HEX = {
    [0x080] =
        "833DB5FFFFFF010F8587000000FF05BDFFFFFF8BC88B05A5FFFFFF480FAFC1448B05A6FFFFFF4585" ..
        "C07449448B4C24644C8D154903000031D24439C27336428D0C02D1E9458B1CCA4539CB721D772041" ..
        "8B4CCA04FF057AFFFFFF480FAFC131D2B9E803000048F7F1EB0A8D5101EBCA4189C8EBC531D2B9E8" ..
        "03000048F7F1483D9CE0F5057605B89CE0F50585C07505B8010000004C8B742430488B6C24684883" ..
        "C438FF25D8FEFFFF",
    [0x180] =
        "8B8D9805000085C97E46833DB7FEFFFF0175338BC18B15A5FEFFFF480FAFC231D2B9E803000048F7" ..
        "F1B9FFFFFF7F4839C876028BC18BC885C97505B901000000FF0592FEFFFF3BD97C06FF2538FEFFFF" ..
        "FF253AFEFFFF",
    [0x200] =
        "8B884806000085C97E41833D37FEFFFF0175338BC18B1525FEFFFF480FAFC231D2B9E803000048F7" ..
        "F1B9FFFFFF7F4839C876028BC18BC885C97505B901000000FF0512FEFFFF413BCD7C06FF25C7FDFF" ..
        "FFFF25C9FDFFFF",
    [0x280] =
        "448B610C833DBDFDFFFF01751A50524489E04869C0E803000031D248F7359EFDFFFF4189C45A5841" ..
        "81FC00D430007E0B488D4C2428FF256DFDFFFFFF256FFDFFFF",
    [0x300] =
        "488B45078B8044060000B9E8030000833D26FDFFFF0175068B0D22FDFFFF890D4CFDFFFFFF054AFD" ..
        "FFFF85C07E3B833D07FDFFFF01752C8BC88B0501FDFFFF480FAFC131D2B9E803000048F7F1483DFF" ..
        "E0F5057605B8FFE0F50585C07505B801000000FF25F7FCFFFFFF25F9FCFFFF",
}
local MKT_CAVE_SIZE = 0x8400
local MKT_MAGIC_AT, MKT_MAGIC = 0x038, "TLM1"
local MKT_ARMED, MKT_MULT, MKT_SYNC, MKT_COUNT = 0x03C, 0x040, 0x048, 0x04C
local MKT_SCALED, MKT_CEILINGS = 0x050, 0x058
local MKT_MULT_MIN, MKT_MULT_MAX = 100, 5000

-- ── 5. Club Transfer Profiles (Live 0x690 Team Table) ───────────────────────
local WORLD_HOLDER_RVA = 0x03705E10
local WORLD_CONTEXT_OFFSET = 0x48
local WORLD_ACCESSOR_RVA = 0x014B6A60
local WORLD_ACCESSOR_BYTES = "\x48\x8B\x05\xA9\xF3\x24\x02\xC3"

local STOCK_PLAYER_COUNT = 30001
local PLAYER_STRIDE = 0x17C
local STOCK_TEAM_TABLE = 0x00ADF4BC
local STOCK_TEAM_COUNT = 751
local STOCK_COUNT_WORDS = 0x00D0BCE8
local STOCK_CAREER_DATE = 0x01642A24
local STOCK_RANKING_OFFSET = 0x016705A8
local RANKING_STRIDE = 0x10
local RANKING_MIN_ROWS = 300
local RANKING_MAX_ROWS = 1490
local MAX_PLAYER_COUNT = 131072
local MAX_TEAM_COUNT = 0x3FFF
local MAX_TEAM_ID = 0x3FFFF

-- Instruction sites read to detect stock vs relocated (FL Mod Studio / Carabao Cup) layouts.
local DATE_SITE_RVA, DATE_SITE_PREFIX = 0x015765F2, "\x8B\x82"
local TEAM_SITE_RVA, TEAM_SITE_PREFIX = 0x012691BD, "\x48\x81\xC1"
local COUNT_SITE_RVA, COUNT_SITE_PREFIX = 0x014BC9C8, "\x8B\x81"

-- Every club-lookup site in the game (must agree before writing to a relocated career).
local CLUB_SITES = {
    { rva = 0x012691BD, prefix = "\x48\x81\xC1", kind = "team" },
    { rva = 0x014BCADE, prefix = "\x49\x8D\xB8", kind = "team" },
    { rva = 0x014BCB24, prefix = "\x41\x8B\x80", kind = "team_count_word" },
    { rva = 0x014BCB2B, prefix = "\x49\x8D\x90", kind = "team" },
    { rva = 0x014BCB3C, prefix = "\x49\x8D\x88", kind = "team" },
    { rva = 0x014BB5CC, prefix = "\x81\xF9",     kind = "team_cap" },
    { rva = 0x014BB5E2, prefix = "\x48\x05",     kind = "team" },
    { rva = 0x014BB5ED, prefix = "\x48\x8D\x83", kind = "outside_players" },
    { rva = 0x014BB5FA, prefix = "\x8B\x83",     kind = "team_count_word" },
    { rva = 0x014BB600, prefix = "\x48\x8D\x93", kind = "team" },
    { rva = 0x014BB611, prefix = "\x48\x8D\x8B", kind = "team" },
}

-- Team record (0x690 bytes) field offsets & constants.
local CP_RECORD_SIZE    = 0x690
local CP_FLAGS_AT       = 0x63C
local CP_FEE_CEILING_AT = 0x648
local CP_AGE_MIX_AT     = 0x655
local CP_PARTNERS_AT    = 0x678
local CP_RIVALS_AT      = 0x684
local CP_NO_CLUB        = 0xFFFFFFFF
local CP_FEE_PER_M      = 10000          -- EUR 1M = 10,000 save units (100 EUR each)
local CP_YOUTH_CAP      = 45

-- Rank caps for non-profiled clubs: { max_rank, max_fee_m (nil=none), tier_floor (nil=none) }
local CP_RANK_CAPS = {
    { 40, nil, nil },
    { 80, 40, 3 },
    { 150, 20, 5 },
    { 300, 8, 7 },
    { 1000000000, 4, 9 },
}
-- Blank (0 = unlimited) fee ceiling replacement by rank (EUR M).
local CP_BLANK_CEILINGS = {
    { 40, 25 },
    { 80, 12 },
    { 150, 6 },
    { 300, 3 },
    { 1000000000, 1 },
}
-- 20 MLS club ceilings (EUR M).
local CP_MLS_CEILINGS = {
    [5738] = 8, -- Inter Miami CF
    [5741] = 8, -- Los Angeles FC
    [5736] = 8, -- Atlanta United FC
    [4155] = 5, -- Los Angeles Galaxy
    [4163] = 5, -- Seattle Sounders
    [5737] = 5, -- FC Cincinnati
    [5061] = 5, -- New York City
    [5739] = 4, -- Nashville SC
    [5740] = 4, -- Austin FC
    [4151] = 4, -- Columbus Crew
    [4160] = 4, -- Portland Timbers
    [4158] = 4, -- New York RB
    [5062] = 4, -- Orlando City
    [4148] = 3, -- Chicago Fire FC
    [4157] = 3, -- New England Revolution
    [4164] = 3, -- Sporting Kansas City
    [4166] = 3, -- Vancouver Whitecaps
    [4153] = 3, -- FC Dallas
    [4162] = 2, -- San Jose Earthquakes
    [4156] = 2, -- CF Montréal
}

-- 51 hand-written club profiles: policy 0 = normal, 1 = selling, 2 = loan_developer.
local CP_PROFILES = {
    -- Spain
    [109]  = { tier = 1, policy = 2, fee_m = 150, ages = { 25, 55, 20 }, partners = {}, rivals = { 108, 172 } },
    [108]  = { tier = 1, policy = 2, fee_m = 80,  ages = { 35, 50, 15 }, partners = {}, rivals = { 109, 259 } },
    [172]  = { tier = 2, policy = 2, fee_m = 75,  ages = { 25, 50, 25 }, partners = {}, rivals = { 109 } },
    [258]  = { tier = 3, policy = 0, fee_m = 40,  ages = { 35, 45, 20 }, partners = {}, rivals = { 196 } },
    [196]  = { tier = 3, policy = 1, fee_m = 40,  ages = { 40, 45, 15 }, partners = {}, rivals = { 258 } },
    [265]  = { tier = 3, policy = 1, fee_m = 25,  ages = { 30, 45, 25 }, partners = {}, rivals = { 194 } },
    [267]  = { tier = 3, policy = 1, fee_m = 35,  ages = { 35, 45, 20 }, partners = {}, rivals = { 110 } },
    -- England
    [173]  = { tier = 1, policy = 2, fee_m = 120, ages = { 25, 55, 20 }, partners = { 2187, 2453, 420 }, rivals = { 100 } },
    [101]  = { tier = 1, policy = 2, fee_m = 110, ages = { 30, 55, 15 }, partners = {}, rivals = { 179, 102 } },
    [103]  = { tier = 1, policy = 2, fee_m = 130, ages = { 30, 50, 20 }, partners = {}, rivals = { 100, 177 } },
    [100]  = { tier = 1, policy = 2, fee_m = 100, ages = { 30, 50, 20 }, partners = { 217 }, rivals = { 173, 103 } },
    [102]  = { tier = 2, policy = 2, fee_m = 120, ages = { 45, 45, 10 }, partners = { 4213 }, rivals = { 179, 101 } },
    [179]  = { tier = 2, policy = 2, fee_m = 70,  ages = { 35, 50, 15 }, partners = {}, rivals = { 101, 102 } },
    [106]  = { tier = 2, policy = 2, fee_m = 70,  ages = { 30, 50, 20 }, partners = {}, rivals = {} },
    [107]  = { tier = 3, policy = 2, fee_m = 60,  ages = { 30, 50, 20 }, partners = {}, rivals = {} },
    -- Germany
    [127]  = { tier = 1, policy = 2, fee_m = 110, ages = { 25, 50, 25 }, partners = {}, rivals = { 126 } },
    [126]  = { tier = 2, policy = 1, fee_m = 55,  ages = { 50, 40, 10 }, partners = {}, rivals = { 127 } },
    [128]  = { tier = 2, policy = 1, fee_m = 55,  ages = { 35, 50, 15 }, partners = {}, rivals = {} },
    [5010] = { tier = 2, policy = 1, fee_m = 60,  ages = { 55, 40, 5 },  partners = { 1586, 2459 }, rivals = {} },
    -- France
    [114]  = { tier = 1, policy = 2, fee_m = 150, ages = { 30, 55, 15 }, partners = {}, rivals = { 113 } },
    [113]  = { tier = 3, policy = 2, fee_m = 30,  ages = { 25, 50, 25 }, partners = {}, rivals = { 114 } },
    [181]  = { tier = 3, policy = 1, fee_m = 30,  ages = { 45, 40, 15 }, partners = { 1246 }, rivals = {} },
    [112]  = { tier = 3, policy = 1, fee_m = 40,  ages = { 50, 40, 10 }, partners = { 2009 }, rivals = { 217 } },
    -- Italy
    [119]  = { tier = 2, policy = 2, fee_m = 50,  ages = { 20, 50, 30 }, partners = {}, rivals = { 121, 120 } },
    [121]  = { tier = 2, policy = 2, fee_m = 50,  ages = { 35, 50, 15 }, partners = {}, rivals = { 119 } },
    [120]  = { tier = 1, policy = 2, fee_m = 70,  ages = { 30, 50, 20 }, partners = {}, rivals = { 119, 333 } },
    [327]  = { tier = 2, policy = 2, fee_m = 60,  ages = { 25, 50, 25 }, partners = {}, rivals = {} },
    [125]  = { tier = 3, policy = 2, fee_m = 35,  ages = { 25, 50, 25 }, partners = {}, rivals = { 122 } },
    -- Portugal
    [191]  = { tier = 3, policy = 1, fee_m = 30,  ages = { 50, 40, 10 }, partners = {}, rivals = { 192, 193 } },
    [192]  = { tier = 3, policy = 1, fee_m = 25,  ages = { 45, 45, 10 }, partners = {}, rivals = { 191, 193 } },
    [193]  = { tier = 3, policy = 1, fee_m = 25,  ages = { 45, 45, 10 }, partners = {}, rivals = { 191, 192 } },
    -- Netherlands
    [116]  = { tier = 4, policy = 1, fee_m = 25,  ages = { 55, 35, 10 }, partners = {}, rivals = { 117, 118 } },
    [118]  = { tier = 4, policy = 1, fee_m = 20,  ages = { 50, 40, 10 }, partners = {}, rivals = { 116, 117 } },
    -- Saudi Arabia
    [1489] = { tier = 3, policy = 0, fee_m = 60,  ages = { 10, 50, 40 }, partners = {}, rivals = { 2577, 1350 } },
    [2577] = { tier = 3, policy = 0, fee_m = 60,  ages = { 10, 50, 40 }, partners = {}, rivals = { 1489, 1350 } },
    -- Brazil
    [1248] = { tier = 3, policy = 1, fee_m = 30,  ages = { 30, 40, 30 }, partners = {}, rivals = { 1249, 136, 1246 } },
    [137]  = { tier = 3, policy = 1, fee_m = 30,  ages = { 35, 40, 25 }, partners = {}, rivals = { 1247, 1255, 1254 } },
    [1246] = { tier = 4, policy = 1, fee_m = 25,  ages = { 30, 45, 25 }, partners = { 181 }, rivals = { 1248, 1249, 136 } },
    [1247] = { tier = 4, policy = 1, fee_m = 15,  ages = { 30, 40, 30 }, partners = {}, rivals = { 137, 1255, 1254 } },
    [1255] = { tier = 4, policy = 1, fee_m = 12,  ages = { 35, 35, 30 }, partners = {}, rivals = { 1247, 137, 1254 } },
    [1245] = { tier = 4, policy = 1, fee_m = 15,  ages = { 30, 40, 30 }, partners = {}, rivals = { 274 } },
    [1249] = { tier = 5, policy = 1, fee_m = 12,  ages = { 30, 35, 35 }, partners = {}, rivals = { 1248, 136, 1246 } },
    [1254] = { tier = 5, policy = 1, fee_m = 10,  ages = { 40, 35, 25 }, partners = {}, rivals = { 1247, 137, 1255 } },
    [136]  = { tier = 5, policy = 1, fee_m = 10,  ages = { 30, 40, 30 }, partners = {}, rivals = { 1248, 1249, 1246 } },
    [274]  = { tier = 5, policy = 1, fee_m = 15,  ages = { 30, 40, 30 }, partners = {}, rivals = { 1245 } },
    [1250] = { tier = 5, policy = 1, fee_m = 10,  ages = { 35, 40, 25 }, partners = {}, rivals = { 1252 } },
    [1252] = { tier = 5, policy = 1, fee_m = 12,  ages = { 35, 40, 25 }, partners = {}, rivals = { 1250 } },
    [2453] = { tier = 5, policy = 1, fee_m = 15,  ages = { 35, 45, 20 }, partners = { 173 }, rivals = { 1937 } },
    [2459] = { tier = 5, policy = 1, fee_m = 15,  ages = { 50, 40, 10 }, partners = { 5010, 1586 }, rivals = {} },
    [5143] = { tier = 6, policy = 1, fee_m = 8,   ages = { 30, 45, 25 }, partners = {}, rivals = { 2454 } },
    [1930] = { tier = 5, policy = 1, fee_m = 10,  ages = { 40, 40, 20 }, partners = {}, rivals = { 1931 } },
}

-- ── Runtime State ───────────────────────────────────────────────────────────
local module_base = nil
local anchor_searched = false
local status = "idle"
local applied_table_mode = "unknown"
local last_poll = -1

local nat_cave = nil
local nat_status = "off"
local nat_applied = nil
local gk_status = "off"

local val_cave = nil
local val_status = "off"
local val_applied = nil

local mkt_cave = nil
local mkt_status = "off"
local mkt_applied = nil

local cp_status = "waiting for career"
local cp_journal = {}
local cp_journal_career = nil
local cp_last_key = nil
local cp_clubs_changed = 0
local cp_fields_changed = 0
local cp_ranked_count = 0

-- ── Helpers ─────────────────────────────────────────────────────────────────
local function trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

-- Never tonumber(s, 16): Sider's LuaJIT saturates multi-digit hex at 0xFFFFFFFF.
local function hex_to_number(value)
    value = tostring(value or ""):gsub("%s", ""):gsub("^0[xX]", "")
    if value == "" or value:find("[^%x]") then return nil end
    local n = 0
    for i = 1, #value do n = n * 16 + tonumber(value:sub(i, i), 16) end
    return n
end

local function numeric_address(addr)
    if not addr then return nil end
    return hex_to_number(memory.hex(addr))
end

local function hex(n)
    if not n then return "nil" end
    local high = math.floor(n / 4294967296)
    return string.format("0x%X%08X", high, n - high * 4294967296)
end

local function read_exact(addr, len)
    if not addr or addr <= 0x10000 then return nil end
    local data = memory.read(addr, len)
    if data and #data == len then return data end
    return nil
end

local function read_num(addr, fmt, len)
    local data = read_exact(addr, len)
    return data and tonumber(memory.unpack(fmt, data)) or nil
end

local function write_u32(addr, value)
    memory.write(addr, memory.pack("u32", value))
end

local function in_image(addr, len)
    if not memory.get_process_info then return false end
    local info = memory.get_process_info()
    if not info or not info.sections then return false end
    for _, section in ipairs(info.sections) do
        local start, finish = numeric_address(section.start), numeric_address(section.finish)
        if start and finish and addr >= start and addr + len <= finish then return true end
    end
    return false
end

local function hex_bytes(text)
    return (text:gsub("%x%x", function(pair) return string.char(hex_to_number(pair)) end))
end

local function recorded_caves(ctx)
    local out = {}
    local f = io.open(ctx.sider_dir .. CAVES_REL, "r")
    if not f then return out end
    for line in f:lines() do
        local name, value = line:gsub("\r", ""):match("^%s*([%w_]+)%s*=%s*(%S+)")
        if name then out[name] = hex_to_number(value) end
    end
    f:close()
    return out
end

local function record_cave(ctx, name, addr)
    local caves = recorded_caves(ctx)
    caves[name] = addr
    local names = {}
    for key in pairs(caves) do names[#names + 1] = key end
    table.sort(names)
    local f = io.open(ctx.sider_dir .. CAVES_REL, "w")
    if not f then return end
    for _, key in ipairs(names) do f:write(key, "=", hex(caves[key]), "\n") end
    f:close()
end

-- ── Settings (modules\TouchlineRealismMarket.ini) ───────────────────────────
local function load_settings(ctx)
    local cfg = {
        mode = "profiles",
        gk_cap = NAT_DEFAULT_GK_LIMIT,
        older_value_age = VAL_DEFAULT_AGE_FROM,
        nationality_rules = "258:236",
        market = { multiplier = 1000, ceilings = 1 },
    }
    local f = io.open(ctx.sider_dir .. CONFIG_REL, "r")
    if not f then return cfg end
    local section = ""
    for line in f:lines() do
        line = line:gsub("\r", ""):gsub("%s*[#;].*$", "")
        local next_section = line:match("^%s*%[([^%]]+)%]")
        if next_section then
            section = trim(next_section):lower()
        elseif section == "transfer_realism" then
            local key, value = line:match("^%s*([%w%._%-]+)%s*=%s*(.-)%s*$")
            key = key and trim(key):lower() or nil
            value = value and trim(value) or ""
            if key == "mode" then
                cfg.mode = value:lower()
            elseif key == "nationality_rules" then
                cfg.nationality_rules = value
            elseif key == "gk_cap" then
                local n = tonumber(value)
                if n then cfg.gk_cap = math.max(0, math.min(99, math.floor(n))) end
            elseif key == "older_value_age" then
                local n = tonumber(value)
                if n then cfg.older_value_age = math.max(0, math.min(50, math.floor(n))) end
            end
        elseif section == "market_value" then
            local key, value = line:match("^%s*([%w%._%-]+)%s*=%s*(.-)%s*$")
            key = key and trim(key):lower() or nil
            value = value and trim(value) or ""
            if key == "multiplier" then
                local n = tonumber(value)
                if n then cfg.market.multiplier = n end
            elseif key == "ceilings" then
                cfg.market.ceilings = (value == "0" or value:lower() == "false" or value:lower() == "off") and 0 or 1
            end
        end
    end
    f:close()
    if cfg.mode ~= "profiles" and cfg.mode ~= "realistic" and cfg.mode ~= "off" then
        cfg.mode = "profiles"
    end
    local mult = math.floor(cfg.market.multiplier + 0.5)
    if mult < MKT_MULT_MIN then mult = MKT_MULT_MIN end
    if mult > MKT_MULT_MAX then mult = MKT_MULT_MAX end
    cfg.market.multiplier = mult
    return cfg
end

-- ── Module Base & Cave Helpers ──────────────────────────────────────────────
local function callees_match(base, callees)
    for _, callee in ipairs(callees) do
        local addr = base + callee.rva
        if not (in_image(addr, #callee.bytes) and read_exact(addr, #callee.bytes) == callee.bytes) then
            return callee.name .. " routine differs; unsupported game build"
        end
    end
    return nil
end

local function locate_module_base()
    if module_base then return module_base end
    local expected = EXPECTED_MODULE_BASE + ANCHOR_RVA
    if in_image(expected, #BUDGET_BYTES) and read_exact(expected, #BUDGET_BYTES) == BUDGET_BYTES then
        module_base = EXPECTED_MODULE_BASE
        return module_base
    end
    -- Fallback when another mod (e.g. DR_ML_Budget) has hooked 0xEA4C58:
    -- verify the build via the four engine routines we know at 0x140000000.
    if not callees_match(EXPECTED_MODULE_BASE, NAT_CALLEES) then
        module_base = EXPECTED_MODULE_BASE
        return module_base
    end
    if not anchor_searched then
        anchor_searched = true
        local anchor = numeric_address(memory.search_process(BUDGET_BYTES))
        if anchor and anchor - ANCHOR_RVA == EXPECTED_MODULE_BASE then
            module_base = EXPECTED_MODULE_BASE
        end
    end
    return module_base
end

local function new_cave(size, base, data, magic_at, magic, codes)
    local cave = numeric_address(memory.allocate_codecave(size))
    if not cave or cave <= 0x10000 then return nil end
    memory.write(cave, string.rep("\0", size))
    for _, item in ipairs(data) do
        memory.write(cave + item.at, memory.pack("u64", base + item.rva))
    end
    for at, code in pairs(codes) do memory.write(cave + at, code) end
    memory.write(cave + magic_at, magic)
    return cave
end

local function jump_target(site_addr)
    local current = read_exact(site_addr, #ABS_JUMP + 8)
    if not current or current:sub(1, #ABS_JUMP) ~= ABS_JUMP then return nil end
    return read_num(site_addr + #ABS_JUMP, "u64", 8)
end

-- ── 1. Rulebook Patches Apply / Restore ─────────────────────────────────────
local function write_changed(addr, current, wanted)
    local first, last = nil, nil
    for i = 1, #wanted do
        if current:sub(i, i) ~= wanted:sub(i, i) then
            first = first or i
            last = i
        end
    end
    if first then memory.write(addr + first - 1, wanted:sub(first, last)) end
end

local function apply_rulebook(table_mode)
    local base = locate_module_base()
    if not base then
        status = "game build not recognised; nothing changed"
        return
    end
    local currents = {}
    for i, patch in ipairs(PATCHES) do
        local addr = base + patch.rva
        local current = in_image(addr, #patch.original) and read_exact(addr, #patch.original) or nil
        if current ~= patch.original and current ~= patch.realistic then
            status = patch.name .. " site changed by another mod or build; nothing changed"
            return
        end
        currents[i] = current
    end
    local written = 0
    log("TouchlineRealismMarket: writing the " .. table_mode .. " rulebook tables")
    local first, last, step = 1, #PATCHES, 1
    if table_mode ~= "realistic" then first, last, step = #PATCHES, 1, -1 end
    for i = first, last, step do
        local patch = PATCHES[i]
        local wanted = table_mode == "realistic" and patch.realistic or patch.original
        if currents[i] ~= wanted then
            write_changed(base + patch.rva, currents[i], wanted)
            written = written + 1
        end
    end
    applied_table_mode = table_mode
    status = table_mode == "realistic" and "realistic tables in place" or "game tables in place"
    if written > 0 then
        log(string.format("TouchlineRealismMarket: %s (%d site(s) written)", status, written))
    end
end

-- ── 2. Deal-Check Cave (Nationality Policies + GK Cap) ──────────────────────
local function parse_rules(text, exclude_team_id)
    local rules = {}
    for part in (text or ""):gmatch("%S+") do
        local team, nations = part:match("^(%d+):([%d,]+)$")
        local tid = team and tonumber(team) or 0
        local list = {}
        if tid > 0 and tid ~= (exclude_team_id or 0) then
            for n in nations:gmatch("%d+") do
                if #list < 3 then list[#list + 1] = tonumber(n) end
            end
        end
        if tid > 0 and tid ~= (exclude_team_id or 0) and #list > 0 and #rules < NAT_MAX_CLUBS then
            while #list < 3 do list[#list + 1] = list[1] end
            rules[#rules + 1] = { tid, list[1], list[2], list[3] }
        end
    end
    return rules
end

local function nat_code_bytes() return hex_bytes(NAT_CODE_HEX) end

local function nat_existing(ctx, site_addr)
    local stub = jump_target(site_addr)
    local cave = recorded_caves(ctx).nat
    if not stub or not cave or stub ~= cave + NAT_CODE then return nil end
    if read_exact(cave + NAT_MAGIC_AT, #NAT_MAGIC) ~= NAT_MAGIC then return nil end
    if read_exact(cave + NAT_CODE, #NAT_CODE_HEX / 2) ~= nat_code_bytes() then return nil end
    return cave
end

local function nat_install(ctx, base)
    if nat_cave then return true end
    local refused = callees_match(base, NAT_CALLEES)
    if refused then nat_status = refused; return false end
    local site = base + NAT_SITE_RVA
    if not in_image(site, #NAT_SITE_BYTES) then
        nat_status = "deal check not found; unsupported game build"
        return false
    end
    local cave = nil
    local current = read_exact(site, #NAT_SITE_BYTES)
    if current ~= NAT_SITE_BYTES then
        cave = nat_existing(ctx, site)
        if not cave then
            nat_status = "deal check changed by another mod; nothing changed"
            return false
        end
    end
    if cave == nil then
        cave = new_cave(NAT_CAVE_SIZE, base, NAT_DATA, NAT_MAGIC_AT, NAT_MAGIC, { [NAT_CODE] = nat_code_bytes() })
        if not cave then
            nat_status = "code cave allocation failed"
            return false
        end
        record_cave(ctx, "nat", cave)
        log("TouchlineRealismMarket: patching deal check at " .. hex(site) .. " -> cave " .. hex(cave))
        memory.write(site, ABS_JUMP .. memory.pack("u64", cave + NAT_CODE))
        log("TouchlineRealismMarket: deal check hook installed at " .. hex(cave))
    end
    nat_cave = cave
    return true
end

local function apply_deal_checks(ctx, text, gk_cap, user_team_id)
    local key = (text or "") .. "|" .. tostring(gk_cap) .. "|" .. tostring(user_team_id or 0)
    if key == nat_applied then return end
    local rules = parse_rules(text, user_team_id)
    if #rules == 0 and gk_cap == 0 then
        if nat_cave then
            write_u32(nat_cave + NAT_ARMED, 0)
            write_u32(nat_cave + NAT_GK_CAP, 0)
        end
        nat_status = nat_cave and "off (hook idle)" or "off"
        gk_status = "off"
        nat_applied = key
        return
    end
    local base = locate_module_base()
    if not base then
        nat_status = "game build not recognised"
        gk_status = nat_status
        return
    end
    nat_applied = key
    if not nat_install(ctx, base) then gk_status = nat_status; return end
    write_u32(nat_cave + NAT_ARMED, 0)
    if #rules > 0 then
        local blob = {}
        for _, rule in ipairs(rules) do
            for _, value in ipairs(rule) do blob[#blob + 1] = memory.pack("u16", value) end
        end
        memory.write(nat_cave + NAT_TABLE, table.concat(blob))
        write_u32(nat_cave + NAT_COUNT, #rules)
        log(string.format("TouchlineRealismMarket: arming deal check for %d club(s)", #rules))
        write_u32(nat_cave + NAT_ARMED, 1)
        nat_status = string.format("%d club(s) in force", #rules)
    else
        nat_status = "off (hook idle)"
    end
    write_u32(nat_cave + NAT_GK_CAP, gk_cap)
    gk_status = gk_cap > 0 and string.format("at most %d per AI club", gk_cap) or "off"
end

-- ── 3. Older-Player Value Decay Cave (TLV1) ─────────────────────────────────
local function val_install(ctx, base)
    if val_cave then return true end
    local sites, existing = {}, nil
    local recorded = recorded_caves(ctx).val
    for i, site in ipairs(VAL_SITES) do
        local addr = base + site.rva
        if not in_image(addr, #site.bytes) then
            val_status = "value routine not found; unsupported game build"
            return false
        end
        local current = read_exact(addr, #site.bytes)
        if current == site.bytes then
            sites[i] = "game"
        else
            local stub = jump_target(addr)
            local cave = stub and recorded and stub == recorded + site.code_at and recorded or nil
            if not (cave and read_exact(cave + VAL_MAGIC_AT, #VAL_MAGIC) == VAL_MAGIC
                    and read_exact(cave + site.code_at, #VAL_CODE_HEX[i] / 2) == hex_bytes(VAL_CODE_HEX[i])
                    and (existing == nil or existing == cave)) then
                val_status = site.name .. " changed by another mod; nothing changed"
                return false
            end
            existing = cave
            sites[i] = "ours"
        end
    end
    if existing and (sites[1] ~= "ours" or sites[2] ~= "ours") then
        val_status = "value hooks half in place; nothing changed"
        return false
    end
    if existing then
        val_cave = existing
        return true
    end
    local codes = {}
    for i, site in ipairs(VAL_SITES) do codes[site.code_at] = hex_bytes(VAL_CODE_HEX[i]) end
    local cave = new_cave(VAL_CAVE_SIZE, base, VAL_DATA, VAL_MAGIC_AT, VAL_MAGIC, codes)
    if not cave then
        val_status = "code cave allocation failed"
        return false
    end
    record_cave(ctx, "val", cave)
    -- Hook B first: idle until hook A tags a player.
    for i = #VAL_SITES, 1, -1 do
        local site = VAL_SITES[i]
        local jump = ABS_JUMP .. memory.pack("u64", cave + site.code_at)
        log("TouchlineRealismMarket: patching " .. site.name .. " at " .. hex(base + site.rva) .. " -> cave " .. hex(cave))
        memory.write(base + site.rva, jump .. string.rep("\x90", #site.bytes - #jump))
    end
    log("TouchlineRealismMarket: older-player value hooks installed at " .. hex(cave))
    val_cave = cave
    return true
end

local function apply_values(ctx, age_from)
    local key = tostring(age_from or 0)
    if key == val_applied then return end
    if not age_from or age_from <= 0 then
        if val_cave then write_u32(val_cave + VAL_ARMED, 0) end
        val_status = val_cave and "off (hook idle)" or "off"
        val_applied = key
        return
    end
    local base = locate_module_base()
    if not base then val_status = "game build not recognised"; return end
    val_applied = key
    if not val_install(ctx, base) then return end
    write_u32(val_cave + VAL_AGE, age_from)
    log(string.format("TouchlineRealismMarket: arming older-player value hooks from age %d", age_from))
    write_u32(val_cave + VAL_ARMED, 1)
    val_status = string.format("from age %d", age_from)
end

-- ── 4. Market Valuation Era Cave (TLM1) ─────────────────────────────────────
local function mkt_install(ctx, base)
    if mkt_cave then return true end
    local existing, game = nil, 0
    local recorded = recorded_caves(ctx).mkt
    for _, site in ipairs(MKT_SITES) do
        local addr = base + site.rva
        if not in_image(addr, #site.bytes) then
            mkt_status = site.name .. " not found; unsupported game build"
            return false
        end
        if read_exact(addr, #site.bytes) == site.bytes then
            game = game + 1
        else
            local stub = jump_target(addr)
            local cave = stub and recorded and stub == recorded + site.code_at and recorded or nil
            local code = hex_bytes(MKT_CODE_HEX[site.code_at])
            if not (cave and read_exact(cave + MKT_MAGIC_AT, #MKT_MAGIC) == MKT_MAGIC
                    and read_exact(cave + site.code_at, #code) == code
                    and (existing == nil or existing == cave)) then
                mkt_status = site.name .. " changed by another mod; nothing changed"
                return false
            end
            existing = cave
        end
    end
    if existing and game > 0 then
        mkt_status = "market hooks half in place; nothing changed"
        return false
    end
    if existing then
        mkt_cave = existing
        return true
    end
    local codes = {}
    for at, text in pairs(MKT_CODE_HEX) do codes[at] = hex_bytes(text) end
    local cave = new_cave(MKT_CAVE_SIZE, base, MKT_DATA, MKT_MAGIC_AT, MKT_MAGIC, codes)
    if not cave then
        mkt_status = "code cave allocation failed"
        return false
    end
    write_u32(cave + MKT_MULT, 1000)
    record_cave(ctx, "mkt", cave)
    for _, site in ipairs(MKT_SITES) do
        local jump = ABS_JUMP .. memory.pack("u64", cave + site.code_at)
        log("TouchlineRealismMarket: patching " .. site.name .. " at " .. hex(base + site.rva) .. " -> cave " .. hex(cave))
        memory.write(base + site.rva, jump .. string.rep("\x90", #site.bytes - #jump))
    end
    log("TouchlineRealismMarket: market value hooks installed at " .. hex(cave))
    mkt_cave = cave
    return true
end

local function apply_market(ctx, market)
    local wanted = market.multiplier ~= 1000
    local key = string.format("%d|%d", market.multiplier, market.ceilings)
    if key == mkt_applied then return end
    if not wanted then
        if mkt_cave then
            write_u32(mkt_cave + MKT_ARMED, 0)
            write_u32(mkt_cave + MKT_SYNC, 0)
            write_u32(mkt_cave + MKT_MULT, 1000)
        end
        mkt_status = mkt_cave and "off (hook idle)" or "off"
        mkt_applied = key
        return
    end
    local base = locate_module_base()
    if not base then mkt_status = "game build not recognised"; return end
    mkt_applied = key
    if not mkt_install(ctx, base) then return end
    write_u32(mkt_cave + MKT_MULT, market.multiplier)
    write_u32(mkt_cave + MKT_COUNT, 0)
    write_u32(mkt_cave + MKT_SYNC, market.ceilings)
    write_u32(mkt_cave + MKT_ARMED, 1)
    mkt_status = string.format("x%.2f%s", market.multiplier / 1000,
        market.ceilings == 1 and " (ceilings synced)" or "")
end

-- ── 5. Club Transfer Profiles (Live 0x690 Team Table) ───────────────────────
local function read_site_u32(base, rva, prefix)
    local addr = base + rva
    if not in_image(addr, #prefix + 4) then return nil end
    local data = read_exact(addr, #prefix + 4)
    if not data or data:sub(1, #prefix) ~= prefix then return nil end
    return tonumber(memory.unpack("u32", data:sub(#prefix + 1, #prefix + 4)))
end

local function verify_relocated_club_sites(base, team_at, count_at, player_count, team_count)
    local player_bytes = player_count * PLAYER_STRIDE
    for _, site in ipairs(CLUB_SITES) do
        local found = read_site_u32(base, site.rva, site.prefix)
        if not found then
            return false, string.format("club lookup at 0x%X changed", site.rva)
        end
        if site.kind == "team" and found ~= team_at then
            return false, string.format("club lookup at 0x%X disagrees with team table", site.rva)
        elseif site.kind == "team_count_word" and found ~= count_at + 4 then
            return false, string.format("club count lookup at 0x%X disagrees", site.rva)
        elseif site.kind == "team_cap" and found < team_count - 1 then
            return false, string.format("club slot cap at 0x%X below team count", site.rva)
        elseif site.kind == "outside_players" and found < player_bytes then
            return false, string.format("sentinel lookup at 0x%X inside player table", site.rva)
        end
    end
    return true, nil
end

-- Locate the live Master League career block, team table, date, and user team id.
-- Returns nil, reason if no career is loaded or the layout is unverified.
local function locate_live_career(base)
    if not (in_image(base + WORLD_ACCESSOR_RVA, #WORLD_ACCESSOR_BYTES)
            and read_exact(base + WORLD_ACCESSOR_RVA, #WORLD_ACCESSOR_BYTES) == WORLD_ACCESSOR_BYTES) then
        return nil, "world accessor differs; unsupported build"
    end
    local holder = read_num(base + WORLD_HOLDER_RVA, "u64", 8)
    if not holder or holder <= 0x10000 then return nil, "waiting for career" end
    local career = read_num(holder + WORLD_CONTEXT_OFFSET, "u64", 8)
    if not career or career <= 0x10000 then return nil, "waiting for career" end

    local date_at  = read_site_u32(base, DATE_SITE_RVA, DATE_SITE_PREFIX)
    local team_at  = read_site_u32(base, TEAM_SITE_RVA, TEAM_SITE_PREFIX)
    local count_at = read_site_u32(base, COUNT_SITE_RVA, COUNT_SITE_PREFIX)
    if not (date_at and team_at and count_at) then
        return nil, "layout instructions differ; profiles skipped"
    end

    local stock = (date_at == STOCK_CAREER_DATE and team_at == STOCK_TEAM_TABLE and count_at == STOCK_COUNT_WORDS)
    local team_count = STOCK_TEAM_COUNT
    if not stock then
        local p_cnt = read_num(career + count_at, "u32", 4)
        local t_cnt = read_num(career + count_at + 4, "u32", 4)
        if not (p_cnt and t_cnt and p_cnt >= 1000 and p_cnt <= MAX_PLAYER_COUNT
                and t_cnt >= 1 and t_cnt <= MAX_TEAM_COUNT and p_cnt * PLAYER_STRIDE <= team_at) then
            return nil, "waiting for career"
        end
        local ok, why = verify_relocated_club_sites(base, team_at, count_at, p_cnt, t_cnt)
        if not ok then return nil, "relocated layout refused: " .. why end
        team_count = t_cnt
    end

    -- Verify plausible career date (year | month << 16 | day << 24).
    local date_word = read_num(career + date_at, "u32", 4)
    if not date_word then return nil, "waiting for career" end
    local year  = date_word % 65536
    local month = math.floor(date_word / 65536) % 256
    local day   = math.floor(date_word / 16777216) % 256
    if year < 2000 or year > 2200 or month < 1 or month > 12 or day < 1 or day > 31 then
        return nil, "waiting for career"
    end

    -- Verify managed club identity and its matching record in the team table.
    local human_ident = read_num(career + date_at + 8, "u32", 4)
    if not human_ident then return nil, "waiting for career" end
    local human_team = math.floor(human_ident / 16384)
    local human_slot = human_ident % 16384
    if human_team < 1 or human_team > MAX_TEAM_ID or human_slot >= team_count then
        return nil, "waiting for career"
    end
    if read_num(career + team_at + human_slot * CP_RECORD_SIZE, "u32", 4) ~= human_ident then
        return nil, "waiting for career"
    end

    -- Guard against unpatched expanded databases on stock code: slots 0..2 must be team identities.
    for s = 0, 2 do
        local id = read_num(career + team_at + s * CP_RECORD_SIZE, "u32", 4)
        if not id or (id % 16384) ~= s or math.floor(id / 16384) < 1 or math.floor(id / 16384) > MAX_TEAM_ID then
            return nil, "expanded or unrecognised team table; profiles skipped"
        end
    end

    return {
        career = career,
        team_table = career + team_at,
        team_count = team_count,
        player_bytes = (stock and STOCK_PLAYER_COUNT or read_num(career + count_at, "u32", 4)) * PLAYER_STRIDE,
        date_word = date_word,
        human_ident = human_ident,
        human_team = human_team,
        stock = stock,
    }, nil
end

-- Read the live worldwide club ranking table at career + 0x16705A8.
-- Validated with the exact same rules as Touchline (sequential ranks 1..N,
-- N >= 300, unique team IDs, positive points, >= 60% non-increasing steps).
local function read_live_rankings(info)
    if not info.stock and info.player_bytes and STOCK_RANKING_OFFSET < info.player_bytes then
        return {}, 0
    end
    local ranks = {}
    local seen = {}
    local count, monotonic, prev_pts = 0, 0, nil
    local base_addr = info.career + STOCK_RANKING_OFFSET
    local limit = math.min(RANKING_MAX_ROWS, info.team_count)
    for rank = 1, limit do
        local row = read_exact(base_addr + (rank - 1) * RANKING_STRIDE, RANKING_STRIDE)
        if not row then break end
        local packed = tonumber(memory.unpack("u32", row:sub(1, 4)))
        local stored = tonumber(memory.unpack("u32", row:sub(5, 8)))
        local points = tonumber(memory.unpack("u32", row:sub(9, 12)))
        local tid = math.floor(packed / 16384)
        if stored ~= rank or tid < 1 or tid > MAX_TEAM_ID or seen[tid] or points < 1 then
            break
        end
        if prev_pts ~= nil and points <= prev_pts then monotonic = monotonic + 1 end
        prev_pts = points
        seen[tid] = true
        ranks[tid] = rank
        count = rank
    end
    if count < RANKING_MIN_ROWS then return {}, 0 end
    if monotonic / math.max(1, count - 1) < 0.6 then return {}, 0 end
    return ranks, count
end

local function cp_rank_caps(rank)
    if not rank or rank <= 0 then return nil, nil end
    for _, row in ipairs(CP_RANK_CAPS) do
        if rank <= row[1] then return row[2], row[3] end
    end
    return nil, nil
end

local function cp_blank_ceiling(rank)
    if not rank or rank <= 0 then return nil end
    for _, row in ipairs(CP_BLANK_CEILINGS) do
        if rank <= row[1] then return row[2] end
    end
    return nil
end

local function cp_club_list(team_ids, identities)
    local out = {}
    for _, tid in ipairs(team_ids) do
        local ident = identities[tid]
        if ident and #out < 3 then out[#out + 1] = ident end
    end
    if #out == 0 then return nil end
    while #out < 3 do out[#out + 1] = CP_NO_CLUB end
    return out
end

local function pack_u32_3(a, b, c)
    return memory.pack("u32", a) .. memory.pack("u32", b) .. memory.pack("u32", c)
end

local function plan_club_writes(team_id, record, rank, identities)
    local flags = tonumber(memory.unpack("u32", record:sub(CP_FLAGS_AT + 1, CP_FLAGS_AT + 4)))
    local cur_tier = math.floor(flags / 32) % 16
    local cur_policy = math.floor(flags / 33554432) % 4
    local cur_fee = tonumber(memory.unpack("u32", record:sub(CP_FEE_CEILING_AT + 1, CP_FEE_CEILING_AT + 4)))
    local cur_y, cur_p, cur_v = record:byte(CP_AGE_MIX_AT + 1, CP_AGE_MIX_AT + 3)

    local target_tier, target_policy, target_fee, target_ages, target_partners, target_rivals
    local profile = CP_PROFILES[team_id]
    if profile then
        target_tier = profile.tier
        target_policy = profile.policy
        target_fee = profile.fee_m * CP_FEE_PER_M
        target_ages = profile.ages
        target_partners = cp_club_list(profile.partners, identities)
        target_rivals = cp_club_list(profile.rivals, identities)
    else
        local cap_fee_m, tier_floor = cp_rank_caps(rank)
        if CP_MLS_CEILINGS[team_id] then
            target_fee = CP_MLS_CEILINGS[team_id] * CP_FEE_PER_M
        elseif cur_fee == 0 then
            local blank_m = cp_blank_ceiling(rank)
            if blank_m then target_fee = blank_m * CP_FEE_PER_M end
        elseif cap_fee_m and cur_fee > cap_fee_m * CP_FEE_PER_M then
            target_fee = cap_fee_m * CP_FEE_PER_M
        end
        if tier_floor and cur_tier > 0 and cur_tier < tier_floor then
            target_tier = tier_floor
        end
        if cur_y > CP_YOUTH_CAP then
            target_ages = { CP_YOUTH_CAP, math.min(100, cur_p + cur_y - CP_YOUTH_CAP), cur_v }
        end
    end

    local writes = {}
    if target_tier ~= nil or target_policy ~= nil then
        local new_flags = flags
        if target_tier ~= nil then
            new_flags = new_flags - cur_tier * 32 + target_tier * 32
        end
        if target_policy ~= nil then
            new_flags = new_flags - cur_policy * 33554432 + target_policy * 33554432
        end
        if new_flags ~= flags then
            writes[#writes + 1] = {
                offset = CP_FLAGS_AT,
                old = memory.pack("u32", flags),
                new = memory.pack("u32", new_flags),
            }
        end
    end
    if target_fee ~= nil and target_fee ~= cur_fee then
        writes[#writes + 1] = {
            offset = CP_FEE_CEILING_AT,
            old = memory.pack("u32", cur_fee),
            new = memory.pack("u32", target_fee),
        }
    end
    if target_ages ~= nil and (target_ages[1] ~= cur_y or target_ages[2] ~= cur_p or target_ages[3] ~= cur_v) then
        writes[#writes + 1] = {
            offset = CP_AGE_MIX_AT,
            old = string.char(cur_y, cur_p, cur_v),
            new = string.char(target_ages[1], target_ages[2], target_ages[3]),
        }
    end
    if target_partners ~= nil then
        local old_bytes = record:sub(CP_PARTNERS_AT + 1, CP_PARTNERS_AT + 12)
        local new_bytes = pack_u32_3(target_partners[1], target_partners[2], target_partners[3])
        if new_bytes ~= old_bytes then
            writes[#writes + 1] = { offset = CP_PARTNERS_AT, old = old_bytes, new = new_bytes }
        end
    end
    if target_rivals ~= nil then
        local old_bytes = record:sub(CP_RIVALS_AT + 1, CP_RIVALS_AT + 12)
        local new_bytes = pack_u32_3(target_rivals[1], target_rivals[2], target_rivals[3])
        if new_bytes ~= old_bytes then
            writes[#writes + 1] = { offset = CP_RIVALS_AT, old = old_bytes, new = new_bytes }
        end
    end
    return writes
end

local function restore_club_profiles(info)
    local restored = 0
    for key, entry in pairs(cp_journal) do
        local rec_addr = info.team_table + entry.slot * CP_RECORD_SIZE
        local cur_ident = read_num(rec_addr, "u32", 4)
        local field_addr = rec_addr + entry.offset
        if cur_ident == entry.identity and read_exact(field_addr, #entry.new) == entry.new then
            memory.write(field_addr, entry.old)
            if read_exact(field_addr, #entry.old) == entry.old then
                restored = restored + 1
            end
        end
        cp_journal[key] = nil
    end
    cp_clubs_changed = 0
    cp_fields_changed = 0
    return restored
end

local function apply_club_profiles(wanted, info, reason)
    if not info then
        if not wanted then
            cp_status = "off"
            cp_last_key = "off|none"
        else
            cp_status = reason or "waiting for career"
        end
        return
    end

    -- Track which career the journal belongs to; a new career resets it.
    local career_sig = string.format("%s|%d", hex(info.career), info.human_ident)
    if cp_journal_career ~= career_sig then
        cp_journal = {}
        cp_journal_career = career_sig
        cp_clubs_changed = 0
        cp_fields_changed = 0
        cp_last_key = nil
    end

    local run_key = string.format("%s|%s|%d", wanted and "on" or "off", career_sig, info.date_word)
    if run_key == cp_last_key then return end

    if not wanted then
        local restored = restore_club_profiles(info)
        cp_last_key = run_key
        cp_status = restored > 0 and string.format("off (restored %d field(s))", restored) or "off"
        if restored > 0 then
            log(string.format("TouchlineRealismMarket: restored %d club profile field(s)", restored))
        end
        return
    end

    -- First pass: read every populated team record and build identities map.
    local identities = {}
    local records = {}
    for slot = 0, info.team_count - 1 do
        local rec_addr = info.team_table + slot * CP_RECORD_SIZE
        local ident = read_num(rec_addr, "u32", 4)
        if ident and (ident % 16384) == slot then
            local tid = math.floor(ident / 16384)
            if tid >= 1 and tid <= MAX_TEAM_ID then
                local rec = read_exact(rec_addr, CP_RECORD_SIZE)
                if rec then
                    identities[tid] = ident
                    records[#records + 1] = { slot = slot, tid = tid, ident = ident, addr = rec_addr, rec = rec }
                end
            end
        end
    end

    local ranks, ranked_count = read_live_rankings(info)
    cp_ranked_count = ranked_count

    -- Second pass: plan & apply writes with read-before-write & read-back verification.
    local written = 0
    for _, item in ipairs(records) do
        local writes = plan_club_writes(item.tid, item.rec, ranks[item.tid] or 0, identities)
        for _, w in ipairs(writes) do
            local addr = item.addr + w.offset
            if read_exact(addr, #w.old) == w.old then
                memory.write(addr, w.new)
                if read_exact(addr, #w.new) == w.new then
                    local jkey = string.format("%d:%X", item.tid, w.offset)
                    local orig = cp_journal[jkey] and cp_journal[jkey].old or w.old
                    written = written + 1
                    if orig == w.new then
                        cp_journal[jkey] = nil
                    else
                        cp_journal[jkey] = {
                            slot = item.slot,
                            identity = item.ident,
                            offset = w.offset,
                            old = orig,
                            new = w.new,
                        }
                    end
                end
            end
        end
    end

    -- Tally total active journaled clubs & fields for overlay display.
    local clubs_set, fields_count = {}, 0
    for jkey in pairs(cp_journal) do
        local tid = jkey:match("^(%d+):")
        if tid then clubs_set[tid] = true end
        fields_count = fields_count + 1
    end
    local clubs_count = 0
    for _ in pairs(clubs_set) do clubs_count = clubs_count + 1 end
    cp_clubs_changed = clubs_count
    cp_fields_changed = fields_count
    cp_last_key = run_key
    cp_status = string.format("%d club(s) active (%d field(s)%s)",
        clubs_count, fields_count,
        ranked_count > 0 and string.format(", %d ranked", ranked_count) or ", profiles + MLS")
    if written > 0 then
        log(string.format("TouchlineRealismMarket: club profiles applied (%d write(s), %d club(s) active, %d ranked)",
            written, clubs_count, ranked_count))
    end
end

-- ── Poll Loop & Sider Hooks ─────────────────────────────────────────────────
local function poll(ctx, force)
    local now = os.time()
    if not force and last_poll >= 0 and now - last_poll < 2 then return end
    last_poll = now

    local cfg = load_settings(ctx)
    local table_mode = cfg.mode == "off" and "off" or "realistic"
    if table_mode ~= applied_table_mode then apply_rulebook(table_mode) end

    local realistic = (table_mode == "realistic" and applied_table_mode == "realistic")
    local profiles_wanted = (cfg.mode == "profiles" and realistic)

    local base = locate_module_base()
    local career_info, career_reason = nil, "game build not recognised"
    if base then
        career_info, career_reason = locate_live_career(base)
    end
    local user_team_id = career_info and career_info.human_team or 0

    apply_deal_checks(ctx,
        profiles_wanted and cfg.nationality_rules or "",
        realistic and cfg.gk_cap or 0,
        user_team_id)
    apply_values(ctx, realistic and cfg.older_value_age or 0)
    apply_market(ctx, cfg.market)
    apply_club_profiles(profiles_wanted, career_info, career_reason)
end

function m.set_teams(ctx) poll(ctx, false) end
function m.after_set_conditions(ctx) poll(ctx, false) end
function m.get_stadium_name(ctx) poll(ctx, false); return nil end
-- Fires on every file load (including Master League menus), so INI changes and
-- freshly loaded careers are picked up promptly without waiting for a match.
function m.livecpk_make_key(ctx, filename) poll(ctx, false); return nil end

function m.overlay_on(ctx)
    poll(ctx, true)
    local lines = {
        string.format("TouchlineRealismMarket v%s", m.version),
        "Rulebook:       " .. status,
        "Club profiles:  " .. cp_status,
        "Goalkeepers:    " .. gk_status,
        "Nationalities:  " .. nat_status,
        "Older values:   " .. val_status,
        "Market era:     " .. mkt_status,
    }
    if nat_cave then
        lines[#lines + 1] = string.format("Deal vetoes:    nationality %d/%d | GK %d/%d",
            read_num(nat_cave + NAT_VETOES, "u32", 4) or 0,
            read_num(nat_cave + NAT_CHECKS, "u32", 4) or 0,
            read_num(nat_cave + NAT_GK_VETOES, "u32", 4) or 0,
            read_num(nat_cave + NAT_GK_CHECKS, "u32", 4) or 0)
    end
    if val_cave then
        lines[#lines + 1] = string.format("Value decay:    %d lowered / %d checked",
            read_num(val_cave + VAL_LOWERED, "u32", 4) or 0,
            read_num(val_cave + VAL_CHECKED, "u32", 4) or 0)
    end
    if mkt_cave and mkt_status ~= "off" and mkt_status ~= "off (hook idle)" then
        lines[#lines + 1] = string.format("Market scaling: %d values | %d ceiling checks",
            read_num(mkt_cave + MKT_SCALED, "u32", 4) or 0,
            read_num(mkt_cave + MKT_CEILINGS, "u32", 4) or 0)
    end
    return table.concat(lines, "\n")
end

function m.init(ctx)
    ctx.register("set_teams", m.set_teams)
    ctx.register("after_set_conditions", m.after_set_conditions)
    ctx.register("get_stadium_name", m.get_stadium_name)
    ctx.register("livecpk_make_key", m.livecpk_make_key)
    ctx.register("overlay_on", m.overlay_on)
    poll(ctx, true)
    log("TouchlineRealismMarket: initialized -- " .. status .. " | profiles: " .. cp_status)
end

return m
