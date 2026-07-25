--- NickTGMods
--- NickTG's challenge-run pack: RarityLock, ForceEdition, BossRush, and
--- BurnDeck as separate modules on separate labeled tabs, plus a master
--- Include-skips switch on the built-in Config tab (Steamodded fixes that
--- tab's label to "Config"; it serves as the pack's Misc section), plus
--- the Cursed Deck -- a new deck, no tab, opt-in by selecting it.
---
--- Layout:
---   NickTGMods.lua      this file: config init, tab wiring, module loading
---   modules/*.lua       one file per original mod, verified headers preserved
---   lovely.toml         REQUIRED for BossRush runs: copy it from the
---                       standalone BossRush folder. Its two pattern patches
---                       target vanilla files and gate on
---                       G.GAME.modifiers.bossrush, so they are
---                       folder-agnostic and carry over unchanged.
---
--- Load order is deliberate and load-bearing:
---   raritylock -> forceedition : both wrap create_card. This order makes the
---       chain ForceEdition(RarityLock(vanilla)) -- the rarity is locked
---       first, then the edition is stamped on the resulting card. Running
---       RarityLock=Legendary + ForceEdition=Negative together yields
---       Negative legendaries, as intended.
---   bossrush -> burndeck -> misc : hooks are disjoint (blind flow /
---       evaluate_play / blind-select UI), so this order is inert, but it is
---       fixed for reproducibility.
---   curseddeck : pure SMODS.Back declaration -- zero hooks, no config, no
---       tab -- so it is order-inert anywhere; loaded before misc so misc
---       stays the tab-finalizing last module.
---
--- Config is namespaced per module (config.raritylock, .forceedition,
--- .bossrush, .burndeck, .misc). Steamodded's config serializer recurses
--- into nested tables (smods src/utils.lua serialize), so the whole tree
--- persists as one saved config. Per-key nil-defaulting below means saved
--- configs survive updates that add new keys.
---
--- PACK DEFAULTS: every module ships DISABLED -- unlike the standalones,
--- which defaulted on -- so a fresh install behaves like vanilla until you
--- opt in per tab. Include skips defaults ON (vanilla behavior). The
--- Cursed Deck has no toggle: it registers in deck select and only
--- applies if you pick it, so opt-in is inherent.
---
--- The standalone RarityLock / ForceEdition / BossRush / BurnDeck mods must
--- be REMOVED from the Mods folder before using this pack: they wrap the
--- same globals and would double-apply (rarity re-rolled twice, editions
--- stamped twice, two burn wrappers). Remove standalone CursedDeck too:
--- loading both yields two Cursed Deck entries in deck select (different
--- keys: b_curseddeck_cursed vs b_ntgmods_cursed).

--- Stable mod reference captured at load time (SMODS.current_mod is nil later).
local THIS_MOD = SMODS.current_mod

----------------------------------------------------------------------
-- Namespaced config with per-key nil-defaulting.
----------------------------------------------------------------------
THIS_MOD.config = THIS_MOD.config or {}
local cfg = THIS_MOD.config

cfg.raritylock = cfg.raritylock or {}
if cfg.raritylock.enabled == nil then cfg.raritylock.enabled = false end
if cfg.raritylock.rarity == nil then cfg.raritylock.rarity = 1 end -- 1 = Common
if cfg.raritylock.allow_dupes == nil then cfg.raritylock.allow_dupes = false end

cfg.forceedition = cfg.forceedition or {}
if cfg.forceedition.enabled == nil then cfg.forceedition.enabled = false end
if cfg.forceedition.edition == nil then cfg.forceedition.edition = 1 end -- 1 = Negative

cfg.bossrush = cfg.bossrush or {}
if cfg.bossrush.enabled == nil then cfg.bossrush.enabled = false end

cfg.burndeck = cfg.burndeck or {}
if cfg.burndeck.enabled == nil then cfg.burndeck.enabled = false end

cfg.misc = cfg.misc or {}
if cfg.misc.include_skips == nil then cfg.misc.include_skips = true end

-- curseddeck: deliberately no config namespace and no tab. The deck is a
-- pure declaration; selecting it in deck select IS the opt-in.

----------------------------------------------------------------------
-- Tab registry. Modules push {label, tab_definition_function} entries;
-- the Misc module owns config_tab (the built-in "Config" tab).
-- extra_tabs is consumed by Steamodded at smods src/ui.lua:540.
----------------------------------------------------------------------
THIS_MOD.NTG = { tabs = {} }

THIS_MOD.extra_tabs = function()
    return THIS_MOD.NTG.tabs
end

----------------------------------------------------------------------
-- Module load. Order matters (see header).
----------------------------------------------------------------------
for _, m in ipairs({ 'raritylock', 'forceedition', 'bossrush', 'burndeck', 'curseddeck', 'misc' }) do
    assert(SMODS.load_file('modules/' .. m .. '.lua'))()
end
