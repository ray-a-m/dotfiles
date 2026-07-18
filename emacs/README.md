# Emacs

A small, deliberately hand-written config — the goal is to *learn* Emacs, not
to hide it behind a framework. Package management is `use-package` (built into
Emacs 29+) over the standard `package.el` archives; every block in `init.el` is
there on purpose and commented. Loosely modelled on Doom's module choices,
minus the framework.

Runs **alongside** Neovim, which stays primary for paper writing (vimtex +
latexmk). Emacs is the learning trial and the home for **notes + Org**; as of
the prose pass below it also styles `.tex` buffers, so it's a viable second
LaTeX editor.

## Files

| File            | Role |
|-----------------|------|
| `early-init.el` | Loaded before `package.el` and the first frame: startup GC / `file-name-handler-alist` tuning, UI-chrome suppression (no flash), and the `package-user-dir` / eln-cache redirects out of this git-tracked dir. |
| `init.el`       | Everything else. |

Symlinked to `~/.config/emacs` by `install.sh` (`ln -sfn`, backing up any real
dir to `~/.config/emacs.bak` first).

## State layout

Runtime junk is redirected **out** of this repo so the tracked dir stays clean
(`early-init.el` + `no-littering`; `.gitignore` is the defensive net):

- `~/.config/emacs/` — this dir (symlink into dotfiles); only `.el` sources tracked
- `~/.local/share/emacs/` — installed packages (`elpa/`) + `no-littering` `var/`
- `~/.cache/emacs/` — native-compilation (`eln-cache/`)

## What's configured

| Area | Package(s) | Notes |
|------|-----------|-------|
| Built-in defaults | — | `electric-pair`, `savehist`, `recentf`, auto-revert, `which-key`; single-space sentence ends; soft-wrap prose; line numbers **only** in `prog-mode` |
| Undo | `undo-fu` | linear undo/redo on `C-z` / `C-S-z` |
| Git | `magit` | `C-x g` |
| Spell / syntax | built-in | `flyspell` (aspell) + `flymake` |
| LaTeX | `auctex`, `cdlatex`, `auctex-latexmk` | RefTeX wired to the shared dissertation `.bib`; `C-c C-c` → LatexMk; SyncTeX ↔ **zathura**; `S-TAB` folds the paper via `outline-minor-mode` |
| Live math | `xenops` | inline-SVG preview in LaTeX **and** Org (see below) |
| Org | built-in | notes + agenda + capture; `~/org/` for tasks, `~/Dropbox/notes/` for the vault; inline images on |
| Emphasis | `org-appear` | `/…/` `*…*` markers hidden and rendered, revealed around point for editing |
| Prose look | `mixed-pitch`, `olivetti` | variable-pitch Liberation Serif + centered column (see below) |
| Notes navigator | `treemacs` | collapsible, proportional-font side pane for the vault |
| Markdown | `markdown-mode` | any stray `.md`; `markdown-command` = pandoc |

## Prose writing environment

Org, Markdown and LaTeX are made to read like a page, not a terminal:

- **Variable-pitch body font** — `Liberation Serif` (set on the `variable-pitch`
  face; swap the `:family` to taste). Chosen over Noto Serif because Emacs
  can't select an italic face from Noto Serif's many-weight family, so
  `/italic/` rendered upright. `mixed-pitch` keeps code, tables,
  verbatim and math **monospaced** so they still align — only prose goes
  proportional.
- **Centered column** — `olivetti-mode`, `olivetti-body-width 72`.
- **No line numbers** — already off in these modes (only `prog-mode` enables them).
- **No gray fringe bars** — the `fringe` face background is blended into the
  default background, so the vertical strips beside the text disappear while
  fringe indicators still function.
- **Rendered emphasis** — `org-hide-emphasis-markers` hides the `/ /`, `* *`,
  `= =` markers so italic/bold/verbatim show styled; `org-appear` re-reveals the
  raw markers (and `[[link]]` syntax) around point so they stay editable —
  Obsidian-style live preview.

## Live math preview (xenops)

`xenops-mode` renders every math fragment (`$…$`, `\(…\)`, `\[…\]`, equation
environments) as an inline SVG and re-renders as you type — the "live preview"
feel, in both LaTeX and Org. Point *inside* a fragment reveals its source to
edit; moving *out* re-renders. Needs `dvisvgm` (ships with texlive). Enabled via
hooks on `LaTeX-mode` and `org-mode`; if it feels heavy on a large `.tex` file,
drop the `LaTeX-mode` hook and toggle by hand with `M-x xenops-mode`.

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

| Key | Command |
|-----|---------|
| `C-x g` | `magit-status` |
| `C-c a` / `C-c c` / `C-c l` | Org agenda / capture / store-link |
| `C-c t` | open the `~/Dropbox/notes` vault in Treemacs |
| `<f8>` | toggle Treemacs |
| `C-z` / `C-S-z` | undo / redo (`undo-fu`) |
| `C-c C-c` | compile via LatexMk (in `.tex`) |
| `S-TAB` | cycle the whole document's outline (in `.tex`) |

## Deliberately omitted (and why)

- **evil** — learning the built-in (non-modal) Emacs first.
- **vertico / orderless / marginalia** — living on the built-in `*Completions*`
  buffer until it's outgrown.
- **org-roam** — see the vault section; folder-of-outlines with hand-added
  static backlinks instead of a zettelkasten database.

## External dependencies

Installed by `install.sh`: `emacs-wayland`, `texlive` (→ `latexmk`, `dvisvgm`),
`aspell` + `aspell-en`, `zathura`, `pandoc-cli`, and `ttf-liberation` (the
`Liberation Serif` prose font). Swap the `variable-pitch` family in `init.el`
if you want a different face.

## Future (from init.el's "optional next steps")

`citar` (richer bibliography UI than RefTeX), `pdf-tools` (in-Emacs PDF view —
zathura already covers this), the vertico completion stack, and wiring the
theme to track Omarchy (Emacs doesn't auto-follow `omarchy-theme-set`).
