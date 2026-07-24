--- BurnDeck (NickTGMods module)
--- Every card you play is destroyed permanently after scoring. Discards are
--- safe. Built for the burning-deck challenge run: the deck is a dwindling
--- resource, discards are the survival lever, card generation is the economy.
---
--- Hook architecture (verified against state_events.lua):
---   All surviving played cards funnel through G.FUNCS.draw_from_play_to_discard.
---   CRITICAL QUIRK: that function is defined INSIDE G.FUNCS.evaluate_play
---   (state_events.lua:1088, enclosed by :571-:1133), so it is (re)assigned as
---   a fresh closure on EVERY hand evaluation and does not exist at mod load
---   time. A load-time wrap would capture nil and get clobbered every hand.
---   Instead we wrap evaluate_play (top-level, exists at load), call the
---   original -- which re-mints the inner draw functions -- then immediately
---   re-wrap the fresh funnel. The vanilla call site (state_events.lua:522)
---   fires the funnel on a delayed event AFTER evaluate_play's synchronous
---   body completes, so the re-wrap is always installed in time.
---
--- Burn semantics:
---   The vanilla funnel already skips cards flagged shattered/destroyed (Glass
---   breaks, joker destruction like Sixth Sense -- all flagged earlier in
---   evaluate_play's destruction pass, state_events.lua:950-998). We burn only
---   the survivors, so there is no double-dissolve. Non-scoring played cards
---   carry no flags and burn too: EVERY played card burns, winning hand
---   included. Discards never pass through this funnel and are untouched.
---
--- Timing: evaluate_play computes score MATH synchronously but queues all
---   scoring ANIMATIONS as events. The funnel fires before that queue plays
---   out, so the dissolve must itself be a queued blockable event to land
---   behind the scoring chain -- otherwise cards burn instantly and the hand
---   scores on an empty screen. Vanilla relies on the same sequencing:
---   draw_card defers its card moves through the event queue
---   (common_events.lua:395).
---
--- Permanence (verified): start_dissolve -> Card:remove() -> removal from
---   G.playing_cards (card.lua:4751) -- the same path Glass shattering uses,
---   so deck count and deck viewer shrink permanently with zero extra
---   bookkeeping, and burned cards never rejoin the round-end reshuffle.
---
--- Jokers see burns as destruction (design ruling): we fire the same
---   eval_card {remove_playing_cards = true, removed = ...} pass vanilla runs
---   after its own destruction pass (state_events.lua:975). Consequences
---   (verified at card.lua:2672): Caino counts every burned face card; Glass
---   Joker checks val.shattered, so it counts real shatters only, NOT glass
---   cards that survived their break roll and then burned. Both intended.
---
--- Deck-out (verified, deliberately no code here): vanilla ends the round
---   when hand + deck + play are all empty (game.lua:3056 -> end_round ->
---   GAME_OVER if the blind is unmet, Mr. Bones saves intact). Burning to
---   zero is a clean loss, never a soft-lock.
---
--- Sound/visuals: default dissolve colours are black/orange/red/gold, which
---   reads as burning out of the box. Dissolves are silenced for all but the
---   last burned card (the card.lua:1307 pattern), so a five-card hand plays
---   one burn sound, not five.

local THIS_MOD = SMODS.current_mod
local CFG = THIS_MOD.config.burndeck

local function get_config()
    return CFG
end

----------------------------------------------------------------------
-- Hook: wrap evaluate_play; after each run of the original, re-wrap the
-- freshly re-minted play->discard funnel so survivors burn instead.
----------------------------------------------------------------------
local ref_evaluate_play = G.FUNCS.evaluate_play
local burn_wrapper = nil

local function make_burn_wrapper(ref_draw)
    return function(e)
        local conf = get_config()
        if not (conf and conf.enabled) then
            return ref_draw(e)
        end

        -- Collect survivors: anything not already claimed by the vanilla
        -- destruction pass. Mirrors the funnel's own skip logic exactly.
        local burned = {}
        for _, v in ipairs(G.play.cards) do
            if (not v.shattered) and (not v.destroyed) then
                v.destroyed = true
                burned[#burned + 1] = v
            end
        end

        if burned[1] then
            -- Same joker notification vanilla fires for destroyed played
            -- cards (state_events.lua:975). Burned == destroyed.
            if G.jokers and G.jokers.cards then
                for j = 1, #G.jokers.cards do
                    eval_card(G.jokers.cards[j], {cardarea = G.jokers, remove_playing_cards = true, removed = burned})
                end
            end
            -- Queue the dissolve (blockable, default trigger) so it lands
            -- BEHIND the scoring animation chain evaluate_play queued -- the
            -- same reason vanilla wraps its glass shatter/dissolve calls in
            -- events (state_events.lua:985) and draw_card defers card moves
            -- through the queue (common_events.lua:395). start_dissolve's own
            -- internals are blockable = false, so calling it directly fires
            -- the burn instantly, before scoring plays out on screen.
            G.E_MANAGER:add_event(Event({
                func = function()
                    for i = 1, #burned do
                        -- nil colours = default black/orange/red/gold dissolve.
                        -- Silent for all but the last card (card.lua:1307 pattern).
                        burned[i]:start_dissolve(nil, i ~= #burned)
                    end
                    return true
                end
            }))
        end
    end
end

G.FUNCS.evaluate_play = function(e)
    local ret = ref_evaluate_play(e)
    -- The original just re-assigned G.FUNCS.draw_from_play_to_discard as a
    -- fresh vanilla closure; re-wrap it. Guard: never wrap our own wrapper
    -- (covers any vanilla path that skips the re-assignment).
    if G.FUNCS.draw_from_play_to_discard ~= burn_wrapper then
        burn_wrapper = make_burn_wrapper(G.FUNCS.draw_from_play_to_discard)
        G.FUNCS.draw_from_play_to_discard = burn_wrapper
    end
    return ret
end

----------------------------------------------------------------------
-- Tab.
----------------------------------------------------------------------
table.insert(THIS_MOD.NTG.tabs, {
    label = 'BurnDeck',
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
                            label = 'Burn played cards',
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
                                text = 'Every card you play is destroyed permanently after scoring. Discards are safe.',
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
