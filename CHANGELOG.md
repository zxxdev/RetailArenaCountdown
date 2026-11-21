# Changelog

## 1.0.0 (2026-11-21)

A standalone addon: Gladdy is no longer needed.

### Added

- Its own number and crest images, sounds and arena messages in every client language, so it runs without Gladdy.
- If Gladdy is loaded, its countdown never starts, so the two never show at once. Gladdy's saved settings are not changed.
- `/racd test` (a 15-second countdown anywhere), `/racd size 64-512`, `/racd on`, `/racd off` and `/racd emotes hide|show`, with the settings saved per account.
- Tests (busted) and luacheck, run in CI on every pull request.

### Fixed

- The tens digit was computed with a decimal division (45 / 10 = 4.5), so from 59 to 11 its image was missing. Both digits show now.

### Changed

- Boss emotes are hidden only from entering the arena until the gates open, and given back only if this addon hid them and nobody turned them back on meanwhile.
- Its own clock instead of `C_Timer`, which the 3.3.5a client does not have. It only runs while a countdown is on screen.
- Each number shows the moment the game's message arrives, not up to a second later.
- The display is created the first time a countdown is shown, and only the player's language of the arena messages is kept in memory.

## The countdown changes, inside Gladdy

The module as it ran in the Gladdy copy in the game folder, on top of Gladdy's own countdown:

- A sound at 10 seconds, on every second from 9 to 1, and when the arena begins.
- The countdown resets itself when it ends.
- Boss emote messages are hidden while it runs.
- Spotting an enemy only stops it while time is left.

## Starting point

Gladdy's arena countdown module, unchanged ([XiconQoo/Gladdy-TBC](https://github.com/XiconQoo/Gladdy-TBC), GPL-2.0).
