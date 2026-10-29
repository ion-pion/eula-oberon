# Eula Oberon

**An Oberon-07 terminal and compiler that runs on an Android phone, and builds Android apps on the phone itself — no PC, no Android Studio.**

Eula Oberon is a small development environment written by Ion Paraschiv (Pion), an independent researcher from Iași, Romania (Jahbalon Research), together with Claude. It started as a toy and grew into the place where all of his phone apps are written: you type an Oberon module, and one command turns it into an installable Android app with its own icon.

> The interface and the comments are in **Romanian**. The language keywords (`MODULE`, `BEGIN`, `IF` …) are standard Oberon-07. An English interface is planned.

## What it does

- **Oberon-07 compiler on the phone** — compiles to Java bytecode, runs your module immediately.
- **Terminal** (dark violet, gold text) with a small shell: `cp`, `ls`, `cat`, editing, history.
- **`apk Module.Mod "Label"`** — packs a module into a separate Android app (own package name, own icon). Your apps get a screen API (`Ecran`), sound (`Sunet`), sensors (`Senzor`), files, TCP / HTTP, notifications, clipboard, and can keep working with the screen off (`Fundal*`, `Ecran.Treaz`).
- **HTML pages → Android apps** directly from the terminal.

## Install (Termux)

Eula Oberon is installed once with a single script, from [Termux](https://f-droid.org/packages/com.termux/):

```sh
bash install-eula-oberon.sh
```

The script contains everything (compiler, runtime, Inferno bits for the terminal) and builds the Eula Oberon app; after that, Termux is no longer needed.

## Make your first app

In the Eula Oberon terminal:

```
cp /sdcard/Download/Cubicum7B18.Mod Cubicum7B18.Mod
apk Cubicum7B18.Mod "Cubicum 7·B"
```

(one command per line — the shell does not accept `;`).

## Examples

- `examples/Cubicum7B18.Mod` — **Cubicum 7·B**, the biggest app built with Eula Oberon: a small operating system inside one app. A scheduler with 7 processes on a "spiral", memory on a 7-dimensional Z₇ torus (7⁷ cells, base 7 written with digits 1–7, no zero), a file system addressed by coordinates (Cubicum FS), a shell, an editor, windowed apps written in its own language Z7, permissions, reminders, background work, backups — and an "Egg" that answers questions with seven expert "arts" (grammar, logic, rhetoric, arithmetic, geometry, music, astronomy), learns from 👍/👎, and looks things up on Wikipedia when nobody knows.
- `examples/pian.z7l` — a 7-key piano written *inside* Cubicum in the Z7 language (run it with `run pian`).

## Source

`source/` holds the readable sources: the Oberon modules (`oberon/`, `sistem/`), the Java "skin" for the Android screen (`aplicatie/`, `src/`), and the small native terminal helper (`native/eulapty.c`). The installer script is the authoritative build.

## Status

A personal, experimental project — built out of curiosity, tested on one phone (Samsung Galaxy A15). Expect rough edges.

Related papers by the author: [Zenodo](https://zenodo.org/search?q=Ion%20Paraschiv).

## License

MIT — see `LICENSE`.
