--- Misc (NickTGMods module)
--- Pack-wide switches. Owns the built-in "Config" tab (Steamodded fixes that
--- tab's label; it serves as the Misc section).
---
--- Include blind skips -- master switch for the skip/tag system:
---   ON (default) = vanilla behavior. The seam is slot-keyed:
---     create_UIBox_blind_tag reads G.GAME.round_resets.blind_tags[blind_choice]
---     (UI_definitions.lua:1461-1463), and vanilla only ever assigns tags to
---     the Small and Big slots. So when BossRush loads bosses into those
---     slots, they STILL offer their skip tag -- you can skip bosses for tags
---     in the gauntlet. The Boss slot never has a tag assigned, so it is
---     never skippable, in any mode.
---   OFF = returning nil from create_UIBox_blind_tag removes the tag row AND
---     the Skip button in one seam, because skip_blind requires the
---     tag_container UIE (button_callbacks.lua:2754). No state mutation, and
---     the run-info overlay stays consistent for free. This is the same
---     proven seam the standalone BossRush used unconditionally.
---
--- Takes effect from the next blind-select screen (the UI is rebuilt per
--- screen), so it can be flipped mid-run.

local THIS_MOD = SMODS.current_mod
local CFG = THIS_MOD.config.misc

local function get_config()
    return CFG
end

----------------------------------------------------------------------
-- Hook: the skip/tag seam.
----------------------------------------------------------------------
local ref_create_UIBox_blind_tag = create_UIBox_blind_tag

function create_UIBox_blind_tag(blind_choice, run_info)
    if not get_config().include_skips then
        return nil
    end
    return ref_create_UIBox_blind_tag(blind_choice, run_info)
end

----------------------------------------------------------------------
-- Built-in Config tab (= the pack's Misc section).
----------------------------------------------------------------------
THIS_MOD.config_tab = function()
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
                        label = 'Include blind skips',
                        ref_table = conf,
                        ref_value = 'include_skips',
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
                            text = 'ON: normal skip tags on Small/Big (even in BossRush). OFF: skip option and tags removed from all runs.',
                            scale = 0.32,
                            colour = G.C.UI.TEXT_LIGHT,
                        },
                    },
                },
            },
            {
                n = G.UIT.R,
                config = { align = 'cm', padding = 0.1 },
                nodes = {
                    {
                        n = G.UIT.T,
                        config = {
                            text = 'Each mod lives on its own tab. All mods ship disabled; opt in per tab.',
                            scale = 0.32,
                            colour = G.C.UI.TEXT_LIGHT,
                        },
                    },
                },
            },
        },
    }
end
