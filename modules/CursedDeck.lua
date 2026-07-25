--- CursedDeck
--- One deck carrying every unambiguous downside from the vanilla decks:
---   Black   -> -1 hand every round
---   Green   -> money earns no Interest
---   Nebula  -> -1 consumable slot
---   Painted -> -1 Joker slot
---   Plasma  -> X2 base Blind size
---
--- Architecture (verified against back.lua + smods source):
---   Pure declaration -- zero hooks. Back:init copies the center's config
---   table verbatim (back.lua: config = copy_table(selected_back.config)),
---   and Back:apply_to_run consumes each key generically:
---     hands           -> starting_params.hands
---     joker_slot      -> starting_params.joker_slots
---     consumable_slot -> starting_params.consumable_slots
---     no_interest     -> G.GAME.modifiers.no_interest  (state_events.lua:1191)
---     ante_scaling    -> starting_params.ante_scaling  (blind.lua:107)
---   smods' lovely patch on apply_to_run only PREPENDS an optional
---   obj:apply() call (smods/lovely/back.toml:43); the vanilla config body
---   still runs, so no apply hook is needed.
---
--- Why Plasma's upside is dodged for free (verified, back.lua:121-135):
---   The chip/mult balancing in Back:trigger_effect is keyed on the literal
---   name 'Plasma Deck'. The X2 blind size flows through the generic
---   ante_scaling starting param (blind.lua:107). Different name => we
---   inherit the scaling without the balancing.
---
--- name field: smods defaults a Back's name to its raw key
---   (smods game_object.lua:1487). RunLogger logs selected_back.name
---   (RunLogger.lua:188), so we set name explicitly to keep JSONL clean.
---
--- Art: placeholder = vanilla Challenge Deck back (default atlas 'centers',
---   pos {x=0,y=4} per game.lua b_challenge) so it doesn't visually collide
---   with a playable vanilla deck. To swap in custom art later:
---     SMODS.Atlas { key = 'cursed_back', path = 'cursed_back.png', px = 71, py = 95 }
---   then set atlas = 'cursed_back', pos = { x = 0, y = 0 } below.

SMODS.Back {
    key = 'cursed',
    name = 'Cursed Deck',
    loc_txt = {
        name = 'Cursed Deck',
        text = {
            '{C:blue}-1{} hand every round',
            '{C:attention}-1{} Joker slot',
            '{C:attention}-1{} consumable slot',
            'Earn no {C:money}Interest{}',
            '{C:attention}X2{} base Blind size',
        },
    },
    config = {
        hands = -1,           -- Black Deck   (game.lua:632)
        joker_slot = -1,      -- Painted Deck (game.lua:639)
        consumable_slot = -1, -- Nebula Deck  (game.lua:634)
        no_interest = true,   -- Green Deck   (game.lua:631)
        ante_scaling = 2,     -- Plasma Deck  (game.lua:641)
    },
    pos = { x = 0, y = 4 },   -- Challenge Deck back, placeholder art
    unlocked = true,
    discovered = true,
}
