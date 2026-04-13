# winduz

A macOS menu bar app and CLI for jumping between frequently-used directories in Ghostty + tmux.

Click (or key-pick) a favorite and winduz does the right thing:

1. If a tmux pane is already `cd`'d to that directory anywhere, focus it.
2. Else, if a tmux session is running, open a new tmux **window** in it at that path (no new Ghostty window, no tabs).
3. Else, launch a fresh Ghostty window with a new tmux session rooted at that path.

The whole idea: one Ghostty window, one tmux session, many tmux windows — and a fast way to land wherever you need to be.

## Requirements

- macOS 14+
- [Ghostty](https://ghostty.org/) installed at `/Applications/Ghostty.app`
- `tmux`
- Swift toolchain (comes with Xcode or Command Line Tools)
- `fzf` (optional, used by the shell functions below)

## Install

```sh
git clone git@github.com:paul-wolf/winduz.git
cd winduz
make install
```

This will:
1. Build a release binary.
2. Install `Winduz` and `wz` to `~/.local/bin/` (override with `PREFIX=/usr/local make install`).
3. Register a launchd agent so Winduz launches automatically at login.
4. Start Winduz immediately.

If `~/.local/bin` is not on your PATH, add it to `~/.zshrc`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

To uninstall:

```sh
make uninstall
```

## Development

```sh
make dev        # runs the debug build in the foreground
swift run Winduz
```

## Features

- **Menu bar dropdown** — click the folder icon to see all favorites; click one to open.
- **Floating window** — a pinnable, always-on-top panel with a filter box and selectable list.
- **Global hotkey** — `⌘⌥W` toggles the floating window from anywhere.
- **Keyboard nav in the window** — type to filter, arrow keys to move, Enter to open, Esc to clear or hide.
- **Pin toggle** — inside the window, toggle between `.floating` and normal levels.
- **Recently used first** — favorites are sorted by last-used timestamp.
- **Visit tracking** — optional zsh hook records every `cd` into `visits.jsonl` with frecency scoring.
- **Live reload** — edits to favorites via the CLI show up in the app without a restart (via filesystem watcher).
- **Shared storage** — `~/Library/Application Support/Winduz/favorites.json` is the single source of truth for both the app and CLI.

## CLI

```
wz                            # list favorites (default)
wz ls [--tab]                 # list favorites; --tab for machine-readable name<TAB>path
wz add [path] [--name N]      # add favorite; path defaults to $PWD, name defaults to basename
wz rm <name|path>             # remove favorite
wz open <name|path|dir>       # open a favorite or any directory in Ghostty+tmux
wz touch <name|path>          # mark as recently used (bumps it to the top)
wz visit <path>               # record a visit (for chpwd hook)
wz top [-l N]                 # top visited directories by frecency
```

Examples:

```sh
wz add                              # add current directory
wz add ~/prj/foo --name foo
wz open foo
wz open /tmp                        # works with arbitrary dirs, not just favorites
```

## Shell integration (zsh)

Add to your `~/.zshrc`:

```zsh
# Interactive fuzzy picker that cds in the current shell
wzcd() {
  local p
  p=$(wz ls --tab | fzf --delimiter=$'\t' --with-nth=1,2 --height=40% --reverse --prompt='wz> ' | awk -F'\t' '{print $2}')
  [ -n "$p" ] && wz touch "$p" && cd "$p"
}

# Interactive picker (or direct arg) that launches in Ghostty+tmux
wzgo() {
  if [ -n "$1" ]; then
    wz open "$1"
    return
  fi
  local p
  p=$(wz ls --tab | fzf --delimiter=$'\t' --with-nth=1,2 --height=40% --reverse --prompt='wz> ' | awk -F'\t' '{print $2}')
  [ -n "$p" ] && wz open "$p"
}

# Auto-record every cd for future frecency ranking
autoload -U add-zsh-hook
_wz_visit() { wz visit "$PWD" &!; }
add-zsh-hook chpwd _wz_visit
```

Then `source ~/.zshrc`.

## Keyboard shortcuts (floating window)

| Key           | Action                                    |
|---------------|-------------------------------------------|
| `⌘⌥W`         | Toggle the window (global, hides if focused) |
| typing        | Filter the list                           |
| `↑` / `↓`     | Move selection                            |
| `Enter`       | Open selected                             |
| `Esc`         | Clear filter if non-empty, else hide window |
| click         | Open that row                             |

## Storage

- `~/Library/Application Support/Winduz/favorites.json` — favorites list (pretty JSON).
- `~/Library/Application Support/Winduz/visits.jsonl` — append-only visit log (JSON per line).

Both are plain text; edit or back up freely.
