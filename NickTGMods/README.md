# NickTGMods

RarityLock + ForceEdition + BossRush + BurnDeck in one mod, each on its own
config tab, plus a pack-wide **Include blind skips** switch on the Config tab.

## Install

1. **Remove** the standalone RarityLock, ForceEdition, BossRush, and BurnDeck
   folders from your Mods directory. They wrap the same functions and would
   double-apply.
2. Drop the `NickTGMods` folder into your Mods directory.
3. **Copy `lovely.toml` from your standalone BossRush folder into
   `NickTGMods/`.** Required for BossRush runs — its two patches target
   vanilla files and gate on the run flag, so the file carries over unchanged.
   Without it, BossRush runs corrupt the blind state machine.

RunLogger and ScorePreview stay standalone and are unaffected.

## Differences vs the standalones

- **All modules default OFF.** The standalones defaulted on; a pack that
  ships four modifiers enabled at once would be chaos. Opt in per tab.
- **Skips in BossRush are now optional.** The standalone removed skips/tags
  unconditionally. Here the Config tab's *Include blind skips* switch governs
  it: ON lets you skip the boss-loaded Small/Big slots for their tags (the
  Boss slot is never skippable); OFF removes skips from every run, BossRush
  or not. Because tags can now exist during BossRush, the vanilla
  `new_blind_choice` tag pass was restored in the reroll path.
- **Fresh config.** Saved settings from the standalone mods do not migrate.
- BossRush enablement is still a per-run flag: toggling it applies to the
  next run, and existing BossRush saves keep working.
