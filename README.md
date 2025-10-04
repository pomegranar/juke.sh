# 🎶 juke.sh

<p align="center">
  <img src="https://raw.githubusercontent.com/pomegranar/juke.sh/main/assets/jukesh-preview.png" alt="juke.sh screenshot" width="480"/>
</p>

A lightweight, terminal-based music dashboard for [Kitty](https://sw.kovidgoyal.net/kitty/) that shows album art, metadata, and playback controls for any [MPRIS](https://specifications.freedesktop.org/mpris-spec/latest/)-compatible player.

---

## Dependencies

- A terminal supporting the **Kitty image protocol** (e.g. [Kitty](https://github.com/kovidgoyal/kitty))
- [`playerctl`](https://github.com/altdesktop/playerctl)
- [`ImageMagick`](https://github.com/ImageMagick/ImageMagick)

---

## Installation

Install in user-space:

```bash
curl -fsSL https://raw.githubusercontent.com/pomegranar/juke.sh/main/juke.sh -o ~/.local/bin/juke.sh 
chmod +x ~/.local/bin/juke.sh
````

Make sure `~/.local/bin` is in your `$PATH`, then run:

```bash
juke.sh
```

---

## Controls

| Key   | Action         |
| ----- | -------------- |
| Space | Play / Pause   |
| n     | Next track     |
| p     | Previous track |

---

## License

MIT License © 2025 [Anar Nyambayar](https://www.anar-n.com/)

