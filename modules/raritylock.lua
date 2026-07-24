--- RarityLock (NickTGMods module)
--- 1) Forces every Joker the game generates to a chosen rarity.
--- 2) Optionally allows duplicate JOKERS (Joker-only Showman) so owned Jokers
---    can reappear in shops/packs and the pool never dries up.
--- Built for rarity-restricted challenge runs (Commons-only, etc.).
---
--- Rarity detail (verified against common_events.lua get_current_pool):
---   create_card's _rarity arg is the rarity ROLL VALUE (0-1), not the 1-4 index:
---     <= 0.7 -> Common, 0.7-0.95 -> Uncommon, > 0.95 -> Rare.
---   Legendary uses the separate legendary=true flag.
---
--- Duplicate-Joker detail (verified against common_events.lua line ~1987):
---   A card is culled from the pool only when:
---       G.GAME.used_jokers[v.key] AND not next(find_joker("Showman"))
---   i.e. it's marked "used" AND no Showman is present. To allow duplicate
---   JOKERS only, we wrap get_current_pool: when it's building the Joker pool
---   and the toggle is on, we temporarily empty G.GAME.used_jokers so nothing
---   reads as "used", then restore it immediately after. Because we only do
---   this for _type == 'Joker', Tarot/Planet/Spectral pools are untouched and
---   keep normal no-duplicate behavior. This avoids hooking find_joker (which
---   was load-order fragile) entirely.
---
--- Pack note: loaded BEFORE forceedition, so ForceEdition's create_card
--- wrapper wraps this one -- rarity locks first, edition stamps second.

local THIS_MOD = SMODS.current_mod
local CFG = THIS_MOD.config.raritylock

local function get_config()
    return CFG
end

local ROLL_FOR_RARITY = {
    [1] = 0.3,   -- Common   (<= 0.7)
    [2] = 0.85,  -- Uncommon (0.7 - 0.95)
    [3] = 0.99,  -- Rare     (> 0.95)
    -- 4 (Legendary) handled via the legendary flag.
}

----------------------------------------------------------------------
-- Hook 1: force Joker rarity in create_card.
----------------------------------------------------------------------
local ref_create_card = create_card

function create_card(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append)
    local conf = get_config()

    if conf and conf.enabled and _type == 'Joker' and not forced_key then
        if conf.rarity == 4 then
            legendary = true
            _rarity = nil
        else
            legendary = false
            _rarity = ROLL_FOR_RARITY[conf.rarity] or 0.3
        end
    end

    return ref_create_card(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append)
end

----------------------------------------------------------------------
-- Hook 2: Joker-only duplicates.
-- While get_current_pool builds the JOKER pool (and dupes are on), temporarily
-- clear G.GAME.used_jokers so no Joker is treated as already-owned, then put it
-- back. Scoped to _type == 'Joker', so consumables are unaffected.
----------------------------------------------------------------------
local ref_get_current_pool = get_current_pool

function get_current_pool(_type, _rarity, _legendary, _append)
    local conf = get_config()

    if conf and conf.allow_dupes and _type == 'Joker'
       and G.GAME and G.GAME.used_jokers then
        -- Stash and clear the used-Joker record just for this pool build.
        local saved = G.GAME.used_jokers
        G.GAME.used_jokers = {}

        -- get_current_pool returns TWO values (pool table, pool key string).
        local pool, pool_key = ref_get_current_pool(_type, _rarity, _legendary, _append)

        -- Restore immediately so nothing else is affected.
        G.GAME.used_jokers = saved
        return pool, pool_key
    end

    return ref_get_current_pool(_type, _rarity, _legendary, _append)
end

----------------------------------------------------------------------
-- Tab.
----------------------------------------------------------------------
local RARITY_NAMES = { 'Common', 'Uncommon', 'Rare', 'Legendary' }

table.insert(THIS_MOD.NTG.tabs, {
    label = 'RarityLock',
    tab_definition_function = function()
        local conf = get_config()
        return {
            n = G.UIT.ROOT,
            config = { align = 'cm', padding = 0.1, colour = G.C.CLEAR },
            nodes = {
                {
                    n = G.UIT.R,
                    config = { align = 'cm', padding = 0.1 },
                    nodes = {
                        create_toggle({
                            label = 'Lock Joker rarity',
                            ref_table = conf,
                            ref_value = 'enabled',
                        }),
                    },
                },
                {
                    n = G.UIT.R,
                    config = { align = 'cm', padding = 0.1 },
                    nodes = {
                        create_option_cycle({
                            label = 'Locked rarity',
                            scale = 0.9,
                            options = RARITY_NAMES,
                            current_option = conf.rarity or 1,
                            opt_callback = 'rlock_set_rarity',
                        }),
                    },
                },
                {
                    n = G.UIT.R,
                    config = { align = 'cm', padding = 0.1 },
                    nodes = {
                        create_toggle({
                            label = 'Allow duplicate Jokers (Joker-only)',
                            ref_table = conf,
                            ref_value = 'allow_dupes',
                        }),
                    },
                },
                {
                    n = G.UIT.R,
                    config = { align = 'cm', padding = 0.1 },
                    nodes = {
                        {
                            n = G.UIT.T,
                            config = {
                                text = 'Locks every spawned Joker to one rarity. Duplicates affects Jokers only.',
                                scale = 0.32,
                                colour = G.C.UI.TEXT_LIGHT,
                            },
                        },
                    },
                },
            },
        }
    end,
})

G.FUNCS.rlock_set_rarity = function(args)
    if not args or not args.to_key then return end
    get_config().rarity = args.to_key
end
