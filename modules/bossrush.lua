--- BossRush (NickTGMods module)
--- Every blind is a Boss Blind. Native boss chip mults ($5 x3 per ante),
--- triple-showdown ante 8 (free from get_new_boss's showdown gate at
--- common_events.lua:2356).
---
--- REQUIRED: the BossRush lovely.toml must sit in the NickTGMods folder.
--- Copy it from the standalone BossRush folder unchanged -- its two pattern
--- patches target vanilla files and gate on G.GAME.modifiers.bossrush, so
--- they are folder-agnostic.
---
--- Skips/tags (pack change vs the standalone): the standalone killed the
--- entire skip/tag system unconditionally via the create_UIBox_blind_tag
--- seam. That seam now lives in modules/misc.lua behind the pack-wide
--- "Include blind skips" switch. The seam is slot-keyed
--- (G.GAME.round_resets.blind_tags[blind_choice], UI_definitions.lua:1461),
--- so with skips ON the boss-loaded Small/Big slots still offer their skip
--- tag; the Boss slot never has a tag assigned and is never skippable.
---
--- Architecture (verified against 1.0.1n source):
---   Slots are just keys in G.GAME.round_resets.blind_choices (game.lua:1976).
---   Putting boss keys in Small/Big makes the select UI, sprite, boss effect,
---   chip requirement (get_blind_amount(ante) * blind.mult, blind.lua:107) and
---   $5 reward all work with zero extra code. What BREAKS is slot identity:
---   the game infers "which slot" from the blind's NAME/object, not the slot:
---
---     1. Blind:get_type() name-sniffs (blind.lua:346) -> any boss returns
---        'Boss'. Gates ease_ante (state_events.lua:238 -> every blind would
---        ante-up), the win check (state_events.lua:111 -> ante-8 Small blind
---        would instantly win), boss_streak, voucher_restock, no_blind_reward.
---        Fixed here by overriding get_type to return G.GAME.blind_on_deck,
---        which holds the true slot through select -> play -> end_round
---        (advanced only by skip_blind, reset_blinds, and the select-screen
---        recompute at UI_definitions.lua:1441).
---     2. end_round's defeat handler and new_round's state marker compare
---        G.GAME.round_resets.blind == G.P_BLINDS.bl_small/bl_big directly
---        (state_events.lua:258/:319). Boss-in-Small would mark the BOSS slot
---        defeated, reroll the shop voucher every blind, and corrupt the state
---        machine. Fixed by the two lovely.toml pattern patches (see that
---        file), gated on G.GAME.modifiers.bossrush so vanilla runs are
---        byte-equivalent.
---     3. The Director's Cut / Retcon reroll is a single prompt-box button
---        (UI_definitions:1427) hardcoded to the Boss slot in both its
---        state func (button_callbacks:2784) and action (:2800). During
---        BossRush it rerolls the ON-DECK blind instead: Director's Cut
---        allows one reroll per SLOT per ante (bossrush_rerolled table,
---        cleared at the same ante boundary where vanilla clears
---        boss_rerolled, common_events.lua:2334); Retcon is unlimited.
---        Preemptive Boss-slot rerolls from earlier screens are
---        intentionally gone in this mode. The 'Reroll Boss' label stays
---        literally accurate -- everything on deck is a boss.
---
--- Enablement is a RUN flag (G.GAME.modifiers.bossrush), captured at
--- start_run and persisted in the save. Toggling the config mid-run changes
--- nothing until the next run; disabling/uninstalling the mod mid-BossRush-run
--- WILL corrupt that run (patches vanish under saved boss slots).
---
--- Intentional side effects (leave unless decided otherwise):
---   - Chicot/Luchador's "disableable" check is get_type()=='Boss'
---     (card.lua:866/:2356), so with slot-based get_type they only disable the
---     Boss-slot blind each ante. Keeps Chicot from invalidating all 24 bosses.
---   - Matador is trigger-based, pays on every blind. Emergent chaos, allowed.
---   - played_this_ante resets only when the Boss SLOT falls (vanilla ante
---     semantics preserved), so The Pillar mid-ante debuffs cards played
---     against earlier slots too. Correct per its rule text.
---   - With Misc skips OFF, G.GAME.skips stays 0 and Throwback is a dead
---     Joker; with skips ON, skipping and Throwback both work vanilla.
---
--- RunLogger compat: RunLogger wraps Game:start_run / Blind:set_blind /
--- new_round by capture-and-call; every hook here does the same, and the
--- lovely patches apply at source load (before anyone captures refs), so
--- load order does not matter.

local THIS_MOD = SMODS.current_mod
local CFG = THIS_MOD.config.bossrush

local function get_config()
    return CFG
end

local function bossrush_active()
    return G.GAME and G.GAME.modifiers and G.GAME.modifiers.bossrush
end

----------------------------------------------------------------------
-- Slot fill: roll real bosses into the Small and Big slots.
-- get_new_boss (common_events.lua:2338) handles everything we need:
-- min-ante eligibility, banned_keys, showdown-only on ante 8, and
-- least-used selection -- and it increments bosses_used per call, so
-- the three slots of an ante come out distinct automatically. Vanilla
-- rolls the Boss slot first (start_run game.lua:2177 / reset_blinds
-- common_events.lua:2333); we fill Small/Big after it.
----------------------------------------------------------------------
local function fill_boss_slots()
    G.GAME.round_resets.blind_choices.Small = get_new_boss()
    G.GAME.round_resets.blind_choices.Big = get_new_boss()
end

----------------------------------------------------------------------
-- Hook: Game:start_run. Fresh runs only -- args.savetext means a loaded
-- save (game.lua:2021), whose blind_choices/modifiers.bossrush persist
-- via round_resets and must not be rerolled.
----------------------------------------------------------------------
local ref_Game_start_run = Game.start_run

function Game:start_run(args)
    ref_Game_start_run(self, args)

    if not (args and args.savetext) and get_config().enabled then
        G.GAME.modifiers.bossrush = true
        fill_boss_slots()
    end
end

----------------------------------------------------------------------
-- Hook: reset_blinds. Vanilla only rerolls the Boss slot when the
-- previous ante's Boss state is 'Defeated' (common_events.lua:2328);
-- we mirror that exact condition by sampling it BEFORE the original
-- runs, then fill Small/Big for the new ante.
----------------------------------------------------------------------
local ref_reset_blinds = reset_blinds

function reset_blinds()
    local new_ante = G.GAME and G.GAME.round_resets
        and G.GAME.round_resets.blind_states
        and G.GAME.round_resets.blind_states.Boss == 'Defeated'

    ref_reset_blinds()

    if new_ante and bossrush_active() then
        fill_boss_slots()
        -- Same ante boundary where vanilla clears boss_rerolled
        -- (common_events.lua:2334): reset the per-slot reroll allowance.
        G.GAME.round_resets.bossrush_rerolled = {}
    end
end

----------------------------------------------------------------------
-- Hook: Blind:get_type. Return the true SLOT from blind_on_deck instead
-- of name-sniffing. Every verified call site wants slot semantics:
-- ante advance (state_events.lua:238), win check (:111), boss_streak
-- (:140), most_played tracking (:129), voucher_restock, no_blind_reward
-- (blind.lua:84), Chicot/Luchador disableable (card.lua:866/:2356).
-- Vanilla fallback outside BossRush runs or if blind_on_deck is unset.
----------------------------------------------------------------------
local ref_Blind_get_type = Blind.get_type

function Blind:get_type()
    if bossrush_active() and G.GAME.blind_on_deck then
        return G.GAME.blind_on_deck
    end
    return ref_Blind_get_type(self)
end

----------------------------------------------------------------------
-- Hook: G.FUNCS.reroll_boss_button (state func, runs per frame).
-- Vanilla enable rule (button_callbacks:2784) with two changes: the
-- slot under judgment is blind_on_deck, and Director's Cut checks the
-- per-slot flag instead of the global boss_rerolled. UI mutations
-- (colour/button/shadows) copied verbatim from vanilla.
----------------------------------------------------------------------
local ref_reroll_boss_button = G.FUNCS.reroll_boss_button

G.FUNCS.reroll_boss_button = function(e)
    if not bossrush_active() then return ref_reroll_boss_button(e) end

    local slot = G.GAME.blind_on_deck
    local rerolled = G.GAME.round_resets.bossrush_rerolled or {}
    if slot and ((G.GAME.dollars - G.GAME.bankrupt_at) - 10 >= 0) and
        (G.GAME.used_vouchers["v_retcon"] or
        (G.GAME.used_vouchers["v_directors_cut"] and not rerolled[slot])) then
        e.config.colour = G.C.RED
        e.config.button = 'reroll_boss'
        e.children[1].children[1].config.shadow = true
        if e.children[2] then e.children[2].children[1].config.shadow = true end
    else
        e.config.colour = G.C.UI.BACKGROUND_INACTIVE
        e.config.button = nil
        e.children[1].children[1].config.shadow = false
        if e.children[2] then e.children[2].children[1].config.shadow = false end
    end
end

----------------------------------------------------------------------
-- Hook: G.FUNCS.reroll_boss (the action). Mirrors button_callbacks:2800
-- generalized by slot: blind_on_deck picks the target, blind_select_opts
-- is keyed lowercase (UI_definitions:1447-1449), and only the Boss
-- container takes the mix_colours 4th arg, matching how the three panels
-- are built there. PACK CHANGE: the vanilla tag loop (new_blind_choice,
-- button_callbacks tail) is RESTORED -- the standalone dropped it on the
-- premise that tags can never exist in BossRush, which stops holding once
-- the Misc "Include blind skips" switch lets you skip for tags here.
----------------------------------------------------------------------
local ref_reroll_boss = G.FUNCS.reroll_boss

G.FUNCS.reroll_boss = function(e)
    if not bossrush_active() then return ref_reroll_boss(e) end

    local slot = G.GAME.blind_on_deck
    if not slot then return end
    local key = string.lower(slot)

    stop_use()
    G.GAME.round_resets.bossrush_rerolled = G.GAME.round_resets.bossrush_rerolled or {}
    G.GAME.round_resets.bossrush_rerolled[slot] = true
    if not G.from_boss_tag then ease_dollars(-10) end
    G.from_boss_tag = nil
    G.CONTROLLER.locks.boss_reroll = true
    G.E_MANAGER:add_event(Event({
        trigger = 'immediate',
        func = function()
            play_sound('other1')
            G.blind_select_opts[key]:set_role({ xy_bond = 'Weak' })
            G.blind_select_opts[key].alignment.offset.y = 20
            return true
        end
    }))
    G.E_MANAGER:add_event(Event({
        trigger = 'after',
        delay = 0.3,
        func = (function()
            local par = G.blind_select_opts[key].parent
            G.GAME.round_resets.blind_choices[slot] = get_new_boss()

            G.blind_select_opts[key]:remove()
            G.blind_select_opts[key] = UIBox{
                T = { par.T.x, 0, 0, 0, },
                definition =
                    {n=G.UIT.ROOT, config={align = "cm", colour = G.C.CLEAR}, nodes={
                        UIBox_dyn_container({create_UIBox_blind_choice(slot)}, false,
                            get_blind_main_colour(slot),
                            slot == 'Boss' and mix_colours(G.C.BLACK, get_blind_main_colour('Boss'), 0.8) or nil)
                    }},
                config = {align="bmi",
                    offset = {x=0, y=G.ROOM.T.y + 9},
                    major = par,
                    xy_bond = 'Weak'
                }
            }
            par.config.object = G.blind_select_opts[key]
            par.config.object:recalculate()
            G.blind_select_opts[key].parent = par
            G.blind_select_opts[key].alignment.offset.y = 0

            G.E_MANAGER:add_event(Event({ blocking = false, trigger = 'after', delay = 0.5, func = function()
                G.CONTROLLER.locks.boss_reroll = nil
                return true
            end }))

            save_run()
            for i = 1, #G.GAME.tags do
                if G.GAME.tags[i]:apply_to_run({type = 'new_blind_choice'}) then break end
            end
            return true
        end)
    }))
end

----------------------------------------------------------------------
-- Tab.
----------------------------------------------------------------------
table.insert(THIS_MOD.NTG.tabs, {
    label = 'BossRush',
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
                            label = 'Enable BossRush (new runs)',
                            ref_table = conf,
                            ref_value = 'enabled',
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
                                text = 'Every blind is a Boss Blind. Applies to runs started while enabled. Skips and tags follow the Config tab setting.',
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
