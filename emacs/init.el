;;; init.el --- Raymond's Emacs configuration  -*- lexical-binding: t; -*-
;;
;; A hand-written config layered on rougier/nano-emacs for the *look* only.
;; nano supplies the visual base (elegant light theme, generous frame margins,
;; a top header-line status bar, Roboto-Mono/ET-Book fonts); everything else --
;; the LaTeX/Org writing stack, window management, prose centering -- is our
;; own, so the config stays understandable and tuned to paper + notes work.
;; Configure by friction: change things here as they annoy you.
;;
;; Keybindings are NATIVE Emacs (evil was dropped 2026-07-19: new packages
;; kept lagging evil-collection support, and the compat layer wasn't worth
;; it for a prose-only Emacs).  The custom layer is scoped to what the
;; defaults do badly: C-h/j/k/l window focus, M-o ace-window, a C-c w window
;; menu with repeatable resize, C-c n / C-c p sidebars.  CapsLock is Ctrl at
;; the Hyprland level (hypr/input.conf) and the command prefix is swapped
;; C-x -> C-a, so the everything-prefix sits entirely on the home row.
;;
;; State layout (see early-init.el for the redirects):
;;   ~/.config/emacs/       this file -- symlink into dotfiles, git-tracked
;;   ~/.config/emacs/nano/  vendored nano-emacs modules (the visual base)
;;   ~/.local/share/emacs/  installed packages + no-littering var/
;;   ~/.cache/emacs/        native-compilation cache
;;
;;   :look   nano (layout / faces / theme / modeline)
;;   :keys   native + windmove/ace-window/C-c w     :tools  magit
;;   :completion vertico + orderless + marginalia   :checkers spell, syntax
;;   :lang   latex (auctex+cdlatex+reftex), org     :prose  mixed-pitch + olivetti

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

;; The stock crash-recovery auto-save (#file# copies) stays on, but its
;; "Auto-saving...done" echo is noise while writing.
(setq auto-save-no-message t)

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
(repeat-mode 1)                           ; C-x o o o..., C-x { { {... -- and the
                                          ; C-c w resize keys below repeat too
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
;; deliberately NOT: nano-bindings (its M-RET frame-maximize would clobber
;; org-meta-return; the one good bit, C-x k, is cherry-picked in the Windows
;; section), nano-defaults (our built-in defaults above stand, and its
;; completion-styles would fight orderless), nano-session, nor the
;; counsel/mu4e/agenda modules (packages we don't use).  Vendored under ./nano so it's editable and
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

;; Prose modelines, quieter: "Musings.org (Org)" reads as just "Musings".
;; In text-mode-derived buffers the .org/.md extension is hidden (sidebar
;; parity) and the "(Mode)" segment is dropped -- the branch, when there is
;; one, still shows.  When two same-named files are open, uniquify names
;; the buffer "Musings.org<Hegel>" -- the <dir> tail is display noise here
;; too, so the strip eats it along with the extension (C-a b still shows
;; it, where telling the two apart actually matters).  Code buffers keep
;; the stock "name (Mode, branch)".  Redefines nano-modeline's dispatcher
;; target; the vendored original is untouched.
(defun nano-modeline-default-mode ()
  (let* ((buffer-name (format-mode-line "%b"))
         (prose       (derived-mode-p 'text-mode))
         (buffer-name (if prose
                          (replace-regexp-in-string
                           "\\.\\(org\\|md\\)\\(<[^>]*>\\)?\\'" ""
                           buffer-name)
                        buffer-name))
         (mode-name   (nano-mode-name))
         (branch      (vc-branch))
         (position    (format-mode-line "%l:%c")))
    (nano-modeline-compose
     (nano-modeline-status)
     buffer-name
     (cond ((and prose branch)
            (concat "(" (propertize branch 'face 'italic) ")"))
           (prose "")
           (t (concat "(" mode-name
                      (if branch
                          (concat ", " (propertize branch 'face 'italic)))
                      ")")))
     position)))

;; nano-help: an echo-area quick-help cheat-sheet plus a full quick-help.org
;; screen (M-x nano-help; its M-h hard-bind loses to the vim motions below).
;; It also hard-binds the cheat-sheet to M-p on load; move it to C-M-h
;; (stock mark-defun, unused here) so M-p is free for paste.  (quick-help.org
;; is vendored alongside the .el files so the nano-help screen resolves.)
(require 'nano-help)
(keymap-global-set "C-M-h" 'nano-quick-help)
(keymap-global-unset "M-p")

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
;; Built-in linear undo/redo (Emacs 28+): as long as you only use these two
;; commands, it behaves exactly like nvim's u / C-r -- no undo-ring surprises.

(global-unset-key (kbd "C-z"))            ; was suspend-frame; reclaim it
(keymap-global-set "C-z"   #'undo)
(keymap-global-set "C-S-z" #'undo-redo)

;; Reload init.el in place -- apply most config edits without a full restart.
;; No keybind: `M-x rm/reload-init' (orderless makes "M-x rel in" find it).
(defun rm/reload-init ()
  "Re-evaluate init.el so config changes take effect without restarting."
  (interactive)
  (load-file user-init-file)
  (message "init.el reloaded."))

;; Echo-area errors vanish on the next keypress, but they all land in
;; *Messages* (C-c h e pops it).  C-c e copies the last one straight to the
;; clipboard -- for pasting an error into a chat/search without spelunking.
(defun rm/copy-last-message ()
  "Copy the last *Messages* line (usually the last error) to the clipboard."
  (interactive)
  (with-current-buffer (messages-buffer)
    (save-excursion
      (goto-char (point-max))
      (skip-chars-backward "\n")
      (let ((end (point)))
        (forward-line 0)
        (let ((msg (buffer-substring-no-properties (point) end)))
          (if (string-empty-p msg)
              (user-error "No messages")
            (kill-new msg)
            (message "Copied: %s" msg)))))))
(keymap-global-set "C-c e" #'rm/copy-last-message)

;; --- Command prefix: C-a (swapped with C-x) ------------------------------
;; C-x is an awkward stretch; with CapsLock as Ctrl, C-a sits entirely on the
;; home row -- so C-a *is* the command prefix here.  Bound DIRECTLY to
;; `ctl-x-map' (not a key-translation-map rewrite, which made every echo and
;; error report "C-x ..." for keys you typed as C-a): the sequence you type
;; is the sequence Emacs sees, so echoes, describe-key and which-key all say
;; C-a.  Only the *manuals* still print "C-x" -- mentally substitute.
;; Beginning-of-line lands on the vacated C-x -- bound at the END of this
;; file, because rebinding the C-x prefix to a command must come after every
;; "C-x ..." key definition (later ones would error on a non-prefix key).
;; (Modes that bind C-a locally -- comint/eshell's bol -- shadow the prefix
;; there; not a mode you write in.)
(define-key global-map (kbd "C-a") ctl-x-map)

;; --- Projects (built-in project.el) --------------------------------------
;; The "land on a file fast" path, next to the sidebar's browse-around path:
;; C-a p p switches project, C-a p f finds a file in it -- with orderless,
;; "hig pap" lands on higgs/paper.tex in a few keystrokes.  research-wip is
;; a git repo so it's a project already; the notes vault is plain files, so
;; an empty .project marker file makes it one too.  Both are pre-registered
;; so C-a p p offers them from the very first session.
(setq project-vc-extra-root-markers '(".project"))
(with-eval-after-load 'project
  (dolist (dir '("~/scholarship/research-wip/" "~/Dropbox/notes/"))
    (when (file-directory-p dir)
      (project-remember-projects-under (expand-file-name dir)))))

;; --- Windows (:ui window-management) ------------------------------------
;; The daily layout is paper (main window) + notes (top right) + agenda or an
;; AI shell (bottom right), rearranged on the fly.  Everything here serves
;; that: instant focus moves, swap-any-two-buffers, directional splits, and
;; repeatable resize.
;;
;;   C-h/j/k/l  focus window left/down/up/right (windmove; the tmux/nvim
;;              habit -- started on M-h/j/k/l, moved to Ctrl 2026-07-20)
;;   M-o        ace-window: <=2 windows hops immediately; 3+ shows a letter
;;              per window -- also `M-o m <letter>' swaps buffers with that
;;              window (agenda -> main window move), `M-o x <letter>' deletes
;;   C-c w      window menu (which-key shows it): s/v split below/right
;;              (:sp/:vs mnemonic), f/b pick a file (vertico) straight into
;;              a new right/below split, h/j/k/l drag the shared divider
;;              left/down/up/right (edge motion, same from either side of
;;              the divider) -- these REPEAT, so
;;              `C-c w l l l h ...' keeps dragging -- w swap, = balance,
;;              d delete, m maximize (u un-maximizes), u/r winner undo/redo
;;
;; What C-h/j/k/l displace, all deliberate:
;;   C-h  help prefix    -> C-c h (and <f1>, stock alias, on the laptop).
;;        Prefix help survives: `C-a C-h' still lists ctl-x-map (help-char).
;;   C-k  kill-line      -> C-S-k
;;   C-l  recenter       -> C-S-l
;;   C-j  newline        -> RET does the job in every mode we use

(keymap-global-set "C-h" #'windmove-left)
(keymap-global-set "C-j" #'windmove-down)
(keymap-global-set "C-k" #'windmove-up)
(keymap-global-set "C-l" #'windmove-right)
(keymap-global-set "C-c h" 'help-command)         ; the help prefix's new home
(keymap-global-set "C-S-k" #'kill-line)
(keymap-global-set "C-S-l" #'recenter-top-bottom)
;; Org and AUCTeX bind C-j locally (newline variants) -- clear both so
;; windmove-down wins in the buffers where it matters most.
(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-j") nil))
(with-eval-after-load 'latex
  (define-key LaTeX-mode-map (kbd "C-j") nil))

(winner-mode 1)                           ; layout history: C-c w u / r

(use-package ace-window
  :bind ("M-o" . ace-window)
  :init (setq aw-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l)  ; home-row window labels
              aw-scope 'frame))

;; The C-c w menu.  :repeat t puts the resize + winner commands in a
;; repeat-map, so after the first press the bare key keeps going (repeat-mode
;; is on above); any other key exits the repeat.  which-key pops the full
;; menu after C-c w.
(defvar-keymap rm/window-repeat-map
  :doc "Repeatable window ops: bare h/j/k/l keep dragging after C-c w."
  :repeat t
  "h" #'rm/window-edge-left               ; defined just below
  "l" #'rm/window-edge-right
  "j" #'rm/window-edge-down
  "k" #'rm/window-edge-up
  "u" #'winner-undo
  "r" #'winner-redo)

;; Resize = drag the divider, not grow/shrink.  Emacs's enlarge/shrink
;; commands invert visually depending on which side of a divider you sit
;; (from the right-hand window, "wider" drags the divider LEFT) -- felt
;; flipped in practice (2026-07-20).  These four instead move the shared
;; edge in the arrow's direction from either side, Hyprland-style.  The
;; edge acted on is the right/bottom one when a neighbour is there, else
;; the left/top (so the rightmost window's h/l still work on its left
;; divider, just from the other side).
(defun rm/window-edge-left (arg)
  "Drag this window's vertical divider ARG columns left."
  (interactive "p")
  (if (window-in-direction 'right)
      (shrink-window-horizontally arg)
    (enlarge-window-horizontally arg)))

(defun rm/window-edge-right (arg)
  "Drag this window's vertical divider ARG columns right."
  (interactive "p")
  (if (window-in-direction 'right)
      (enlarge-window-horizontally arg)
    (shrink-window-horizontally arg)))

(defun rm/window-edge-down (arg)
  "Drag this window's horizontal divider ARG lines down."
  (interactive "p")
  (if (window-in-direction 'below)
      (enlarge-window arg)
    (shrink-window arg)))

(defun rm/window-edge-up (arg)
  "Drag this window's horizontal divider ARG lines up."
  (interactive "p")
  (if (window-in-direction 'below)
      (shrink-window arg)
    (enlarge-window arg)))

(defun rm/find-file-split (side)
  "Prompt for a file, then visit it in a new SIDE split of this window.
The prompt comes before the split, so quitting it (C-g) leaves the
layout untouched -- no empty window to clean up."
  (let ((file (read-file-name "Find file in split: ")))
    (select-window (split-window nil nil side))
    (find-file file)))

(defun rm/find-file-right ()
  "Pick a file and open it in a split to the right."
  (interactive)
  (rm/find-file-split 'right))

(defun rm/find-file-below ()
  "Pick a file and open it in a split below."
  (interactive)
  (rm/find-file-split 'below))

(defvar-keymap rm/window-map
  :doc "Window menu: splits, file-into-split, swap, divider drag, balance, layout undo."
  "s" #'split-window-below                ; like :sp
  "v" #'split-window-right                ; like :vs
  "f" #'rm/find-file-right                ; pick a file into a right split
  "b" #'rm/find-file-below                ; pick a file into a below split
  "h" #'rm/window-edge-left               ; drag the divider left
  "l" #'rm/window-edge-right              ; drag the divider right
  "j" #'rm/window-edge-down               ; drag the divider down
  "k" #'rm/window-edge-up                 ; drag the divider up
  "w" #'ace-swap-window                   ; swap 2 windows' buffers (asks if 3+)
  "=" #'balance-windows
  "d" #'delete-window
  "m" #'delete-other-windows              ; maximize; C-c w u brings the rest back
  "u" #'winner-undo
  "r" #'winner-redo)
(keymap-global-set "C-c w" rm/window-map)

;; Kill the current buffer without the which-buffer prompt (from nano-bindings,
;; which we don't load wholesale -- its M-RET frame-maximize would clobber
;; org-meta-return).  Defined via the C-x path, so it lands in ctl-x-map;
;; typed as C-a k.
(keymap-global-set "C-x k" #'kill-current-buffer)

;; --- Vim motions on Meta (mirrors the nvim workflow) --------------------
;; M-hjkl / M-w / M-b move (w is vim-exact: start of NEXT word, via misc.el's
;; forward-to-word).  M-v toggles the highlight (the active region); motions
;; then extend it, M-d cuts it, M-y copies it -- strict vim operators: with
;; no highlight they just say so.  M-p pastes.  M-4 / M-6 = backward/forward
;; paragraph (vim's { and } -- 4 and 6 sit under left/right on the Corne
;; number row, and M-{ / M-} can't be chorded there).  pgtk syncs the
;; kill-ring with the Wayland clipboard both ways, so M-y / M-p see the
;; system clipboard for free.
;; Stock keys knowingly replaced: M-h nano-help screen (still M-x nano-help),
;; M-v scroll-down (C-v still pages down), M-w kill-ring-save (M-y now),
;; M-d kill-word, M-y yank-pop, M-j indent-newline, M-k kill-sentence,
;; M-l downcase-word, M-4/M-6 digit args (the other digits keep theirs).
;; Vertico's minibuffer M-p (history) deliberately stays -- paste there
;; is C-y.

(autoload 'forward-to-word "misc")

(defun rm/visual-toggle ()
  "Start a highlight at point, or drop the active one (vim's v)."
  (interactive)
  (if (region-active-p)
      (deactivate-mark)
    (set-mark-command nil)))

(defun rm/visual-cut ()
  "Cut the highlight (vim's d).  No highlight, no cut."
  (interactive)
  (if (region-active-p)
      (kill-region (region-beginning) (region-end))
    (message "No selection")))

(defun rm/visual-copy ()
  "Copy the highlight (vim's y).  No highlight, no copy."
  (interactive)
  (if (region-active-p)
      (kill-ring-save (region-beginning) (region-end))
    (message "No selection")))

(keymap-global-set "M-h" #'backward-char)
(keymap-global-set "M-j" #'next-line)
(keymap-global-set "M-k" #'previous-line)
(keymap-global-set "M-l" #'forward-char)
(keymap-global-set "M-w" #'forward-to-word)
(keymap-global-set "M-b" #'backward-word)   ; stock already; kept explicit
(keymap-global-set "M-v" #'rm/visual-toggle)
(keymap-global-set "M-d" #'rm/visual-cut)
(keymap-global-set "M-y" #'rm/visual-copy)
(keymap-global-set "M-p" #'yank)
(keymap-global-set "M-4" #'backward-paragraph)
(keymap-global-set "M-6" #'forward-paragraph)

;; org locally shadows M-h (org-mark-element) -- clear it so the motion
;; wins.  Only shadow found across the org/LaTeX/markdown/dired maps.
(with-eval-after-load 'org
  (define-key org-mode-map (kbd "M-h") nil))

;; --- Completion (vertico + orderless + marginalia) ----------------------
;; Minibuffer-only upgrades -- no popups in buffers, no compat layer:
;;   vertico     every prompt (C-x b, M-x, find-file, refile, ispell) shows a
;;               live vertical list you can C-n/C-p through
;;   orderless   type space-separated fragments in any order: "C-x b hig not"
;;               matches notes-on-higgs.org -- the 111-file-vault feature
;;   marginalia  annotations: M-x shows each command's keybinding + docstring
;;               (it teaches the native bindings as you go), buffers show paths
;; savehist (on above) feeds vertico's most-recent-first sorting.

(use-package vertico
  :init
  (setq vertico-cycle t)                  ; C-n past the bottom wraps to the top
  (vertico-mode 1))

(use-package orderless
  :init
  (setq completion-styles '(orderless basic)   ; basic = fallback (e.g. TAB paths)
        completion-category-defaults nil
        ;; find-file: keep /u/l/s -> /usr/local/share -style expansion working
        completion-category-overrides '((file (styles partial-completion)))))

(use-package marginalia
  :init (marginalia-mode 1))

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
        ;; Agenda scans the dedicated org dir, the whole notes vault, *and* the
        ;; research documents tree, so a TODO jotted in any note -- or mid-paper
        ;; in a paper.org -- surfaces.  Recursive (the trees are nested) and
        ;; filtered to skip Emacs lock/temp files.  New files need a restart
        ;; (or re-eval) to join the agenda; the org dir itself rescans live.
        org-agenda-files
        (append
         (cons "~/Dropbox/org/"
               (when (file-directory-p "~/Dropbox/notes/")
                 (seq-remove (lambda (f) (string-prefix-p "." (file-name-nondirectory f)))
                             (directory-files-recursively
                              (expand-file-name "~/Dropbox/notes/") "\\.org\\'"))))
         (when (file-directory-p "~/scholarship/research-wip/documents/")
           (seq-remove (lambda (f) (string-prefix-p "." (file-name-nondirectory f)))
                       (directory-files-recursively
                        (expand-file-name "~/scholarship/research-wip/documents/")
                        "\\.org\\'"))))
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

;; --- Papers in Org: body-only LaTeX export --------------------------------
;; paper.org files under research-wip/documents/papers/<slug>/ export to the
;; body.tex their paper.tex driver \input's -- machinery and rationale live
;; in org-paper-export.el (beside this init; also loaded by the publish
;; shell function via emacs -Q --batch).  Wiring here: the paper-latex
;; backend registers when ox-latex loads; every save of a paper.org
;; regenerates body.tex (never stale in git); C-c C-c in a paper.org
;; exports + latexmks, matching the AUCTeX muscle memory.  The path guard
;; is inlined in the hooks so the module stays lazy-loaded.
(with-eval-after-load 'ox-latex
  (require 'org-paper-export
           (expand-file-name "org-paper-export.el" user-emacs-directory)))
(defun rm/org-paper--maybe-export-on-save ()
  "Regenerate body.tex when the saved buffer is a paper.org."
  (when (and buffer-file-name
             (string-match-p "/documents/papers/[^/]+/paper\\.org\\'"
                             buffer-file-name))
    (require 'org-paper-export
             (expand-file-name "org-paper-export.el" user-emacs-directory))
    (rm/org-paper-export)))
(add-hook 'after-save-hook #'rm/org-paper--maybe-export-on-save)
(with-eval-after-load 'org
  (add-hook 'org-ctrl-c-ctrl-c-final-hook
            (lambda ()
              (when (and buffer-file-name
                         (string-match-p
                          "/documents/papers/[^/]+/paper\\.org\\'"
                          buffer-file-name))
                (require 'org-paper-export
                         (expand-file-name "org-paper-export.el"
                                           user-emacs-directory))
                (rm/org-paper-compile)))))

;; org-appear complements `org-hide-emphasis-markers' above: the markers are
;; hidden for clean, rendered text, but re-appear around the span your cursor
;; is on so you can still edit them -- Obsidian-style live preview.
(use-package org-appear
  :hook (org-mode . org-appear-mode)
  :init (setq org-appear-autolinks t))    ; also reveal [[link]] syntax on entry

;; org-modern (minad): renders Org's raw syntax as clean typography --
;; heading stars as bullets, TODO keywords and :tags: as pills, timestamps
;; as boxes, tidy list bullets and table lines.  Content styling only; it
;; doesn't touch emphasis markers (org-appear's turf) or the header-line
;; (nano-modeline's).  Same author as vertico/orderless/marginalia.
(use-package org-modern
  :hook ((org-mode            . org-modern-mode)
         (org-agenda-finalize . org-modern-agenda))  ; same look in C-c a
  :init
  (setq org-modern-star 'replace          ; static glyphs, not fold-state triangles
        org-modern-replace-stars "✦✧✱✳"   ; one per level; level 5+ reuses the last
        org-modern-block-fringe nil       ; fringe markers sit wrong next to olivetti's margins
        ;; tag/keyword pills look best unaligned (no trailing-whitespace columns)
        org-auto-align-tags nil
        org-tags-column 0))

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
  :init (setq olivetti-body-width 72)     ; text column width, in columns
  :config
  ;; Centering margins count toward a window's MINIMUM width, so frame-level
  ;; splits that halve the root refuse when half the frame is narrower than
  ;; margins + body -- concretely: dired-sidebar's side window on the laptop
  ;; frame (half of 184 cols < 56+56 margins) died with "window too small
  ;; for splitting", which dired-sidebar turned into "window-live-p, nil"
  ;; (2026-07-20).  Olivetti handles window-level splits via the
  ;; `split-window' window parameter, but frame-root splits bypass it (its
  ;; own FIXME admits side windows escape).  The built-in `min-margins'
  ;; window parameter exists for exactly this: declare the margins
  ;; collapsible, and splits shrink them freely -- olivetti then re-centers
  ;; in the narrowed window from its own resize hook.  Stamped on every
  ;; window olivetti dresses.
  (define-advice olivetti-set-window (:after (&rest _) rm/collapsible-margins)
    (walk-windows
     (lambda (w)
       (when (buffer-local-value 'olivetti-mode (window-buffer w))
         (set-window-parameter w 'min-margins '(0 . 0))))
     'no-minibuf t)))

;; Face tweaks layered over nano's theme (must run after it, so they win):
;;   * darker prose -- nano's body colour is a soft blue-grey (#37474F); the
;;     `variable-pitch' face (what mixed-pitch renders prose in) is darkened
;;     for contrast while writing; code and UI keep nano's grey.  Tune the
;;     hex to taste (#000 = pure black, nano's own "strong").
;;   * `fixed-pitch' pinned to Roboto Mono (its default is the generic
;;     "Monospace", i.e. whatever fontconfig picks) and shrunk to 0.75 --
;;     Roboto Mono renders visibly larger than ET Book at the same point
;;     size, so this sits \commands and math level with the prose.
(defun rm/apply-face-tweaks ()
  "Re-apply the post-nano face adjustments (prose colour, fixed-pitch size)."
  (set-face-attribute 'variable-pitch nil :foreground "#1c1c1c")
  (set-face-attribute 'fixed-pitch nil :family "Roboto Mono" :height 0.75)
  ;; nano maps `italic' to its faded grey (Rougier considers italics abused).
  ;; For prose that's wrong: /emphasis/ should slant, in an Obsidian-style
  ;; soft blue that reads as emphasis without going faint (ET Book's italic
  ;; strokes are thinner than the roman, so same-colour italics look faded).
  ;; Break the inherit nano sets and restore the slant it wiped.
  (set-face-attribute 'italic nil :inherit 'unspecified :slant 'italic
                      :foreground "#4a6fa5"))
(rm/apply-face-tweaks)

;; Daemon hardening: when Emacs starts as a daemon there is no graphical
;; frame yet, so nano-faces takes its TTY branches (bold weights, dummy
;; heights).  Re-apply the whole theme -- and the tweaks above -- once the
;; first GUI client frame exists, then unhook.
(when (daemonp)
  (defun rm/nano-refresh-on-first-frame ()
    (when (display-graphic-p)
      (nano-theme-set-light)
      (nano-refresh-theme)
      (rm/apply-face-tweaks)
      (remove-hook 'server-after-make-frame-hook
                   #'rm/nano-refresh-on-first-frame)))
  (add-hook 'server-after-make-frame-hook #'rm/nano-refresh-on-first-frame))

;; --- Welcome screen (elegant-emacs style, from welcome.org) -------------
;; Ported from Rougier's elegant-emacs: the startup buffer is an *Org file*
;; (`welcome.org' beside this init) rendered read-only -- the pixel-centered
;; logo (`org-image-align', org 9.7+), then alphabetical *Commands* and
;; *Help* cheat-sheets.  Because it's Org, you edit the page by editing that
;; file.  Shown on `window-setup-hook', skipped when Emacs opens a file.
;;
;; A few deliberate choices make it behave under our stack:
;;   * we run `org-mode' with `org-mode-hook' let-bound to nil, so the prose
;;     hooks (mixed-pitch, flyspell, org-fragtog, ...) do NOT fire -- the page
;;     stays monospace so the cheat-sheet columns line up
;;   * `olivetti-mode' centres it in a measure that re-flows on resize, so it
;;     stays centred as you flip a Hyprland tile between small and full-screen
;;   * [bracketed keys] are coloured with nano's salient face via a scoped
;;     font-lock rule (the `[^][()]' class would skip [[elisp:(...)]] link
;;     internals, should links ever return to the page)
;;   * the logo is sized to the window: the page below it is a fixed stack
;;     of text lines, so the logo gets whatever height remains (capped at
;;     500px wide, the full-monitor look).  Recomputed on window resize, so
;;     the whole page fits docked and on the laptop panel alike
;;   * cursor is hidden (`cursor-type' nil); q / ESC dismiss via a local keymap
;;     layered over org-mode-map
;;   * it auto-dismisses on the first real file visit (one-shot find-file-hook),
;;     so the buffer never lingers in C-x b or gets split around by later
;;     windows.  Dired-only visits (incl. the sidebars) don't run
;;     `find-file-hook' -- accepted scope; q / winner-undo cover that.

(defun rm/welcome--logo-width ()
  "Logo pixel width that lets the whole page fit the selected window.
Every line but the logo's is plain text at `default-line-height'; the
logo gets the height left over (minus a one-line cushion), converted to
a width via the SVG's 270:217 aspect.  Capped at 500px -- the size it
has always rendered at on the external monitor -- and floored at 250px
so a half-tile still shows a legible logo rather than a speck."
  (let* ((text-px (* (count-lines (point-min) (point-max))
                     (default-line-height)))
         (budget  (- (window-pixel-height) text-px)))
    (min 500 (max 250 (round (* budget (/ 270.0 217.0)))))))

(defun rm/welcome--refit (window)
  "Re-inline the logo at the size WINDOW now calls for.
On `window-size-change-functions' (buffer-local, so WINDOW is the one
showing the splash).  No-op unless the computed width actually changed."
  (with-selected-window window
    (let ((width (rm/welcome--logo-width)))
      (unless (equal width org-image-actual-width)
        (setq-local org-image-actual-width width)
        (org-remove-inline-images)
        (org-display-inline-images)))))

(defun rm/welcome-kill ()
  "Dismiss the welcome screen."
  (interactive)
  (remove-hook 'find-file-hook #'rm/welcome--auto-dismiss)
  (when (get-buffer "*welcome*")
    (kill-buffer "*welcome*")))

(defun rm/welcome--auto-dismiss ()
  "One-shot: dismiss the welcome screen once a real file is visited.
Runs on `find-file-hook', which fires before the new buffer is
displayed -- so the teardown is deferred a tick, lest we delete the
very window the file is about to land in."
  (remove-hook 'find-file-hook #'rm/welcome--auto-dismiss)
  (when (get-buffer "*welcome*")
    (run-with-timer 0 nil
                    (lambda ()
                      (when-let ((buf (get-buffer "*welcome*")))
                        (dolist (win (get-buffer-window-list buf nil t))
                          ;; a sole window can't be deleted; killing the
                          ;; buffer below makes it show something else
                          (ignore-errors (delete-window win)))
                        (kill-buffer buf))))))

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
          (setq-local org-hide-emphasis-markers t
                      org-image-align 'center)     ; logo pixel-centered (org 9.7+)
          ;; colour [bracketed keys] salient; the [^][()] class avoids matching
          ;; inside [[elisp:(...)]] links (which contain parens)
          (font-lock-add-keywords nil
                                  '(("\\[[^][()]*\\]" 0 'nano-face-salient prepend)) t)
          (font-lock-flush) (font-lock-ensure)
          (setq-local mode-line-format nil         ; clean of nano's status bars
                      header-line-format nil
                      cursor-type nil)             ; no cursor
          ;; q / ESC dismiss; parenting org-mode-map keeps RET-on-links working.
          (let ((map (make-sparse-keymap)))
            (set-keymap-parent map org-mode-map)
            (define-key map (kbd "q")        #'rm/welcome-kill)
            (define-key map (kbd "<escape>") #'rm/welcome-kill)
            (use-local-map map))
          (read-only-mode 1)
          (goto-char (point-min)))
        (switch-to-buffer buf)
        (add-hook 'find-file-hook #'rm/welcome--auto-dismiss)
        ;; Window-dependent bits, now that the buffer is actually on screen:
        ;; inline the logo image, and centre with olivetti (re-flows on resize).
        (with-current-buffer buf
          (setq-local org-image-actual-width (rm/welcome--logo-width))
          (org-display-inline-images)
          (add-hook 'window-size-change-functions #'rm/welcome--refit nil t)
          (when (fboundp 'olivetti-mode)
            (setq-local olivetti-body-width 80)    ; 2 cols slack over the 78-col block
            (olivetti-mode 1))
          ;; olivetti turns on visual-line-mode; in a narrowed window (sidebar
          ;; open) that word-wraps the aligned cheat-sheet by a hair.  Truncate
          ;; instead -- the columns stay sane at any window width.
          (visual-line-mode -1)
          (setq-local truncate-lines t))))))

(add-hook 'window-setup-hook #'rm/welcome)

;; No "When done with this frame, type C-a 5 0" echo in client frames --
;; Hyprland's Super+Q closes the frame like any window; the hint is noise.
(setq server-client-instructions nil)

;; Client frames (the launcher's "Emacs" entry, emacsclient -c) open on the
;; daemon, where window-setup-hook already ran frameless -- without this
;; they'd show *scratch*.  The visit logic lives in the docstring below.
(when (daemonp)
  (defun rm/welcome-on-new-frame ()
    "First frame of a visit: the splash.  Additional frames: your last file.
Closing the last frame (Super+Q) ends the \"visit\" -- the daemon keeps
every buffer, but the next frame greets with a fresh splash.  A second
frame opened alongside a live one resumes the last file instead (stock
emacsclient would show *scratch*).  Frames opened ON a file still win:
the server displays the file after this hook, and its find-file-hook
dismisses the splash."
    (if (cdr (seq-filter #'display-graphic-p (frame-list)))
        ;; another GUI frame is already up -> resume
        (when-let ((last-file (seq-find #'buffer-file-name (buffer-list))))
          (switch-to-buffer last-file))
      ;; only frame -> (re)render the splash; the interactive path skips
      ;; rm/welcome's bare-launch guards, and rendering happens on THIS
      ;; graphic frame, so the logo inlines and auto-dismiss re-arms
      (funcall-interactively #'rm/welcome)))
  (add-hook 'server-after-make-frame-hook #'rm/welcome-on-new-frame))

;; --- Notes + papers sidebar (dired-sidebar) ------------------------------
;; A file-tree side pane, like Obsidian's explorer.  It's just dired in a
;; side window (native machinery, no workspace model -- replaced treemacs
;; 2026-07-19), styled like rougier's nano dired: Roboto Mono, no icons,
;; airy rows, details hidden, no banner line (the header line names the
;; root instead).  TAB expands a folder in-place (dired-subtree); RET
;; opens the file into the main window; f / b open it in a split right
;; of / below the main window (same letters as C-c w f/b); hjkl navigate
;; vim-style (see below).  Dotfiles, . / .., README/TODO, and LaTeX build
;; artifacts are omitted (dired-omit-mode); .org/.md extensions are hidden;
;; directories sort before files at every level.  Two roots for the two corpora:
;; C-c n = the notes vault, C-c p = research-wip (papers/dissertation/CV
;; under documents/); <f8> toggles a sidebar at the current project.
;; Directories before files, at every level -- dired-subtree's expansions
;; read with the same switches, so the whole tree groups consistently.
;; Global on purpose: plain dired benefits too.
(setq dired-listing-switches "-al --group-directories-first")

;; File operations in plain dired: R renames/moves the file at point (same
;; prompt -- type a new name, or a path to move), + makes a directory, `a'
;; makes an empty file (was dired-find-alternate-file, a disabled command).
;; The sidebar layers yazi-style lowercase keys on top (see its section).
;; C-a C-q = wdired: the listing becomes an editable buffer -- rename by
;; editing names like text, C-c C-c commits, C-c C-k aborts.  (Free ride
;; from the C-a swap: dired remaps read-only-mode to dired-toggle-read-only,
;; which enters wdired.)
(with-eval-after-load 'dired
  (define-key dired-mode-map "a" #'dired-create-empty-file))
(setq wdired-create-parent-directories t) ; editing in a new subdir = move + mkdir

(use-package dired-sidebar
  :defer t
  :bind (("C-c n" . rm/notes-sidebar)
         ("C-c p" . rm/papers-sidebar)
         ("<f8>"  . dired-sidebar-toggle-sidebar))
  :init
  (defun rm/notes-sidebar ()
    "Toggle a dired sidebar rooted at the ~/Dropbox/notes vault."
    (interactive)
    (let ((default-directory (expand-file-name "~/Dropbox/notes/")))
      (dired-sidebar-toggle-sidebar)))
  (defun rm/papers-sidebar ()
    "Toggle a dired sidebar rooted at research-wip.
dired-sidebar roots at the *project* root (and its follow-file
re-rooting keeps it there), so documents/ can't be the root -- it's
one `l' away instead."
    (interactive)
    (let ((default-directory
           (expand-file-name "~/scholarship/research-wip/")))
      (dired-sidebar-toggle-sidebar)))
  :config
  (setq dired-sidebar-theme 'none          ; no icons -- plain names
        dired-sidebar-width 32
        ;; No custom font: the default face is Roboto Mono, rougier's nano
        ;; look (ET Book was tried 2026-07-20 and reverted the same day).
        dired-sidebar-use-custom-font nil
        dired-sidebar-should-follow-file t) ; keep the tree on the file you're editing
  ;; `a' (new file) should refresh the tree like R / + / D already do.
  (add-to-list 'dired-sidebar-special-refresh-commands 'dired-create-empty-file)
  ;; Hide dired's banner line (absolute path + free space); the header line
  ;; shows the root directory's name instead.
  (defun rm/sidebar-hide-heading ()
    "Make the sidebar's dired banner line invisible."
    (when (derived-mode-p 'dired-sidebar-mode)
      (save-excursion
        (goto-char (point-min))
        (let ((o (make-overlay (line-beginning-position) (line-beginning-position 2))))
          (overlay-put o 'invisible t)
          (overlay-put o 'evaporate t)))))
  (add-hook 'dired-after-readin-hook #'rm/sidebar-hide-heading)
  ;; Hide .org / .md extensions, Obsidian-style: an invisible overlay over
  ;; the suffix.  Display-only -- the buffer text is intact, so dired still
  ;; parses full filenames and RET opens the right file.
  (defun rm/sidebar-hide-extensions (&rest _)
    "Hide .org / .md extensions in the sidebar's file names."
    (when (derived-mode-p 'dired-sidebar-mode)
      (save-excursion
        (goto-char (point-min))
        (while (not (eobp))
          (let ((fn (dired-get-filename 'no-dir t)))
            (when (and fn (string-match "\\.\\(org\\|md\\)\\'" fn))
              (let ((ext-len (- (length fn) (match-beginning 0))))
                (when-let ((end (dired-move-to-end-of-filename t)))
                  (let ((beg (- end ext-len)))
                    (unless (get-char-property beg 'invisible)
                      (let ((o (make-overlay beg end)))
                        (overlay-put o 'invisible t)
                        (overlay-put o 'evaporate t))))))))
          (forward-line 1)))))
  (add-hook 'dired-after-readin-hook #'rm/sidebar-hide-extensions)
  ;; dired-omit-mode does NOT reach dired-subtree's inserted lines (its
  ;; own filter hook needs the dired-filter package), so expanded folders
  ;; would show README.md & co.  Expunge them ourselves with the same
  ;; regexp dired-omit uses (files + extensions).
  (defun rm/sidebar-omit-subtree ()
    "Delete omitted entries from freshly inserted subtrees."
    (when (and (derived-mode-p 'dired-sidebar-mode)
               (bound-and-true-p dired-omit-mode))
      (let ((regexp (dired-omit-regexp))
            (inhibit-read-only t))
        (unless (string-empty-p regexp)
          (save-excursion
            (goto-char (point-min))
            (while (not (eobp))
              (let ((fn (dired-get-filename 'no-dir t)))
                (if (and fn (string-match-p regexp fn))
                    (delete-region (line-beginning-position)
                                   (line-beginning-position 2))
                  (forward-line 1)))))))))
  (with-eval-after-load 'dired-subtree
    ;; add-hook prepends: omit runs first, then extension hiding.
    (add-hook 'dired-subtree-after-insert-hook #'rm/sidebar-hide-extensions)
    (add-hook 'dired-subtree-after-insert-hook #'rm/sidebar-omit-subtree))
  ;; Hide clutter -- sidebar only, plain dired still lists everything.
  ;; The regexp omits dotfiles (.git, .gitignore, and the . / .. self/parent
  ;; entries every Unix dir carries) plus README.md / TODO.md; on top of
  ;; that, dired-omit-mode's default `dired-omit-extensions' hides LaTeX
  ;; build artifacts (.aux, .log, .bbl, ...).  Subtree expansions are out
  ;; of dired-omit's reach -- rm/sidebar-omit-subtree (above) covers them.
  (setq dired-omit-verbose nil)
  (add-hook 'dired-sidebar-mode-hook
            (lambda ()
              (setq-local line-spacing 3   ; airier rows
                          dired-omit-files
                          "\\`\\.\\|\\`README\\.md\\'\\|\\`TODO\\.md\\'"
                          ;; nano's header line would show the buffer name
                          ;; (":~/full/path/..."); show just the root's name
                          header-line-format
                          (list " " (file-name-nondirectory
                                     (directory-file-name
                                      (expand-file-name default-directory)))
                                "/"))
              (dired-omit-mode 1)
              ;; initial readin predates the mode, so run both once here
              (rm/sidebar-hide-heading)
              (rm/sidebar-hide-extensions)))
  ;; Vim-style tree navigation on plain hjkl -- the pane is read-only, so
  ;; the letters are free, and dired's single-letter legacy binds are traps
  ;; (j prompted "Goto file:", k killed lines).  l: expand a dir (again:
  ;; step into it) or visit a file; h: collapse an expanded dir, else jump
  ;; to the parent line.
  (defun rm/sidebar-open ()
    "Expand the directory at point, or visit the file in the main window."
    (interactive)
    (if (dired-subtree--dired-line-is-directory-or-link-p)
        (if (dired-subtree--is-expanded-p)
            (dired-subtree-down)
          (dired-subtree-toggle))
      (dired-sidebar-find-file)))
  (defun rm/sidebar-close ()
    "Collapse the expanded directory at point, else jump to the parent."
    (interactive)
    (if (and (dired-subtree--dired-line-is-directory-or-link-p)
             (dired-subtree--is-expanded-p))
        (dired-subtree-toggle)
      (dired-subtree-up)))
  (define-key dired-sidebar-mode-map (kbd "j") #'dired-next-line)
  (define-key dired-sidebar-mode-map (kbd "k") #'dired-previous-line)
  (define-key dired-sidebar-mode-map (kbd "l") #'rm/sidebar-open)
  (define-key dired-sidebar-mode-map (kbd "h") #'rm/sidebar-close)
  ;; f / b: open the file at point in a split of the MAIN window -- right
  ;; and below, the same letters as C-c w f/b (one split vocabulary
  ;; everywhere).  The main window is found the way dired-sidebar itself
  ;; finds it (most recently used; the sidebar is dedicated, so it's never
  ;; picked).  Shadows dired's f (find-file; l/RET already cover opening)
  ;; -- sidebar only, plain dired keeps it.
  (defun rm/sidebar--open-split (side)
    "Visit the file at point in a new SIDE split of the main window."
    (let ((file (dired-get-filename nil t)))
      (when (or (null file) (file-directory-p file))
        (user-error "No file at point"))
      (let ((main (get-mru-window nil nil t)))
        (unless main (user-error "No other window to split"))
        (select-window (split-window main nil side))
        (find-file file))))
  (defun rm/sidebar-open-right ()
    "Open the file at point in a split right of the main window."
    (interactive)
    (rm/sidebar--open-split 'right))
  (defun rm/sidebar-open-below ()
    "Open the file at point in a split below the main window."
    (interactive)
    (rm/sidebar--open-split 'below))
  (define-key dired-sidebar-mode-map (kbd "f") #'rm/sidebar-open-right)
  (define-key dired-sidebar-mode-map (kbd "b") #'rm/sidebar-open-below)
  ;; Yazi-style file ops, single lowercase keys (sidebar only -- plain
  ;; dired keeps its stock commands).  "At point" targeting: on a folder
  ;; line ops go INTO that folder; on a file line, beside it.
  ;;   a  create (a trailing / makes a folder, parents included)
  ;;   r  rename/move   d  delete   y  yank   p  paste
  (defvar rm/sidebar-yanked nil
    "Absolute path last yanked with `rm/sidebar-yank'.")
  (defun rm/sidebar--dir-at-point ()
    "Directory point is in: a folder line is itself, a file its parent."
    (if-let ((file (dired-get-filename nil t)))
        (if (file-directory-p file)
            (file-name-as-directory file)
          (file-name-directory file))
      (dired-current-directory)))
  (defun rm/sidebar-create ()
    "Create a file at point's directory; a trailing / creates a folder."
    (interactive)
    (let* ((dir (rm/sidebar--dir-at-point))
           (name (read-string (format "Create in %s: " (abbreviate-file-name dir)))))
      (when (string-empty-p name) (user-error "No name given"))
      (let ((target (expand-file-name name dir)))
        (when (file-exists-p target)
          (user-error "%s already exists" (abbreviate-file-name target)))
        (if (string-suffix-p "/" name)
            (make-directory target t)
          (make-directory (file-name-directory target) t)
          (write-region "" nil target nil 0))
        (dired-sidebar-refresh-buffer))))
  (defun rm/sidebar-rename ()
    "Rename the file at point, editing its current name (yazi-style).
Plain `read-string' on purpose: `dired-do-rename' completes over
existing files, and vertico's RET submits the highlighted candidate --
typing \"Musings\" selected \"Current Musings.org\" itself and errored
with \"Cannot move to same file\".  A path as the new name still moves."
    (interactive)
    (let ((file (dired-get-filename nil t)))
      (unless file (user-error "No file at point"))
      (let* ((dir (file-name-directory (directory-file-name file)))
             (old (file-name-nondirectory (directory-file-name file)))
             (new (read-string "Rename to: " old)))
        (when (or (string-empty-p new) (equal new old))
          (user-error "Not renamed"))
        (let ((target (expand-file-name new dir)))
          (when (file-exists-p target)
            (user-error "%s already exists" (abbreviate-file-name target)))
          (make-directory (file-name-directory target) t)
          (dired-rename-file file target nil)
          (dired-sidebar-refresh-buffer)))))
  (defun rm/sidebar-yank ()
    "Yank (copy) the file at point for `rm/sidebar-paste'."
    (interactive)
    (let ((file (dired-get-filename nil t)))
      (unless file (user-error "No file at point"))
      (setq rm/sidebar-yanked file)
      (message "Yanked %s" (abbreviate-file-name file))))
  (defun rm/sidebar-paste ()
    "Paste the yanked file into the directory at point."
    (interactive)
    (unless rm/sidebar-yanked (user-error "Nothing yanked (y first)"))
    (let* ((dir (rm/sidebar--dir-at-point))
           (target (expand-file-name (file-name-nondirectory
                                      (directory-file-name rm/sidebar-yanked))
                                     dir)))
      (when (file-exists-p target)
        (user-error "%s already exists" (abbreviate-file-name target)))
      (if (file-directory-p rm/sidebar-yanked)
          (copy-directory rm/sidebar-yanked target)
        (copy-file rm/sidebar-yanked target))
      (message "Pasted %s" (abbreviate-file-name target))
      (dired-sidebar-refresh-buffer)))
  (define-key dired-sidebar-mode-map "a" #'rm/sidebar-create)
  (define-key dired-sidebar-mode-map "r" #'rm/sidebar-rename)
  (define-key dired-sidebar-mode-map "d" #'dired-do-delete)
  (define-key dired-sidebar-mode-map "y" #'rm/sidebar-yank)
  (define-key dired-sidebar-mode-map "p" #'rm/sidebar-paste))

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
;;   * citar      -- \cite by fuzzy author/title search over references.bib,
;;                   riding on vertico; deferred while RefTeX (C-c [) suffices
;;   * pdf-tools  -- view/annotate PDFs in Emacs (zathura already views)
;;   * a theme that follows Omarchy -- Emacs won't auto-track it; its own project

;; --- C-x -> beginning-of-line (the other half of the C-a swap) -----------
;; Deliberately LAST: every "C-x ..." definition above (C-x k, magit's C-x g,
;; ...) must already be inside ctl-x-map before the C-x key itself stops
;; being a prefix -- define-key errors if asked to extend through a
;; non-prefix key.  ctl-x-map itself is untouched; C-a reaches all of it.
(keymap-global-set "C-x" #'move-beginning-of-line)

;;; init.el ends here
