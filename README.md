# RetailArenaCountdown

[![CI](https://github.com/zxxdev/RetailArenaCountdown/actions/workflows/ci.yml/badge.svg)](https://github.com/zxxdev/RetailArenaCountdown/actions/workflows/ci.yml)
[![License: GPL-2.0](https://img.shields.io/badge/license-GPL--2.0-blue.svg)](LICENSE)

The arena countdown as in the modern game, for the **World of Warcraft 3.3.5a** client (Wrath of the Lich King): big numbers in the middle of the screen, a sound on the last seconds, and your faction's crest when the gates open. It works on its own; Gladdy is not needed.

<!-- SCREENSHOT -->

## Why it exists

Before an arena match, the 3.3.5a client only prints a line in the chat at 60, 30 and 15 seconds. Gladdy has a countdown module, but it needs the whole of Gladdy, and in some of its copies the tens digit goes missing from 59 to 11. RetailArenaCountdown is that module made into a small addon of its own, with the sounds and the crest of the modern game.

## What it does

- **Numbers** from 60 down, in the middle of the screen, the moment the game announces the countdown. Two digits up to 10, then one big digit.
- **Sounds:** one at 10 seconds, one on every second from 9 to 1, and a closing one when the gates open.
- **Your faction's crest** (Alliance or Horde) when the match begins.
- **Every client language** the game's arena messages come in: English, Spanish, Portuguese, German, French, Russian, Korean and Chinese.
- **Gladdy, if installed, stays quiet:** its own countdown never starts, so the two never overlap. Gladdy's saved settings are not changed.
- **Boss emotes** (the big text that repeats the arena messages) are hidden from entering the arena until the gates open, so they do not cover the numbers. If another addon had hidden them, or turns them back on meanwhile, they are left alone.
- Seeing an enemy while time is left stops the countdown: the match is already on.

## Limitations

- It follows the arena messages of the standard 3.3.5a client. A server that words them differently gets no countdown.
- The position is fixed, a little above the middle of the screen; only the size can be changed.
- Only arenas, not battlegrounds.

## Install

1. Download this repository (**Code → Download ZIP**) and unzip it.
2. Rename the folder to `RetailArenaCountdown` and put it inside `World of Warcraft/Interface/AddOns/`.
3. Start the game and check that **RetailArenaCountdown** is enabled in the AddOns list on the character screen.

A ready-to-copy zip will be attached to the v1.0.0 release.

## Usage

There is nothing to set up: the countdown starts by itself in the arena. To see it anywhere, type `/racd test`.

| Command | What it does |
|---|---|
| `/racd` | Says whether it is on, its size and what happens to boss emotes, and lists the commands |
| `/racd test` | A 15-second countdown, to see it outside the arena |
| `/racd size 64-512` | The size of the numbers in pixels (256 by default) |
| `/racd on`, `/racd off` | Turns it on or off |
| `/racd emotes hide` | Hides boss emotes during the countdown (the default) |
| `/racd emotes show` | Never touches boss emotes |

`/retailarenacountdown` works as well as `/racd`. The settings are saved for the whole account.

## How it works

- **The arena messages start it.** Inside an arena, the addon listens to the game's system messages and compares them with the countdown messages in the client's language (60, 30, 15 and 0 seconds). Outside an arena it listens to none of them.
- **Its own clock.** 3.3.5a has no `C_Timer`, so a hidden frame's `OnUpdate` adds up the time between frames and ticks once a second. It only runs while a countdown is on screen, about a minute per match.
- **Gladdy is silenced in memory.** Gladdy looks its methods up by name each time, so replacing the two that start its countdown with empty ones is enough; nothing it saved is touched.
- **Light on the game.** The display and its textures are created the first time a countdown is shown. Only the player's language of the arena messages is kept; the others are freed after loading. Nothing global except the saved settings and the slash command.

## Development

You need Lua 5.1, [busted](https://lunarmodules.github.io/busted/) and [luacheck](https://github.com/lunarmodules/luacheck). From the repository root:

```sh
luacheck .   # lint
busted       # tests
```

Files:

```text
RetailArenaCountdown.toc   what the game loads
RetailArenaCountdown.lua   the countdown, the clock, Gladdy and the commands
Locales.lua                the arena messages in each client language
Images/                    numbers 0-9 and the two faction crests
Sounds/                    the tick and closing sounds
spec/                      tests
```

### Quality

- **Tests** (busted): the game is played by plain Lua tables in [`spec/countdown_spec.lua`](spec/countdown_spec.lua). They cover the messages in each language, both digits of 45, the sounds second by second, the crest, enemies seen early, boss emotes, Gladdy, the commands and that nothing is created before it is needed.
- **Lint** (luacheck), with the list of game functions the addon reads.
- Both run in [CI](.github/workflows/ci.yml) on every pull request. They test the logic against a fake game, not the game itself; it has been checked in the game.

## Credits

- Based on the arena countdown module of [Gladdy](https://github.com/XiconQoo/Gladdy-TBC) by XiconQoo, DnB_Junkee, Knall and Tsoukie, GPL-2.0. The number and crest images and the arena messages in each language come from Gladdy.
- The two sounds are Blizzard Entertainment's, from the modern game.

## History

The [first commit](https://github.com/zxxdev/RetailArenaCountdown/commit/056d81f) is Gladdy's module, unchanged. The next one holds the changes made to it inside Gladdy, as they ran in the game: the sounds, the reset at the end and the hidden boss emotes. After that comes the standalone addon: see the [changelog](CHANGELOG.md).

## License

[GPL-2.0](LICENSE), like Gladdy, which it derives from. World of Warcraft is a trademark of Blizzard Entertainment; this addon is not affiliated with or endorsed by Blizzard.
