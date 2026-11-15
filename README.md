<p align="center"><img src="assets/logo/logo-wordmark.png" alt="ekitai" width="460"></p>

# liquid

ekitai (液体, "liquid") is a [Quickshell](https://quickshell.org) shell for Hyprland: a bar, panels, a lock
screen, a launcher, notifications and desktop widgets, all in one glowing liquid. It replaces waybar, mako, wofi
and hyprlock.

It's the shell half of the `ekitai-qs` rice in my [dotfiles](https://github.com/BugzySleeps/bugzysdotfiles), which
provide the colours (the `rice` theme switcher writes `~/.local/state/rice/palette.json`), the fonts and the helper
scripts it calls. See [Needs](#needs).

## See it

<p align="center"><img src="docs/lock-intro.gif" alt="the lock screen's login intro" width="800"></p>

**[▶ Watch the tour](docs/tour.mp4)** (1:49, with sound): the lock screen and its water sounds, notifications,
the launcher, control centre, calendar, music, wallpapers, terminal sounds, the overview, the shapes and glass,
settings, the screenshot editor and the welcome. The song in the music part is muted.

| | |
| --- | --- |
| <img src="docs/screenshots/desktop.png" alt="the desktop: bar, widgets, now playing"><br>the desktop: bar, widgets, now playing | <img src="docs/screenshots/lock.png" alt="the lock screen, floating on the liquid"><br>the lock screen, floating on the liquid |
| <img src="docs/screenshots/lock-splash.png" alt="a wrong password splashes"><br>a wrong password splashes | <img src="docs/screenshots/control.png" alt="control centre"><br>control centre |
| <img src="docs/screenshots/music.png" alt="music: visualizer and lyrics"><br>music: visualizer and lyrics | <img src="docs/screenshots/eq.png" alt="a 10-band eq on everything playing"><br>a 10-band eq on everything playing |
| <img src="docs/screenshots/library.png" alt="cmus's library and queue"><br>cmus's library and queue | <img src="docs/screenshots/island-track.png" alt="the island: a new track"><br>the island: a new track |
| <img src="docs/screenshots/island-notify.png" alt="the island: a notification"><br>the island: a notification | <img src="docs/screenshots/island-level.png" alt="the island: volume, filling like liquid"><br>the island: volume, filling like liquid |
| <img src="docs/screenshots/launcher.png" alt="launcher"><br>launcher | <img src="docs/screenshots/launcher-emoji.png" alt="launcher: emoji"><br>launcher: emoji |
| <img src="docs/screenshots/launcher-maths.png" alt="launcher: maths"><br>launcher: maths | <img src="docs/screenshots/launcher-colour.png" alt="launcher: colours"><br>launcher: colours |
| <img src="docs/screenshots/wallpapers.png" alt="wallpaper picker (recolours everything)"><br>wallpaper picker (recolours everything) | <img src="docs/screenshots/overview.png" alt="workspace overview"><br>workspace overview |
| <img src="docs/screenshots/calendar.png" alt="calendar"><br>calendar | <img src="docs/screenshots/terminal.png" alt="a terminal, with its own sounds"><br>a terminal, with its own sounds |
| <img src="docs/screenshots/round.png" alt="round"><br>round | <img src="docs/screenshots/squiggle.png" alt="squiggle"><br>squiggle |
| <img src="docs/screenshots/glass.png" alt="liquid glass"><br>liquid glass | <img src="docs/screenshots/editor.png" alt="screenshot editor"><br>screenshot editor |
| <img src="docs/screenshots/settings.png" alt="settings"><br>settings | <img src="docs/screenshots/settings-sound.png" alt="settings: sound"><br>settings: sound |
| <img src="docs/screenshots/welcome.png" alt="welcome, on the first start"><br>welcome, on the first start | <img src="docs/screenshots/welcome-wall.png" alt="welcome: pick a wallpaper"><br>welcome: pick a wallpaper |
| <img src="docs/screenshots/welcome-shape.png" alt="welcome: pick a shape"><br>welcome: pick a shape | <img src="docs/screenshots/welcome-keys.png" alt="welcome: the keys"><br>welcome: the keys |

## Licence

You're welcome to **use** liquid: install it, run it as your shell, tweak your own copy, and show it off. What
you can't do without asking is **take its code** (or its sounds, shaders or logo) and put it into your own shell,
dotfiles or project, or re-upload it. To share your setup, link here instead. The details are in
[LICENSE](LICENSE); ask in an issue if you want to use part of it.

## Run it

```sh
git clone https://github.com/BugzySleeps/liquid ~/.config/quickshell/ekitai
qs -c ekitai
```

Talk to it from anywhere with `qs -c ekitai ipc call <target> <function>`; the targets are listed in
`services/Ui.qml` (and `qs -c ekitai ipc show` lists them all).

## Keys

These are bound in Hyprland (`hyprland.lua` in the dotfiles), each one an IPC call.

| Key | Action |
| --- | --- |
| `SUPER + R` | launcher |
| `SUPER + .` | emoji (the launcher's `:` mode) |
| `SUPER + N` | control centre |
| `SUPER + I` | settings |
| `SUPER + T` | wallpaper picker (recolours everything) |
| `SUPER + O` | workspace overview (drag windows between workspaces) |
| `ALT + Tab` | window switcher (live previews; let go of ALT to switch) |
| `SUPER + SHIFT + V` | clipboard history |
| `SUPER + W` | edit desktop widgets |
| `SUPER + Tab` | show / hide the bar |
| `SUPER + Escape` | lock |
| `Print` | screenshot a region, into the editor |

## What's in it

- **bar:** one slim borderless strip (or three islands, in settings), mostly icons: hover one to slide out its
  detail (the wifi name, the volume). Workspace dots stretch into a pill for the active one; the clock is the hour
  big, with the minutes and seconds stacked beside it. The logo opens the launcher; then workspaces; the clock
  (calendar); the playing track with live cava bars (media panel); cpu / memory meters, wifi, volume, a screen
  recorder, notifications and the control centre.
- **dynamic island:** the middle of the bar swells down out of it like a drop stretching (spring physics) when
  something happens, then shrinks back: the volume / brightness level (liquid filling across it, sloshing as it
  moves), a new track with its cover, or a notification. Simple notifications show there instead of as a popup.
  `qs -c ekitai ipc call island preview level|track|notify` to see each.
- **lock screen:** glowing liquid rises from the bottom over your blurred wallpaper (a GPU shader,
  `shaders/liquid.frag`), bending the picture under its rolling surface, with bubbles and a bright waterline. The
  login box floats on the surface and rides the waves; every key drops a ripple, a wrong password splashes, and
  unlocking drains it all away. Passwords go through PAM (`login`). The first lock of a session opens with an intro:
  the logo's drop falls just as the liquid rises over it, fills the screen, and drains to rest. If music's playing,
  it goes **underwater** while locked (a low-pass glides in as the liquid rises). It has its own widgets, which can
  float on the liquid. `qs -c ekitai ipc call lock preview` (or `previewIntro`) shows it without locking.
- **control centre:** wifi, sound, mic and do-not-disturb toggles, volume and brightness sliders, cpu / ram / disk,
  notification history, a scratchpad, lock / sleep / log out / reboot / power off.
- **music panel:** the cover blurred and tinted through the whole panel, a waterline visualizer, synced lyrics
  (lrclib), a seek bar and controls; cmus's **library** and queue; **art** (the shell and window borders take the
  album cover's colours, track by track); and a 10-band **eq** that works on everything playing, live, inside each
  stream's own PipeWire converter.
- **launcher:** type to search apps. The first character switches mode (or click the chips):
  - `=` calculator · `:` emoji (types it into your window) · `/` files in your home folder
  - `!` web search (`!g` `!d` `!y` `!w` `!gh` `!r` `!aw` `!gw` `!gp`; DuckDuckGo with no bang)
  - `#` colours: pick one off the screen, recent picks, the palette, hex → rgb / hsl
  - `>` run a command, with history and completion from your `$PATH`
- **wallpaper picker:** a fan of slanted cards; picking one recolours the whole rice from it (bar, panels, borders,
  terminal, lock screen) without reloading the shell: the new wallpaper wipes up while the colours crossfade.
- **workspace overview:** liquid floods up with every workspace floating on it as a tile of live window previews,
  each holding its own pool, deeper the more windows it has. Drag a window (it lifts off as a glowing droplet) onto
  another workspace to move it there: that pool rises to meet it and splashes when it lands.
- **window switcher**, **clipboard history** (text and images, in memory only, never passwords) and a
  **screenshot editor** (pen, arrow, box, crop; save and/or copy).
- **shape and glass:** `square`, `round` or `squiggle` (wavy edges, scalloped buttons) for everything at once, and
  liquid glass on top of any of them (see-through with a frosted blur and a sheen).
- **desktop widgets:** clock, calendar, weather (open-meteo; hidden while you share your screen), fetch, now
  playing, lyrics, visualizer, notes, images, and Claude Code's token usage. Drag, resize, and pick the workspaces
  each one shows on.
- **welcome:** on the first start, the liquid rises and walks you through a wallpaper, a shape and the keys.
  `qs -c ekitai ipc call welcome open` to see it again.
- **sounds**, all switchable in settings → sound:
  - **lock screen:** the liquid sounds like water as it moves, each sound timed to its animation: pouring in,
    a drop per key, a splash for a wrong password, a gurgling drain as it unlocks.
  - **terminals:** a sound as one opens and another as it closes: **mine** (my own clips), or **ps2**, **hud**,
    **crt** and **glitch**.
  - **notifications:** any terminal style's opening sound, or a water drip.
  - **little sounds:** bubbles, a shutter click for screenshots, a tick for volume.

  Everything but **mine** is synthesised from scratch by `sounds/make.py` (pure Python, no samples).
- **performance mode:** while a window is fullscreen or on battery (or always / never), cava, the visualizers and
  the glass blur pause.

## The logo

A drop falling into rings of ripples. The shell draws it itself (`components/Logo.qml`) in the theme's colours,
and it drips: in the bar when you hover it, in the fetch widget now and then, and in the lock intro. Under 64 px it
switches to a plainer version. The files (SVG and PNG: the mark, a small one, one glowing on black, the wordmark)
are in `assets/logo/`, made by `assets/logo/make.py`.

## Layout

```
shell.qml        the root: every window and the services it keeps running
bar/             the bar, workspaces, the dynamic island
panels/          control centre, calendar, music, eq, library
lock/            the lock screen
launcher/        launcher, clipboard picker (emoji.tsv: gemoji's names)
switcher/        window switcher, workspace overview
notifs/ osd/     notification popups, the volume vial
desktop/         wallpaper, desktop widgets
picker/          wallpaper picker
screenshot/      the screenshot editor
settings/        the settings app
welcome/         the first-run welcome
components/      shared pieces (Frame, Pool, Logo, ...)
services/        state singletons (audio, media, notifications, lock, settings, ...)
config/          colours, sizes and fonts, the keybind list
shaders/         liquid.frag (+ the compiled .qsb)
sounds/          the sounds and make.py
assets/logo/     the logo
```

Its own settings are saved in `~/.local/state/ekitai/` (`settings.json`, `look.json`, `widgets.json`).

## Needs

- Quickshell (with Qt 6 and Qt5Compat), Hyprland 0.55+
- From the [dotfiles](https://github.com/BugzySleeps/bugzysdotfiles): the `rice` scripts in `~/.config/rice/`
  (`rice`, `eq`, `music-lib`, `pick-colour`, `cava-run`, `active-sink`, `claude-usage`), the palette they write, and
  the fonts: Departure Mono, Symbols Nerd Font and Noto Sans CJK
- PipeWire + WirePlumber (`paplay`, `pactl`), cava, cmus, brightnessctl, NetworkManager, wl-clipboard, grim,
  slurp, libnotify, wtype; optionally fd and hyprpicker

## Credits

Emoji names from [gemoji](https://github.com/github/gemoji) (MIT; its notice is in [LICENSE](LICENSE)). Lyrics from [lrclib](https://lrclib.net),
weather from [open-meteo](https://open-meteo.com).
