# Emacs

A config built on **[rougier/nano-emacs](https://github.com/rougier/nano-emacs)**
for the *look*, with **native Emacs keybindings** and a LaTeX + Org writing
stack layered on top. nano supplies the visual base — elegant light theme,
generous frame margins, a top header-line status bar, Roboto Mono + ET Book
typography. Everything else (window management, AUCTeX, Org, prose centering,
the welcome screen) is hand-written in `init.el` and commented, so the config
stays understandable and tuned to **paper + notes** work. Configure by
friction: change things as they annoy you.

**evil was dropped on 2026-07-19**: new packages kept lagging evil-collection
support, and a compat layer wasn't worth it for a prose-only Emacs. The custom
key layer is scoped to what the defaults do badly — window focus/resize/swap
and the sidebars — everything else is stock. Two ergonomic moves make stock
livable: CapsLock is Ctrl at the Hyprland level (`hypr/input.conf`), and the
command prefix is **swapped `C-x` → `C-a`** (so saving is `C-a C-s`, all on
the home row; beginning-of-line lands on the vacated `C-x`). `C-a` is bound
directly to `ctl-x-map`, so echoes and `describe-key` all report
`C-a` — only external manuals still write "C-x".

Runs **alongside** Neovim (still used for some paper writing via vimtex +
latexmk, and for all coding); Emacs is a full second LaTeX editor and the home
for **notes + Org**.

## Files

| File | Role |
|------|------|
| `early-init.el` | Loaded before `package.el` and the first frame: startup GC / `file-name-handler-alist` tuning, UI-chrome suppression (no flash), `package-user-dir` / eln-cache redirects out of this git-tracked dir. |
| `init.el` | Everything else. |
| `nano/` | Vendored nano-emacs modules (the visual base). Only the visual ones are `require`d — see below. Re-pull from upstream to update. |
| `welcome.org` | The startup screen content — an editable Org file (logo + the system map: tasks, find, vault grammar, and the form/matter taxonomy — with splash-local single keys; the full command cheat-sheet is `welcome-commands.org`, shown full-window on `c`). |
| `welcome-commands.org` | The keybinding cheat-sheet shown full-window when you press `c` on the splash. |
| `welcome-logo.svg` | The Emacs logo shown on the welcome screen. |
| `org-paper-export.el` | LaTeX export for the org-authored research workflow (the `paper-latex` backend + generated driver artifacts; also loaded headless by the `publish` shell function). See "Research documents in Org". |
| `org-site-export.el` | HTML export for the org-authored website (the `site-html` backend; pages in `~/scholarship/website` export into the research-public tree GitHub Pages serves; also loaded headless by `publish site`). See "The website in Org". |
| `aspell-personal.pws` | Personal spelling dictionary (tracked + synced; `M-$` `i` appends to it). |

Symlinked to `~/.config/emacs` by `install.sh` (`ln -sfn`, backing up any real
dir to `~/.config/emacs.bak` first).

## The nano base

Vendored under `nano/`. `init.el` loads only the **visual** modules:
`nano-layout`, `nano-faces`, `nano-theme` (+ `nano-theme-light`),
`nano-modeline`, and `nano-help` (`C-M-h` echo-area quick help; the full
help screen via `M-x nano-help` — its `M-h` bind is taken by vim motions). Deliberately
**not** loaded:

- `nano-bindings` — its `M-RET` frame-maximize would clobber `org-meta-return`;
  the one good bit (kill-current-buffer on the prefix's `k`, typed `C-a k`)
  is cherry-picked inline
- `nano-defaults` — the hand-written "sensible defaults" block stands instead
  (and its `completion-styles` would fight orderless)
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
| Keys | — (native) | stock bindings + a scoped window/sidebar layer; the help prefix lives on `C-c h` (and `<f1>`) since `C-h` moves windows |
| Windows | built-in `windmove`/`winner`/`repeat` + `ace-window` | `C-h/j/k/l` focus (tmux/nvim habit), `M-o` jump/swap, `C-c w` menu with repeatable resize (see below) |
| Completion | `vertico`, `orderless`, `marginalia` | live minibuffer lists; out-of-order fragment matching; annotated candidates (M-x shows each command's keybinding) |
| Retrieval | `consult`, `embark` (+`embark-consult`) | previewed prompts/searches: `C-a b` buffers+recents, `M-s l` in-buffer lines, `M-s r` ripgrep here, `M-s o` org headings, `C-c d f`/`g` the note picker (full-window titles, preview right, `M-d` deletes); `C-.` acts on thing at point, `C-. E` in a minibuffer exports the candidate set; prefix help (`C-c d C-h`) is a searchable list via `embark-prefix-help-command` |
| Built-in defaults | — | `electric-pair`, `savehist`, `recentf`, auto-revert, `repeat-mode`; single-space sentence ends; soft-wrap prose; line numbers **only** in `prog-mode` |
| Session | built-in `savehist` | persists kill-ring + command/search history across runs (the useful part of `nano-session`, keeping no-littering's file paths) |
| Undo | built-in | linear undo/redo on `C-z` / `C-S-z` (also `M-z` / `M-S-z`) |
| Git | `magit` | `C-a g` |
| Spell / syntax | built-in + `hl-todo` | `flyspell` (aspell, personal dict in dotfiles, no duplicate-flagging) + `flymake`; `hl-todo` colours TODO/FIXME in code **and** prose |
| LaTeX | `auctex` (14, via the `latex` feature), `cdlatex`, `auctex-latexmk` | RefTeX → shared dissertation `.bib`; `C-c C-c` → LatexMk (save-and-compile); SyncTeX ↔ **zathura**; `S-TAB` folds via `outline-minor-mode` |
| LaTeX in prose | `org-highlight-latex-and-related` + manual preview | `\commands` (cites included) and `$math$` read as highlighted source — muted sienna, same ET Book family as the text. No auto image rendering (`org-fragtog` REMOVED 2026-07-23: fragments made scrolling stutter; xenops dropped earlier — broke font-lock). On-demand preview stays: `C-c C-x C-l` in Org, `C-c C-p C-p` in `.tex` (dvisvgm). Escape-free spellings (the `@@latex:...@@` hatch is historical and its ink hides like a pill): `$G$-action` parses natively (hyphen reclassified as punctuation in the export module); math directly beside a LETTER → `\(...\)` (exports as `$...$`); accents → type é directly; `\dots` bare; footnote-after-emphasis via `/term/[fn::…]`, never straight after a braced `\command{}`. |
| PDFs | `pdf-tools` | replaces DocView (crisp poppler rendering; `epdfinfo` compiled into the package dir). `j`/`k` scroll, `J`/`K` flip pages, `h`/`l` nudge sideways when zoomed; stock `SPC`/`S-SPC`, `+`/`-` zoom, `W`/`P` fit width/page, `o` outline, `C-s` searches the text layer. |
| Org | built-in | notes + agenda + capture; `~/Dropbox/org/` for tasks, `~/Dropbox/notes/` for the vault; inline images on |
| Emphasis | `org-appear` | `/…/` `*…*` markers hidden and rendered, revealed around point for editing |
| Org typography | `org-modern` | heading stars → ✦ ✧ ✱ ✳ (static, per level), TODO/tags → pills, boxed timestamps, tidy lists/tables (agenda too) |
| Prose look | `mixed-pitch`, `olivetti` | ET Book body font, centered column, darkened prose (see below) |
| Sidebars | `dired-sidebar` | dired in a side pane, nano-styled: Roboto Mono, no icons, no banner line (header shows the root's name), TAB expands folders, `hjkl` vim navigation; dotfiles / `.` `..` / README / TODO / LaTeX artifacts hidden via dired-omit (plain dired also omits build exhaust — generated `.tex`, latexmk leftovers, and `.bib` (Zotero-managed); `M-x dired-omit-mode` toggles the truth back); `.org`/`.md` extensions hidden; folders sort before files at every level (dired-wide); papers root on `C-c p`; the vault sidebar is `M-x rm/notes-sidebar` or `<f8>` (`C-c n` captures a note now); follow-file only re-roots from file-visiting buffers — UI buffers like the splash carry a `default-directory` but don't drag the tree (replaced treemacs 2026-07-19) |
| Projects | built-in `project.el` | `C-a p p` switch (research-wip via git, notes vault via a `.project` marker), `C-a p f` find file in project — the fast "land on `higgs/paper.tex`" path |
| Markdown | `markdown-mode` | any stray `.md`; `markdown-command` = pandoc |

## Window management

The daily layout is paper (main window) + notes (top right) + agenda or an AI
shell (bottom right), rearranged on the fly:

- **`C-h/j/k/l`** — focus the window left/down/up/right (windmove; the
  tmux/nvim habit). Org's and AUCTeX's local `C-j` are cleared so this wins
  everywhere. Displaced, deliberately: help prefix → `C-c h` (or `<f1>`;
  prefix help like `C-a C-h` still works via `help-char`), kill-line →
  `C-S-k`, recenter → `C-S-l`.
- **`M-o`** — ace-window: with ≤2 windows it hops immediately; with 3+ each
  window gets a home-row letter. Dispatch keys ride along: `M-o m <letter>`
  **swaps buffers** with that window (the "put the agenda in the big window"
  move), `M-o x <letter>` deletes it.
- **`C-c w`** — the window menu (`C-c w C-h` lists the keys): `s`/`v` split
  below/right (`:sp`/`:vs` mnemonic), `f`/`b` pick a file (vertico) straight
  into a new right/below split — the prompt comes *before* the split, so
  `C-g` leaves the layout untouched — `h/j/k/l` drag the window's divider
  left/down/up/right (edge motion, Hyprland-style: the same key does the same
  visual thing from either side of the divider) — and these **repeat**, so
  `C-c w l l l h …` keeps dragging until any other key — `w` swap, `=`
  balance, `d` delete, `m` maximize, `u`/`r` winner undo/redo (also repeat).
- **winner-mode** — every layout change is undoable (`C-c w u`), so
  "maximize, then bring it all back" is `C-c w m` … `C-c w u`.

## Prose writing environment

Org, Markdown and LaTeX are made to read like a page, not a terminal:

- **Body font: ET Book** (`ETBembo`) on `variable-pitch`, via nano's proportional
  family. `mixed-pitch` keeps code, tables, verbatim and math **monospaced**
  (Roboto Mono) so they still align — only prose goes proportional.
- **Darker prose** — nano's body colour is a soft blue-grey; the prose face is
  darkened (`#1c1c1c`) for contrast while writing, leaving code/UI in nano's grey.
- **Blue italics** — nano fades `italic` to grey; overridden to a soft
  Obsidian-style blue (`#4a6fa5`), full slant (ET Book's thin italic strokes
  read faded at the body colour).
- **Quiet prose modeline** — text-mode buffers show just the name (`.org`/`.md`
  and uniquify's `<dir>` tail hidden, no `(Mode)`; a git branch still shows);
  code buffers keep `name (Mode, branch)`.
- **Matched sizes** — Roboto Mono renders larger than ET Book at the same point
  size, so `fixed-pitch` is shrunk (`:height 0.75`) to sit the `\commands`/math
  level with the prose.
- **Centered column** — `olivetti-mode`, `olivetti-body-width 72`.
- **Rendered emphasis** — `org-hide-emphasis-markers` + `org-appear` (Obsidian-style
  live preview: markers hidden, revealed around point).
- Fringes and UI chrome are handled by nano-layout.

## Welcome screen

At startup (bare `emacs`, no file argument) `rm/welcome` renders `welcome.org`
read-only: the Emacs logo (pixel-centered via `org-image-align`), then the
system map — **Tasks**, **find**, and the **Vault** grammar stacked at the
left, the **form**/**matter** taxonomy in single columns at the right — with
splash-local single keys (`t` `n` `a` `f` `g` `l` `p` `s` `c` `w`). Headers, the
file-name hint, and `[keys]` are coloured with font-lock faces (bold / italic /
salient), **not** Org emphasis markers — that marker-hiding proved unreliable on
a fresh daemon frame (it showed raw asterisks), so the markers are gone from the
file entirely. The full keybinding cheat-sheet lives in `welcome-commands.org`,
shown full-window on `c` (any key returns). `q` / `ESC` dismiss; it also auto-dismisses the first time a real file is
visited, so it never lingers in the buffer list or gets split around by later
windows. Daemon client frames (`emacsclient -c`, the launcher's "Emacs"
entry): the *first* frame of a visit greets with the splash — closing the
last frame (Super+Q) ends the visit, so the next open splashes again even
though the daemon kept every buffer. A frame opened alongside a live one
resumes your last file instead. Its lines truncate rather than
wrap, so the cheat-sheet columns stay aligned at any window width. The logo
is sized to the window — the text below it is a fixed stack of lines, so the
logo gets the height that remains (capped at 500px wide, the external-monitor
look; refit on resize) — so the whole page fits docked and on the laptop
panel alike. The cursor
is hidden. Because it's Org, you customise the page by editing `welcome.org`.

## The notes vault (Org, migrated 2026-07-18)

`~/Dropbox/notes/` is the working note vault, converted from an Obsidian
markdown vault to Org on 2026-07-18. The conversion was **link-aware** (a
one-off `pandoc` + Python pass, not a stored tool):

- `[[wikilinks]]` → real Org file links; `![[embeds]]` → inline image / PDF links
- a static `:BACKLINKS:` drawer at the **top** of each linked-to note (folded,
  since it's a drawer, not a heading) — every one-way link gets a return route
- Markdown `$math$` → Org `\(…\)` / `\[…\]`; dangling links kept as Org
  unresolved links
- headings (`#`) → Org outline (`*`), giving folding + outline navigation

**Deliberate choices:** plain Org file links, **no org-roam** (folder-of-
outlines, not zettelkasten). The backlinks are therefore a **point-in-time
snapshot** — they don't self-update when links change later; that auto-updating
is exactly the database org-roam provides and was declined. No in-file
`#+title:` (keeps files rename-safe).

The original Obsidian vault lives in a **separate location and is left
absolutely untouched** as the deep backup; the `.md` copies inside
`~/Dropbox/notes/` were deleted once the Org conversion was verified.

## Denote: the vault's naming grammar (adopted 2026-07-21)

The vault's organizing principle is [denote](https://protesilaos.com/emacs/denote)
(GNU ELPA): **the filename is the note's address** —
`20260721T105751--topological-realism__paperidea_physics_hegel.org` carries
timestamp, title, and keywords; no database, legible to `ls` forever. The
grammar (all custom, in init.el's Denote section):

- **First keyword = the form** (the act of writing), exactly one:
  `musing poetry idea paperidea wip lit log talk meeting hub presentation`.
  Two families with **no pipeline between them**: contemplative
  (musing/poetry/log/talk/meeting — finished when written) and productive
  (`idea → paperidea → wip`, promoted by `denote-rename-file`, `C-c d r` —
  the ID is immutable so links survive; a live `wip` exits to research-wip).
  `lit` = reading notes; `talk` = talks attended; `presentation` = notes
  for Raymond's own talks; `hub` = curated standing notes (e.g. the
  Technology hub, whose `TODO` headings the agenda picks up).
- **Remaining keywords = matter** (research programs):
  `physics hegel kant math aesthetics science concepts history neo-kantian
  phenomenology teaching fun` (grown during the act-two migration review).
  Keywords sluggify like titles so `neo-kantian` keeps its hyphen; the one
  cost is that org's tag-match syntax reads `-` as NOT, so `C-c a m` can't
  match that atom — find it via `C-c d l` / `C-c d g` instead.
  **No matter means miscellaneous by design** — there is deliberately no
  "misc" keyword; a form-only filename (`__idea.org`) *is* the misc marker
  and is regexp-searchable. `denote-sort-keywords` is nil so the form
  always stays first. Note-matter `teaching` and the org task tag
  `:teaching:` share a name on purpose: denote keywords land in
  `#+filetags`, which the agenda inherits, so teaching-matter TODOs and
  teaching-tagged tasks meet under the same `C-c a m` match.
- **Retrieval — the note picker** (2026-07-23, also splash `f`/`g`/`l`): all
  three keys open straight into a full-window catalog (vertico-buffer) of
  titles, newest first — no ID, no date. Typing narrows: `f` by title,
  `l` by title *or* keywords (shown faded after the title), `g` by
  **content** (each keystroke re-runs rg over the vault). `M-j`/`M-k`
  move, the selection previews in a window to the right, `M-d` deletes
  the note after confirmation, `RET` opens, ESC aborts home. `C-c d b`
  backlinks. Span markers `#important` / `#definition` inside lit notes
  stay as grep-able ink, not keywords. The full map lives on the splash.
- **Capture is frictionless**: `C-c n` opens an untitled, unclassified note
  instantly (zero prompts). On save it titles itself from the first line
  (`rm/denote-autotitle`, only while untitled); `M-c` (`rm/denote-classify`)
  assigns form + matter from the curated lists and renames in place —
  re-runnable, identifier stable. Per-form commands
  (`C-c d i/p/m/o/w/s/t/e/h/n`) still create with a form directly,
  prompting only for matter. (Terminology is Raymond's hylomorphic pair:
  **form** = the act of writing, **matter** = the research program it
  serves; vocabulary growth is deliberate, not drift.)

The vault is **git-tracked** (local repo, initialized 2026-07-21 with a
pre-denote baseline commit) so every migration step is a reviewable diff.
**Act two (the legacy migration) ran 2026-07-22**: 103 legacy files became
415 denote notes at the vault root, split per the reviewed mapping
(`act-two-mapping.org` in the vault records every ruling; originals live in
git history and `~/Dropbox/notes-premigration-20260722.tar.gz`). Only
`Dissertation/` (active-paper notes, deliberately left) and `Files/`
(attachments) remain as folders.

## Research documents in Org (papers 2026-07-20; whole workflow 2026-07-23)

Everything in `research-wip/documents/` is org-authored; the `.tex` each
document compiles from are **generated, gitignored build artifacts**:

- `papers/<slug>/paper.org` → `body.tex` + a `paper.tex` driver built from
  the `#+PAPER_BIB:` keyword (the `\addbibresource` argument)
- `dissertation/dissertation.org` → `body.tex` + `dissertation.tex`
  (title-page fields ride as `#+LATEX_HEADER:` lines so hyperref's
  `pdfusetitle` still sees them before `\begin{document}`)
- `dissertation/frontmatter/*.org` → `<name>.tex` (`\input`ed, no driver)
- `cv/cv.org` → `body.tex` + `maung_cv.tex`

What stays hand-written LaTeX is typesetting config only:
`shared/preamble.tex`, `shared/body-packages.tex`,
`dissertation/preamble.tex` (which also holds `\inputpaperbody`),
`cv/preamble.tex`, and the texmf `.sty` files.

Machinery in `org-paper-export.el`: a `paper-latex` backend that keeps
`$…$` inline math (stock ox-latex rewrites to `\(…\)`), strips the
auto-generated random `\label{sec:orgNNN}`, and ends bodies with exactly
one blank line; a doc-type table mapping the four source patterns to their
artifacts; and a driver writer with per-type templates. Shared export
options live in `research-wip/documents/shared/org-paper.setup` (smart
quotes and special strings off, `tasks:t`, the TODO keywords for batch
runs). Saving regenerates the artifacts (after-save hook); `C-c C-c`
exports + latexmks, matching the AUCTeX binding; `M-x rm/org-paper-watch`
runs `latexmk -pvc` for continuous compile-on-save preview (zathura
refreshes; no inverse search — SyncTeX maps to the generated `.tex`);
`publish` regenerates everything headless via `emacs -Q --batch` before
building. A `** TODO …` jotted mid-document reaches the global agenda
(`org-agenda-files` includes `research-wip/documents/**/*.org`); on export
the TODO headline LINE vanishes while everything beneath it exports as
paper prose (2026-07-23 inversion — the old drop-the-subtree rule silently
hid real sections). Reminder text that must not reach the PDF goes in `#`
org comments. Citations stay raw LaTeX
(`\cite`/`\textcite`/`\parencite`), passed through verbatim.

One cross-document token: `\papertitle{<slug>}` resolves at export time to
`documents/papers/<slug>/paper.org`'s real `\title` (peeling the `\textbf`
the titles carry), so one document can name another's title without
restating it — the CV's Works-in-Progress list uses it, and it stays in
sync as papers are retitled. It rides inside a `#+begin_export latex` block
(which org never parses), so a `:filter-final-output` string pass swaps the
token after export, and the source dir is bound around the export so the
slug resolves relative to it. Each consuming preamble carries a
`\providecommand{\papertitle}[1]{[#1]}` fallback so a stray/unresolved token
degrades to `[slug]` rather than erroring.

Every migration step was gated: generated artifacts byte-identical to the
previously committed files where applicable, and each document verified
`pdftotext`-identical and pixel-identical (`pdftoppm -r 150` + ImageMagick
`compare`, AE=0 every page — all 31 dissertation pages included) against a
pre-migration baseline built at `98b474f`.

## The website in Org (2026-08-01)

raymondmaung.com follows the same philosophy: sources in
`~/scholarship/website` (one `.org` per page), generated HTML written
**straight into the research-public working tree**, which GitHub Pages
serves — no artifact ever lands in the website repo. `shared/` there is
the hand-written presentation config: `template.html` (the page shell —
head, nav; the exporter substitutes the double-braced TITLE/ROOT/BODY
tokens), `style.css` (all theme decisions in a `:root` CSS-variable
block — re-theming is a one-block edit), self-hosted fonts, and
`org-site.setup` (shared export options; smart quotes deliberately ON
here, opposite the LaTeX setup — in HTML that's what makes curly
quotes).

Machinery in `org-site-export.el`: a `site-html` backend derived from
stock ox-html with the paper backend's determinism rule (ox-html's
random `id="orgNNN"` attributes are stripped; same export twice, same
bytes). URL mapping preserves the WordPress-era paths: `index.org` →
`/index.html`, `<name>.org` → `/<name>/index.html`. Saving a page
re-exports it (after-save hook, beside the paper hook); `C-c C-c` too.
Splash `w` opens a dired of the page sources. Deploy is the shell side:
`publish site` batch-exports every page headless, copies the assets,
commits, pushes (the push is the deploy), and tags the website repo.

The Research page auto-syncs with publishing: a
`<!-- published-papers -->` token in `research.org` expands at export
into a list of every PDF in `research-public/documents/papers/`, each
titled from its `paper.org`'s `\title` (the `\papertitle` resolution,
ported — `\emph`/escapes converted to HTML, anything else refused
loudly). `publish <slug>` re-exports the page in the same push, so
publishing a paper puts it on the site with zero editing.

## Keybindings

Stock Emacs everywhere, with **`C-a` as the command prefix** (bound straight
to `ctl-x-map`: type `C-a C-s` to save, `C-a b` to switch buffers, `C-a k`
to kill; plain `C-x` is now beginning-of-line). Every prefix also answers
from the **Alt thumb** (2026-07-25): `M-a` = `C-a`, `M-SPC` = `C-c`,
`M-g` = `C-g`, with M-modified second keys too — `M-a M-s` saves,
`M-SPC SPC` goes home, `M-SPC M-SPC` is `C-c C-c`. The `C-` originals all
still work; the M-SPC/M-g/second-key forms are key-translations, so echoes
and `describe-key` display them as `C-…`. `M-g` quits at the command level
(prompts, pending prefixes, regions) — interrupting *running* code is still
real-`C-g`-only. `M-a M-SPC` is defused to plain quit (it would otherwise
land on `C-x C-c`, close-the-frame). The custom layer on top:

| Key | Command |
|-----|---------|
| `C-h` / `C-j` / `C-k` / `C-l` | focus window left / down / up / right |
| `C-c h` | help prefix (`C-c h k` = describe key); `<f1>` works too |
| `C-S-k` / `C-S-l` | kill-line / recenter (displaced from `C-k` / `C-l`) |
| `M-o` | ace-window: jump to a window; `m` swaps, `x` deletes |
| `C-c w` | window menu: split / `SPC` fresh right split showing the splash (blank slate) / pick-file-into-split (`f` right, `b` below) / swap / repeatable divider drag (`hjkl`) / winner undo |
| `C-c n` | capture a note: instant untitled vault note; titles itself from line 1 on save; `M-c` classifies (form+matter) in place |
| `C-c p` | papers sidebar on `~/scholarship/research-wip` (dired-sidebar roots at the project; `documents/` is one `l` away) |
| `<f8>` | toggle a sidebar at the current project |
| `h` / `j` / `k` / `l` | *in the sidebar:* collapse/up · down · up · expand/visit (vim-style; sidebar-local — plain letters work because the pane is read-only, and they shadow dired's legacy single-key commands) |
| `f` / `b` | *in the sidebar:* open the file at point in a split right of / below the **main** window (same letters as `C-c w f`/`b`; shadows dired's find-file, sidebar-only) |
| `a` / `r` / `d` / `y` / `p` | *in the sidebar:* yazi-style file ops — create (trailing `/` = folder) / rename (pre-fills the current name; a path moves) / delete (to the system trash) / yank / paste. On a folder line, create/paste go *into* it; on a file line, beside it. Every op ends by expanding the tree down to its result and parking point on it — a paste into a collapsed folder is never invisible |
| `C-c e` | copy the last echo-area message (usually the last error) to the clipboard; `C-c h e` pops the full \*Messages\* log |
| `R` / `+` / `a` / `D` | *in plain dired:* rename-or-move (type a name or a path) / new directory / new empty file / delete (to the system trash) |
| `C-a C-q` | *in dired:* wdired — edit filenames like buffer text; `C-c C-c` commits, `C-c C-k` aborts (dired remaps `read-only-mode` to the wdired toggle) |
| `C-a p p` / `C-a p f` | switch project / find file in project (project.el) |
| `C-a k` | kill current buffer, no prompt |
| `C-z` / `C-S-z`, `M-z` / `M-S-z` | undo / redo (built-in `undo` / `undo-redo`; the M forms displaced `zap-to-char`) |
| `M-h/j/k/l`, `M-w`/`M-b` | vim motions: char/line movement, word forward (vim-exact start-of-next-word) / word back |
| `M-v` / `M-d` / `M-y` / `M-p` | highlight toggle / cut / copy / paste — strict vim operators (`d`/`y` need a highlight); kill-ring ↔ system clipboard |
| `M-4` / `M-6` | paragraph back / forward (vim `{`/`}` — on Corne-reachable keys) |
| `C-M-h` | echo-area quick-help cheat-sheet (nano-help) |
| `C-a g` | `magit-status` |
| `C-c g` | the shell `save`, from inside: save buffer → `git add -A` / commit / push this repo, async verdict in the echo area (`C-u` prompts for the message; a remote-less repo like the vault just commits) |
| `C-c a` / `C-c l` | Org agenda dispatcher / store-link (capture lives on the splash: `t` task, `n` note; `C-c c` unbound) |
| `C-c M-s` | `org-schedule` (reached as `M-SPC M-s`; mirrors the `M-SPC` family; default `C-c C-s` still works) — a `SCHEDULED`/`DEADLINE` timestamp is what turns a TODO into a calendar event. Also bound on `C-c M-S` / `C-c S-M-s` for input paths that keep the Shift (this Wayland setup drops it) |
| `C-c G` | push timestamped `inbox.org` TODOs to the Google "org" calendar via **org-gcal** (REST, one-way — nothing read back; visible on the phone + rencal). Scheduling a task also auto-pushes just that entry, so `C-c G` is the bulk/manual fallback. Creds live in `~/.authinfo.gpg`; Google 403s CalDAV for unverified apps, hence REST/org-gcal not org-caldav |
| `M-x restart-emacs` | restart the systemd Emacs daemon **and** reopen a frame (Super+Q / `super+w` only close the frame; a bare daemon restart leaves you headless) |
| `C-c b` | insert a citation via completion (citar over the Zotero bibs): `\textcite{...}` in prose, `C-u` = `\parencite`; inside a hand-typed `\cite{`'s braces it completes just the key. Typing inside the braces also pops keys as-you-type (corfu + a bib-parsing capf, org and LaTeX buffers) |
| `C-c C-c` | compile via LatexMk (in `.tex`, and in any org-authored research document: exports the artifacts, then builds); in a website page it re-exports the HTML |
| `S-TAB` | cycle the document outline (in `.tex`) |
| `ESC` | universal back: abort prompt → drop region → dismiss a sidebar → one step back through this window's buffer history (machinery popups skipped; the splash counts as a stop) → when the trail ends, a popup window closes; the frame's last real window (sidebars don't count) dismisses an open sidebar first, then floors on the splash (one splash only — ESC on a duplicate closes it) |
| `M-ESC` | switch buffer (consult, previewing, most recent first) — the forward leap opposite ESC |
| `M-c` | classify: vault note → form+matter rename; task heading / agenda entry → task tags (in the minibuffer: one letter tags and exits; `C-c` there shows the key grid) |
| `C-c s` | pop the \*scratch\* buffer |
| `C-c SPC` | straight home: the splash in the current window — the teleport when ESC's step-by-step walk is too long (`C-c w SPC` is the same destination in a new split) |
| `q` | dismiss the welcome screen |

Config reload after edits is `M-x rm/reload-init` (unbound — orderless makes
`M-x rel in` find it instantly).

## Deliberately omitted (and why)

- **evil / evil-collection** — dropped 2026-07-19 after a day of use: new
  packages kept lagging evil-collection support, and maintaining a compat
  layer wasn't worth it for a prose-only Emacs (coding stays in nvim).
- **citar** — RefTeX already inserts citations from the shared `.bib`; citar
  (fuzzy author/title search over the bib, riding on vertico) is the upgrade
  path when RefTeX's prompt chafes.
- **org-roam** — see the vault section; folder-of-outlines with hand-added
  static backlinks instead of a zettelkasten database.

## External dependencies

Installed by `install.sh`: `emacs-wayland`, `texlive` (→ `latexmk`, `dvisvgm`),
`aspell` + `aspell-en`, `zathura`, `pandoc-cli`. Fonts live in
`~/.local/share/fonts/`: **ET Book** (`ETBembo`, the prose face), **Roboto Mono**
(default / code), and **Fira Code** (glyph fallback). Change the families via
`nano-font-family-*` in `init.el`.

## Future (from init.el's "optional next steps")

`citar` (see above), `pdf-tools` (in-Emacs PDF view — zathura already covers
this), wiring the theme to track Omarchy, and the elegant `Welcome.org` second
(quick-commands) page.
