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
;; menu with repeatable resize, the C-c p sidebar, ESC as universal
;; back (splash floor).  CapsLock is Ctrl at
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

;; (which-key removed 2026-07-21.)  To list a prefix's bindings on demand,
;; press `C-h' after the prefix -- e.g. `C-c w C-h' shows the window menu,
;; `C-a C-h' lists ctl-x-map.  marginalia already teaches binds inside M-x.

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
;; ...and from the thumb (his ask, 2026-07-25, with the M-a/M-SPC/M-g
;; family): M-z was zap-to-char, unused
(keymap-global-set "M-z"   #'undo)
(keymap-global-set "M-S-z" #'undo-redo)

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
;; is the sequence Emacs sees, so echoes and describe-key all say
;; C-a.  Only the *manuals* still print "C-x" -- mentally substitute.
;; Beginning-of-line lands on the vacated C-x -- bound at the END of this
;; file, because rebinding the C-x prefix to a command must come after every
;; "C-x ..." key definition (later ones would error on a non-prefix key).
;; (Modes that bind C-a locally -- comint/eshell's bol -- shadow the prefix
;; there; not a mode you write in.)
(define-key global-map (kbd "C-a") ctl-x-map)

;; M-SPC = C-c, everywhere (his ask, 2026-07-25: thumb on Alt + SPC beats
;; the C-c pinky reach).  Unlike C-a above there is NO keymap to bind
;; directly: global C-c lives in mode-specific-map but every mode's own
;; C-c C-x... lives inside that mode's map under the literal "C-c"
;; sequence -- only a key-translation rewrite reaches both (M-SPC M-SPC
;; = C-c C-c compiles, M-SPC SPC = home).  Accepted cost, unlike the
;; C-a call: echoes and describe-key report the sequence as "C-c ...".
;; C-c itself still works; stock M-SPC (cycle-spacing, unused) is gone.
(keymap-set key-translation-map "M-SPC" "C-c")

;; M-a = C-a too (same ask): the prefix itself binds DIRECTLY to
;; ctl-x-map (clean echoes, the C-a pattern above), so M-a k / M-a p p /
;; M-a C-s all just work.  The M-modified SECOND key (M-a M-s = C-a C-s)
;; needs sequence translations -- ctl-x-map holds C-s, not M-s, and M-s
;; can't be translated globally (it's the search prefix).  Unmatched
;; seconds (M-a k) fall through untranslated to the prefix binding.
;; Stock M-a (backward-sentence, unused) is gone.
(define-key global-map (kbd "M-a") ctl-x-map)
(dolist (c (number-sequence ?a ?z))
  (keymap-set key-translation-map
              (format "M-a M-%c" c) (format "C-a C-%c" c)))
;; ...except M-a M-SPC: the M-SPC=C-c rewrite applies mid-sequence, so it
;; landed on C-x C-c = save-buffers-kill-terminal -- an accidental
;; frame-close from two thumb keys.  Quit instead.
(keymap-set key-translation-map "M-a M-SPC" "C-g")

;; M-g = C-g (same ask): quit from the thumb.  Command-level only -- a
;; translated C-g aborts prompts, pending prefixes, and regions, but
;; interrupting RUNNING code stays real-C-g-only (quit-char is checked
;; below the keymap layer).  Cost: the stock goto prefix (M-g g etc.,
;; never bound here) -- M-x goto-line still exists.
(keymap-set key-translation-map "M-g" "C-g")

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
;;   C-c w      window menu (C-c w C-h lists it): s/v split below/right
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
;; ... minus `C-c h h' (view-hello-file): etc/HELLO is full of RTL/composed
;; scripts that reliably SEGFAULT pgtk Emacs 30.2's ftcrfont on redisplay
;; -- consult-buffer previewing a stray HELLO buffer core-dumped the daemon
;; (diagnosed from the core, 2026-07-21).  One help-prefix double-tap opens
;; it by accident; unbind until the upstream font bug is fixed.
(keymap-set help-map "h" nil)
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
;; is on above); any other key exits the repeat.  `C-c w C-h' lists the
;; full menu.
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

(defun rm/window-new ()
  "Fresh window to the right, showing the splash -- a blank slate to
navigate from with the splash's single keys (f, l, a, n, ...)."
  (interactive)
  (select-window (split-window-right))
  (rm/welcome t))
(defvar-keymap rm/window-map
  :doc "Window menu: splits, file-into-split, swap, divider drag, balance, layout undo."
  "s" #'split-window-below                ; like :sp
  "v" #'split-window-right                ; like :vs
  "SPC" #'rm/window-new                   ; blank slate: fresh right split
                                          ; showing the splash (h = home was
                                          ; his first pick, but h is the
                                          ; resize quartet's drag-left)
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
;; org-meta-return).  Bound into ctl-x-map DIRECTLY, not via the "C-x k"
;; path: after the end-of-init C-a/C-x swap, "C-x" is no longer a prefix,
;; so the path form would error on any rm/reload-init.  Typed as C-a k.
;; rm/kill-buffer (defined with the splash machinery) additionally lands
;; on the splash when the window's real history is all dead -- killing a
;; note captured from the splash returns you to the splash, not whatever
;; buffer Emacs cycles in as filler.
(keymap-set ctl-x-map "k" #'rm/kill-buffer)

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
  (vertico-mode 1)
  ;; The note picker (splash f/g) shows its candidates in the ORIGINAL
  ;; window, not the minibuffer overlay: vertico-buffer via multiform,
  ;; scoped to exactly those two commands.
  (require 'vertico-multiform)
  (require 'vertico-buffer)
  (setq vertico-multiform-commands '((rm/denote-find buffer)
                                     (rm/denote-grep buffer)
                                     (rm/denote-list buffer))
        vertico-buffer-display-action '(display-buffer-same-window))
  (vertico-multiform-mode 1))

(use-package orderless
  :init
  (setq completion-styles '(orderless basic)   ; basic = fallback (e.g. TAB paths)
        completion-category-defaults nil
        ;; find-file: keep /u/l/s -> /usr/local/share -style expansion working
        completion-category-overrides '((file (styles partial-completion)))))

(use-package marginalia
  :init (marginalia-mode 1))

;; --- consult + embark (retrieval layer over vertico) ---------------------
;; Same philosophy as the stack above: minibuffer-only, no in-buffer popups.
;;   consult   live-PREVIEWED prompts and searches:
;;             C-a b    switch buffer -- now also recent files, previewed
;;             M-s l    search this buffer's lines as you type
;;             M-s r    ripgrep from the current project/directory
;;             M-s o    jump to a heading (org buffers)
;;             C-c d g  ripgrep the VAULT (defined in the denote block) --
;;                      the splash's "text" find; type #important there
;;                      for the "marks" find
;;   embark    C-. acts on the thing at point (file, link, candidate...);
;;             inside a minibuffer, C-. then E EXPORTS the live candidate
;;             set to a real buffer (ripgrep results -> grep buffer, file
;;             matches -> dired) for browsing or bulk edits.  Also takes
;;             over prefix help: C-c d C-h (etc.) now opens a SEARCHABLE
;;             list of the prefix's bindings -- the good half of the
;;             retired which-key, on demand only.
(use-package consult
  :init
  ;; Bound via ctl-x-map DIRECTLY, not a "C-x b" path bind, which would
  ;; break rm/reload-init once C-x stops being a prefix (the C-a k lesson).
  (keymap-set ctl-x-map "b" #'consult-buffer)
  (keymap-global-set "M-s l" #'consult-line)
  (keymap-global-set "M-s r" #'consult-ripgrep)
  (with-eval-after-load 'org
    (define-key org-mode-map (kbd "M-s o") #'consult-org-heading)))

(use-package embark
  :init
  ;; flyspell's buffer-local C-. auto-correct loses the key; M-$ covers
  ;; spelling.  Global C-. was free.
  (with-eval-after-load 'flyspell
    (define-key flyspell-mode-map (kbd "C-.") nil))
  (keymap-global-set "C-." #'embark-act)
  (setq prefix-help-command #'embark-prefix-help-command))

;; Glue: previews inside embark-collect buffers (e.g. an exported grep set).
(use-package embark-consult
  :hook (embark-collect-mode . consult-preview-at-point-mode))

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
  ;; Into ctl-x-map DIRECTLY (typed C-a g): a "C-x g" sequence bind works
  ;; at first boot but errors on every rm/reload-init once end-of-init
  ;; makes plain C-x a non-prefix (same class as the old C-x k bug).
  :bind (:map ctl-x-map ("g" . magit-status)))

;; C-c g: the `save' shell function, from inside -- save the buffer, then
;; git add -A / commit / push its repo, async, verdict in the echo area.
;; C-u C-c g prompts for the commit message (plain C-c g commits as ".").
;; The vault has no remote: it reports "committed" instead of failing.
(defun rm/save (&optional message)
  "Save the buffer, then add/commit/push its git repo (shell `save')."
  (interactive (list (when current-prefix-arg
                       (read-string "Commit message: " nil nil "."))))
  (when (and buffer-file-name (buffer-modified-p)) (save-buffer))
  (let* ((dir (or (and buffer-file-name
                       (file-name-directory buffer-file-name))
                  default-directory))
         (root (locate-dominating-file dir ".git")))
    (unless root (user-error "Not in a git repository"))
    (let ((default-directory root)
          (name (abbreviate-file-name root)))
      (with-current-buffer (get-buffer-create "*rm-save*")
        (erase-buffer))
      (make-process
       :name "rm-save" :buffer "*rm-save*"
       :command
       (list "sh" "-c"
             (format (concat "git add -A || exit 1\n"
                             "if git diff --cached --quiet; then echo __NOTHING__; exit 0; fi\n"
                             "git commit -m %s || exit 1\n"
                             "git push 2>&1 || echo __PUSHFAIL__\n")
                     (shell-quote-argument (or message "."))))
       :sentinel
       (lambda (p _e)
         (when (memq (process-status p) '(exit signal))
           (let ((out (with-current-buffer "*rm-save*" (buffer-string))))
             (cond
              ((not (zerop (process-exit-status p)))
               (message "save failed in %s — log in *rm-save*" name))
              ((string-match-p "__NOTHING__" out)
               (message "Nothing to commit in %s" name))
              ((string-match-p "__PUSHFAIL__" out)
               (message "Committed in %s (push failed — no remote?)" name))
              (t (message "Committed & pushed %s ✓" name))))))))))
(keymap-global-set "C-c g" #'rm/save)

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

;; --- LaTeX in buffers: highlighted source, preview on demand ------------
;; No in-text auto-rendering: org-fragtog REMOVED 2026-07-23 (his ruling --
;; the image fragments made scrolling stutter).  Preview stays manual:
;; `C-c C-x C-l' in Org, AUCTeX's `C-c C-p C-p' in .tex (both dvisvgm;
;; options in the Org block).  In prose, LaTeX reads as highlighted
;; SOURCE instead -- org-highlight-latex-and-related in the Org block.

;; --- PDFs: pdf-tools replaces DocView -----------------------------------
;; Crisp poppler rendering (DocView rasterizes through ghostscript and
;; blurs).  The epdfinfo helper is compiled into the package dir at
;; install time.  Vim feel on the reading keys: j/k scroll, J/K flip
;; pages, h/l nudge sideways when zoomed in.  Stock keys kept: SPC /
;; S-SPC page-scroll, +/- zoom, W fit width, P fit page, o outline,
;; C-s isearch (searches the actual text layer).
(use-package pdf-tools
  :mode ("\\.pdf\\'" . pdf-view-mode)
  :magic ("%PDF" . pdf-view-mode)
  :config
  (pdf-tools-install :no-query)
  (setq pdf-view-display-size 'fit-width)
  (defun rm/pdf-scroll-down ()
    "Scroll the page down a comfortable step (vim j)."
    (interactive)
    (pdf-view-next-line-or-next-page 4))
  (defun rm/pdf-scroll-up ()
    "Scroll the page up a comfortable step (vim k)."
    (interactive)
    (pdf-view-previous-line-or-previous-page 4))
  (keymap-set pdf-view-mode-map "j" #'rm/pdf-scroll-down)
  (keymap-set pdf-view-mode-map "k" #'rm/pdf-scroll-up)
  (keymap-set pdf-view-mode-map "J" #'pdf-view-next-page-command)
  (keymap-set pdf-view-mode-map "K" #'pdf-view-previous-page-command)
  (keymap-set pdf-view-mode-map "h" #'image-backward-hscroll)
  (keymap-set pdf-view-mode-map "l" #'image-forward-hscroll))

;; --- Org: notes + TODO/agenda (:lang org, built into Emacs) -------------
;; Papers stay in LaTeX.  Org is for tasks/agenda and prose notes (the
;; folder-of-outlines style, not zettelkasten).  Everything here is
;; built in -- no packages, no org-roam.

(use-package org
  :ensure nil                             ; org ships with Emacs
  :bind (("C-c a" . org-agenda)           ; the calendar/todo dispatcher
         ;; (C-c c UNBOUND 2026-07-23: t/n on the splash are capture --
         ;;  rm/capture-task still calls org-capture programmatically)
         ("C-c l" . org-store-link)
         :map org-mode-map
         ;; preview is OFF for good (rendered fragments kept reappearing);
         ;; the stock preview key can only ever CLEAR images now
         ("C-c C-x C-l" . rm/latex-preview-clear)
         ;; list ergonomics = Obsidian's (his spec, 2026-07-24): RET
         ;; continues a list with a bullet on the very next line; on an
         ;; empty bullet it outdents a level per press, ending the list
         ;; at top level; TAB indents the item one level (4-space steps,
         ;; see org-list-indent-offset), C-TAB outdents (C-TAB was
         ;; org-force-cycle-archived, never used)
         ("RET" . rm/org-return)
         ("TAB" . rm/org-tab)
         ("C-<tab>" . rm/org-untab))
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
        ;; The default 'reorganize-frame DELETES the other windows on C-c a --
        ;; the agenda hijacks the frame and there's nothing left to resize
        ;; against.  'other-window keeps the buffer you launched from
        ;; visible (agenda lands in another/new window -- 'current-window
        ;; put the task list ON TOP of the file you were reading); the
        ;; daily paper+notes+agenda layout survives and C-c w hjkl work.
        ;; Which "other window" is pinned by the display-buffer-alist rule
        ;; below: reuse a visible agenda window, else ALWAYS split a fresh
        ;; one -- never commandeer an existing window.
        org-agenda-window-setup 'other-window
        org-startup-folded 'showall       ; open fully expanded; S-TAB cycles all folding
        org-startup-with-inline-images t  ; render ![[image]] embeds inline (Obsidian-like)
        org-image-actual-width '(500)     ; cap oversized inline images at 500px
        org-hide-emphasis-markers t       ; show *bold* / italic rendered, hide the markers
        ;; RET's new bullet goes on the VERY NEXT line, always (Obsidian
        ;; behavior).  The default `auto' guesses from nearby blank lines
        ;; -- the blank separating a list from the paragraph above it was
        ;; enough to make every new item arrive a blank line down, reading
        ;; as a separate list (his repro, 2026-07-24)
        org-blank-before-new-entry '((heading . auto) (plain-list-item . nil))
        ;; sub-items step in 4 spaces, not org's 2 (Obsidian's tab
        ;; width): the offset is ADDED to the parent bullet's 2
        org-list-indent-offset 2
        org-log-done 'time                ; stamp the time when a TODO -> DONE
        org-todo-keywords
        '((sequence "TODO" "NEXT" "WAITING" "|" "DONE" "CANCELLED"))
        ;; Task MATTER tags (the TODO keyword is the form, the tag is the
        ;; matter it concerns): fast-select on M-c / C-c C-c -- one letter
        ;; tags and exits.  `expert' keeps the whole exchange in the
        ;; minibuffer (the stock grid WINDOW jarred against M-c's other
        ;; contexts, all tiny prompts -- his rule, 2026-07-24); C-c inside
        ;; the prompt still summons the grid.  Orthogonal to location:
        ;; C-c a m gathers a tag's TODOs from inbox.org, the technology
        ;; hub, anywhere the agenda scans.  Distinct namespace from the
        ;; vault's note-matter (that names research programs; these name
        ;; the legs of the job).
        org-fast-tag-selection-single-key 'expert
        org-tag-alist '(("technology" . ?t) ("teaching" . ?e)
                        ("service" . ?s) ("research" . ?r)))
  :config
  ;; Dispatcher `m' = todos by tag (the stock m is a headline-tag match
  ;; that filetag inheritance floods with note sections -- dead weight
  ;; in this grammar; stock M behavior takes its key).
  (setq org-agenda-custom-commands
        '(("m" "Todos, by tag" (lambda (_) (org-tags-view t)))))
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
  (setq org-format-latex-options (plist-put org-format-latex-options :scale 1.5))
  ;; LaTeX reads as highlighted SOURCE in prose: $math$, environments,
  ;; and \commands (citation keys included) get org-latex-and-related --
  ;; sienna Roboto Mono at prose height, the export-block look he liked
  ;; (family+size via the mixed-pitch pin, colour via
  ;; rm/apply-face-tweaks).  This is the whole in-text story: NO image
  ;; rendering (org-fragtog removed 2026-07-23 -- scroll stutter; the
  ;; preview key is neutered below because renders kept reappearing).
  (setq org-highlight-latex-and-related '(latex)
        org-startup-with-latex-preview nil)
  ;; org's 'latex option covers fragments/environments but NOT prose
  ;; macros -- \textcite{...} stayed unhighlighted.  Add the macro
  ;; pattern ourselves.  In prose the span gets org-latex-and-related
  ;; (sienna mono at prose height).  Inside org-block-faced text
  ;; (export blocks) it gets a COLOUR-ONLY face instead: the block
  ;; already supplies mono + the 0.75 size, and stacking a second
  ;; height-remapped face there compounds the two relative heights
  ;; into tiny text (float face heights MULTIPLY down the merge chain).
  (defface rm/org-latex-in-block
    '((t :foreground "#9c6644"))
    "LaTeX macro colour inside blocks: colour only, no family/height.")
  (defconst rm/org-latex-macro-rx
    "\\\\[a-zA-Z@]+\\*?\\(?:\\[[^]\n]*\\]\\)*\\(?:{[^{}\n]*}\\)*")
  (defun rm/org-latex-macro-matcher (limit)
    (re-search-forward rm/org-latex-macro-rx limit t))
  (font-lock-add-keywords
   'org-mode
   '((rm/org-latex-macro-matcher
      0
      (if (memq 'org-block
                (flatten-tree (list (get-text-property (match-beginning 0)
                                                       'face))))
          'rm/org-latex-in-block
        'org-latex-and-related)
      prepend))
   t)
  ;; Citation pills (his ruling, 2026-07-23): a full
  ;; \textcite{dasguptaSymmetryEpistemicNotion2016} is a 40-char
  ;; unbreakable chunk that forces early soft-wraps and ragged lines.
  ;; In prose it DISPLAYS as a compact ‹author2016› (display property --
  ;; the file is untouched); the full command reveals while point is
  ;; inside, the org-appear pattern.  Blocks keep their full text.
  (defconst rm/org-cite-rx
    "\\\\\\(?:text\\|paren\\|auto\\|foot\\)?[Cc]ite\\*?\\(?:\\[[^]\n]*\\]\\)*{\\([^{}\n]*\\)}")
  (defun rm/cite-pill--short (key)
    "KEY's compact form: author+year from either Better BibTeX shape."
    (setq key (string-trim key))
    (let ((case-fold-search nil))         ; [a-z] must NOT eat the CamelCase
      (cond
       ((string-match "\\`\\([A-Za-z-]+[0-9]\\{4\\}\\)-[a-z]\\{2\\}\\'" key)
        (match-string 1 key))                          ; Dewar2019-ns
       ((string-match "\\`\\([a-z-]+\\)[A-Z].*?\\([0-9]\\{4\\}[a-z]?\\)\\'" key)
        (concat (match-string 1 key) (match-string 2 key))) ; dasguptaTitle2016
       (t key))))
  (defun rm/org-cite-pill-matcher (limit)
    (catch 'found
      (while (re-search-forward rm/org-cite-rx limit t)
        (unless (memq 'org-block
                      (flatten-tree
                       (list (get-text-property (match-beginning 0) 'face))))
          (throw 'found t)))
      nil))
  (defun rm/org-cite-pill-spec ()
    ;; facespec plists must START with `face' (nil = no face of its own;
    ;; the macro keyword already coloured the span)
    (list 'face nil
          'display (format "‹%s›"
                           (mapconcat #'rm/cite-pill--short
                                      (split-string (match-string 1) ",")
                                      ","))
          'rm-cite-pill t))
  (font-lock-add-keywords
   'org-mode
   '((rm/org-cite-pill-matcher 0 (rm/org-cite-pill-spec) prepend))
   t)
  ;; @@latex:...@@ escape hatches: the INK vanishes -- the span displays
  ;; as its inner content only (empty separators disappear entirely),
  ;; revealing raw at point via the same watcher as the citation pills.
  ;; Mostly historical: the byte-parity era needed escapes for accents /
  ;; \dots / $math$-hyphen collisions, all of which now have escape-free
  ;; spellings (see README "LaTeX in org prose").
  (font-lock-add-keywords
   'org-mode
   '(("@@latex:\\([^@\n]*\\)@@"
      0
      (list 'face nil
            'display (substring-no-properties (match-string 1))
            'rm-cite-pill t)
      prepend))
   t)
  (defvar-local rm/cite-pill--revealed nil)
  (defun rm/cite-pill--watch ()
    "Reveal the pill at point (full \\cite command); re-hide on exit."
    (when-let ((range rm/cite-pill--revealed))
      (when (or (< (point) (car range)) (> (point) (cdr range))
                (not (get-text-property (car range) 'rm-cite-pill)))
        (font-lock-flush (car range) (cdr range))
        (setq rm/cite-pill--revealed nil)))
    (unless rm/cite-pill--revealed
      (when (get-text-property (point) 'rm-cite-pill)
        (let ((beg (or (previous-single-property-change
                        (min (1+ (point)) (point-max)) 'rm-cite-pill)
                       (point-min)))
              (end (or (next-single-property-change (point) 'rm-cite-pill)
                       (point-max))))
          (with-silent-modifications
            (remove-text-properties beg end '(display nil)))
          (setq rm/cite-pill--revealed (cons beg end))))))
  (defun rm/cite-pill-setup ()
    "Buffer-local plumbing for the citation pills."
    (setq-local font-lock-extra-managed-props
                (append '(display rm-cite-pill)
                        font-lock-extra-managed-props))
    (add-hook 'post-command-hook #'rm/cite-pill--watch nil t))
  (add-hook 'org-mode-hook #'rm/cite-pill-setup)
  (defun rm/capture-task ()
    "Straight into a task capture (the t template) -- splash `t'."
    (interactive)
    (org-capture nil "t"))
  (defun rm/org-return ()
    "RET continues a list: a new bullet on the very next line (Obsidian).
On an EMPTY bullet it walks back out, also Obsidian-style: a nested
item outdents one level per press; a top-level one loses its bullet,
leaving point on the emptied line -- no extra newline.  `org-at-item-p'
on purpose: the old `org-in-item-p' counted the blank line just below
a list as still \"in\" it, so the RET after ending a list re-inserted
a bullet (make/delete loop, 2026-07-24).  Everywhere else, stock
`org-return' (tables, headings, prose)."
    (interactive)
    (cond
     ((and (org-at-item-p)
           (save-excursion
             (beginning-of-line)
             (looking-at "[ \t]*\\(?:[-+*]\\|[0-9]+[.)]\\)\\(?: \\[[ X-]\\]\\)?[ \t]*$")))
      (if (> (current-indentation) 0)
          (org-outdent-item)
        (delete-region (line-beginning-position) (line-end-position))))
     ((org-at-item-p)
      (org-insert-item (org-at-item-checkbox-p)))
     (t (org-return))))
  (defun rm/org-tab ()
    "TAB on a list item indents it one level; elsewhere, stock cycling."
    (interactive)
    (if (org-at-item-p)
        (org-indent-item)
      (org-cycle)))
  (defun rm/org-untab ()
    "C-TAB on a list item outdents it one level."
    (interactive)
    (if (org-at-item-p)
        (org-outdent-item)
      (user-error "Not on a list item")))
  ;; Prose is soft-wrapped (visual-line + olivetti own the line width;
  ;; the papers' legacy hard fills were removed 2026-07-23, gated by
  ;; pdftotext + pixel comparison).  A huge fill-column turns M-q into
  ;; an UNfiller: refilling can't reintroduce char-count line breaks,
  ;; which render ragged under a proportional font.
  (defun rm/org-no-hard-fill ()
    (setq-local fill-column most-positive-fixnum))
  (add-hook 'org-mode-hook #'rm/org-no-hard-fill)
  ;; org's multi-key selectors (capture templates, export dispatch) read
  ;; chars in a recursive loop that ESC cannot break: the ESC char is
  ;; just one more "Invalid key" and the pending selector eats every
  ;; keystroke until C-g -- which stranded the splash behind a stuck
  ;; "Invalid key: 'a'" (2026-07-23).  Teach the reader that ESC aborts,
  ;; consistent with ESC = universal back.  Stock body otherwise
  ;; (org-macs.el, org--mks-read-key).
  (defun rm/org--mks-read-key (allowed-keys prompt navigation-keys)
    (setq header-line-format
          (when navigation-keys "Use C-n, C-p, C-v, M-v to navigate."))
    (let ((char-key (read-char-exclusive prompt)))
      (cond
       ((eq char-key ?\e) (user-error "Abort"))
       ((and navigation-keys (memq char-key '(14 16 22 134217846)))
        (org-scroll char-key)
        (rm/org--mks-read-key allowed-keys prompt navigation-keys))
       (t
        (let ((key (char-to-string
                    (pcase char-key
                      ((or ?\s ?\t ?\r) ?\t)
                      (char char)))))
          (if (member key allowed-keys)
              key
            (message "Invalid key: `%s'" key)
            (sit-for 1)
            (rm/org--mks-read-key allowed-keys prompt navigation-keys)))))))
  (advice-add 'org--mks-read-key :override #'rm/org--mks-read-key)
  (defun rm/latex-preview-clear ()
    "LaTeX preview stays OFF: clear any rendered fragments here instead."
    (interactive)
    (let ((n 0))
      (dolist (ov (overlays-in (point-min) (point-max)))
        (when (eq (overlay-get ov 'org-overlay-type) 'org-latex-overlay)
          (delete-overlay ov) (setq n (1+ n))))
      (message "LaTeX preview is off%s"
               (if (> n 0) (format " — %d rendered fragment(s) cleared" n) ""))))
  ;; Agenda vim feel: hjkl moves (j/k lines, h/l shifts the date range in
  ;; calendar views), r progresses the TODO state at point (cycle; C-u r to
  ;; pick), d deletes the entry from its source file (his flow: fixed
  ;; frictions get deleted, not archived).  Stock keys displaced: refresh
  ;; stays on `g', goto-date via M-x org-agenda-goto-date, capture via
  ;; C-c c, log mode via `v l', day view via `v d'.
  (with-eval-after-load 'org-agenda
    (keymap-set org-agenda-mode-map "j" #'org-agenda-next-line)
    (keymap-set org-agenda-mode-map "k" #'org-agenda-previous-line)
    (keymap-set org-agenda-mode-map "h" #'org-agenda-earlier)
    (keymap-set org-agenda-mode-map "l" #'org-agenda-later)
    (keymap-set org-agenda-mode-map "r" #'org-agenda-todo)
    (keymap-set org-agenda-mode-map "d" #'org-agenda-kill))
  ;; Quieter agenda dressing.  The todo/match views insert a "Press 'N r'
  ;; ..." hint under the header, whose keyword list wraps onto indented
  ;; "(4)NEXT (5)TODO" continuation lines -- strip the whole block (real
  ;; entries are indented but never start with a parenthesized number).
  (defun rm/agenda-strip-hints ()
    (save-restriction
      (widen)
      (save-excursion
        (goto-char (point-min))
        (let ((inhibit-read-only t))
          (while (re-search-forward
                  "^Press .*\n\\(?:[ \t]+([0-9]+)[^\n]*\n?\\)*" nil t)
            (delete-region (match-beginning 0) (match-end 0)))))))
  (add-hook 'org-agenda-finalize-hook #'rm/agenda-strip-hints)
  ;; The agenda's own keys, printed where they apply (footer of every
  ;; agenda view) rather than on the splash.
  (defconst rm/agenda-footer-text
    " hjkl move \u00b7 r progress \u00b7 d delete \u00b7 s save")
  (defun rm/agenda-footer ()
    ;; Idempotent by CONTENT: agenda redraws strip text properties, so
    ;; sweep the literal footer line (and its leading blank) wherever it
    ;; sits, then append exactly one at the end.  MUST widen: state
    ;; changes run finalize narrowed to the changed line (org-agenda.el
    ;; admits as much above org-agenda-mark-clocking-task).
    (let ((inhibit-read-only t))
      (save-restriction
        (widen)
        (save-excursion
          (goto-char (point-min))
          (while (re-search-forward
                  (concat "\n?" (regexp-quote rm/agenda-footer-text) "\n?")
                  nil t)
            (delete-region (match-beginning 0) (match-end 0)))
          (goto-char (point-max))
          (insert (propertize (concat "\n" rm/agenda-footer-text "\n")
                              'face 'nano-face-faded))))))
  (add-hook 'org-agenda-finalize-hook #'rm/agenda-footer 90)
  ;; Source column: denote files would show as their raw filename
  ;; ("20260721T105802--technology__hub", truncated); show "title form"
  ;; instead, fixed-width so the TODO column stays aligned.
  (defun rm/agenda-category ()
    (let* ((f (buffer-file-name (buffer-base-buffer)))
           (base (and f (file-name-base f)))
           (s (if (and base (string-match
                             "\\`[0-9]\\{8\\}T[0-9]\\{6\\}--\\(.+?\\)\\(?:__\\([a-z]+\\).*\\)?\\'"
                             base))
                  (concat (subst-char-in-string ?- ?\s (match-string 1 base))
                          (if (match-string 2 base)
                              (concat " " (match-string 2 base)) ""))
                (org-get-category))))
      (truncate-string-to-width (or s "") 18 nil ?\s "…")))
  (setq org-agenda-prefix-format
        '((agenda . " %i %(rm/agenda-category) %?-12t% s")
          (todo   . " %i %(rm/agenda-category) ")
          (tags   . " %i %(rm/agenda-category) ")
          (search . " %i %(rm/agenda-category) ")))
  ;; The agenda always gets its own window: reuse one already showing it,
  ;; else split fresh (largest window gives up the space); never replace
  ;; the buffer in an existing window.  Pairs with 'other-window above.
  (add-to-list 'display-buffer-alist
               '("\\*Org Agenda\\*"
                 (display-buffer-reuse-window display-buffer-pop-up-window)
                 (inhibit-same-window . t))))

;; --- Papers in Org: body-only LaTeX export --------------------------------
;; paper.org files under research-wip/documents/papers/<slug>/ export to the
;; body.tex their paper.tex driver \input's; the dissertation's
;; frontmatter/introduction.org exports to introduction.tex the same way --
;; machinery and rationale live in org-paper-export.el (beside this init;
;; also loaded by the publish shell function via emacs -Q --batch).  Wiring here: the paper-latex
;; backend registers when ox-latex loads; every save of a paper.org
;; regenerates body.tex (never stale in git); C-c C-c in a paper.org
;; exports + latexmks, matching the AUCTeX muscle memory.  The path guard
;; is inlined in the hooks so the module stays lazy-loaded.
(with-eval-after-load 'ox-latex
  (require 'org-paper-export
           (expand-file-name "org-paper-export.el" user-emacs-directory)))
(defun rm/org-paper--maybe-export-on-save ()
  "Regenerate the generated .tex when the saved buffer is org-authored.
Cheap outer guard (any research-wip .org) before loading the module;
the precise pattern lives in `rm/org-paper-buffer-p' there."
  (when (and buffer-file-name
             (string-match-p "/research-wip/.*\\.org\\'" buffer-file-name))
    (require 'org-paper-export
             (expand-file-name "org-paper-export.el" user-emacs-directory))
    (when (rm/org-paper-buffer-p)
      (rm/org-paper-export))))
(add-hook 'after-save-hook #'rm/org-paper--maybe-export-on-save)
(with-eval-after-load 'org
  (add-hook 'org-ctrl-c-ctrl-c-final-hook
            (lambda ()
              (when (and buffer-file-name
                         (string-match-p "/research-wip/.*\\.org\\'"
                                         buffer-file-name))
                (require 'org-paper-export
                         (expand-file-name "org-paper-export.el"
                                           user-emacs-directory))
                (rm/org-paper-compile)))))

;; Push timestamped Org TODOs from inbox.org to a dedicated Google Calendar
;; ("org") via org-gcal (REST API v3).  ONE-WAY: we only ever POST entries,
;; never fetch/import, so nothing is read back.  Both the phone Google
;; Calendar app and rencal (itself a Google Calendar client) then display it;
;; one push, two views.  Push on demand via M-SPC G (= C-c G, sibling of
;; M-SPC g = git push); no timer.  (org-caldav was abandoned here: Google 403s
;; its CalDAV gateway for unverified apps, while the REST API works fine.)
;;
;; Credential storage: ~/.authinfo.gpg encrypts to this machine's GPG key
;; (ray@raymondmaung.com, no passphrase) non-interactively -- no recipient
;; prompt on save, no decrypt prompt on read.  auth-sources is pinned to the
;; encrypted file only (no plaintext ~/.authinfo fallback).
(setq epa-file-encrypt-to '("ray@raymondmaung.com")
      plstore-encrypt-to  '("ray@raymondmaung.com")
      auth-sources        '("~/.authinfo.gpg"))

;; org-gcal (REST API v3) pulls in aio/alert/oauth2-auto/persist/request as
;; deps.  oauth2-auto runs a loopback redirect server, so consent is caught
;; automatically -- no code-pasting.  Client id/secret come from
;; ~/.authinfo.gpg; the token lives under no-littering's var/.  We only ever
;; POST -- bulk via `rm/org-gcal-push' (M-SPC G), or one entry at a time via
;; `rm/org-gcal-auto-push' (fires after you schedule/deadline in inbox.org).
;; The fetch/sync commands are never called, so the calendar stays write-only
;; from Emacs's side.
(use-package org-gcal
  :commands (org-gcal-post-at-point)
  :init
  (setq org-gcal-dir (no-littering-expand-var-file-name "org-gcal/")
        org-gcal-token-file (no-littering-expand-var-file-name "org-gcal/token")
        ;; Keep org-gcal's runtime state OUT of user-emacs-directory (= the
        ;; dotfiles dir): oauth2-auto's OAuth token store and org-generic-id's
        ;; location cache both default there and would litter -- and leak a
        ;; (encrypted) token -- into git.  Redirect to no-littering's var/.
        oauth2-auto-plstore (no-littering-expand-var-file-name "oauth2-auto.plist")
        org-generic-id-locations-file (no-littering-expand-var-file-name "org-generic-id-locations")
        ;; Placeholders so org-gcal's load-time check stays quiet (it warns when
        ;; client-id/secret are nil).  The REAL values are read from authinfo at
        ;; push time by `rm/org-gcal--ensure-auth', which also re-registers the
        ;; provider -- so these strings are never actually used to authenticate.
        org-gcal-client-id "set-at-push-time"
        org-gcal-client-secret "set-at-push-time"
        ;; inbox.org <-> the "org" calendar.  Used only to resolve the target
        ;; calendar-id for pushes; the fetching commands stay unused.
        org-gcal-fetch-file-alist
        '(("18e761b7f73a7aa68dc5b96efc6273b189816168bf96b6f3d2fe791389b5bfe8@group.calendar.google.com"
           . "~/Dropbox/org/inbox.org"))))

;; Push helpers live at TOP LEVEL (not the use-package :config) so the auto-push
;; advice and the M-SPC G command exist from startup; each loads org-gcal on
;; first use via `require'.
(defun rm/org-gcal--ensure-auth ()
  "Load the Google OAuth client id/secret from ~/.authinfo.gpg and re-register
the oauth2-auto `org-gcal' provider.  Read at PUSH time, not startup: in the
systemd daemon gpg-agent may not be reachable when init loads, so a startup read
returns nil and the authorize URL goes out with an empty client_id.  Retries
once, since a cold gpg-agent can miss the first decrypt."
  (require 'org-gcal)
  (let ((c (or (car (auth-source-search :host "google-calendar-oauth"
                                        :max 1 :require '(:user :secret)))
               (progn (auth-source-forget-all-cached)
                      (car (auth-source-search :host "google-calendar-oauth"
                                               :max 1 :require '(:user :secret)))))))
    (unless (and c (plist-get c :user) (plist-get c :secret))
      (user-error "Could not read `google-calendar-oauth' from ~/.authinfo.gpg"))
    (setq org-gcal-client-id (plist-get c :user)
          org-gcal-client-secret
          (let ((s (plist-get c :secret))) (if (functionp s) (funcall s) s))
          oauth2-auto-additional-providers-alist
          (assq-delete-all 'org-gcal oauth2-auto-additional-providers-alist))
    (org-gcal-reload-client-id-secret)))

(defun rm/org-gcal--push-entry (calid)
  "Post the entry at point one-way (skip-import); return org-gcal's deferred.
Stamps CALID as the entry's calendar-id if absent, so no prompt appears."
  (unless (org-entry-get (point) org-gcal-calendar-id-property)
    (org-entry-put (point) org-gcal-calendar-id-property calid))
  (org-gcal-post-at-point t))

(defun rm/org-gcal-push ()
  "One-way push: POST every SCHEDULED/DEADLINE entry in inbox.org to the Google
`org' calendar, importing nothing back.  Untimestamped entries are skipped, so
they never reach the calendar.  Each POST is awaited so org-gcal's entry-id/etag
writeback lands (re-push PATCHes, no duplicates); the file is then saved."
  (interactive)
  (rm/org-gcal--ensure-auth)
  (with-current-buffer (find-file-noselect
                        (expand-file-name "~/Dropbox/org/inbox.org"))
    (let ((calid (org-gcal--get-calendar-id-of-buffer))
          (n 0))
      (org-map-entries
       (lambda ()
         (let ((elem (org-element-at-point)))
           (when (or (org-element-property :scheduled elem)
                     (org-element-property :deadline elem))
             (deferred:sync! (rm/org-gcal--push-entry calid))
             (setq n (1+ n)))))
       nil 'file)
      (save-buffer)
      (message "org-gcal: pushed %d timestamped entr%s from inbox.org"
               n (if (= n 1) "y" "ies")))))

(defun rm/org-gcal-auto-push ()
  "Auto-push the entry at point when it's a timestamped entry in inbox.org.
Fired after `org-schedule'/`org-deadline' so a scheduled TODO becomes an event
without a manual M-SPC G.  Async (non-blocking) with a save chained after the
POST so the id/etag writeback persists; M-SPC G stays the bulk fallback."
  (when (and buffer-file-name
             (file-equal-p buffer-file-name
                           (expand-file-name "~/Dropbox/org/inbox.org"))
             (or (org-get-scheduled-time (point))
                 (org-get-deadline-time (point))))
    (rm/org-gcal--ensure-auth)
    (let ((buf (current-buffer)))
      (deferred:nextc (rm/org-gcal--push-entry (org-gcal--get-calendar-id-of-buffer))
        (lambda (_)
          (with-current-buffer buf (save-buffer))
          (message "org-gcal: auto-pushed \"%s\"" (org-get-heading t t t t)))))))

(defun rm/org-gcal--schedule-advice (&rest _)
  "After-advice on `org-schedule'/`org-deadline': auto-push the entry."
  (ignore-errors (rm/org-gcal-auto-push)))
(dolist (fn '(org-schedule org-deadline))
  (advice-add fn :after #'rm/org-gcal--schedule-advice))

;; Also cover the splash-`t' capture path: there, scheduling happens INSIDE the
;; capture buffer (not inbox.org), so the advice above can't see it.  On capture
;; finish, push the just-filed entry if it landed a timestamp.  The marker moves
;; to the newest stored entry each capture, so unrelated captures (notes, plain
;; tasks) are skipped by `rm/org-gcal-auto-push's own timestamp check.
(defun rm/org-gcal--capture-push ()
  "Auto-push the just-captured entry if it filed a timestamp into inbox.org."
  (when (and (bound-and-true-p org-capture-last-stored-marker)
             (marker-buffer org-capture-last-stored-marker))
    (org-with-point-at org-capture-last-stored-marker
      (rm/org-gcal-auto-push))))
(add-hook 'org-capture-after-finalize-hook #'rm/org-gcal--capture-push)

(keymap-global-set "C-c G" #'rm/org-gcal-push)   ; M-SPC G -- bulk one-way push

;; Set a SCHEDULED stamp with M-SPC M-s (= C-c M-s), matching the M-SPC command
;; family (the default C-c C-s still works).  On this Wayland/Hyprland setup
;; Alt+Shift+letter drops the Shift and delivers plain M-s (meta + lowercase s)
;; -- so the lowercase form is what actually arrives.  Bind the capital/shift
;; forms too as cross-machine insurance (other input paths send M-S or S-M-s).
(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c M-s")   #'org-schedule)
  (define-key org-mode-map (kbd "C-c M-S")   #'org-schedule)
  (define-key org-mode-map (kbd "C-c S-M-s") #'org-schedule))

;; Restart the systemd Emacs daemon (super+w only closes the frame).  Detached
;; via systemd-run so the restart survives THIS process being killed.
(defun rm/restart-emacs ()
  "Restart the systemd user Emacs daemon (`emacs.service') AND reopen a frame.
Restarting the daemon alone brings it back headless -- your window is an
`emacsclient' frame that must be re-created.  Both steps run in a detached
`systemd-run' transient unit so they survive this process's death (a child in
the emacs.service cgroup would be SIGTERMed with the daemon).  `emacs.service'
is Type=notify, so `systemctl restart' only returns once the new daemon is
ready to accept the client.  Display vars are forwarded so the frame lands on
this session."
  (interactive)
  (when (yes-or-no-p "Restart the Emacs daemon (buffers are saved first)? ")
    (save-some-buffers t)
    (call-process
     "systemd-run" nil 0 nil "--user"
     (concat "--setenv=WAYLAND_DISPLAY=" (or (getenv "WAYLAND_DISPLAY") ""))
     (concat "--setenv=DISPLAY=" (or (getenv "DISPLAY") ""))
     "--"
     "sh" "-c"
     "systemctl --user restart emacs && exec emacsclient --alternate-editor= --create-frame -n")))
(defalias 'restart-emacs #'rm/restart-emacs)

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
  (setq org-modern-star nil               ; the ✦✧✱✳ glyphs moved into the
                                          ; MARGIN (org-margin below) --
                                          ; headline text sits flush left
        ;; real bullets for plain lists -- the stock "-" -> "–" en dash
        ;; read as hyphens (his complaint, 2026-07-23)
        org-modern-list '((?- . "•") (?+ . "◦") (?* . "▹"))
        org-modern-block-fringe nil       ; fringe markers sit wrong next to olivetti
        ;; tag/keyword pills look best unaligned (no trailing-whitespace columns)
        org-auto-align-tags nil
        org-tags-column 0))

;; org-margin (rougier, vendored like nano): headline stars render IN the
;; left margin as the level glyphs, so headline text starts at column 0 --
;; the outdented look.  Implementation: font-lock puts a
;; `display ((margin left-margin) GLYPH)' property on the leading stars.
;; olivetti must center via FRINGES for this (style t below): both would
;; otherwise fight over window margins.  nano paints fringes in the
;; background colour, so the switch is visually silent.
(require 'org-margin (expand-file-name "org-margin.el" user-emacs-directory))
(setq org-margin-headers
      (list (cons 'rm (list (propertize "✦" 'face 'org-level-1)
                            (propertize "✧" 'face 'org-level-2)
                            (propertize "✱" 'face 'org-level-3)
                            (propertize "✳" 'face 'org-level-4)
                            (propertize "✳" 'face 'org-level-5)
                            (propertize "✳" 'face 'org-level-6))))
      org-margin-headers-set 'rm
      ;; quiet quote marker only (the icon-font defaults render as boxes)
      org-margin-markers
      (list (cons "\\(#\\+begin_quote\\)"
                  (propertize "❝" 'face 'nano-face-faded))))
(add-hook 'org-mode-hook #'org-margin-mode)

;; --- Denote: the thought vault (~/Dropbox/notes) --------------------------
;; One flat naming grammar instead of folders: every note's filename is its
;; address on three axes at once --
;;   20260721T101530--topological-realism__paperidea_physics.org
;;   `-- timestamp --'  `-- title --------'  `- form + matter -'
;; The FIRST keyword is the FORM (what act of writing this is); the rest are
;; MATTER (which research program it serves; none = miscellaneous, by
;; design -- don't invent a "misc" keyword).  Two families of forms, no
;; pipeline between them:
;;   contemplative  musing poetry log talk meeting  -- finished when written
;;   productive     idea -> paperidea -> wip        -- promote by RENAME
;;                  (C-c d r; the ID never changes so links survive); a wip
;;                  that goes live EXITS the vault to research-wip as a paper
;;   reference      lit (reading notes)  hub (curated standing notes, e.g.
;;                  the Technology hub; span markers like #important and
;;                  #definition stay as grep-able ink in lit bodies)
;; Retrieval: the note picker (f/l/g, splash and C-c d) -- full-window
;; title catalog, typing narrows (f titles, l titles+keywords, g note
;; CONTENT via live rg), preview right, M-d deletes; C-c d b backlinks.
;; Capture: C-c n is instant and untitled (titles itself from line 1 on
;; save); M-c classifies in place.  Map on the splash.  Vault fully
;; denote since the 2026-07-22 migration (git-tracked -- commit often).
(use-package denote
  :bind (("C-c n" . rm/denote-note))       ; instant untitled capture
  :bind-keymap ("C-c d" . rm/denote-map)
  :init
  (defvar rm/denote-forms
    '("musing" "poetry" "idea" "paperidea" "wip" "lit" "log" "talk" "meeting"
      "hub" "presentation")
    "Note forms: the first filename keyword, exactly one per note.")
  (defvar rm/denote-matter
    '("physics" "hegel" "kant" "math" "aesthetics" "science" "concepts"
      "history" "neo-kantian" "phenomenology" "teaching" "fun")
    "Matter keywords: the research programs.  Grow this list only when a
new program is genuinely born; free-typing new matter still works.")
  (setq denote-directory (expand-file-name "~/Dropbox/notes/")
        denote-known-keywords rm/denote-matter
        ;; Keep hyphens in keywords (neo-kantian): keywords sluggify like
        ;; titles.  Caveat: org's tag-match syntax reads "-" as NOT, so
        ;; C-c a m can't match this one atom -- find it via C-c d c / g.
        denote-file-name-slug-functions
        '((title . denote-sluggify-title) (signature . denote-sluggify-signature)
          (keyword . denote-sluggify-title))
        denote-sort-keywords nil          ; NEVER alphabetize: form stays first
        denote-history-completion-in-prompts nil)  ; vertico noise otherwise
  ;; One named command per form (rm/denote-idea, rm/denote-musing, ...):
  ;; prompt for title, then matter -- completion offers ONLY the curated
  ;; matter list (forms and inferred strays excluded), but new matter can
  ;; still be typed through it.
  (defun rm/denote-new (form)
    "Create a denote note of FORM, prompting only for matter.
No title prompt: write first, name after.  An untitled note takes its
title from the first line on save (see rm/denote-autotitle); C-c d r
renames deliberately whenever."
    (require 'denote)                     ; M-x rm/denote-idea before any C-c d
    (let ((matter (let ((denote-known-keywords rm/denote-matter)
                        (denote-infer-keywords nil))
                    (denote-keywords-prompt "Matter (RET = none)"))))
      (denote nil (cons form matter))))
  (defun rm/denote-autotitle ()
    "First save of an untitled vault note: derive the title from line 1.
Only fires while the note is untitled, so a deliberate C-c d r (or a
hand-edited #+title) is never overridden.  The featurep guard: this
sits on the GLOBAL after-save-hook, and before denote loads it errored
void-function on every save of anything (fresh-daemon repro,
2026-07-24) -- untitled notes can only be born from commands that load
denote, so nothing is missed."
    (when (and (featurep 'denote)
               buffer-file-name
               (denote-file-is-note-p buffer-file-name)
               (string-empty-p (or (denote-retrieve-title-value
                                    buffer-file-name 'org) "")))
      (save-excursion
        (goto-char (point-min))
        (when (re-search-forward "^[^#: \n].*$" nil t)
          (let ((title (truncate-string-to-width
                        (string-trim (replace-regexp-in-string
                                      "[*/=~_]" "" (match-string 0)))
                        60)))
            (unless (string-blank-p title)
              (goto-char (point-min))
              (when (re-search-forward "^#\\+title:\\s-*$" nil t)
                (insert " " title)
                (let ((denote-rename-confirmations nil)
                      (denote-save-buffers t))
                  (denote-rename-file-using-front-matter buffer-file-name)))))))))
  (add-hook 'after-save-hook #'rm/denote-autotitle)
  (dolist (form rm/denote-forms)
    (defalias (intern (concat "rm/denote-" form))
      (lambda () (interactive) (rm/denote-new form))
      (format "Create a new %s note in the vault." form)))
  (defun rm/denote-attach (file)
    "Copy FILE into the vault's Files/ bin and link it at point (C-c d a).
Attachments stay plain files by design -- see README; promote one to a
denote name only if it becomes something you search for."
    (interactive "fAttach file: ")
    (let* ((dest-dir (expand-file-name "Files/" denote-directory))
           (dest (expand-file-name (file-name-nondirectory file) dest-dir)))
      (make-directory dest-dir t)
      (copy-file file dest 1)
      (insert (format "[[file:Files/%s]]" (file-name-nondirectory file)))
      (when (derived-mode-p 'org-mode) (org-display-inline-images))))
  (defun rm/denote-list ()
    "The picker over titles AND keywords: fragments match either (splash l).
Same catalog as f, but candidates carry their keywords (faded, after
the title), so `_hegel hub' narrows by form/matter too."
    (interactive)
    (require 'denote)
    (when-let ((f (rm/note-pick (nreverse (denote-directory-files))
                                "Note (title/keywords): "
                                #'rm/note--display-kw)))
      (find-file f)))
  (defun rm/denote-hubs ()
    "Dired listing of the hub notes (splash `h')."
    (interactive)
    (denote-sort-dired "_hub" nil nil nil))
  (defun rm/denote--form-prompt ()
    "Pick a form, listed alphabetically (metadata pins the order --
vertico would otherwise re-sort by history and length)."
    (let ((forms (sort (copy-sequence rm/denote-forms) #'string<)))
      (completing-read "Form: "
                       (lambda (str pred action)
                         (if (eq action 'metadata)
                             '(metadata (display-sort-function . identity)
                                        (cycle-sort-function . identity))
                           (complete-with-action action forms str pred)))
                       nil t)))
  (defun rm/denote-note ()
    "Frictionless capture: straight into an empty note, zero prompts.
Title arrives from the first line on save (rm/denote-autotitle); form
and matter are assigned in the note with C-c d c (rm/denote-classify)."
    (interactive)
    (require 'denote)
    (denote nil nil))
  (defun rm/denote-classify ()
    "Classify the thing at hand -- one gesture, context decides.
Vault note: form + matter, renames in place (identifier kept,
re-runnable).  Org heading elsewhere (capture buffer, inbox, any
TODO): the task tags via the fast-select menu.  Agenda view: tags for
the entry at point."
    (interactive)
    (cond
     ((derived-mode-p 'org-agenda-mode)
      (call-interactively #'org-agenda-set-tags))
     ;; require, not featurep: M-c on a raw-opened vault note in a fresh
     ;; session must still classify, not fall through to task tags
     ((and buffer-file-name
           (progn (require 'denote) (denote-file-is-note-p buffer-file-name)))
      (let ((form (rm/denote--form-prompt))
            (matter (let ((denote-known-keywords rm/denote-matter)
                          (denote-infer-keywords nil))
                      (denote-keywords-prompt "Matter (RET = none)")))
            (denote-rename-confirmations nil)
            (denote-save-buffers t))
        (denote-rename-file buffer-file-name 'keep-current
                            (cons form matter) 'keep-current 'keep-current
                            'keep-current)))
     ((and (derived-mode-p 'org-mode)
           (or buffer-file-name (buffer-base-buffer)) ; a file OR a capture
                                        ; buffer (indirect: file-name nil,
                                        ; base-buffer set) -- not the scratch
           (not (org-before-first-heading-p)))
      (org-set-tags-command))
     (t (user-error "Nothing here to classify"))))
  ;; --- The note picker: f (titles), l (titles+keywords), g (content) ----
  ;; Type-to-narrow completion, displayed BIG: vertico-multiform routes
  ;; these commands through vertico-buffer into the original window, not
  ;; the minibuffer's echo line, and each opens STRAIGHT into the full
  ;; catalog -- typing narrows from there.  Candidates are TITLES (no
  ;; ID, no date; untitled notes show their bare ID; l appends the
  ;; keywords, faded, so fragments match form/matter too).  M-j/M-k walk
  ;; candidates for free (vertico remaps next/previous-line, which is
  ;; what the vim-Meta keys call); the candidate previews in a window to
  ;; the right as the selection moves; M-d deletes it after
  ;; confirmation; RET opens; ESC aborts home.  g narrows by CONTENT:
  ;; every keystroke re-runs rg over the vault and the pass-through
  ;; rm-anything completion style stops vertico from also filtering the
  ;; titles against the typed words.
  (defvar rm/note-pick--alist nil)
  (defvar rm/note-pick--pwin nil)
  (defvar rm/note-pick--pfile nil)
  (defvar rm/note-pick--display-fn nil)
  (defvar rm/note-pick--content-mode nil)
  (defvar rm/note-pick--content-words 'unset)
  (defun rm/note--display (file)
    "FILE's picker name: the title slug, or the bare ID when untitled."
    (let ((base (file-name-sans-extension (file-name-nondirectory file))))
      (if (string-match
           "\\`[0-9]\\{8\\}T[0-9]\\{6\\}--\\(.*?\\)\\(?:__.*\\)?\\'" base)
          (match-string 1 base)
        base)))
  (defun rm/note--display-kw (file)
    "Like `rm/note--display', with the keywords faded after the title."
    (let ((base (file-name-sans-extension (file-name-nondirectory file))))
      (if (string-match
           "\\`[0-9]\\{8\\}T[0-9]\\{6\\}--\\(.*?\\)\\(?:__\\(.*\\)\\)?\\'" base)
          (let ((title (match-string 1 base))
                (kw (match-string 2 base)))
            (if kw
                (format "%s  %s" title
                        (propertize kw 'face 'nano-face-faded))
              title))
        base)))
  (defun rm/note-pick--set-files (files)
    "Fill the candidate alist from FILES, qualifying duplicate titles."
    (setq rm/note-pick--alist
          (mapcar (lambda (f) (cons (funcall rm/note-pick--display-fn f) f))
                  files))
    (let (seen)
      (dolist (cell rm/note-pick--alist)
        (if (member (car cell) seen)
            (setcar cell (format "%s · %s" (car cell)
                                 (file-name-nondirectory (cdr cell))))
          (push (car cell) seen)))))
  ;; pass-through completion style: the table's candidates ARE the answer
  ;; (g's rg already narrowed them); the typed words must not be matched
  ;; against the titles again
  (defun rm/style-anything-all (_str table pred _point)
    (all-completions "" table pred))
  (defun rm/style-anything-try (str _table _pred _point &optional _md) str)
  (add-to-list 'completion-styles-alist
               '(rm-anything rm/style-anything-try rm/style-anything-all
                             "Pass-through: table decides."))
  (defun rm/note-pick--content-update ()
    "g's live narrowing: re-run rg when the typed words change."
    (when rm/note-pick--content-mode
      (let ((words (split-string (minibuffer-contents-no-properties))))
        (unless (equal words rm/note-pick--content-words)
          (setq rm/note-pick--content-words words)
          (let ((files (nreverse (denote-directory-files))))
            (dolist (w words)
              (setq files (rm/denote--files-containing w files)))
            (rm/note-pick--set-files files))
          (when (and (minibufferp) (fboundp 'vertico--exhibit))
            (vertico--exhibit))))))
  (defun rm/note-pick--table (str pred action)
    (if (eq action 'metadata)
        '(metadata (display-sort-function . identity)
                   (cycle-sort-function . identity))
      (complete-with-action action (mapcar #'car rm/note-pick--alist)
                            str pred)))
  (defun rm/note-pick--preview ()
    (when-let* ((cand (and (bound-and-true-p vertico--input)
                           (vertico--candidate)))
                (f (cdr (assoc cand rm/note-pick--alist))))
      (unless (equal f rm/note-pick--pfile)
        (setq rm/note-pick--pfile f)
        (let ((buf (find-file-noselect f)))
          (if (window-live-p rm/note-pick--pwin)
              (set-window-buffer rm/note-pick--pwin buf)
            (setq rm/note-pick--pwin
                  (with-selected-window
                      (or (minibuffer-selected-window) (selected-window))
                    (display-buffer buf
                                    '(display-buffer-in-direction
                                      (direction . right))))))))))
  (defun rm/note-pick-delete ()
    "Delete the picker's current note, after confirmation (M-d)."
    (interactive)
    (when-let* ((cand (vertico--candidate))
                (f (cdr (assoc cand rm/note-pick--alist))))
      (when (let ((enable-recursive-minibuffers t))
              (y-or-n-p (format "Delete note %s? " cand)))
        (when-let ((b (find-buffer-visiting f)))
          (with-current-buffer b (set-buffer-modified-p nil))
          (kill-buffer b))
        (delete-file f delete-by-moving-to-trash)
        (setq rm/note-pick--alist
              (assoc-delete-all cand rm/note-pick--alist))
        (when (equal f rm/note-pick--pfile)
          (setq rm/note-pick--pfile nil))
        ;; nudge the input so vertico refilters against the shrunken table
        (insert "x") (delete-char -1)
        (minibuffer-message "Deleted"))))
  (defvar-keymap rm/note-pick-map "M-d" #'rm/note-pick-delete)
  (defun rm/note-pick (files prompt &optional display-fn content-mode)
    "Pick a note from FILES; return its path, nil on abort.
DISPLAY-FN renders a candidate (default: the title slug).  With
CONTENT-MODE, typing narrows by note CONTENT (live rg) instead of by
candidate text."
    (setq rm/note-pick--display-fn (or display-fn #'rm/note--display)
          rm/note-pick--content-mode content-mode
          rm/note-pick--content-words 'unset
          rm/note-pick--pfile nil)
    (rm/note-pick--set-files files)
    (unwind-protect
        (let ((choice
               (minibuffer-with-setup-hook
                   (lambda ()
                     (use-local-map (make-composed-keymap
                                     rm/note-pick-map (current-local-map)))
                     (when rm/note-pick--content-mode
                       (setq-local completion-styles '(rm-anything)))
                     (add-hook 'post-command-hook
                               #'rm/note-pick--content-update nil t)
                     (add-hook 'post-command-hook
                               #'rm/note-pick--preview nil t))
                 (completing-read prompt #'rm/note-pick--table nil t))))
          (cdr (assoc choice rm/note-pick--alist)))
      (when (window-live-p rm/note-pick--pwin)
        (delete-window rm/note-pick--pwin))
      (setq rm/note-pick--pwin nil)))
  (defun rm/denote-find ()
    "The vault, newest first: pick a note by title (splash f)."
    (interactive)
    (require 'denote)
    (when-let ((f (rm/note-pick (nreverse (denote-directory-files)) "Note: ")))
      (find-file f)))
  (defun rm/denote--files-containing (word files)
    "The members of FILES whose text contains WORD, in FILES' order
\(rg -l parallelizes and returns hits in arbitrary order)."
    (when files
      (let ((hits (with-temp-buffer
                    (apply #'call-process "rg" nil t nil
                           "-l" "-i" "--fixed-strings" word files)
                    (split-string (buffer-string) "\n" t))))
        (seq-filter (lambda (f) (member f hits)) files))))
  (defun rm/denote-grep ()
    "Straight into the catalog; typing narrows by CONTENT (splash g).
Every keystroke re-runs rg: the list shrinks to the notes containing
all the typed words."
    (interactive)
    (require 'denote)
    (when-let ((f (rm/note-pick (nreverse (denote-directory-files))
                                "Notes containing: " nil t)))
      (find-file f)))
  (defvar-keymap rm/denote-map
    :doc "Denote: create by form, jump, catalog, grep, backlinks, rename."
    "d" #'denote                          ; raw create: full keyword control
    "f" #'rm/denote-find                  ; the picker: titles, preview, M-d
    "l" #'rm/denote-list                  ; the picker, keywords matchable
    "c" #'rm/denote-classify              ; classify (alias; main key: M-c)
    "g" #'rm/denote-grep                  ; by content: words -> the picker
    "b" #'denote-backlinks                ; who links here?
    "r" #'denote-rename-file              ; promotion (idea->paperidea->wip)
    "k" #'denote-link                     ; insert a link to another note
    "m" #'rm/denote-musing  "o" #'rm/denote-poetry    "i" #'rm/denote-idea
    "p" #'rm/denote-paperidea  "w" #'rm/denote-wip     ; (lit: use C-c n --
    "s" #'rm/denote-log     "t" #'rm/denote-talk      ;  l is the list key)
    "e" #'rm/denote-meeting
    "h" #'rm/denote-hub     "n" #'rm/denote-presentation
    "a" #'rm/denote-attach)
  :config
  ;; Vault dired buffers fontify the filename grammar (ID / title / keywords
  ;; each get a face) -- the catalog reads like a catalog, not a file dump.
  (setq denote-dired-directories (list denote-directory))
  (add-hook 'dired-mode-hook #'denote-dired-mode-in-directories)
  ;; Buffer names show the note's TITLE, not the ID gibberish.
  (denote-rename-buffer-mode 1))

;; consult-denote: denote's own file prompts (C-c d f, C-c d k, ...) go
;; through consult, so picking a note gets live preview like M-ESC's buffer
;; switch.  The custom C-c d g already rides consult-ripgrep directly.
(use-package consult-denote
  :after denote
  :config (consult-denote-mode 1))

;; citar: completion over the Zotero-exported bibliographies -- browse
;; references, open their PDFs/URLs, and insert citation keys.  Citations in
;; papers stay RAW LaTeX (\textcite/\parencite); org-cite's syntax is
;; deliberately unused so compiled output never moves.  rm/cite is the
;; insertion path: pick refs, get \textcite{...} (C-u = \parencite).
(use-package citar
  :bind (("C-c b" . rm/cite))
  :init
  (setq citar-bibliography
        (list "~/scholarship/research-wip/documents/dissertation/references.bib"
              "~/scholarship/research-wip/documents/papers/friedman-kuhn-hegel-kant/Friedman and Kuhn, Hegel and Kant.bib"))
  (defun rm/cite (&optional arg)
    "Insert a citation via completion over the bibliographies.
Inside the braces of a hand-typed \\cite/\\textcite/\\parencite, insert
just the key(s); elsewhere insert a full \\textcite{...} (with C-u,
\\parencite{...})."
    (interactive "P")
    (require 'citar)
    (let ((keys (string-join (citar-select-refs) ",")))
      (if (looking-back
           "\\\\\\(?:text\\|paren\\|auto\\|foot\\)?cite\\(?:\\[[^]]*\\]\\)?{[^}]*"
           (line-beginning-position))
          (insert keys)
        (insert (format "\\%s{%s}" (if arg "parencite" "textcite") keys)))))
  ;; As-you-type key completion (corfu pops it up): a capf that fires only
  ;; inside a hand-typed \cite-family's braces.  Candidates come from
  ;; parsing the bibliographies directly (cached until a bib's mtime
  ;; changes) -- no citar internals, works before citar ever loads.
  (defvar rm/cite--keys-cache nil
    "(STAMP . KEYS) where STAMP is the bibs' (file . mtime) alist.")
  (defun rm/cite--keys ()
    "Citation keys from `citar-bibliography', re-parsed when a bib changes."
    (let* ((files (seq-filter #'file-readable-p
                              (mapcar #'expand-file-name citar-bibliography)))
           (stamp (mapcar (lambda (f)
                            (cons f (file-attribute-modification-time
                                     (file-attributes f))))
                          files)))
      (unless (equal stamp (car rm/cite--keys-cache))
        (let (keys)
          (dolist (f files)
            (with-temp-buffer
              (insert-file-contents f)
              (goto-char (point-min))
              (while (re-search-forward
                      "^@[[:alpha:]]+[({][ \t]*\\([^,\n]+\\)," nil t)
                (push (string-trim (match-string 1)) keys))))
          (setq rm/cite--keys-cache (cons stamp (nreverse keys)))))
      (cdr rm/cite--keys-cache)))
  (defun rm/cite-capf ()
    "Complete citation keys inside a raw \\cite/\\textcite/\\parencite."
    (when (looking-back
           "\\\\\\(?:text\\|paren\\|auto\\|foot\\)?cite\\(?:\\[[^]]*\\]\\)?{\\([^}]*\\)"
           (line-beginning-position))
      (let* ((content-start (match-beginning 1))
             (start (save-excursion
                      (if (search-backward "," content-start t)
                          (1+ (point))
                        content-start))))
        (list start (point) (rm/cite--keys) :exclusive 'no))))
  (defun rm/cite-capf-enable ()
    (add-hook 'completion-at-point-functions #'rm/cite-capf -10 t))
  (add-hook 'org-mode-hook #'rm/cite-capf-enable)
  (add-hook 'LaTeX-mode-hook #'rm/cite-capf-enable))

;; corfu: the in-buffer completion popup (vertico's sibling, same author).
;; Scoped to the writing modes -- its job here is citation keys via
;; rm/cite-capf; auto-on so \textcite{Fr... pops candidates unprompted.
;; C-c b stays the picker gesture (full minibuffer + vertico).
(use-package corfu
  :hook ((org-mode . corfu-mode)
         (LaTeX-mode . corfu-mode))
  :init
  (setq corfu-auto t
        corfu-auto-delay 0.15
        corfu-auto-prefix 2
        corfu-cycle t))

;; citar-denote: ties bibliography entries to vault notes -- the lit form IS
;; the reference-note keyword, so "open the note on this book" works from
;; the citar picker (and citar-denote-open-note the other way around).
(use-package citar-denote
  :after (citar denote)
  :init (setq citar-denote-keyword "lit")
  :config (citar-denote-mode 1))

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
         (LaTeX-mode    . mixed-pitch-mode))
  :init
  ;; mixed-pitch pins block/code/table faces to mono by FAMILY only, so
  ;; export blocks rendered at full mono height -- larger than the prose
  ;; around them (his report, 2026-07-23; mixed-pitch-set-height copies
  ;; an absolute full-size height, no better).  Layer the fixed-pitch
  ;; scale (0.75, tuned to sit level with ET Book) onto every pinned
  ;; face ourselves, on the same mode hook.
  (defvar-local rm/mixed-pitch-height-cookies nil)
  (defun rm/mixed-pitch-fix-height ()
    (if mixed-pitch-mode
        (dolist (face mixed-pitch-fixed-pitch-faces)
          (push (face-remap-add-relative
                 face :height
                 ;; inline LaTeX sits INSIDE a serif line: at the block
                 ;; scale (0.75) it read visibly smaller than the prose
                 ;; around it (his $\Omega^-$ report) -- give it more
                 (if (eq face 'org-latex-and-related) 0.9 0.75))
                rm/mixed-pitch-height-cookies))
      (mapc #'face-remap-remove-relative rm/mixed-pitch-height-cookies)
      (setq rm/mixed-pitch-height-cookies nil)))
  (add-hook 'mixed-pitch-mode-hook #'rm/mixed-pitch-fix-height))
  ;; (org-latex-and-related stays IN mixed-pitch's pinned list: LaTeX
  ;; spans render Roboto Mono at prose height, the block look -- his
  ;; 2026-07-23 (later) ruling, reversing the brief keep-the-prose-family
  ;; experiment from earlier the same day.)

(use-package olivetti
  :hook ((org-mode      . olivetti-mode)
         (markdown-mode . olivetti-mode)
         (LaTeX-mode    . olivetti-mode))
  :init (setq olivetti-body-width 72      ; text column width, in columns
              ;; center via FRINGES, not margins: org-margin owns the left
              ;; margin now (headline glyphs render there).  nano paints
              ;; fringes in the background colour -- looks identical.
              olivetti-style t)
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
                      :foreground "#4a6fa5")
  ;; LaTeX-in-prose: the face carries only the COLOUR (muted sienna,
  ;; reads as markup next to the blue italics); family and size arrive
  ;; via mixed-pitch's mono pin + the 0.75 layer -- Roboto Mono at prose
  ;; height, the export-block look.
  (when (facep 'org-latex-and-related)
    (set-face-attribute 'org-latex-and-related nil
                        :inherit 'unspecified :family 'unspecified
                        :foreground "#9c6644")))
(rm/apply-face-tweaks)
(with-eval-after-load 'org (rm/apply-face-tweaks))  ; the org face exists only once org loads

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
;;     hooks (mixed-pitch, flyspell, ...) do NOT fire -- the page
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

(defvar-local rm/welcome--origin nil
  "Non-nil in a buffer whose visit dismissed the splash.
C-a k (rm/kill-buffer) sends such a buffer back to the splash.")

(defun rm/welcome--dismiss-check (visitor)
  "Decide the splash's fate once VISITOR's file visit has displayed.
Splash no longer on any window: the visit replaced it -- kill the
buffer (ESC's floor recreates it on demand).  Splash still showing:
the visit landed elsewhere (a popup window, the agenda loading its
files) -- keep the splash where it is, unstamp VISITOR, re-arm the
one-shot hook."
  (when-let ((buf (get-buffer "*welcome*")))
    (if (get-buffer-window buf t)
        (progn
          (when (buffer-live-p visitor)
            (with-current-buffer visitor (setq rm/welcome--origin nil)))
          (add-hook 'find-file-hook #'rm/welcome--auto-dismiss))
      (kill-buffer buf))))

(defun rm/welcome--auto-dismiss ()
  "One-shot: dismiss the welcome screen when a file visit REPLACES it.
Runs on `find-file-hook', which fires before the new buffer is
displayed -- the decision is deferred a tick to
`rm/welcome--dismiss-check', which sees the settled window layout."
  (remove-hook 'find-file-hook #'rm/welcome--auto-dismiss)
  (when (get-buffer "*welcome*")
    (setq rm/welcome--origin t)                     ; provisional; check may undo
    (run-with-timer 0 nil #'rm/welcome--dismiss-check (current-buffer))))

(defun rm/welcome-commands ()
  "Show the Commands cheatsheet (welcome-commands.org) full-window, in place of
the splash; any key returns to the splash.  This is a clean buffer SWAP in the
same window -- so NOTHING resizes or moves (a side-window, a tall echo area, or
a posframe all disturb the splash / re-fit the logo).  A non-dismiss key then
runs its normal splash binding (so `c' then `t' still captures a task)."
  (interactive)
  (let* ((dir  (file-name-directory user-init-file))
         (file (expand-file-name "welcome-commands.org" dir))
         (buf  (get-buffer-create "*commands*"))
         (prev (current-buffer)))
    (with-current-buffer buf
      (let ((inhibit-read-only t)) (erase-buffer) (insert-file-contents file))
      (setq default-directory dir)
      (let ((org-mode-hook nil)) (org-mode))       ; monospace, no prose hooks
      (setq-local mode-line-format nil header-line-format nil cursor-type nil)
      (font-lock-add-keywords nil
                              '(("^Commands\\b" 0 'bold)
                                ("C = Ctrl.*$" 0 'italic)
                                ("any key to dismiss" 0 'italic)
                                ("\\[[^][()]*\\]" 0 'nano-face-salient prepend))
                              t)
      (font-lock-flush) (font-lock-ensure)
      (when (fboundp 'olivetti-mode)
        (setq-local olivetti-body-width 80)
        (olivetti-mode 1))
      (read-only-mode 1)
      (goto-char (point-min)))
    (switch-to-buffer buf)
    (unwind-protect
        (let ((ev (read-key)))
          (unless (memq ev '(?c ?q ?\e escape return ?\r))
            (push ev unread-command-events)))
      (when (buffer-live-p prev) (switch-to-buffer prev)))))

(defun rm/welcome (&optional force)
  "Show the welcome screen (welcome.org) unless a file was opened at launch.
Interactive calls and a non-nil FORCE always show it; the guard below is
a LAUNCH-time check (it only passes before any file is visited), there
so the startup hook stays quiet when a frame opens on a file."
  (interactive "p")
  (when (or force
            (called-interactively-p 'interactive)   ; M-x always previews it
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
          ;; Style with font-lock, NOT org emphasis (whose marker-hiding is
          ;; unreliable on a fresh daemon frame -- it showed raw *asterisks*):
          ;; section headers bold, the Vault filename hint italic, and
          ;; [bracketed keys] salient (the [^][()] class skips [[elisp:(...)]]).
          (font-lock-add-keywords nil
                                  '(("^\\(?:Tasks\\|find\\|Vault\\)\\b" 0 'bold)
                                    ("\\_<\\(?:form\\|matter\\)\\_>" 0 'bold)
                                    ("^ *GNU Emacs$" 0 'bold)
                                    ("^Vault  \\(file = .*\\)$" 1 'italic)
                                    ("\\[[^][()]*\\]" 0 'nano-face-salient prepend))
                                  t)
          (font-lock-flush) (font-lock-ensure)
          (setq-local mode-line-format nil         ; clean of nano's status bars
                      header-line-format nil
                      cursor-type nil)             ; no cursor
          ;; q / ESC dismiss; parenting org-mode-map keeps RET-on-links working.
          ;; Single-key accelerators for the frequent moves (splash-local
          ;; only -- the buffer is read-only, so letters are free):
          (let ((map (make-sparse-keymap)))
            (set-keymap-parent map org-mode-map)
            (define-key map (kbd "q")        #'rm/welcome-kill)

            (define-key map (kbd "n") #'rm/denote-note)         ; new note
            (define-key map (kbd "p") #'rm/papers-sidebar)      ; papers
            (define-key map (kbd "f") #'rm/denote-find)         ; the note picker
            (define-key map (kbd "g") #'rm/denote-grep)         ; grep bodies
            (define-key map (kbd "a") #'org-todo-list)          ; todos, all -- what
                                        ; he actually uses (agenda views: C-c a)
            (define-key map (kbd "t") #'rm/capture-task)        ; new todo, directly
                                        ; (no c/capture menu: t and n ARE capture)
            (define-key map (kbd "h") #'rm/denote-hubs)         ; hub catalog
            (define-key map (kbd "l") #'rm/denote-list)         ; list by words
            (define-key map (kbd "s") #'rm/scratch)             ; scratch
            (define-key map (kbd "c") #'rm/welcome-commands)    ; peek commands
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
            (setq-local olivetti-body-width 70)    ; 1 col slack over the 69-col block
            (olivetti-mode 1))
          ;; olivetti turns on visual-line-mode; in a narrowed window (sidebar
          ;; open) that word-wraps the aligned cheat-sheet by a hair.  Truncate
          ;; instead -- the columns stay sane at any window width.
          (visual-line-mode -1)
          (setq-local truncate-lines t))))))

(add-hook 'window-setup-hook #'rm/welcome)
;; Summon the splash on demand -- "go home" (interactive calls always show it).
;; C-c s: the *scratch* buffer, from anywhere (s on the splash too).
;; C-c SPC: straight home in the CURRENT window -- the teleport ESC's
;; step-by-step walk can't offer when the day's trail is long (his ask,
;; 2026-07-24).  Sibling of C-c w SPC, which is the same destination in
;; a NEW split.
(defun rm/scratch ()
  "Pop to the *scratch* buffer."
  (interactive)
  (switch-to-buffer (get-scratch-buffer-create)))
(keymap-global-set "C-c s" #'rm/scratch)
(defun rm/home ()
  "Jump straight to the splash in the selected window."
  (interactive)
  (rm/welcome t))
(keymap-global-set "C-c SPC" #'rm/home)
;; ESC, single press: universal "back out of where I am".
;; Prompts abort; a marked region deactivates; otherwise one literal
;; step back through the SELECTED WINDOW's own buffer history (every
;; stop kept, by his ruling), with the splash as the sticky floor.
;; Costs ESC-as-Meta in GUI frames -- his Meta is the real Alt key.
;; Terminal frames are untouched (<escape> is a GUI-only event there).
;; Unsaved edits are never at risk: this only changes what the window
;; displays; buffers and their modifications live on untouched.
(defun rm/escape ()
  "Back out: abort prompt / drop region / window-back / splash floor."
  (interactive)
  (cond
   ((minibufferp) (abort-minibuffers))
   ((minibuffer-window-active-p (minibuffer-window)) (abort-recursive-edit))
   ((region-active-p) (deactivate-mark))
   ((> (recursion-depth) 0) (abort-recursive-edit))
   ;; a capture in progress: ESC aborts it (org's C-c C-k) -- the
   ;; inserted template leaves the target with it, so an ESCed empty
   ;; todo never reaches inbox.org (C-c C-c finalizes, as before)
   ((bound-and-true-p org-capture-mode) (org-capture-kill))
   ;; an empty, untitled vault note: `n' writes the file at creation, so
   ;; backing out of one you never wrote in DELETES it -- the note
   ;; sibling of the capture rule above (empty notes were piling up as
   ;; undeletable ID-only files)
   ((and buffer-file-name
         (featurep 'denote)
         (denote-file-is-note-p buffer-file-name)
         (string-empty-p (or (denote-retrieve-title-value
                              buffer-file-name 'org) ""))
         (save-excursion
           (goto-char (point-min))
           (not (re-search-forward "^[^#: \n]" nil t))))
    (let ((f buffer-file-name)
          (born rm/welcome--origin))     ; splash-born? (its visit killed
      (set-buffer-modified-p nil)        ;  the splash, so the window's
      (kill-buffer)                      ;  fallback history is the whole
      (delete-file f)                    ;  day -- go home directly)
      (when born (rm/welcome t))
      (message "Empty note discarded")))
   ((eq (current-buffer) (get-buffer "*welcome*"))
    ;; the floor.  A duplicate splash in an extra window is a stale
    ;; popup: close it (ONE splash is the floor).  A sidebar beside the
    ;; real splash dismisses instead -- it made the splash "not the last
    ;; window", and deleting home stranded the frame on the file tree
    ;; (his repro, 2026-07-24).
    (cond
     ((not (rm/escape--last-real-window-p)) (delete-window))
     ((rm/escape--sidebar-visible-p) (dired-sidebar-hide-sidebar))))
   ;; a sidebar is a popup whatever its window history says (it re-roots
   ;; and follows files, so its history wanders): ESC dismisses it
   ((derived-mode-p 'dired-sidebar-mode) (dired-sidebar-hide-sidebar))
   (t (rm/escape--back))))
(defun rm/escape--interesting-p (buf)
  "Non-nil for stops HE made: files, dired, scratch, the agenda.
Internal popups (*Calendar*, preview outputs, helper buffers) that
machinery flashed through the window are not part of his trail."
  (let ((name (buffer-name buf)))
    (and name
         (not (string-prefix-p " " name))
         (or (not (string-prefix-p "*" name))
             ;; the splash is a real stop: launch a dired/note from it and
             ;; ESC walks back TO it (the floor rule then holds it there)
             (member name '("*scratch*" "*Org Agenda*" "*welcome*"))))))
(defun rm/escape--back ()
  "One meaningful step back in this window; the floor when the trail ends.
Walks with switch-to-prev-buffer (native bookkeeping: point restore,
skipped stops land on the forward list), hopping over uninteresting
buffers, capped so exhausted or cyclic histories hit the floor."
  (let ((tries 10) done)
    (while (and (not done) (> tries 0))
      (setq tries (1- tries))
      (if (seq-find (lambda (e) (and (buffer-live-p (car e))
                                     (not (eq (car e) (current-buffer)))))
                    (window-prev-buffers))
          (progn (switch-to-prev-buffer)
                 (setq done (rm/escape--interesting-p (current-buffer))))
        (rm/escape--floor) (setq done t)))
    (unless done (rm/escape--floor))))
(defun rm/escape--sidebar-visible-p ()
  "Non-nil when a dired-sidebar window is showing in this frame."
  (and (featurep 'dired-sidebar)
       (dired-sidebar-showing-sidebar-p)))
(defun rm/escape--last-real-window-p ()
  "Is the selected window the frame's only window, sidebars aside?
Sidebar windows don't count: they are chrome, and letting one make a
real window \"not the last\" got the real window DELETED at the floor,
stranding the frame on the file tree."
  (not (seq-some (lambda (w)
                   (and (not (eq w (selected-window)))
                        (with-current-buffer (window-buffer w)
                          (not (derived-mode-p 'dired-sidebar-mode)))))
                 (window-list))))
(defun rm/escape--floor ()
  "Trail exhausted: close a popup window, else floor on the splash.
A window with no meaningful history of its own was created FOR its
buffer (the agenda's split, a popped file) -- backing out of it means
closing it; the frame's last REAL window (sidebars aside) dismisses an
open sidebar first, then floors on the splash.  Forced: rm/welcome's
non-interactive guard is a launch-time check (no file buffers yet)
that is never true in a working session -- a plain call would no-op
and strand ESC."
  (cond
   ((not (rm/escape--last-real-window-p)) (delete-window))
   ((rm/escape--sidebar-visible-p) (dired-sidebar-hide-sidebar))
   (t (rm/welcome t))))
(keymap-global-set "<escape>" #'rm/escape)
;; C-a k: kill the buffer, but never strand the window on filler.  A
;; buffer whose visit dismissed the splash (rm/welcome--origin, stamped
;; by the auto-dismiss hook) returns TO the splash -- capture a note
;; from the splash, kill it, you're back where you started.  Likewise
;; when every real stop in the window's history is dead and Emacs would
;; cycle in an arbitrary frame-list buffer.  A replacement that WAS in
;; the window's live history is kept (killing mid-work still returns to
;; the previous file).
(defun rm/kill-buffer ()
  "Kill the current buffer; splash-born buffers return to the splash."
  (interactive)
  (let ((victim (current-buffer))
        (was-welcome (string= (buffer-name) "*welcome*"))
        (born-of-splash rm/welcome--origin)
        (history (delq (current-buffer)
                       (mapcar #'car (window-prev-buffers)))))
    (kill-current-buffer)
    (when (and (not (buffer-live-p victim))          ; user may abort the kill
               (not was-welcome)
               (or born-of-splash
                   (not (memq (current-buffer) history))))
      (rm/welcome t))))
;; ...and its opposite: M-ESC leaps forward to any buffer (previewing
;; list, most recent first -- the one-gesture return after an ESC).
(keymap-global-set "M-<escape>" #'consult-buffer)
;; M-c: classify the thing at hand (note -> form/matter, task -> tags).
;; Used constantly, so it earns home-row Meta; capitalize-word yields
;; (M-u / M-l cover the rare case).
(keymap-global-set "M-c" #'rm/denote-classify)
(with-eval-after-load 'isearch
  (keymap-set isearch-mode-map "<escape>" #'isearch-abort))

;; Super+F fullscreen shows the page, nothing else: nano's header-line
;; status bar hides while the frame fills its monitor, returns when it
;; shrinks back.  (Hyprland can't tell Emacs about WM fullscreen, so
;; detect it geometrically on size changes.  The opacity half lives in
;; hypr/windows.conf: fullscreen no longer snaps to opaque.)  nano sets
;; the DEFAULT header-line; buffers with their own local one (sidebar
;; root name, agenda) keep it.
(defvar rm/fullscreen--saved-chrome 'none)
(defun rm/fullscreen--p (frame)
  (let ((geo (frame-monitor-attribute 'geometry frame)))
    (and geo
         (>= (frame-pixel-width frame) (nth 2 geo))
         (>= (frame-pixel-height frame) (- (nth 3 geo) 2)))))
(defun rm/fullscreen-chrome (&optional frame)
  (let ((f (or (and (framep frame) frame) (selected-frame))))
    (when (display-graphic-p f)
      (if (rm/fullscreen--p f)
          (when (eq rm/fullscreen--saved-chrome 'none)
            (setq rm/fullscreen--saved-chrome
                  (cons (default-value 'header-line-format)
                        (default-value 'mode-line-format)))
            (setq-default header-line-format nil)
            ;; nano's default mode-line is "" -- an empty string still
            ;; DRAWS the thin bar; nil removes it (text stays intact)
            (setq-default mode-line-format nil))
        (unless (eq rm/fullscreen--saved-chrome 'none)
          (setq-default header-line-format (car rm/fullscreen--saved-chrome))
          (setq-default mode-line-format (cdr rm/fullscreen--saved-chrome))
          (setq rm/fullscreen--saved-chrome 'none))))))
(add-hook 'window-size-change-functions #'rm/fullscreen-chrome)

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
      (progn
        (funcall-interactively #'rm/welcome)
        ;; On a freshly-started daemon the emphasis-marker hiding can miss on
        ;; this first frame (font-lock runs before the frame fully settles),
        ;; leaving raw *asterisks*.  Re-fontify once idle to fix it.
        (run-with-idle-timer
         0.2 nil
         (lambda ()
           (when-let ((b (get-buffer "*welcome*")))
             (with-current-buffer b
               (font-lock-flush)
               (font-lock-ensure))))))))
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
;; directories sort before files at every level.  C-c p roots at
;; research-wip (papers/dissertation/CV under documents/); the vault
;; sidebar is M-x rm/notes-sidebar (C-c n is note capture now); <f8>
;; toggles a sidebar at the current project.
;; Directories before files, at every level -- dired-subtree's expansions
;; read with the same switches, so the whole tree groups consistently.
;; Global on purpose: plain dired benefits too.
(setq dired-listing-switches "-al --group-directories-first")

;; Every dired hides build exhaust (his ask, 2026-07-23): the generated
;; .tex artifacts (org is the authoring surface; hand-written preamble/
;; config .tex stay listed) and latexmk leftovers the stock extension
;; list predates (.bcf, .fdb_latexmk, ...).  Dotfiles and README stay
;; visible in plain dired; the sidebar's stricter buffer-local regexp
;; hides those too.  M-x dired-omit-mode toggles when you need the truth.
(with-eval-after-load 'dired-x
  (setq dired-omit-files
        (concat dired-omit-files
                "\\|\\`\\(?:body\\|paper\\|dissertation\\|maung_cv"
                "\\|introduction\\|dedication\\|acknowledgements"
                "\\|summary\\|vita\\)\\.tex\\'"
                "\\|\\`ltximg\\'"))       ; org latex-preview image cache dirs
  (setq dired-omit-extensions
        (append dired-omit-extensions
                ;; .bib too (his ask, 2026-07-25): bibs are Zotero
                ;; auto-exports, never hand-edited -- friedman's local
                ;; bib and the dissertation master both
                '(".bcf" ".bib" ".fdb_latexmk" ".fls" ".log" ".out"
                  ".run.xml" ".synctex.gz" ".xdv"))))
(add-hook 'dired-mode-hook #'dired-omit-mode)

;; Deletions go to the system trash (freedesktop ~/.local/share/Trash),
;; not oblivion -- dired's recursive `y' was a literal rm -rf until it
;; ate a notes/ folder (2026-07-24; git happened to have it).  Undo a
;; deletion by pulling the files back out of the trash.  The ESC
;; empty-note discard stays a real delete on purpose: those files are
;; guaranteed contentless.
(setq delete-by-moving-to-trash t)

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
  :bind (("C-c p" . rm/papers-sidebar)   ; notes browsing lives in C-c d now;
                                         ; vault sidebar: M-x rm/notes-sidebar or <f8>
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
  ;; Follow means "the FILE you're editing": stock follow re-roots for ANY
  ;; buffer via its default-directory, and UI buffers carry one too -- the
  ;; splash's is dotfiles/emacs (logo path), so going home re-rooted the
  ;; tree to the config dir (his repro, 2026-07-25).  No file, no follow;
  ;; dired/magit keep their own root logic.
  (defun rm/sidebar-follow-only-files (orig &rest args)
    (when (or buffer-file-name
              (derived-mode-p 'dired-mode 'magit-mode))
      (apply orig args)))
  (advice-add 'dired-sidebar-follow-file :around #'rm/sidebar-follow-only-files)
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
  ;; Hide clutter -- the sidebar goes further than the dired-wide omit
  ;; (see the dired section above): its buffer-local regexp also drops
  ;; dotfiles (.git, .gitignore, the . / .. self/parent entries),
  ;; README.md / TODO.md, and AUCTeX auto/, on top of the generated .tex
  ;; and artifact extensions everyone omits.  Subtree expansions are out
  ;; of dired-omit's reach -- rm/sidebar-omit-subtree (above) covers them.
  (setq dired-omit-verbose nil)
  (add-hook 'dired-sidebar-mode-hook
            (lambda ()
              (setq-local line-spacing 3   ; airier rows
                          dired-omit-files
                          (concat
                           "\\`\\.\\|\\`README\\.md\\'\\|\\`TODO\\.md\\'"
                           "\\|\\`auto\\'\\|\\`ltximg\\'"
                           "\\|\\`\\(?:body\\|paper\\|dissertation\\|maung_cv"
                           "\\|introduction\\|dedication\\|acknowledgements"
                           "\\|summary\\|vita\\)\\.tex\\'")
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
  (defun rm/sidebar--reveal (file)
    "Expand the tree down to FILE and land point on its line.
An op targeting a COLLAPSED folder succeeds on disk but changes
nothing on screen (\"yank not working?\", 2026-07-24 -- the pasted
notes/ sat invisibly inside an unexpanded folder), so create/paste/
rename all end here.  Walks top-down from the sidebar root, expanding
each collapsed ancestor so the next component's line exists; stops
silently if a component is omitted from the listing."
    (let* ((root (expand-file-name default-directory))
           (rel (file-relative-name (expand-file-name file) root)))
      (unless (string-prefix-p ".." rel)
        (let ((dir root) (parts (split-string rel "/" t)))
          (while (cdr parts)
            (setq dir (expand-file-name (car parts) dir))
            (when (dired-utils-goto-line dir)
              (unless (dired-subtree--is-expanded-p)
                (dired-subtree-insert)))
            (setq parts (cdr parts)))
          (dired-utils-goto-line (expand-file-name (car parts) dir))))))
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
        (dired-sidebar-refresh-buffer)
        (rm/sidebar--reveal target))))
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
          (dired-sidebar-refresh-buffer)
          (rm/sidebar--reveal target)))))
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
      (dired-sidebar-refresh-buffer)
      (rm/sidebar--reveal target)))
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
;;   * a theme that follows Omarchy -- Emacs won't auto-track it; its own project
;; (citar and pdf-tools graduated from this list on 2026-07-23.)

;; --- C-x -> beginning-of-line (the other half of the C-a swap) -----------
;; Deliberately LAST: every "C-x ..." definition above (C-x k, magit's C-x g,
;; ...) must already be inside ctl-x-map before the C-x key itself stops
;; being a prefix -- define-key errors if asked to extend through a
;; non-prefix key.  ctl-x-map itself is untouched; C-a reaches all of it.
(keymap-global-set "C-x" #'move-beginning-of-line)

;;; init.el ends here
