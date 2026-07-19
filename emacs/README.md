# Emacs

A config built on **[rougier/nano-emacs](https://github.com/rougier/nano-emacs)**
for the *look*, with an **evil** (vim) keybinding layer and a LaTeX + Org writing
stack layered on top. nano supplies the visual base — elegant light theme,
generous frame margins, a top header-line status bar, Roboto Mono + ET Book
typography. Everything else (evil, AUCTeX, Org, prose centering, the welcome
screen) is hand-written in `init.el` and commented, so the config stays
understandable and tuned to **paper + notes** work. Configure by friction: change
things as they annoy you.

Runs **alongside** Neovim (still used for some paper writing via vimtex +
latexmk); Emacs is now a full second LaTeX editor and the home for **notes + Org**.

## Files

| File | Role |
|------|------|
| `early-init.el` | Loaded before `package.el` and the first frame: startup GC / `file-name-handler-alist` tuning, UI-chrome suppression (no flash), `package-user-dir` / eln-cache redirects out of this git-tracked dir. |
| `init.el` | Everything else. |
| `nano/` | Vendored nano-emacs modules (the visual base). Only the visual ones are `require`d — see below. Re-pull from upstream to update. |
| `welcome.org` | The startup screen content — an editable Org file (logo, quick help, keybind cheat-sheet, clickable actions). |
| `welcome-logo.svg` | The Emacs logo shown on the welcome screen. |
| `aspell-personal.pws` | Personal spelling dictionary (tracked + synced; `M-$` `i` appends to it). |

Symlinked to `~/.config/emacs` by `install.sh` (`ln -sfn`, backing up any real
dir to `~/.config/emacs.bak` first).

## The nano base

Vendored under `nano/`. `init.el` loads only the **visual** modules:
`nano-layout`, `nano-faces`, `nano-theme` (+ `nano-theme-light`),
`nano-modeline`, and `nano-help` (`M-p` echo-area quick help). Deliberately
**not** loaded:

- `nano-bindings` — evil owns the keys
- `nano-defaults` — the hand-written "sensible defaults" block stands instead
- `nano-session` — its history-persistence idea is adopted inline (see below), minus its `~/.nano-*` litter
- `nano-counsel` / `nano-mu4e` / `nano-agenda` — packages not used

Fonts are routed **through** nano: `Roboto Mono` (default / code), **ET Book**
(prose) — note the family Emacs wants is `ETBembo`, *not* `et-book`. Size is one
knob, `nano-font-size`.

## State layout

Runtime junk is redirected **out** of this repo so the tracked dir stays clean
(`early-init.el` + `no-littering`; `.gitignore` is the defensive net):

- `~/.config/emacs/` — this dir (symlink into dotfiles); only sources tracked
- `~/.local/share/emacs/` — installed packages (`elpa/`) + `no-littering` `var/`
- `~/.cache/emacs/` — native-compilation (`eln-cache/`)

## What's configured

| Area | Package(s) | Notes |
|------|-----------|-------|
| Look | `nano-*` (vendored) | light theme, frame margins, top header-line modeline, Roboto Mono + ET Book |
| Keys | `evil`, `evil-collection`, `evil-org` | vim everywhere; help prefix moved to `M-h` so `C-h` is window-left |
| Built-in defaults | — | `electric-pair`, `savehist`, `recentf`, auto-revert, `which-key`; single-space sentence ends; soft-wrap prose; line numbers **only** in `prog-mode` |
| Session | built-in `savehist` | persists kill-ring + command/search history across runs (the useful part of `nano-session`, keeping no-littering's file paths) |
| Undo | `undo-fu` | linear undo/redo on `C-z` / `C-S-z` (evil `u` / `C-r`) |
| Git | `magit` | `C-x g` |
| Spell / syntax | built-in + `hl-todo` | `flyspell` (aspell, personal dict in dotfiles, no duplicate-flagging) + `flymake`; `hl-todo` colours TODO/FIXME in code **and** prose |
| LaTeX | `auctex` (14, via the `latex` feature), `cdlatex`, `auctex-latexmk` | RefTeX → shared dissertation `.bib`; `C-c C-c` → LatexMk (save-and-compile); SyncTeX ↔ **zathura**; `S-TAB` folds via `outline-minor-mode` |
| Live math | built-in preview + `org-fragtog` | inline SVG via `dvisvgm` (`C-c C-x C-l` in Org, `C-c C-p C-p` in `.tex`); `org-fragtog` auto-renders Org fragments. **Not** xenops (dropped — broke font-lock). |
| Org | built-in | notes + agenda + capture; `~/Dropbox/org/` for tasks, `~/Dropbox/notes/` for the vault; inline images on |
| Emphasis | `org-appear` | `/…/` `*…*` markers hidden and rendered, revealed around point for editing |
| Prose look | `mixed-pitch`, `olivetti` | ET Book body font, centered column, darkened prose (see below) |
| Notes navigator | `treemacs` | collapsible, proportional-font side pane for the vault |
| Markdown | `markdown-mode` | any stray `.md`; `markdown-command` = pandoc |

## Prose writing environment

Org, Markdown and LaTeX are made to read like a page, not a terminal:

- **Body font: ET Book** (`ETBembo`) on `variable-pitch`, via nano's proportional
  family. `mixed-pitch` keeps code, tables, verbatim and math **monospaced**
  (Roboto Mono) so they still align — only prose goes proportional.
- **Darker prose** — nano's body colour is a soft blue-grey; the prose face is
  darkened (`#1c1c1c`) for contrast while writing, leaving code/UI in nano's grey.
- **Matched sizes** — Roboto Mono renders larger than ET Book at the same point
  size, so `fixed-pitch` is shrunk (`:height 0.75`) to sit the `\commands`/math
  level with the prose.
- **Centered column** — `olivetti-mode`, `olivetti-body-width 72`.
- **Rendered emphasis** — `org-hide-emphasis-markers` + `org-appear` (Obsidian-style
  live preview: markers hidden, revealed around point).
- Fringes and UI chrome are handled by nano-layout.

## Welcome screen

At startup (bare `emacs`, no file argument) `rm/welcome` renders `welcome.org`
read-only: the Emacs logo, a *Quick help* section, a two-column keybind
cheat-sheet, and clickable actions (open the dissertation, the notes tree, or the
welcome file itself). It stays in evil **normal** state so `SPC` is still your
leader; `q` / `ESC` dismiss; the cursor is hidden. Because it's Org, you customise
the page by editing `welcome.org` (there's an "Edit this screen" link on it).

## The notes vault (Org, migrated 2026-07-18)

`~/Dropbox/notes/` is the working note vault, converted from an Obsidian
markdown vault to Org on 2026-07-18. The conversion was **link-aware** (a
one-off `pandoc` + Python pass, not a stored tool):

- `[[wikilinks]]` → real Org file links; `![[embeds]]` → inline image / PDF links
- a static `:BACKLINKS:` drawer at the **top** of each linked-to note (folded,
  and invisible to Treemacs since it's a drawer, not a heading) — every
  one-way link gets a return route
- Markdown `$math$` → Org `\(…\)` / `\[…\]`; dangling links kept as Org
  unresolved links
- headings (`#`) → Org outline (`*`), giving folding + Treemacs navigation

**Deliberate choices:** plain Org file links, **no org-roam** (folder-of-
outlines, not zettelkasten). The backlinks are therefore a **point-in-time
snapshot** — they don't self-update when links change later; that auto-updating
is exactly the database org-roam provides and was declined. No in-file
`#+title:` (keeps files rename-safe).

The original Obsidian vault lives in a **separate location and is left
absolutely untouched** as the deep backup; the `.md` copies inside
`~/Dropbox/notes/` were deleted once the Org conversion was verified.

## Keybindings

evil provides vim motions/editing everywhere; the notable custom binds:

| Key | Command |
|-----|---------|
| `M-h` | help prefix (moved from `C-h`; e.g. `M-h k` describe-key) |
| `C-h` / `C-j` / `C-k` / `C-l` | move between windows |
| `SPC o` | open the `~/Dropbox/notes` vault in Treemacs |
| `SPC b d` | close buffer |
| `SPC q r` | reload `init.el` |
| `<f8>` | toggle Treemacs |
| `M-p` | echo-area quick-help cheat-sheet (nano-help) |
| `C-z` / `C-S-z` | undo / redo (`undo-fu`; evil `u` / `C-r`) |
| `C-x g` | `magit-status` |
| `C-c a` / `C-c c` / `C-c l` | Org agenda / capture / store-link |
| `C-c C-c` | compile via LatexMk (in `.tex`) |
| `S-TAB` | cycle the document outline (in `.tex`) |
| `q` / `ESC` | dismiss the welcome screen |

## Deliberately omitted (and why)

- **vertico / orderless / marginalia** — living on the built-in `*Completions*`
  buffer until it's outgrown.
- **org-roam** — see the vault section; folder-of-outlines with hand-added
  static backlinks instead of a zettelkasten database.

## External dependencies

Installed by `install.sh`: `emacs-wayland`, `texlive` (→ `latexmk`, `dvisvgm`),
`aspell` + `aspell-en`, `zathura`, `pandoc-cli`. Fonts live in
`~/.local/share/fonts/`: **ET Book** (`ETBembo`, the prose face), **Roboto Mono**
(default / code), and **Fira Code** (glyph fallback). Change the families via
`nano-font-family-*` in `init.el`.

## Future (from init.el's "optional next steps")

`citar` (richer bibliography UI than RefTeX), `pdf-tools` (in-Emacs PDF view —
zathura already covers this), the vertico completion stack, wiring the theme to
track Omarchy, the elegant `Welcome.org` second (quick-commands) page, and a
trial of `sidetabs` (left-side buffer tabs).
