;;; init.el --- Raymond's Emacs configuration  -*- lexical-binding: t; -*-
;;
;; A hand-written config layered on rougier/nano-emacs for the *look* only.
;; nano supplies the visual base (elegant light theme, generous frame margins,
;; a top header-line status bar, Roboto-Mono/ET-Book fonts); everything else --
;; evil (nvim keybindings), the LaTeX/Org writing stack, prose centering -- is
;; our own, so the config stays understandable and tuned to paper + notes work.
;; Configure by friction: change things here as they annoy you.
;;
;; State layout (see early-init.el for the redirects):
;;   ~/.config/emacs/       this file -- symlink into dotfiles, git-tracked
;;   ~/.config/emacs/nano/  vendored nano-emacs modules (the visual base)
;;   ~/.local/share/emacs/  installed packages + no-littering var/
;;   ~/.cache/emacs/        native-compilation cache
;;
;;   :look   nano (layout / faces / theme / modeline)
;;   :keys   evil + evil-collection + evil-org      :tools  magit
;;   :lang   latex (auctex+cdlatex+reftex), org     :checkers spell, syntax
;;   :prose  mixed-pitch + olivetti + ETBembo

;;; Code:

;; --- Package system ------------------------------------------------------

(require 'package)
(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa"  . "https://melpa.org/packages/")))
(package-initialize)

;; Install anything missing so a fresh machine bootstraps itself.
(require 'use-package)
(setq use-package-always-ensure t)

(unless package-archive-contents        ; refresh archives on first run only
  (package-refresh-contents))

;; --- Keep the config dir clean ------------------------------------------
;; Must load early: redirects auto-saves, backups, history, recentf, url
;; cache, transient files, etc. out of this git-tracked directory.

(use-package no-littering
  :init
  (setq no-littering-var-directory
        (expand-file-name "emacs/var/"
                          (or (getenv "XDG_DATA_HOME") "~/.local/share"))
        no-littering-etc-directory
        (expand-file-name "emacs/etc/"
                          (or (getenv "XDG_DATA_HOME") "~/.local/share")))
  :config
  ;; Send Customize's auto-written settings to var/ (untracked); we
  ;; configure everything here by hand instead.
  (setq custom-file (no-littering-expand-var-file-name "custom.el"))
  (load custom-file 'noerror 'nomessage)
  ;; Force auto-save #files# and backup file~ files out of the (Dropbox-synced)
  ;; working tree into var/, so they don't sync as phantom "duplicates".  (Lock
  ;; files .#foo are disabled via `create-lockfiles' above.)  no-littering is
  ;; supposed to set both, but in practice it wasn't winning, so pin them here.
  (setq auto-save-file-name-transforms
        `((".*" ,(no-littering-expand-var-file-name "auto-save/") t))
        backup-directory-alist
        `((".*" . ,(no-littering-expand-var-file-name "backup/")))))

;; --- Sensible built-in defaults -----------------------------------------
;; No packages here -- this is Emacs teaching you what Emacs is.

(setq inhibit-startup-screen t
      initial-scratch-message nil
      ring-bell-function #'ignore         ; no beep
      use-short-answers t                 ; y/n instead of yes/no
      sentence-end-double-space nil)      ; prose: single space ends a sentence

;; The notes vault lives in Dropbox, so Emacs lock files (.#file) sync as
;; phantom "duplicate" files (and churn on every edit).  Disable them --
;; single-user machine, so the "already open elsewhere" guard isn't needed.
;; Auto-save (#file#) and backups are already redirected out of the tree by
;; no-littering, so those don't litter the vault.
(setq create-lockfiles nil)

(setq-default indent-tabs-mode nil
              fill-column 80)

;; Native-comp is on in the Arch emacs-wayland build; don't pop its async
;; warnings buffer while you write.
(setq native-comp-async-report-warnings-errors 'silent)

;; Session persistence (the useful part of nano-session, minus its litter).
;; savehist already persists the minibuffer history; here we persist *more*
;; across runs so a restart feels continuous -- yanks, command/search history.
;; Set before `savehist-mode' below so these are restored on load.  Unlike
;; nano-session.el we do NOT touch savehist-file / recentf-save-file /
;; backup-directory-alist -- no-littering already owns those, out of $HOME.
(setq savehist-additional-variables
      '(kill-ring                        ; yanks survive a restart
        command-history                  ; M-: / M-! history
        search-ring regexp-search-ring   ; / and ? search history
        query-replace-history
        read-expression-history)
      history-length 250
      kill-ring-max 25)
;; Kill-ring entries can carry text properties (faces/overlays); strip them so
;; the saved history stays small and plain.
(add-hook 'kill-emacs-hook
          (lambda ()
            (setq kill-ring (mapcar #'substring-no-properties
                                    (seq-filter #'stringp kill-ring)))))

(electric-pair-mode 1)                    ; auto-close brackets and $...$
(savehist-mode 1)                         ; persist minibuffer history (+ the above)
(recentf-mode 1)                          ; M-x recentf-open-files
(global-auto-revert-mode 1)               ; reload files changed on disk
(column-number-mode 1)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'text-mode-hook #'visual-line-mode)   ; soft-wrap prose

;; which-key shows the possible completions after you start a key
;; sequence -- indispensable while learning binds.  Built in on Emacs 30,
;; but :ensure keeps this working on older Emacsen too.
(use-package which-key
  :config (which-key-mode 1))

;; --- NANO visual base (rougier/nano-emacs, vendored in ./nano) ----------
;; The look: an elegant light theme, generous frame margins (internal-border),
;; a top header-line status bar with the bottom mode-line hidden, and the
;; Roboto-Mono + ET-Book typography.  We load only the *visual* modules, and
;; deliberately NOT: nano-bindings (evil owns the keys), nano-defaults (our
;; built-in defaults above stand), nano-session, nor the counsel/mu4e/agenda
;; modules (packages we don't use).  Vendored under ./nano so it's editable and
;; pinned; re-pull from github.com/rougier/nano-emacs to update.
(add-to-list 'load-path
             (expand-file-name "nano" (file-name-directory user-init-file)))

;; Fonts must be set BEFORE nano-faces reads them.  Both are installed under
;; ~/.local/share/fonts.  GOTCHA on ET Book: the family Emacs wants is
;; "ETBembo", *not* "et-book" (that's only the CSS @font-face alias; the TTF's
;; internal family is ETBembo -- verify with `fc-list | grep -i etbembo').
;; Setting it as the proportional family routes it through `variable-pitch',
;; which mixed-pitch swaps in for prose while code/tables stay Roboto Mono.
(setq nano-font-family-monospaced "Roboto Mono"
      nano-font-family-proportional "ETBembo"
      nano-font-size 12)              ; whole-UI size knob; bump/drop by 1 to taste

(require 'nano-layout)          ; frame margins, no chrome, pretty wrap/truncate glyphs
(require 'nano-faces)           ; the semantic faces (default/strong/faded/salient/...)
(require 'nano-theme)
(require 'nano-theme-light)
(nano-theme-set-light)          ; Material-design light palette (light only, no dark)
(nano-refresh-theme)            ; = (nano-faces) + (nano-theme): actually apply it
(require 'nano-modeline)        ; status -> top header-line; bottom mode-line hidden

;; nano-help: `M-p' pops a one-line quick-help cheat-sheet in the echo area, and
;; `M-x nano-help' opens the full quick-help.org screen.  NOTE it also does
;; `(global-set-key "M-h" 'nano-help)', which would steal your help prefix --
;; but evil's `:config' re-binds M-h -> help-command *after* this loads, so your
;; prefix wins and you just gain M-p.  (quick-help.org is vendored alongside the
;; .el files so the M-x nano-help screen resolves.)
(require 'nano-help)

;; nano-layout sets `default-frame-alist', which only affects frames created
;; *after* it -- so the already-open initial frame won't show nano's margin
;; (internal-border) until nudged.  Push it (and the thin fringes) onto every
;; live frame now, reading the values back from the alist so there's no magic
;; number to keep in sync.
(modify-all-frames-parameters
 (seq-filter (lambda (kv) (memq (car kv) '(internal-border-width
                                           left-fringe right-fringe)))
             default-frame-alist))

;; nano-layout calls `(tool-bar-mode nil)' / `(scroll-bar-mode nil)', and for a
;; minor mode a nil argument *toggles* -- since early-init already turned these
;; off, nano toggled them back ON (a stray toolbar + scrollbar).  Force off.
(tool-bar-mode -1)
(scroll-bar-mode -1)
(menu-bar-mode -1)

;; --- Undo (:emacs undo) -------------------------------------------------
;; Linear, predictable undo/redo instead of Emacs's undo-ring.

(use-package undo-fu
  :init (global-unset-key (kbd "C-z"))    ; was suspend-frame; reclaim it
  :bind (("C-z"   . undo-fu-only-undo)
         ("C-S-z" . undo-fu-only-redo)))

;; --- Vim keybindings (evil) ---------------------------------------------
;; Emacs with Neovim muscle memory.  evil-collection vimifies the built-in
;; modes (dired, help, magit, treemacs, ...); evil-org handles Org.  A few
;; custom binds mirror the LazyVim habits.  Undo/redo is the undo-fu above
;; (`u' / `C-r' in normal state).  Help moves from C-h to M-h so C-h is free
;; for window-left (no F1 on the Corne).  (nano hides the bottom mode-line, so
;; there's no evil-state text indicator -- the cursor shape shows the state.)

;; Reload init.el in place -- apply most config edits without a full restart.
(defun rm/reload-init ()
  "Re-evaluate init.el so config changes take effect without restarting."
  (interactive)
  (load-file user-init-file)
  (message "init.el reloaded."))

(use-package evil
  :init
  (setq evil-want-integration t
        evil-want-keybinding nil          ; must be set before load for evil-collection
        evil-want-C-u-scroll t            ; C-u scrolls up a half-page, like vim
        evil-want-C-i-jump nil            ; leave TAB alone (Org folding / indent)
        evil-undo-system 'undo-fu)        ; reuse the undo-fu configured above
  :config
  (evil-mode 1)
  (keymap-global-set "M-h" #'help-command)          ; help prefix -> M-h
  ;; C-hjkl: move between windows, in every editing state (like nvim n/i/v).
  (evil-define-key '(normal insert visual motion) 'global
    (kbd "C-h") #'windmove-left
    (kbd "C-j") #'windmove-down
    (kbd "C-k") #'windmove-up
    (kbd "C-l") #'windmove-right)
  ;; SPC leader -- just the keys you actually use.
  (evil-define-key '(normal visual) 'global
    (kbd "SPC o")   #'treemacs               ; leader+o: file explorer
    (kbd "SPC b d") #'kill-current-buffer    ; leader+bd: close buffer
    (kbd "SPC q r") #'rm/reload-init))       ; reload config after edits

(use-package evil-collection
  :after evil
  :config (evil-collection-init))

(use-package evil-org
  :after (evil org)
  :hook (org-mode . evil-org-mode)
  :config
  (require 'evil-org-agenda)
  (evil-org-agenda-set-keys))

;; --- Spell + syntax checking (:checkers spell / syntax) -----------------
;; Both are built in.  Flyspell needs `aspell' (+ a dictionary) on PATH.

(setq ispell-program-name (or (executable-find "aspell")
                              (executable-find "hunspell")))
;; Personal word list kept in the dotfiles (tracked + synced), not aspell's
;; default ~/.aspell.en.pws.  M-$ then `i' saves a word here.
(setq ispell-personal-dictionary
      (expand-file-name "aspell-personal.pws" (file-name-directory user-init-file)))
;; Don't flag a word repeated across a line break as an error -- it fires on
;; e.g. a `* Emacs' heading followed by a paragraph starting "Emacs ...".
(setq flyspell-mark-duplications-flag nil)
(add-hook 'text-mode-hook #'flyspell-mode)
(add-hook 'prog-mode-hook #'flyspell-prog-mode)
(add-hook 'prog-mode-hook #'flymake-mode)

;; --- TODO / FIXME highlighting (hl-todo) --------------------------------
;; Colour TODO, FIXME, NOTE, HACK ... keywords wherever they appear -- code and
;; prose, including .tex.  Pure highlighting, no Org needed: drop a `TODO' in a
;; paper and it stands out.  Jump with `hl-todo-next' / `hl-todo-previous';
;; `M-x hl-todo-occur' lists them in the buffer.  (Org's TODO *workflow* -- state
;; cycling, agenda -- is Org-only; for a TODO list across all papers ask about
;; magit-todos / consult-todo, which scan any file type.)
(use-package hl-todo
  :hook ((prog-mode     . hl-todo-mode)
         (LaTeX-mode    . hl-todo-mode)
         (markdown-mode . hl-todo-mode)))

;; --- Git (:tools magit) -------------------------------------------------

(use-package magit
  :defer t
  :bind ("C-x g" . magit-status))

;; --- LaTeX (:lang latex +cdlatex) ---------------------------------------
;; AUCTeX + CDLaTeX, wired to latexmk and zathura so it matches your
;; existing nvim/latexmk/zathura flow.

;; AUCTeX 14 defines `LaTeX-mode' / `LaTeX-mode-map' in the `latex' feature (not
;; `tex'), so we `use-package latex' -- still installing the `auctex' package.
;; Using `tex' here left `LaTeX-mode-map' void when the mode loaded, which errored
;; and silently dropped every .tex to Fundamental mode (no font-lock, no hooks).
(use-package latex
  :ensure auctex
  :mode ("\\.tex\\'" . LaTeX-mode)        ; route .tex -> AUCTeX's LaTeX-mode
  :hook ((LaTeX-mode . turn-on-cdlatex)   ; fast math input (impatient-scholar step 1)
         (LaTeX-mode . turn-on-reftex)    ; \ref / \cite from the .bib
         (LaTeX-mode . TeX-source-correlate-mode)  ; SyncTeX forward/inverse
         (LaTeX-mode . outline-minor-mode)) ; fold on \section / \subsection
  :bind (:map LaTeX-mode-map
         ;; S-TAB anywhere in the buffer cycles the whole paper:
         ;; overview (sections only) -> contents (all headings) -> show all.
         ("<backtab>" . outline-cycle-buffer))
  :init
  (setq TeX-auto-save t                   ; parse macros/labels on save
        TeX-parse-self t
        TeX-master nil                     ; prompt for the master file
        TeX-save-query nil                 ; C-c C-c saves without asking -> 1-gesture compile
        reftex-plug-into-AUCTeX t
        ;; Shared dissertation bibliography (see CLAUDE.md conventions).
        reftex-default-bibliography
        '("~/scholarship/research-wip/documents/dissertation/references.bib"))
  ;; org-like folding in LaTeX: with cycle on, TAB on a \section/\subsection
  ;; line folds/unfolds that subtree (the heading-line keymap takes priority
  ;; there, so cdlatex keeps TAB everywhere else).  Headings get a subtle
  ;; highlight so they're easy to spot when collapsed.
  (setq outline-minor-mode-cycle t
        outline-minor-mode-highlight 'append)
  :config
  (setq TeX-view-program-selection '((output-pdf "Zathura"))))

;; Adds the `LatexMk' command so C-c C-c compiles with latexmk.
(use-package auctex-latexmk
  :after tex
  :config
  (setq auctex-latexmk-inherit-TeX-PDF-mode t)
  (auctex-latexmk-setup)
  (setq-default TeX-command-default "LatexMk"))

;; CDLaTeX is enabled via the LaTeX-mode hook above; this ensures it's
;; installed.  Backtick -> Greek/math symbols, apostrophe -> accents,
;; _ / ^ auto-insert braces.
(use-package cdlatex
  :defer t)

;; --- Inline math preview: built-in Org/AUCTeX + org-fragtog -------------
;; In Org, `C-c C-x C-l' renders the LaTeX fragment at point to an image; in
;; .tex, AUCTeX's `C-c C-p C-p' does the same (both use dvisvgm).  org-fragtog
;; makes the Org side *automatic*: point on a fragment shows editable source,
;; point away auto-renders it -- the "live" feel, without xenops' font-lock
;; breakage.  Rendering options (dvisvgm process + scale) are in the Org block.
(use-package org-fragtog
  :hook (org-mode . org-fragtog-mode))

;; --- Org: notes + TODO/agenda (:lang org, built into Emacs) -------------
;; Papers stay in LaTeX.  Org is for tasks/agenda and prose notes (the
;; folder-of-outlines style, not zettelkasten).  Everything here is
;; built in -- no packages, no org-roam.

(use-package org
  :ensure nil                             ; org ships with Emacs
  :bind (("C-c a" . org-agenda)           ; the calendar/todo dispatcher
         ("C-c c" . org-capture)          ; jot a task/note from anywhere
         ("C-c l" . org-store-link))
  :init
  (setq org-directory "~/Dropbox/org/"    ; agenda + capture home (synced, NOT the vault)
        ;; Agenda scans the dedicated org dir *and* the whole notes vault, so a
        ;; TODO jotted in any note surfaces.  Recursive (the vault is nested) and
        ;; filtered to skip Emacs lock/temp files.  New note files need a restart
        ;; (or re-eval) to join the agenda; the org dir itself rescans live.
        org-agenda-files
        (cons "~/Dropbox/org/"
              (when (file-directory-p "~/Dropbox/notes/")
                (seq-remove (lambda (f) (string-prefix-p "." (file-name-nondirectory f)))
                            (directory-files-recursively
                             (expand-file-name "~/Dropbox/notes/") "\\.org\\'"))))
        org-startup-folded 'showall       ; open fully expanded; S-TAB cycles all folding
        org-startup-with-inline-images t  ; render ![[image]] embeds inline (Obsidian-like)
        org-image-actual-width '(500)     ; cap oversized inline images at 500px
        org-hide-emphasis-markers t       ; show *bold* / italic rendered, hide the markers
        org-log-done 'time                ; stamp the time when a TODO -> DONE
        org-todo-keywords
        '((sequence "TODO" "NEXT" "WAITING" "|" "DONE" "CANCELLED")))
  :config
  (setq org-capture-templates
        '(("t" "Task" entry (file+headline "~/Dropbox/org/inbox.org" "Tasks")
           "* TODO %?\n  %U\n" :empty-lines 1)
          ("n" "Note" entry (file+headline "~/Dropbox/org/inbox.org" "Notes")
           "* %?\n  %U\n" :empty-lines 1)))
  ;; Headings render via the org-level faces once font-lock runs; bump their
  ;; size so they stand out more than the body.  Tune the :heights.
  (set-face-attribute 'org-level-1 nil :height 1.3)
  (set-face-attribute 'org-level-2 nil :height 1.15)
  (set-face-attribute 'org-level-3 nil :height 1.05)
  ;; Inline LaTeX preview (C-c C-x C-l): crisp SVG output, a bit larger than
  ;; the tiny default so equations are readable next to the prose font.
  (setq org-preview-latex-default-process 'dvisvgm)
  (setq org-format-latex-options (plist-put org-format-latex-options :scale 1.5)))

;; org-appear complements `org-hide-emphasis-markers' above: the markers are
;; hidden for clean, rendered text, but re-appear around the span your cursor
;; is on so you can still edit them -- Obsidian-style live preview.
(use-package org-appear
  :hook (org-mode . org-appear-mode)
  :init (setq org-appear-autolinks t))    ; also reveal [[link]] syntax on entry

;; --- Prose writing environment (variable-pitch + centered) --------------
;; Goal: Org, Markdown and LaTeX read like a page, not a terminal.
;;   * the body font is ET Book (ETBembo), supplied via nano's proportional
;;     family above; mixed-pitch swaps `variable-pitch' in for prose while
;;     keeping code / tables / verbatim / math in Roboto Mono so they align
;;   * olivetti centers the text in a comfortable measure
;; Line numbers are already off in these modes (only prog-mode turns them on).
;; (The old blank-header-line top-padding was removed -- nano-modeline now owns
;; the header-line for its status bar, so the two can't coexist.)

(use-package mixed-pitch
  :hook ((org-mode      . mixed-pitch-mode)
         (markdown-mode . mixed-pitch-mode)
         (LaTeX-mode    . mixed-pitch-mode)))

(use-package olivetti
  :hook ((org-mode      . olivetti-mode)
         (markdown-mode . olivetti-mode)
         (LaTeX-mode    . olivetti-mode))
  :init (setq olivetti-body-width 72))    ; text column width, in columns

;; Darker prose text.  Nano's body colour is a soft blue-grey (#37474F); this
;; darkens the *prose* face for more contrast while writing, leaving code and
;; the UI in nano's grey.  mixed-pitch renders prose in `variable-pitch', so
;; that's the face to darken.  It runs after nano's theme, so it wins.  (ET Book
;; only changes the letterforms, not the colour -- darkening is a separate knob.)
;; Tune the hex to taste (#000 = pure black, nano's own "strong").
(set-face-attribute 'variable-pitch nil :foreground "#1c1c1c")

;; Match the monospace bits to ET Book's apparent size.  In mixed-pitch, prose is
;; ETBembo (variable-pitch) while LaTeX commands, math and code stay `fixed-pitch'
;; (Roboto Mono) -- and Roboto Mono renders visibly larger than ET Book at the
;; same point size.  Shrinking `fixed-pitch' sits the \commands level with the
;; prose.  Tune the ratio to taste (1.0 = same nominal size; lower = smaller).
(set-face-attribute 'fixed-pitch nil :height 0.75)

;; --- Welcome screen (elegant-emacs style, from welcome.org) -------------
;; Ported from Rougier's elegant-emacs: the startup buffer is an *Org file*
;; (`welcome.org' beside this init) rendered read-only -- logo, quick help,
;; a keybind cheat-sheet, and clickable actions.  Because it's Org, you edit
;; the page by editing that file (there's an "Edit this screen" link on it).
;; Shown on `window-setup-hook', skipped when Emacs opens a file.
;;
;; A few deliberate choices make it behave under our stack:
;;   * we run `org-mode' with `org-mode-hook' let-bound to nil, so the prose
;;     hooks (mixed-pitch, flyspell, org-fragtog, ...) do NOT fire -- the page
;;     stays monospace so the cheat-sheet columns line up
;;   * `olivetti-mode' centres it in a measure that re-flows on resize, so it
;;     stays centred as you flip a Hyprland tile between small and full-screen
;;   * [bracketed keys] are coloured with nano's salient face via a scoped
;;     font-lock rule (the `[^][()]' class skips [[elisp:(...)]] link internals)
;;   * cursor is hidden -- including evil's block cursor, via a buffer-local
;;     `evil-normal-state-cursor'
;;   * evil stays in normal state so SPC is still your leader; q / ESC dismiss

(defun rm/welcome-kill ()
  "Dismiss the welcome screen."
  (interactive)
  (when (get-buffer "*welcome*")
    (kill-buffer "*welcome*")))

(defun rm/welcome ()
  "Show the welcome screen (welcome.org) unless a file was opened at launch."
  (interactive)
  (when (or (called-interactively-p 'interactive)   ; M-x always previews it
            (and (not (member "-no-splash" command-line-args))
                 ;; no file-visiting buffers yet -> a bare `emacs' launch
                 (not (seq-some #'buffer-file-name (buffer-list)))))
    (let* ((dir  (file-name-directory user-init-file))
           (file (expand-file-name "welcome.org" dir))
           (buf  (get-buffer-create "*welcome*")))
      (when (file-exists-p file)
        (require 'org)                             ; so `org-mode-hook' is special before
        (with-current-buffer buf                   ; we let-bind it below (else, under
          (let ((inhibit-read-only t))             ; lexical-binding, it errors)
            (erase-buffer)
            (insert-file-contents file))
          (setq default-directory dir)             ; so [[file:welcome-logo.svg]] resolves
          (let ((org-mode-hook nil)) (org-mode))   ; Org WITHOUT the prose hooks
          (setq-local org-hide-emphasis-markers t)
          ;; colour [bracketed keys] salient; the [^][()] class avoids matching
          ;; inside [[elisp:(...)]] links (which contain parens)
          (font-lock-add-keywords nil
                                  '(("\\[[^][()]*\\]" 0 'nano-face-salient prepend)) t)
          (font-lock-flush) (font-lock-ensure)
          (setq-local mode-line-format nil         ; clean of nano's status bars
                      header-line-format nil
                      cursor-type nil)             ; no cursor...
          (when (fboundp 'evil-normal-state)
            (evil-normal-state)                    ; keep SPC as leader; make local keymap
            (setq-local evil-normal-state-cursor '(nil))  ; ...including evil's box cursor
            (when (fboundp 'evil-refresh-cursor) (evil-refresh-cursor))
            (evil-local-set-key 'normal (kbd "q")        #'rm/welcome-kill)
            (evil-local-set-key 'normal (kbd "<escape>") #'rm/welcome-kill))
          (read-only-mode 1)
          (goto-char (point-min)))
        (switch-to-buffer buf)
        ;; Window-dependent bits, now that the buffer is actually on screen:
        ;; inline the logo image, and centre with olivetti (re-flows on resize).
        (with-current-buffer buf
          (org-display-inline-images)
          (when (fboundp 'olivetti-mode)
            (setq-local olivetti-body-width 78)    ; wide enough for the 2-col block
            (olivetti-mode 1)))))))

(add-hook 'window-setup-hook #'rm/welcome)

;; --- Notes navigator (treemacs) -----------------------------------------
;; A collapsible file-tree side pane, like Obsidian's explorer, for the
;; ~/Dropbox/notes vault.  Rendered in a proportional sans font, with
;; pixel-based indentation so nesting stays aligned.  C-c t opens the vault;
;; <f8> is a plain toggle.  Opening a file (l / RET) shows it in its own
;; buffer in the adjacent window.
(use-package treemacs
  :defer t
  :bind (("C-c t" . rm/notes-tree)
         ("<f8>"  . treemacs))
  :init
  (defun rm/notes-tree ()
    "Open the ~/Dropbox/notes vault in a Treemacs side pane."
    (interactive)
    (require 'treemacs)
    (treemacs-select-window)              ; create the window + workspace if needed
    (treemacs-do-add-project-to-workspace ; no-op if already added
     (expand-file-name "~/Dropbox/notes") "notes"))
  :config
  (setq treemacs-width 34
        treemacs-indentation '(6 px))      ; pixel indent: aligns under a proportional font
  (treemacs-follow-mode 1)                 ; keep the tree on the file you're editing
  ;; h / l close and open folders, vim-style (evil-collection has no treemacs
  ;; module, so bind them ourselves).  j/k already move line-by-line via evil.
  (evil-define-key '(normal motion) treemacs-mode-map
    (kbd "l") #'treemacs-RET-action              ; expand dir / open file
    (kbd "h") #'treemacs-collapse-parent-node)   ; collapse
  ;; Non-monospace tree.  A *sans* proportional font (not the serif body font)
  ;; reads like Obsidian's sidebar.  buffer-face-set didn't stick on treemacs'
  ;; own faces, so set the family on them directly.  Swap "Noto Sans" to taste.
  (dolist (face '(treemacs-root-face treemacs-directory-face
                  treemacs-directory-collapsed-face treemacs-file-face
                  treemacs-tags-face))
    (set-face-attribute face nil :family "Noto Sans"))
  (add-hook 'treemacs-mode-hook
            (lambda () (setq-local line-spacing 3))))   ; airier rows

;; --- Markdown (any notes you keep as .md) -------------------------------
;; The vault is Org now, but markdown-mode covers any stray .md.  It inherits
;; the proportional font + centering from the hooks above.
(use-package markdown-mode
  :mode ("\\.md\\'" . markdown-mode)
  :init (setq markdown-command "pandoc"))

;; --- Optional next steps (left off on purpose) --------------------------
;; When you want them:
;;   * the elegant "Welcome" second page (quick-help + clickable commands),
;;     ported from rougier/elegant-emacs's Welcome.org
;;   * citar      -- richer bibliography UI than RefTeX          (:tools biblio)
;;   * pdf-tools  -- view/annotate PDFs in Emacs (zathura already views)
;;   * vertico + orderless + marginalia -- the completion stack
;;   * a theme that follows Omarchy -- Emacs won't auto-track it; its own project

;;; init.el ends here
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages '(auctex no-littering)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
