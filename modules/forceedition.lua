--- ForceEdition (NickTGMods module)
--- Forces every Joker the game generates to a chosen edition (default: Negative).
--- Built for edition-themed challenge runs (all-Negative, etc.).
---
--- Architecture (verified against card.lua):
---   We hook create_card and call set_edition on the RETURNED card, the same
---   pattern RarityLock uses. Because shop/pack Jokers are built through
---   create_card, they render with the chosen edition IN THE SHOP, before
---   purchase -- not flipped on buy.
---
--- Negative slot detail (verified against card.lua):
---   At create time the card is NOT added_to_deck, so set_edition's own slot
---   logic is skipped (card.lua:408 guard -- it only fires when the card is
---   already in the deck). The +1 Joker slot is instead granted by the game's
---   own add_to_deck path (card.lua:630) when you actually buy the Joker. So we
---   do NOT touch add_to_deck; the base game handles the slot. One grant, on
---   purchase. set_edition resets self.edition first, so re-application is
---   idempotent -- no double-counting.
---
--- silent = true on set_edition suppresses the juice/sound event block
---   (card.lua:432, gated by `not silent`) so shops/rerolls don't spam the
---   negative shimmer. The edition data is set before that block, so the
---   border still renders. Flip SILENT to false below if you want the shimmer.
---
--- Pack note: loaded AFTER raritylock, so this create_card wrapper wraps
--- RarityLock's -- the rarity lock applies first, then the edition stamp.

local THIS_MOD = SMODS.current_mod
local CFG = THIS_MOD.config.forceedition

local SILENT = true

local function get_config()
    return CFG
end

--- Edition table keys as set_edition expects them (card.lua: holo/foil/polychrome/negative).
local EDITION_KEYS  = { 'negative', 'foil', 'holo', 'polychrome' }
local EDITION_NAMES = { 'Negative', 'Foil', 'Holographic', 'Polychrome' }

----------------------------------------------------------------------
-- Hook: force Joker edition in create_card.
-- We let the original build the card, then stamp the edition on the result.
-- Applies to ALL Jokers, including forced_key spawns and Soul legendaries,
-- so it's "every Joker, no matter what" within the create_card path.
----------------------------------------------------------------------
local ref_create_card = create_card

function create_card(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append)
    local card = ref_create_card(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append)

    local conf = get_config()
    if conf and conf.enabled and _type == 'Joker' and card then
        local key = EDITION_KEYS[conf.edition] or 'negative'
        card:set_edition({ [key] = true }, true, SILENT)
    end

    return card
end

----------------------------------------------------------------------
-- Tab.
----------------------------------------------------------------------
table.insert(THIS_MOD.NTG.tabs, {
    label = 'ForceEdition',
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
                            label = 'Force Joker edition',
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
                            label = 'Edition',
                            scale = 0.9,
                            options = EDITION_NAMES,
                            current_option = conf.edition or 1,
                            opt_callback = 'fedition_set_edition',
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
                                text = 'Every spawned Joker shows the chosen edition in the shop. Negative grants its Joker slot on purchase.',
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

G.FUNCS.fedition_set_edition = function(args)
    if not args or not args.to_key then return end
    get_config().edition = args.to_key
end
