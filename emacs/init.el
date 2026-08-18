;;; init.el --- Emacs configuration  -*- lexical-binding: t; -*-
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
  ;; Force auto-save #files# and backup file~ files out of the (synced)
  ;; working tree into var/, so they don't sync as phantom "duplicates".  (Lock
  ;; files .#foo are disabled via `create-lockfiles' above.)  no-littering is
  ;; supposed to set both, but in practice it wasn't winning, so pin them here.
  (setq auto-save-file-name-transforms
        `((".*" ,(no-littering-expand-var-file-name "auto-save/") t))
        backup-directory-alist
        `((".*" . ,(no-littering-expand-var-file-name "backup/")))))

;; --- Platform ------------------------------------------------------------
;; The phone runs this same file.  It loads from a small stub that lives in
;; the Android Emacs home (see the dotfiles-android repo), and the stub binds
;; the content locations below before loading this file.  So there is one
;; config, not two, and a change here reaches the phone on its next launch.
;;
;; Emacs's own sources test for Android both ways, so test for both.  A wrong
;; test here fails silently: the guarded sections would load on the phone and
;; break it, or skip on the laptop and break that.

(defconst rm/android-p (or (featurep 'android)
                           (eq system-type 'android))
  "Non-nil when this Emacs is the Android port.
Guards the sections that need a desktop: a TeX toolchain and a
compiled PDF renderer.  Guard with `unless', not use-package's :if --
:ensure (always on here) installs the package even when :if is nil.")

;; --- Content locations ---------------------------------------------------
;; Every reference to the vault and the agenda home goes through these two
;; variables.  Nothing below hardcodes a path, so one machine can put the
;; trees somewhere else without touching the rest of this file.
;;
;; They are `defvar', not `setq', on purpose.  The Android port loads this
;; file from a small stub that binds both first, and `defvar' leaves an
;; already-bound value alone.  That is what lets the phone and the laptop
;; share one config.

(defvar rm/notes-directory (expand-file-name "~/Dropbox/notes/")
  "Directory of the denote thought vault.")

(defvar rm/org-directory (expand-file-name "~/Dropbox/org/")
  "Directory of the agenda and capture files.  Synced, but NOT the vault.")

(defun rm/org-file (name)
  "Return the absolute path of NAME inside `rm/org-directory'."
  (expand-file-name name rm/org-directory))

;; --- Sensible built-in defaults -----------------------------------------
;; No packages here -- this is Emacs teaching you what Emacs is.

(setq inhibit-startup-screen t
      initial-scratch-message nil
      ring-bell-function #'ignore         ; no beep
      use-short-answers t                 ; y/n instead of yes/no
      sentence-end-double-space nil)      ; prose: single space ends a sentence

;; The notes vault is file-synced, so Emacs lock files (.#file) sync as
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
        read-expression-history
        rm/bookmarks)                    ; the 9 splash bookmark slots
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
;; ~/.local/share/fonts.  Prose runs Atkinson Hyperlegible Next (the family
;; Emacs wants is the human name "Atkinson Hyperlegible Next", verify with
;; `fc-list | grep -i atkinson').  Setting it as the proportional family routes
;; it through `variable-pitch', which mixed-pitch swaps in for prose while
;; code/tables stay Roboto Mono.  (Was ETBembo/ET Book through 2026-07-31.)
(setq nano-font-family-monospaced "Roboto Mono"
      nano-font-family-proportional "Atkinson Hyperlegible Next"
      nano-font-size 12)              ; whole-UI size knob; bump/drop by 1 to taste

;; Atkinson Hyperlegible Next ships no U+0060 (grave/backtick) glyph, so LaTeX
;; opening quotes (``) show up as tofu rectangles.  set-fontset-font CANNOT fix
;; this -- Emacs refuses to set a font for a single ASCII codepoint ("Can't set
;; a font for partial ASCII range").  Instead remap the backtick's DISPLAY to a
;; glyph drawn in a Roboto Mono face (Roboto Mono has the glyph; Atkinson Mono
;; lacks it too).  Code buffers already run Roboto Mono, so this is a no-op
;; there; only prose (variable-pitch Atkinson) changes.  The real curly quotes
;; U+2018..U+201D ARE present in Atkinson, so smart-quote display is unaffected.
(defface rm/backtick-face '((t :inherit default :family "Roboto Mono"))
  "Draw the backtick, which Atkinson Hyperlegible Next has no glyph for.")
(unless standard-display-table
  (setq standard-display-table (make-display-table)))
(aset standard-display-table ?`
      (vector (make-glyph-code ?` 'rm/backtick-face)))

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
  (dolist (dir (list "~/scholarship/research-wip/" rm/notes-directory))
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
         (markdown-mode . hl-todo-mode)
         (org-mode      . hl-todo-mode)))   ; papers are org-authored now

;; --- Git (:tools magit) -------------------------------------------------

(use-package magit
  :defer t
  ;; Into ctl-x-map DIRECTLY (typed C-a g): a "C-x g" sequence bind works
  ;; at first boot but errors on every rm/reload-init once end-of-init
  ;; makes plain C-x a non-prefix (same class as the old C-x k bug).
  :bind (:map ctl-x-map ("g" . magit-status)))

;; --- Project-wide comment TODOs (magit-todos) --------------------------
;; Collect every hl-todo keyword (TODO/FIXME/NOTE/HACK) from `# TODO:' comments
;; across a repo into a TODOs section at the top of `magit-status'.  For
;; research-wip this is the "all my paper TODOs in one place" list: inline
;; comment notes -- which never reach the PDF -- surface here automatically,
;; with no org headline and no agenda entry.  `C-a g' in the repo shows the
;; section; RET on an item jumps to its source line.  Plain `# TODO: ...' is
;; enough; the keyword is what magit-todos scans for (the `***' is not needed).
(use-package magit-todos
  :after magit
  :config (magit-todos-mode 1))

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

;; C-c P: the `publish' shell function, from inside -- DEPLOY, not save.
;; Deliberately a separate key from C-c g: committing sources (private)
;; and publishing output (public) are different intents, and the capital
;; makes it a considered keystroke.  The target is derived from the
;; buffer: a website file publishes the site, cv.org the CV, a paper its
;; slug, the dissertation itself.  Runs the real shell function (bash,
;; rc-additions sourced) so Emacs and terminal deploys can never differ.
(defun rm/publish ()
  "Publish the document this buffer belongs to (shell `publish'), async."
  (interactive)
  (let* ((f (or buffer-file-name
                (user-error "This buffer is not visiting a file")))
         (target
          (cond
           ((string-match-p "/scholarship/website/" f) "site")
           ((string-match-p "/documents/cv/" f) "cv")
           ((string-match-p "/documents/dissertation/" f) "dissertation")
           ((string-match "/documents/papers/\\([^/]+\\)/" f)
            (match-string 1 f))
           (t (user-error "Nothing publishable here: %s" f)))))
    (when (buffer-modified-p) (save-buffer))
    (with-current-buffer (get-buffer-create "*rm-publish*")
      (erase-buffer))
    (message "Publishing %s…" target)
    (make-process
     :name "rm-publish" :buffer "*rm-publish*"
     :command
     (list "bash" "-c"
           (format "source ~/code/dotfiles/shell/rc-additions.sh >/dev/null 2>&1; publish %s"
                   (shell-quote-argument target)))
     :sentinel
     (let ((target target))
       (lambda (p _e)
         (when (memq (process-status p) '(exit signal))
           (if (zerop (process-exit-status p))
               (message "Published %s ✓" target)
             (message "publish %s failed — log in *rm-publish* (M-ESC reaches it)"
                      target))))))))
(keymap-global-set "C-c P" #'rm/publish)

;; --- LaTeX (:lang latex +cdlatex) ---------------------------------------
;; AUCTeX + CDLaTeX, wired to latexmk and zathura so it matches your
;; existing nvim/latexmk/zathura flow.

;; AUCTeX 14 defines `LaTeX-mode' / `LaTeX-mode-map' in the `latex' feature (not
;; `tex'), so we `use-package latex' -- still installing the `auctex' package.
;; Using `tex' here left `LaTeX-mode-map' void when the mode loaded, which errored
;; and silently dropped every .tex to Fundamental mode (no font-lock, no hooks).
;; The whole toolchain is wrapped in `unless' rather than guarded with
;; use-package's :if -- :ensure (forced globally by
;; `use-package-always-ensure') installs the package even when :if is
;; nil, so the phone would download AUCTeX for nothing.  `unless' gates
;; the install too.
(unless rm/android-p                     ; no TeX toolchain on the phone
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
          ;; Shared dissertation bibliography (the one-master-bib convention).
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
    :defer t))

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
;; `unless', not :if, for the same reason as the LaTeX block above:
;; epdfinfo is a C helper compiled in the package dir, so on Android the
;; package must not even be INSTALLED, and :ensure ignores :if.
(unless rm/android-p
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
    (keymap-set pdf-view-mode-map "l" #'image-forward-hscroll)))

;; --- Org: notes + TODO/agenda (:lang org, built into Emacs) -------------
;; Papers stay in LaTeX.  Org is for tasks/agenda and prose notes (the
;; folder-of-outlines style, not zettelkasten).  Everything here is
;; built in -- no packages, no org-roam.

(use-package org
  :ensure nil                             ; org ships with Emacs
  :bind (("C-c a" . org-agenda)           ; the calendar/todo dispatcher
         ;; (C-c c UNBOUND 2026-07-23: t/n on the splash are capture --
         ;;  rm/capture-task still calls org-capture programmatically)
         ;; C-c L since 2026-08-16: C-c l is the llm.el prefix (below)
         ("C-c L" . org-store-link)
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
  (setq org-directory rm/org-directory    ; agenda + capture home (synced, NOT the vault)
        ;; Agenda scans the dedicated org dir *and* the research documents
        ;; tree, so a TODO jotted in the inbox -- or mid-paper in a paper.org
        ;; -- surfaces.  The notes vault is deliberately NOT scanned: it held
        ;; 421 files with zero TODOs and cost ~11s to visit on the first `a'
        ;; of a session (vs ~0.4s without it); thought-notes aren't task
        ;; lists.  Recursive (the trees are nested) and filtered to skip
        ;; Emacs lock/temp files.  New files need a restart (or re-eval) to
        ;; join the agenda; the org dir itself rescans live.
        org-agenda-files
        (cons rm/org-directory
              (when (file-directory-p "~/scholarship/research-wip/documents/")
                (seq-remove (lambda (f) (string-prefix-p "." (file-name-nondirectory f)))
                            (directory-files-recursively
                             (expand-file-name "~/scholarship/research-wip/documents/")
                             "\\.org\\'"))))
        ;; The agenda REPLACES the buffer in the window you called it from --
        ;; from the splash that is the point of it (2026-08-18, reversing the
        ;; earlier 'other-window rule): `a' turns home into the task list
        ;; rather than splitting the frame in two.  ESC walks back, so the
        ;; buffer underneath is one key away.  ('reorganize-frame, the org
        ;; default, would DELETE the other windows instead.)
        org-agenda-window-setup 'current-window
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
        '((sequence "TODO" "NEXT" "CONTINUING" "|" "DONE"))
        ;; Keyword highlight by progress (org buffers AND the agenda).  TODO is
        ;; purple; NEXT the Emacs-logo red; CONTINUING the logo blue
        ;; (welcome-logo.svg); DONE green.
        org-todo-keyword-faces
        '(("TODO"       . "#8b5fbf")
          ("NEXT"       . "#c64e3b")
          ("CONTINUING" . "#2076c1")
          ("DONE"       . "#3a9e57")))
  :config
  ;; `agenda' = todos as an indented project TREE (rm/agenda-projects drives it,
  ;; splash `a').  A custom block, not a bare let over org-todo-list, so the
  ;; grouping and sort re-apply on every redo -- a/y/p rebuild the list and must
  ;; keep it.  :auto-map groups by the top-level `*' ancestor, so a todo and its
  ;; sub-todos share one project section (projects come out alphabetical).  The
  ;; user-defined sort (rm/agenda--cmp-tree) walks each section as a tree --
  ;; parent before its children, siblings A-Z -- and rm/agenda-indent (in
  ;; org-agenda-prefix-format) steps each level in, so children nest under their
  ;; parent.
  (setq org-agenda-cmp-user-defined #'rm/agenda--cmp-tree
        org-agenda-custom-commands
        '(("agenda" "Todos, by project"
           todo ""
           ((org-super-agenda-groups '((:auto-map rm/agenda--item-project)))
            (org-agenda-sorting-strategy '((todo user-defined-up)))
            ;; Suppress org-todo-list's "Global list of TODO items of type:
            ;; ALL / Press N..." banner; "" makes the overriding-header macro
            ;; insert nothing (the project group headers are label enough).
            (org-agenda-overriding-header "")))))
  (setq org-capture-templates
        `(("t" "Task" entry (file+headline ,(rm/org-file "inbox.org") "miscellany")
           "* TODO %?\n  %U\n" :empty-lines 1)
          ("n" "Note" entry (file+headline ,(rm/org-file "inbox.org") "Notes")
           "* %?\n  %U\n" :empty-lines 1)))
  ;; Headings render via the org-level faces once font-lock runs; bump their
  ;; size so they stand out more than the body.  Tune the :heights.
  (set-face-attribute 'org-level-1 nil :height 1.3)
  (set-face-attribute 'org-level-2 nil :height 1.15)
  (set-face-attribute 'org-level-3 nil :height 1.05)
  ;; Inline LaTeX preview: crisp SVG output.  Since the preview key was
  ;; neutered (below), the only consumer is llm.el, which renders math in
  ;; session files; the scale is judged against the prose font there
  ;; (1.5 read too large, 2026-08-16 -- dvisvgm adds its own 1.7 factor).
  (setq org-preview-latex-default-process 'dvisvgm)
  (setq org-format-latex-options (plist-put org-format-latex-options :scale 1.0))
  ;; The rendered SVGs are a per-machine cache keyed by fragment hash, not
  ;; a record: keep them out of the synced notes vault (llm.el renders
  ;; math in every session file, 2026-08-16).
  (setq org-preview-latex-image-directory
        (expand-file-name "org-ltximg/" (or (getenv "XDG_CACHE_HOME") "~/.cache/")))
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
  ;; C-c c; the view-switch prefix (log mode, day/week view, ...) moves off
  ;; `v' to `V' -- V l log mode, V d day view -- because plain v is now
  ;; visual selection (below).
  ;;
  ;; e opens the entry at point as a capture-like view -- an indirect buffer
  ;; NARROWED to just this subtree (heading on top, body below for notes),
  ;; not the whole file with every other todo.  It REUSES the agenda's own
  ;; window (the agenda buffer slides into that window's history), which is
  ;; tagged 'rm-excursion (see rm/escape, rm/agenda-mark-excursion).  So ESC
  ;; on an edit view restores the agenda in place; ESC on the agenda closes
  ;; the window back to wherever `a' launched.  `e' again just opens the next
  ;; entry the same way -- ESC still walks edit -> agenda -> closed.
  ;; (Displaces the unused org-agenda-set-effort on `e'.)  Yazi-style bulk
  ;; select: SPC toggles the mark on the current line, v starts a native
  ;; visual region that j/k extend, v again marks every entry inside it.
  ;; Marked entries then take a bulk action via B (B + tag to group, B s
  ;; schedule, B r refile, ...); u / U unmark.  Yazi-style create/move:
  ;; a adds a todo (name ending `/' adds a project instead), y grabs an
  ;; entry, p moves it under a project -- see rm/agenda-new and friends.
  (defvar-local rm/edit-origin nil
    "The agenda buffer an `e' edit clone restores on ESC (see `rm/escape').")
  (defun rm/agenda-edit-entry ()
    "Open the agenda entry at point as a capture-like, narrowed edit view.
Reuses the agenda's own window: an indirect buffer narrowed to the entry's
subtree replaces the agenda (heading on top, body below).  ESC restores the
agenda in this window; ESC again closes it (see `rm/escape')."
    (interactive)
    (let* ((marker (or (org-get-at-bol 'org-hd-marker)
                       (org-get-at-bol 'org-marker)
                       (user-error "No agenda entry on this line")))
           (base (marker-buffer marker))
           (name (org-with-point-at marker (org-get-heading t t t t)))
           (agenda (current-buffer))
           (edit (make-indirect-buffer
                  base
                  (generate-new-buffer-name (format "*edit: %s*" (or name "todo")))
                  t)))                          ; clone => inherits org-mode
      (with-current-buffer edit
        (goto-char marker)
        (org-narrow-to-subtree)
        (goto-char (point-min))
        (setq-local rm/edit-origin agenda))
      (switch-to-buffer edit)))                 ; reuse the agenda's window
  (defun rm/agenda-visual-toggle ()
    "Yazi-style visual select in the agenda.
First press anchors a region; j/k extend it; a second press marks every
entry inside it for a bulk action (see `org-agenda-bulk-action', on B)."
    (interactive)
    (if (region-active-p)
        (progn (org-agenda-bulk-mark)     ; marks every entry in the region
               (deactivate-mark)
               (message "range marked — B for bulk action, u to unmark"))
      (set-mark (point))
      (activate-mark)
      (message "visual: move j/k, v to mark the range")))
  ;; Yazi-style create and move, straight from the agenda.  Projects are
  ;; top-level `*' inbox headings (containers, no TODO keyword); todos are
  ;; their `** TODO' children -- the shape rm/agenda-projects groups on.  a
  ;; makes a todo (a trailing `/' makes a project instead, like yazi mkdir);
  ;; y grabs an entry and p moves it under a project.  All creation lands in
  ;; inbox.org; a move refiles the real subtree (heading + notes), then the
  ;; agenda rebuilds so the change shows.  A just-made, still-empty project
  ;; shows as its own header (rm/agenda-empty-projects) that a/p target
  ;; positionally -- navigate onto it and p drops the yanked todo straight
  ;; in, no prompt (the prompt is only the fallback when point names no
  ;; project).
  (defvar rm/agenda-yank nil
    "Marker on the subtree `y' grabbed, for `p' to move (see agenda keymap).")
  (defun rm/inbox--file ()
    (rm/org-file "inbox.org"))
  (defun rm/inbox--buffer ()
    (find-file-noselect (rm/inbox--file)))
  (defun rm/inbox--project-headings ()
    "Alist of (NAME . MARKER) for every top-level `*' heading but Notes."
    (with-current-buffer (rm/inbox--buffer)
      (org-with-wide-buffer
       (goto-char (point-min))
       (let (acc)
         (while (re-search-forward "^\\* \\(.+\\)$" nil t)
           (let ((name (string-trim (match-string-no-properties 1))))
             (unless (string= name "Notes")
               (push (cons name (copy-marker (line-beginning-position))) acc))))
         (nreverse acc)))))
  (defun rm/inbox--project-at (marker)
    "Marker on the inbox top-level ancestor of MARKER, or nil if not in inbox."
    (when (and marker (marker-buffer marker)
               (buffer-file-name (marker-buffer marker))
               (file-equal-p (buffer-file-name (marker-buffer marker))
                             (rm/inbox--file)))
      (org-with-point-at marker
        (org-back-to-heading t)
        (while (and (org-current-level) (> (org-current-level) 1))
          (org-up-heading-safe))
        (copy-marker (line-beginning-position)))))
  (defun rm/inbox--add-project (name)
    "Add a top-level `* NAME' project to the inbox; return its marker.
Placed before the Notes section (or at end of file)."
    (with-current-buffer (rm/inbox--buffer)
      (org-with-wide-buffer
       (goto-char (point-min))
       (if (re-search-forward "^\\* Notes\\b" nil t)
           (goto-char (match-beginning 0))
         (goto-char (point-max)))
       (unless (bolp) (insert "\n"))
       (let ((pos (point)))
         (insert "* " name "\n")
         (save-buffer)
         (copy-marker pos)))))
  (defun rm/inbox--add-todo (project-marker title)
    "Insert `** TODO TITLE' among PROJECT-MARKER's direct children, keeping them
alphabetical by heading text (case-insensitive); appends when TITLE sorts last.
Used for a project's todos and, on a todo, its sub-todos -- so every level stays
in the A-Z order the agenda tree already displays."
    (with-current-buffer (marker-buffer project-marker)
      (org-with-wide-buffer
       (goto-char project-marker)
       (org-back-to-heading t)
       (let* ((clevel (1+ (org-current-level)))            ; direct-child level
              (stars (make-string clevel ?*))
              (key (downcase title))
              (end (save-excursion (org-end-of-subtree t t) (point)))  ; next heading/eob
              (insert-at nil))
         ;; first direct child whose title sorts after TITLE -> insert before it
         (save-excursion
           (while (and (not insert-at)
                       (outline-next-heading)
                       (< (point) end))
             (when (and (= (org-current-level) clevel)
                        (string-lessp key (downcase (org-get-heading t t t t))))
               (setq insert-at (line-beginning-position)))))
         (goto-char (or insert-at end))
         (unless (bolp) (insert "\n"))
         (insert stars " TODO " title "\n")
         (save-buffer)))))
  (defun rm/inbox--read-project (&optional default-marker)
    "Pick an inbox project by name (completion), creating it if the name is new.
Returns a marker on the chosen `*' heading; DEFAULT-MARKER seeds the default."
    (let* ((alist (rm/inbox--project-headings))
           (default (and default-marker (marker-buffer default-marker)
                         (org-with-point-at default-marker
                           (org-get-heading t t t t))))
           (name (string-trim
                  (completing-read
                   (format "Project%s: " (if default (format " (%s)" default) ""))
                   (mapcar #'car alist) nil nil nil nil default)))
           (hit (assoc name alist)))
      (cond ((string-empty-p name) (user-error "No project chosen"))
            (hit (cdr hit))
            (t (rm/inbox--add-project name)))))
  (defun rm/inbox--projects-status ()
    "List of (NAME MARKER HAS-TODO) for each top-level inbox project but Notes.
HAS-TODO is non-nil when the project's subtree holds an open todo (TODO,
NEXT or CONTINUING) -- i.e. something the project agenda would already show."
    (with-current-buffer (rm/inbox--buffer)
      (org-with-wide-buffer
       (goto-char (point-min))
       (let (out)
         (while (re-search-forward "^\\* \\(.+\\)$" nil t)
           (let ((name (string-trim (match-string-no-properties 1)))
                 (beg (line-beginning-position)))
             (unless (string= name "Notes")
               (let ((end (save-excursion (goto-char beg)
                                          (org-end-of-subtree t t) (point))))
                 (push (list name (copy-marker beg)
                             (save-excursion
                               (goto-char beg) (forward-line 1)
                               (and (re-search-forward
                                     "^\\*\\{2,\\} \\(?:TODO\\|NEXT\\|CONTINUING\\) "
                                     end t)
                                    t)))
                       out)))))
         (nreverse out)))))
  (defun rm/agenda--project-at-point ()
    "Project marker for the agenda line at point, or nil.
Resolves three line kinds: an empty-project header by its marker property,
any project section header (ours or org-super-agenda's) by its visible name,
and an entry line by its inbox project ancestor.  The name match is what lets
a/p act on a header line without a prompt -- the property alone did not
survive org-agenda's finalize."
    (or (get-text-property (line-beginning-position) 'rm-project-marker)
        (cdr (assoc (string-trim (buffer-substring-no-properties
                                  (line-beginning-position) (line-end-position)))
                    (rm/inbox--project-headings)))
        (rm/inbox--project-at (or (org-get-at-bol 'org-hd-marker)
                                  (org-get-at-bol 'org-marker)))))
  ;; --- Project TREE view (the `agenda' block): group by project, order as an
  ;; outline, indent by depth.  These read the marker each org-super-agenda
  ;; entry string carries.
  (defun rm/agenda--item-marker (item)
    "The org marker an org-super-agenda ITEM string carries."
    (or (get-text-property 0 'org-hd-marker item)
        (get-text-property 0 'org-marker item)))
  (defun rm/agenda--item-project (item)
    "Group key for :auto-map -- ITEM's top-level `*' ancestor heading.
A todo and all its descendants map to the same project, so they share a
section instead of splitting off (which :auto-parent did).  A todo in an
llm.el referee log files under `research', whatever the log's heading
says: the log is research work on a paper, and its title is a file
name, not a project."
    (when-let ((m (rm/agenda--item-marker item)))
      (org-with-point-at m
        (if (and (fboundp 'llm-project-referee-log-p)
                 (llm-project-referee-log-p
                  (buffer-file-name (or (buffer-base-buffer) (current-buffer)))))
            "research"
          (org-back-to-heading t)
          (while (and (org-current-level) (> (org-current-level) 1))
            (org-up-heading-safe))
          (org-get-heading t t t t)))))
  (defun rm/agenda--outline-path (item)
    "ITEM's heading titles from its project down to itself, each lowercased."
    (when-let ((m (rm/agenda--item-marker item)))
      (org-with-point-at m
        (org-back-to-heading t)
        (let ((path (list (downcase (org-get-heading t t t t)))))
          (while (org-up-heading-safe)
            (push (downcase (org-get-heading t t t t)) path))
          path))))
  (defun rm/agenda--cmp-tree (a b)
    "Order two entries as a pre-order tree walk (parent first, siblings A-Z).
For `org-agenda-cmp-user-defined': compare outline paths segment by segment;
a shorter path -- an ancestor -- sorts before its descendants."
    (let ((pa (rm/agenda--outline-path a))
          (pb (rm/agenda--outline-path b)))
      (catch 'done
        (while (or pa pb)
          (let ((sa (car pa)) (sb (car pb)))
            (cond ((null sa) (throw 'done -1))
                  ((null sb) (throw 'done +1))
                  ((string-lessp sa sb) (throw 'done -1))
                  ((string-lessp sb sa) (throw 'done +1))
                  (t (setq pa (cdr pa) pb (cdr pb))))))
        nil)))
  (defun rm/agenda-indent ()
    "Prefix indent for a project-view line: two spaces per level below the
project, so a sub-todo nests under its parent (org-agenda-prefix-format)."
    (let ((lvl (org-current-level)))
      (if (and lvl (> lvl 2)) (make-string (* 2 (- lvl 2)) ?\s) "")))
  (defun rm/agenda--has-children-p (marker)
    "Non-nil when the heading at MARKER has a child heading (a sub-todo)."
    (org-with-point-at marker
      (org-back-to-heading t)
      (let ((lvl (org-current-level)))
        (save-excursion
          (outline-next-heading)
          (and (org-at-heading-p) (> (org-current-level) lvl))))))
  (defun rm/agenda-bold-parents ()
    "In the project tree, bold a todo's heading when it has sub-todos.
The bold marks it as a container the nested notes sit under.  Tree view only
(guarded on `org-super-agenda-groups', which only the `agenda' block sets)."
    (when (bound-and-true-p org-super-agenda-groups)
      (let ((inhibit-read-only t))
        (save-excursion
          (goto-char (point-min))
          (while (not (eobp))
            (let ((m (org-get-at-bol 'org-hd-marker)))
              (when (and m (rm/agenda--has-children-p m))
                (let ((title (org-with-point-at m (org-get-heading t t t t))))
                  (beginning-of-line)
                  (when (and (stringp title) (not (string-empty-p title))
                             (search-forward title (line-end-position) t))
                    (add-face-text-property (match-beginning 0) (match-end 0)
                                            'bold)))))
            (forward-line 1))))))
  (defun rm/agenda--dedup-keyword-1 ()
    "Dedup pass over the accessible region: hide a sub-todo's TODO keyword
when it equals its outline parent's, and SHOW it (drop any prior hide) when
it differs.  Being self-correcting is what lets a re-run after a state change
settle every case -- a child cycled back to its parent's state, and a child
whose parent moved out from under it.  Only the glyph is masked (a `display'
property); the real keyword and marker stay, so `r' progresses as normal."
    (let ((inhibit-read-only t))
      (save-excursion
        (goto-char (point-min))
        (while (not (eobp))
          (when-let ((m (org-get-at-bol 'org-hd-marker)))
            (let ((kw  (org-with-point-at m (org-get-todo-state)))
                  (pkw (org-with-point-at m
                         (org-back-to-heading t)
                         (and (org-up-heading-safe) (org-get-todo-state)))))
              (when kw
                (beginning-of-line)
                (when (re-search-forward
                       (concat "\\_<" (regexp-quote kw) "\\_> ")
                       (line-end-position) t)
                  (if (equal kw pkw)
                      (put-text-property (match-beginning 0) (match-end 0)
                                         'display "")
                    (remove-text-properties (match-beginning 0) (match-end 0)
                                            '(display nil)))))))
          (forward-line 1)))))
  (defun rm/agenda-dedup-keyword ()
    "Finalize-hook entry: run the dedup pass in the tree view.
Guarded like the sibling hooks on `org-super-agenda-groups', which the
`agenda' block let-binds during a full build.  A state change re-finalizes without
that binding, so `rm/agenda-todo' covers that path instead."
    (when (bound-and-true-p org-super-agenda-groups)
      (rm/agenda--dedup-keyword-1)))
  (defun rm/agenda-todo ()
    "Progress the entry at point (agenda `r'), then re-settle keyword dedup.
`org-agenda-todo' rewrites only the changed line and re-finalizes it narrowed,
with the tree's grouping no longer bound -- so the finalize-hook dedup can't
re-fire.  When the line is a project-tree line (its `org-lprops' carry the
grouping), re-run the pass over the whole buffer: the cycled entry re-hides
if it now matches its parent, and any child whose parent just changed shows
its keyword again."
    (interactive)
    (let ((tree (assq 'org-super-agenda-groups
                      (get-text-property (line-beginning-position) 'org-lprops))))
      (call-interactively #'org-agenda-todo)
      (when tree
        (save-excursion
          (save-restriction
            (widen)
            (rm/agenda--dedup-keyword-1))))))
  (defun rm/agenda--group-header-pos (name)
    "Where to insert an empty-project header for NAME so the project group
headers stay alphabetical.  Returns the bol of the first existing group header
\(populated or already-inserted) that sorts after NAME, else `point-max'."
    (let ((projects (mapcar #'car (rm/inbox--project-headings))))
      (save-excursion
        (goto-char (point-min))
        (catch 'pos
          (while (not (eobp))
            (let ((line (string-trim (buffer-substring-no-properties
                                      (line-beginning-position)
                                      (line-end-position)))))
              ;; a group-header line: carries no entry marker, and its text is
              ;; one of the project names (org-super-agenda renders them plain)
              (when (and (not (org-get-at-bol 'org-hd-marker))
                         (member line projects)
                         (string-lessp (downcase name) (downcase line)))
                (throw 'pos (line-beginning-position))))
            (forward-line 1))
          (point-max)))))
  (defun rm/agenda-empty-projects ()
    "Show projects with no open todos as their own (empty) section headers.
The stock todo list only renders a group once it has an entry, so a project
freshly made with `a/' would stay invisible.  Runs on finalize but only in
the project view (`org-super-agenda-groups' is let-bound there); each header
carries its project marker, so a/p on that line file or move straight in.
Each empty header lands in its ALPHABETICAL slot among the group headers (not
dumped at the end), so a project keeps its place whether or not it holds
todos -- populating one never reshuffles the view."
    (when (bound-and-true-p org-super-agenda-groups)
      (let ((empties (seq-remove (lambda (p) (nth 2 p))
                                 (rm/inbox--projects-status)))
            (inhibit-read-only t))
        (dolist (p empties)
          (save-excursion
            (goto-char (rm/agenda--group-header-pos (car p)))
            (insert (propertize (concat " " (car p) "\n")
                                'face 'org-super-agenda-header
                                'rm-project-marker (nth 1 p))))))))
  (defun rm/agenda-rebuild ()
    "Rebuild the agenda in place, reliably, after an a/y/p/classify edit.
org-agenda-redo reads its rebuild parameters (org-lprops: the project
grouping and sort) from the text properties of the line at point.  On an
inserted empty-project header that line carries none, so the redo comes
back STALE -- the move landed in the file but the view still shows the old
grouping.  Move to a real agenda line (the top) first, then redo."
    (goto-char (point-min))
    (org-agenda-redo))
  (defun rm/agenda-new (name)
    "Create an inbox item from the agenda (yazi `a').
A plain NAME adds a `** TODO' under the project at point (or a chosen project
when point isn't in one).  A NAME ending in \"/\" makes a container, one level
in from where point sits: on a todo it adds a child sub-todo under that todo;
anywhere else it makes a top-level project.  Rebuilds the agenda so the item
appears."
    (interactive "sNew (end with / to nest a sub-todo / project): ")
    (setq name (string-trim name))
    (cond
     ((string-empty-p name) (message "Cancelled"))
     ((string-suffix-p "/" name)
      (let ((pname (string-trim (substring name 0 -1)))
            (todo (or (org-get-at-bol 'org-hd-marker)
                      (org-get-at-bol 'org-marker))))
        (when (string-empty-p pname) (user-error "Empty name"))
        (if todo
            ;; on a todo: a sub-todo nested under it
            (progn
              (rm/inbox--add-todo todo pname)
              (rm/agenda-rebuild)
              (message "Sub-todo added under %s"
                       (org-with-point-at todo (org-get-heading t t t t))))
          ;; elsewhere: a new top-level project
          (rm/inbox--add-project pname)
          (rm/agenda-rebuild)
          (message "Project %s created -- add a todo with a, or move one in with y/p"
                   pname))))
     (t
      (let ((proj (or (rm/agenda--project-at-point)
                      (rm/inbox--read-project))))
        (rm/inbox--add-todo proj name)
        (rm/agenda-rebuild)
        (message "Added under %s"
                 (org-with-point-at proj (org-get-heading t t t t)))))))
  (defun rm/agenda-yank ()
    "Grab the entry at point for a later `p' move (yazi `y')."
    (interactive)
    (let ((m (or (org-get-at-bol 'org-hd-marker)
                 (org-get-at-bol 'org-marker)
                 (user-error "No entry to yank on this line"))))
      (setq rm/agenda-yank (copy-marker m))
      (message "Yanked: %s -- move it with p"
               (org-with-point-at m (org-get-heading t t t t)))))
  (defun rm/agenda-paste ()
    "Move the yanked entry under the heading at point (yazi `p').
Refiles the `y'-grabbed subtree -- heading, sub-todos, and notes -- as a
child of whatever the cursor sits on: an ENTRY (so it nests under that todo,
e.g. under `Website'), a project HEADER, or -- off any entry -- a project
chosen by name.  Land on a project's header line to file at its top level.
Rebuilds the agenda."
    (interactive)
    (unless (and rm/agenda-yank (marker-buffer rm/agenda-yank))
      (user-error "Nothing yanked -- press y on an entry first"))
    (let* ((dest (or (org-get-at-bol 'org-hd-marker)   ; on an entry -> nest under it
                     (org-get-at-bol 'org-marker)
                     (rm/agenda--project-at-point)      ; on a project header -> under it
                     (rm/inbox--read-project)))
           (src (marker-buffer rm/agenda-yank))
           (file (buffer-file-name (marker-buffer dest)))
           (head (org-with-point-at dest (org-get-heading t t t t)))
           (rfloc (list head file nil (marker-position dest))))
      ;; Refiling a subtree into itself (paste onto the yanked entry or one of
      ;; its own descendants) is what org would signal a cryptic error on.
      (when (and (eq (marker-buffer dest) (marker-buffer rm/agenda-yank))
                 (org-with-point-at rm/agenda-yank
                   (org-back-to-heading t)
                   (<= (point)
                       (marker-position dest)
                       (progn (org-end-of-subtree t t) (point)))))
        (user-error "Can't paste an entry into itself"))
      (org-with-point-at rm/agenda-yank
        (org-refile nil nil rfloc))
      (when (buffer-live-p src) (with-current-buffer src (save-buffer)))
      (with-current-buffer (marker-buffer dest) (save-buffer))
      (setq rm/agenda-yank nil)
      (rm/agenda-rebuild)
      (message "Moved under %s" head)))
  (defun rm/inbox--project-empty-p (marker)
    "Non-nil when the project heading at MARKER has no child heading."
    (org-with-point-at marker
      (org-back-to-heading t)
      (let ((end (save-excursion (org-end-of-subtree t t) (point))))
        (save-excursion
          (forward-line 1)
          (not (re-search-forward "^\\*\\{2,\\} " end t))))))
  (defun rm/inbox--delete-heading (marker)
    "Delete the heading and its subtree at MARKER, then save the file."
    (with-current-buffer (marker-buffer marker)
      (org-with-wide-buffer
       (goto-char marker)
       (org-back-to-heading t)
       (delete-region (point) (progn (org-end-of-subtree t t) (point)))
       (save-buffer))))
  (defvar rm/agenda--deleted nil
    "Snapshot of the last `d' deletion, consumed by `rm/agenda-undo-delete'.
A plist :file/:pos/:text/:heading, or nil once nothing is pending.")
  (defun rm/agenda--snapshot (marker)
    "A restore plist for the subtree at MARKER -- its file, start position,
full text (heading + body + children) and heading title.  Plain values, so
it outlives the agenda rebuild that a delete triggers."
    (org-with-point-at marker
      (org-back-to-heading t)
      (let ((beg (point))
            (heading (org-get-heading t t t t)))
        (list :file (buffer-file-name (marker-buffer marker))
              :pos beg
              :text (buffer-substring-no-properties
                     beg (save-excursion (org-end-of-subtree t t) (point)))
              :heading heading))))
  (defun rm/agenda-delete ()
    "Delete the thing at point: a todo, or an empty project.  Undo with `u'.
On a todo entry, remove its subtree; on a project header, remove its `*'
heading -- but only when the project holds no todos (a project with todos is
left alone; empty it with y/p or d first).  Either deletion is snapshotted,
so `rm/agenda-undo-delete' (u) restores the last one.  No confirm prompt --
u is the safety net."
    (interactive)
    (let ((m (org-get-at-bol 'org-hd-marker)))
      (if m
          (let ((name (org-with-point-at m (org-get-heading t t t t))))
            (setq rm/agenda--deleted (rm/agenda--snapshot m))
            (rm/inbox--delete-heading m)         ; generic subtree delete + save
            (rm/agenda-rebuild)
            (message "Deleted %s -- u to undo" name))
        (let ((proj (rm/agenda--project-at-point)))
          (unless proj (user-error "Nothing to delete on this line"))
          (let ((name (org-with-point-at proj (org-get-heading t t t t))))
            (if (rm/inbox--project-empty-p proj)
                (progn
                  (setq rm/agenda--deleted (rm/agenda--snapshot proj))
                  (rm/inbox--delete-heading proj)
                  (rm/agenda-rebuild)
                  (message "Deleted project %s -- u to undo" name))
              (user-error "Project \"%s\" still has todos -- clear them first" name)))))))
  (defun rm/agenda-undo-delete ()
    "Restore the todo or project last deleted with `d' (agenda `u').
Re-inserts the snapshotted subtree at the position it came from, saves the
file, and rebuilds the agenda.  One level deep -- it undoes the most recent
delete only."
    (interactive)
    (let ((s (or rm/agenda--deleted (user-error "Nothing to undo"))))
      (let ((file (plist-get s :file)))
        (unless (and file (file-exists-p file))
          (user-error "Can't undo -- source file is gone"))
        (with-current-buffer (find-file-noselect file)
          (org-with-wide-buffer
           (goto-char (min (plist-get s :pos) (point-max)))
           (unless (bolp) (insert "\n"))
           (insert (plist-get s :text))
           (save-buffer)))
        (setq rm/agenda--deleted nil)
        (rm/agenda-rebuild)
        (message "Restored %s" (plist-get s :heading)))))
  (defun rm/agenda-schedule (arg)
    "Put a date on the agenda entry at point (`s').
`org-agenda-schedule' -- which routes through `org-schedule', so the calendar
push advice sees it -- with the file saved after, the way every other agenda
edit here leaves nothing unwritten.  ARG passes through (C-u removes the
date).  Stock `s' was `org-save-all-org-buffers'; M-a M-s already saves."
    (interactive "P")
    (org-agenda-schedule arg)
    (let ((m (or (org-get-at-bol 'org-hd-marker) (org-get-at-bol 'org-marker))))
      (when (and m (buffer-live-p (marker-buffer m)))
        (with-current-buffer (marker-buffer m) (save-buffer)))))
  (with-eval-after-load 'org-agenda
    (keymap-set org-agenda-mode-map "j" #'org-agenda-next-line)
    (keymap-set org-agenda-mode-map "k" #'org-agenda-previous-line)
    (keymap-set org-agenda-mode-map "h" #'org-agenda-earlier)
    (keymap-set org-agenda-mode-map "l" #'org-agenda-later)
    (keymap-set org-agenda-mode-map "r" #'rm/agenda-todo)
    (keymap-set org-agenda-mode-map "d" #'rm/agenda-delete)
    (keymap-set org-agenda-mode-map "u" #'rm/agenda-undo-delete)
    (keymap-set org-agenda-mode-map "e" #'rm/agenda-edit-entry)
    (keymap-set org-agenda-mode-map "a" #'rm/agenda-new)
    (keymap-set org-agenda-mode-map "y" #'rm/agenda-yank)
    (keymap-set org-agenda-mode-map "p" #'rm/agenda-paste)
    (keymap-set org-agenda-mode-map "s" #'rm/agenda-schedule)
    ;; M-a M-s in the agenda: the agenda buffer visits no file, so stock
    ;; `save-buffer' fell through to `write-file' and asked where to save it.
    ;; Save the org files instead -- what `s' used to do here.  A remap, not a
    ;; key bind, so every route to save-buffer lands on it.
    (keymap-set org-agenda-mode-map "<remap> <save-buffer>"
                #'org-save-all-org-buffers)
    (keymap-set org-agenda-mode-map "V" #'org-agenda-view-mode-dispatch)
    (keymap-set org-agenda-mode-map "SPC" #'org-agenda-bulk-toggle)
    (keymap-set org-agenda-mode-map "v" #'rm/agenda-visual-toggle))
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
  ;; Tag the agenda's window an excursion so ESC closes it (back to where
  ;; `a' launched) instead of walking its buffer history into the file
  ;; underneath.  Runs on every finalize (current-buffer is the agenda);
  ;; idempotent.
  (defun rm/agenda-mark-excursion ()
    (let ((win (get-buffer-window (current-buffer))))
      (when win (set-window-parameter win 'rm-excursion t))))
  (add-hook 'org-agenda-finalize-hook #'rm/agenda-mark-excursion)
  ;; Empty projects (depth 80): after the real groups, before the footer (90).
  (add-hook 'org-agenda-finalize-hook #'rm/agenda-empty-projects 80)
  ;; Bold parent todos (depth 85): after entries exist, before the footer.
  (add-hook 'org-agenda-finalize-hook #'rm/agenda-bold-parents 85)
  ;; Hide a sub-todo's keyword when it repeats its parent's (depth 84).
  (add-hook 'org-agenda-finalize-hook #'rm/agenda-dedup-keyword 84)
  ;; The agenda's own keys, printed where they apply (footer of every
  ;; agenda view) rather than on the splash.
  (defconst rm/agenda-footer-text
    " a new \u00b7 d delete \u00b7 e edit \u00b7 hjkl move \u00b7 r progress \u00b7 s schedule \u00b7 u undo \u00b7 y/p move")
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
      ;; inbox.org's file-derived category is "inbox" -- redundant with the
      ;; project group header, and just repeats down the whole column.  Blank it.
      (when (equal s "inbox") (setq s ""))
      ;; An llm.el referee log is grouped under `research' already, and its
      ;; project tag names the paper; its title-form ("higgs referee 1 ai")
      ;; would only repeat that.  Blank, like inbox (his ask, 2026-08-18).
      (when (and f (fboundp 'llm-project-referee-log-p)
                 (llm-project-referee-log-p f))
        (setq s ""))
      ;; A blank category (inbox todos) used to still pad to 18 columns, which
      ;; pushed every todo far to the right of its project header.  Emit nothing
      ;; when blank so todos don't sit at the old far-right 18-col gutter.  But
      ;; flush-left reads as no nesting, so hang inbox todos to the END OF THE
      ;; LONGEST PROJECT NAME -- a tidy column just past the headers that
      ;; self-adjusts if projects are renamed.  Real categories (research-wip
      ;; denote names) still align at 18.
      (if (string-empty-p (or s ""))
          (make-string (apply #'max 1 (mapcar (lambda (p) (length (car p)))
                                              (rm/inbox--project-headings)))
                       ?\s)
        (truncate-string-to-width s 18 nil ?\s "…"))))
  (setq org-agenda-prefix-format
        '((agenda . " %i %(rm/agenda-category) %?-12t% s")
          (todo   . " %(rm/agenda-category)%(rm/agenda-indent)")
          (tags   . " %i %(rm/agenda-category) ")
          (search . " %i %(rm/agenda-category) ")))
  ;; Reuse a window already showing the agenda; otherwise it lands in the
  ;; current one ('current-window above -- pop-to-buffer-same-window reads
  ;; this alist, so no `inhibit-same-window' here or the split comes back).
  (add-to-list 'display-buffer-alist
               '("\\*Org Agenda\\*"
                 (display-buffer-reuse-window display-buffer-same-window))))

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

;; The website (~/scholarship/website -> raymondmaung.com) gets the same
;; treatment: saving a page re-exports its HTML into the research-public
;; working tree (uncommitted -- `publish site' in a shell commits and
;; deploys), and C-c C-c is re-export too, matching the paper muscle
;; memory.  Same lazy-load shape: cheap inlined path guard first, module
;; only when it matches.
(defun rm/org-site--maybe-export-on-save ()
  "Regenerate the generated HTML when the saved buffer is a website page."
  (when (and buffer-file-name
             (string-match-p "/scholarship/website/.*\\.org\\'"
                             buffer-file-name))
    (require 'org-site-export
             (expand-file-name "org-site-export.el" user-emacs-directory))
    (when (rm/org-site-buffer-p)
      (rm/org-site-export))))
(add-hook 'after-save-hook #'rm/org-site--maybe-export-on-save)
(with-eval-after-load 'org
  (add-hook 'org-ctrl-c-ctrl-c-final-hook
            (lambda ()
              (when (and buffer-file-name
                         (string-match-p "/scholarship/website/.*\\.org\\'"
                                         buffer-file-name))
                (require 'org-site-export
                         (expand-file-name "org-site-export.el"
                                           user-emacs-directory))
                (when (rm/org-site-buffer-p)
                  (rm/org-site-export)
                  t)))))

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
        `(("18e761b7f73a7aa68dc5b96efc6273b189816168bf96b6f3d2fe791389b5bfe8@group.calendar.google.com"
           . ,(rm/org-file "inbox.org")))))

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
  (with-current-buffer (find-file-noselect (rm/org-file "inbox.org"))
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

(defvar rm/task--classifying nil
  "Non-nil while a classify is mid-flight, to hold the calendar push back.
Classify schedules the entry BEFORE it refiles it, so a push fired by the
`org-schedule' advice (or by the capture finalize) would come back and write
its id/etag through a marker the refile has since moved out from under.
`rm/task-classify-project' pushes once, itself, from the entry's final home.")

(defun rm/org-gcal-auto-push ()
  "Auto-push the entry at point when it's a timestamped entry in inbox.org.
Fired after `org-schedule'/`org-deadline' so a scheduled TODO becomes an event
without a manual M-SPC G.  Async (non-blocking) with a save chained after the
POST so the id/etag writeback persists; M-SPC G stays the bulk fallback."
  (when (and (not rm/task--classifying)
             buffer-file-name
             (file-equal-p buffer-file-name (rm/org-file "inbox.org"))
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

;; org-gcal also wires TWO auto-post hooks of its OWN: `org-gcal--refile-post'
;; on `org-after-refile-insert-hook' and `org-gcal--capture-post' on
;; `org-capture-after-finalize-hook'.  Both POST any entry that lands in a file
;; from `org-gcal-fetch-file-alist' (here: inbox.org), timestamp or not -- and
;; `org-gcal-post-at-point' PROMPTS with `org-read-date' when the entry carries
;; no timestamp.  That is what turned a plain classify (M-c, pick the project,
;; refile into inbox.org) into a date/time prompt, and it hit fresh captures
;; the same way.  Drop both.  The push story stays one-way and deliberate:
;; `rm/org-gcal--capture-push' above (guarded on an actual timestamp), the
;; org-schedule/org-deadline advice, and M-SPC G for bulk.  Nested
;; `with-eval-after-load' so the removal runs AFTER org-gcal's own adds,
;; whichever of org-refile/org-capture loads first.
(with-eval-after-load 'org-gcal
  (with-eval-after-load 'org-refile
    (remove-hook 'org-after-refile-insert-hook #'org-gcal--refile-post))
  (with-eval-after-load 'org-capture
    (remove-hook 'org-capture-after-finalize-hook #'org-gcal--capture-post)))

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

;; Restart the Emacs daemon and reopen a frame (Super+W only closes the frame).
;; `emacs.service' (dotfiles/systemd/user/emacs.service, bound to
;; graphical-session.target) is the daemon.  The restart runs in a detached
;; `systemd-run' unit, so it outlives the daemon it stops.  A child in the
;; emacs.service cgroup would be killed with the daemon, hence the detachment.
(defun rm/restart-emacs ()
  "Restart the `emacs.service' daemon and open a fresh frame.
Save the buffers first.  A detached `systemd-run' helper restarts the service
and creates a frame.  The helper runs outside the service cgroup, so it
survives the daemon's death.  `emacs.service' is Type=notify, so the restart
returns only once the new daemon is ready.  Display vars are forwarded so the
frame lands on this session."
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
  ;; Heading stars in-line: each leading star displays as a space (?\s --
  ;; NOT `leading', which collapses them to nothing), so a heading sits as
  ;; many columns in as its depth, and the last star is the level glyph.
  ;; (Until 2026-08-16 the glyphs sat in the margin via org-margin and every
  ;; headline was flush left; a folded outline then showed no depth -- his
  ;; complaint on the first llm.el session.)
  (setq org-modern-star 'replace
        ;; polygons by depth, all outlines: circle, triangle, square,
        ;; pentagon, hexagon (Unicode has no outline octagon; 6+ repeat)
        org-modern-replace-stars "○△□⬠⬡"
        org-modern-hide-stars ?\s
        ;; real bullets for plain lists -- the stock "-" -> "–" en dash
        ;; read as hyphens (his complaint, 2026-07-23)
        org-modern-list '((?- . "•") (?+ . "◦") (?* . "▹"))
        org-modern-block-fringe nil       ; fringe markers sit wrong next to olivetti
        ;; tag/keyword pills look best unaligned (no trailing-whitespace columns)
        org-auto-align-tags nil
        org-tags-column 0
        ;; Colour the keyword pills by progress -- org-modern draws these labels
        ;; in org buffers AND the agenda, so org-todo-keyword-faces alone can't
        ;; reach them; these must match it.  inverse-video makes each foreground
        ;; the pill fill (org-modern's own look).  TODO purple, NEXT logo red,
        ;; CONTINUING logo blue, DONE green.
        org-modern-todo-faces
        '(("TODO"       . (:foreground "#8b5fbf" :inverse-video t :weight semibold))
          ("NEXT"       . (:foreground "#c64e3b" :inverse-video t :weight semibold))
          ("CONTINUING" . (:foreground "#2076c1" :inverse-video t :weight semibold))
          ("DONE"       . (:foreground "#3a9e57" :inverse-video t :weight semibold))))
  :config
  ;; the level glyphs at 3/4 size: full-size polygons overpower the headline
  ;; (his call, 2026-08-16); the face also covers checkboxes and progress
  ;; One font for the whole set: circle/triangle/square otherwise fall to
  ;; Noto Sans Mono and draw larger than the Math-font pentagon/hexagon.
  (set-face-attribute 'org-modern-symbol nil :family "Noto Sans Math" :height 0.75))

;; org-super-agenda (alphapapa): groups the otherwise-flat todo list into
;; titled sections.  Wired for ONE view -- the splash `a' (rm/agenda-projects)
;; -- to cluster todos under their parent `*' heading, so a one-level project
;; container (Philosophy, Technology, ...) becomes a header with its `** TODO'
;; children beneath.  The mode is global but INERT unless
;; `org-super-agenda-groups' is non-nil, which only the `agenda' custom block sets
;; (see org-agenda-custom-commands), so the date agenda and `m' view stay flat.
(use-package org-super-agenda
  :init
  (with-eval-after-load 'org-agenda (org-super-agenda-mode 1)))
;; org-super-agenda pins a keymap onto its group-header lines, built once with
;; (copy-keymap org-agenda-mode-map) at load -- a SNAPSHOT that can predate our
;; j/k/a/p rebindings, so headers kept the stock keys (j = goto-date, a =
;; archive).  Re-point it at a parent-linked map with no own bindings, so a
;; header line always resolves through the live org-agenda-mode-map (our keys,
;; and a/p onto a project header file or move straight in).
(with-eval-after-load 'org-super-agenda
  (setq org-super-agenda-header-map
        (make-composed-keymap nil org-agenda-mode-map)))
(defun rm/agenda-projects ()
  "Todos as an indented project tree (splash `a').
Each top-level `*' project is a section; within it, todos nest as an outline
-- a sub-todo indents under its parent, siblings sorted A-Z.  Runs the
`agenda' custom block (not a bare let over org-todo-list) so a redo -- after
a/y/p edit the list -- keeps the tree.  Move with j/k/h/l; a adds (a/ nests a
sub-todo),
y/p move, e/r/d act on the entry at point."
  (interactive)
  (require 'org-super-agenda)
  (org-agenda nil "agenda"))

;; --- Denote: the thought vault (`rm/notes-directory') ---------------------
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
  (setq denote-directory rm/notes-directory
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
    "The picker over titles AND keywords: fragments match either (splash d).
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
  (defun rm/inbox--find-child (parent title)
    "Marker on PARENT's descendant headline titled TITLE (the last match), or nil.
How the entry is picked up again after a refile has moved it: org's refile
leaves no handle on what it moved, and the refile lands the entry LAST among
its new siblings, so the last title match is the one just filed."
    (org-with-point-at parent
      (org-back-to-heading t)
      (let ((end (save-excursion (org-end-of-subtree t t) (point)))
            found)
        (save-excursion
          (while (and (outline-next-heading) (< (point) end))
            (when (equal (org-get-heading t t t t) title)
              (setq found (point-marker)))))
        found)))
  (defun rm/task--offer-schedule (pom)
    "Ask whether to schedule the entry at POM; non-nil when it got a date.
Classifying and scheduling are separate decisions -- most todos want a project
and no date -- so this only ASKS, and only when the entry carries no
SCHEDULED/DEADLINE yet: `n' leaves it undated, `y' opens
`org-schedule's date prompt.  Asked BEFORE the entry is filed, so from a
capture the date question comes up while the capture window is still standing,
not after it has closed.  M-g (C-g) at the question backs out of the classify
altogether -- nothing has moved yet.  The calendar push is held back here
(`rm/task--classifying') and fired once the entry has landed."
    (when pom
      (org-with-point-at pom
        (unless (or (org-get-scheduled-time (point))
                    (org-get-deadline-time (point)))
          (when (y-or-n-p "Schedule it? ")
            (let ((rm/task--classifying t)) (org-schedule nil))
            (when buffer-file-name (save-buffer))   ; nil in a capture buffer
            t)))))
  (defun rm/task-classify-project (&optional agenda)
    "File the task at hand under a project chosen by name, then offer a date.
Projects are the top-level `*' headings in inbox.org -- the replacement
for the old task tags, now that the agenda groups by project.  With
AGENDA non-nil, refile the agenda entry at point and rebuild the view
(default project = the one under point); otherwise refile the org
heading at point.  A LIVE CAPTURE takes org-capture's own dance instead
(finalize first, then refile the stored entry from the base buffer): a
plain refile out of a capture buffer loses the todo outright, because
finalize goes on to delete the region the refile has already moved away.
Filed, `rm/task--offer-schedule' asks whether to date it -- classify
first, schedule only when the todo actually wants a day."
    (let* ((capture (bound-and-true-p org-capture-mode))
           (marker (when agenda
                     (or (org-get-at-bol 'org-hd-marker)
                         (org-get-at-bol 'org-marker)
                         (user-error "No entry on this line"))))
           (title (if agenda
                      (org-with-point-at marker (org-get-heading t t t t))
                    (save-excursion (org-back-to-heading t)
                                    (org-get-heading t t t t))))
           (dest (rm/inbox--read-project
                  (and agenda (rm/agenda--project-at-point))))
           (file (buffer-file-name (marker-buffer dest)))
           (head (org-with-point-at dest (org-get-heading t t t t)))
           (rfloc (list head file nil (marker-position dest)))
           (dated (rm/task--offer-schedule (or marker (point)))))
      ;; The whole move runs with the calendar push held back -- the capture
      ;; finalize fires one of its own, through a marker the refile below
      ;; then invalidates.
      (let ((rm/task--classifying t))
        (cond
         (agenda
          (let ((src (marker-buffer marker)))
            (org-with-point-at marker (org-refile nil nil rfloc))
            (when (buffer-live-p src) (with-current-buffer src (save-buffer)))))
         (capture
          (let ((base (or (buffer-base-buffer) (current-buffer)))
                (pos (make-marker))
                (org-capture-is-refiling t))
            ;; Marker in the BASE buffer: the indirect capture buffer is killed
            ;; by the finalize, and finalize can shift text around the entry.
            (set-marker pos (save-excursion (org-back-to-heading t) (point)) base)
            (org-capture-put :kill-buffer nil :jump-to-captured nil)
            (org-capture-finalize)
            (save-window-excursion
              (with-current-buffer base
                (org-with-point-at pos (org-refile nil nil rfloc))
                (save-buffer)))))
         (t (org-refile nil nil rfloc)))
        (with-current-buffer (marker-buffer dest) (save-buffer)))
      ;; Now that the entry has stopped moving, let the calendar have it.
      (when dated
        (let ((m (rm/inbox--find-child dest title)))
          (when m (org-with-point-at m (rm/org-gcal-auto-push)))))
      ;; Land on the agenda whenever it is on screen -- a capture window
      ;; closing should hand him back the task list, not whatever sat behind
      ;; it.  Rebuilt there, so the entry shows under its new project.
      (let ((win (get-buffer-window (or (bound-and-true-p org-agenda-buffer-name)
                                        "*Org Agenda*"))))
        (cond (win (select-window win) (rm/agenda-rebuild))
              (agenda (rm/agenda-rebuild))))
      (message "Filed under %s" head)))
  (defun rm/denote-classify ()
    "Classify the thing at hand -- one gesture, context decides.
Vault note: form + matter, renames in place (identifier kept,
re-runnable).  Task (agenda entry, inbox heading, or capture buffer):
file it under a project, chosen by name -- projects replaced the task
tags, and the agenda groups by them."
    (interactive)
    (cond
     ((derived-mode-p 'org-agenda-mode)
      (rm/task-classify-project t))
     ;; require, not featurep: M-c on a raw-opened vault note in a fresh
     ;; session must still classify, not fall through to the task branch
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
      (rm/task-classify-project))
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
        ;; find-file-noselect runs find-file-hook, which carries the splash's
        ;; one-shot auto-dismiss -- but vertico-buffer has swapped *welcome*
        ;; off-window here, so the dismiss check sees it "gone" and KILLS it.
        ;; vertico-buffer's teardown then can't restore the killed splash
        ;; ("selecting deleted buffer", landing on the agenda).  A preview is
        ;; not a real visit: keep the dismiss hook out of it so the splash
        ;; survives to be restored, and the real RET open dismisses it.
        (let ((buf (let ((find-file-hook
                          (remq 'rm/welcome--auto-dismiss find-file-hook)))
                     (find-file-noselect f))))
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

;; --- llm.el: research and referee-edit in org, on denote -------------------
;; In development at ~/projects/llm.el; loaded straight from the working tree
;; so every edit stays in that repo (no symlink, no copy into elpa/).  The
;; load-path line goes when the package has a home.  llm-global-mode turns
;; llm-mode on in ai-keyed denote files: M-RET asks, C-c l (M-SPC l) is the
;; prefix.  Spec: ~/projects/llm.el/SPEC.org.
(add-to-list 'load-path (expand-file-name "~/projects/llm.el"))
;; org-side-tree: the branch viewer (M-SPC l t) is the session's outline as
;; an indented tree in a side window.
(use-package org-side-tree
  :commands (org-side-tree)
  :init (setq org-side-tree-fontify nil))   ; plain text, our own faces
(require 'llm)
(llm-global-mode 1)
;; Referee logs carry TODOs (filed under `research', see
;; rm/agenda--item-project).  The vault stays out of the agenda; the logs
;; join it by file -- the ones that exist here, the new ones as llm.el
;; makes them (llm-referee-agenda).
(setq org-agenda-files (append org-agenda-files (llm-referee-log-files)))
;; A log's todo inherits the file tags :ai:<project>:referee:.  The form
;; keywords say nothing in the agenda; the project tag names the paper and
;; stays.
(setq org-agenda-hide-tags-regexp
      (regexp-opt (list llm-project-form-keyword llm-project-referee-keyword
                        llm-project-note-keyword)
                  'symbols))
;; ...and the project tag goes too: a todo in a log wears no tags at all
;; (his ask, 2026-08-18 -- no new tag pill for todos).  Done after the
;; agenda is built, per line, since the project tag is not a fixed word.
(defun rm/agenda--strip-log-tags ()
  "Remove the tag string from every agenda line whose entry is in a referee log."
  (let ((inhibit-read-only t))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (when-let* ((m (or (get-text-property (point) 'org-hd-marker)
                           (get-text-property (point) 'org-marker)))
                    (f (buffer-file-name (marker-buffer m))))
          (when (and (llm-project-referee-log-p f)
                     (re-search-forward org-tag-group-re (line-end-position) t))
            (delete-region (match-beginning 0) (line-end-position))
            (delete-horizontal-space)))
        (forward-line 1)))))
(add-hook 'org-agenda-finalize-hook #'rm/agenda--strip-log-tags)
;; Bundled PDFs go to the model as marker markdown (pdf2md, Datalab; the
;; key comes from ~/.config/secrets.env), converted in the background the
;; first time a PDF is linked; pdftotext text until then.
(setq llm-project-pdf-converter 'marker)
;; The prefix is global, not only in sessions: M-SPC l s must work from any
;; buffer to create the first session.  org-store-link moved to C-c L.
(keymap-global-set "C-c l" llm-prefix-map)
;; Splash l opens the project tree (bound in the splash keymap below).

;; --- Prose writing environment (variable-pitch + centered) --------------
;; Goal: Org, Markdown and LaTeX read like a page, not a terminal.
;;   * the body font is Atkinson Hyperlegible Next, supplied via nano's
;;     proportional family above; mixed-pitch swaps `variable-pitch' in for
;;     prose while keeping code / tables / verbatim / math in Roboto Mono so
;;     they align
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
              ;; center via FRINGES, not margins (kept from the org-margin
              ;; days; nano paints fringes in the background colour, so it
              ;; looks identical and leaves the margins free).
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

;; --- Prose layout: centered vs justified (M-t) ---------------------------
;; Two reading widths for a prose buffer, toggled with M-t:
;;   centered   -- olivetti centres the text in a 72-col measure (the default,
;;                 set on the org/markdown/LaTeX hooks above)
;;   justified  -- olivetti off, so the text spans the full window, no centering
;; Turning olivetti off also drops the visual-line-mode it switched on, so we
;; re-assert soft-wrap in the justified branch -- long prose lines still wrap at
;; the window edge, they just aren't centered.  M-t is transpose-words by
;; default (unused here -- Meta carries the vim motions), so we claim it.
(defun rm/prose-layout-toggle ()
  "Toggle the current buffer's prose layout: centered (olivetti) vs justified."
  (interactive)
  (if (bound-and-true-p olivetti-mode)
      (progn
        (olivetti-mode -1)
        (visual-line-mode 1))
    (olivetti-mode 1)))
(keymap-global-set "M-t" #'rm/prose-layout-toggle)

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

;; --- Bookmarks: nine file slots, shown on the splash --------------------
;; A tiny numbered registry, distinct from stock bookmark.el: nine slots,
;; each an absolute file path.  Set the current file into a slot with
;; `rm/bookmark-set' (M-SPC B), then jump with M-SPC 1..9 (= C-c 1..9) from
;; anywhere, or the bare digit on the splash (its keymap adds 1..9 there).
;; The vector rides in `savehist-additional-variables', so slots persist.
(defvar rm/bookmarks (make-vector 9 nil)
  "Nine bookmark slots for the splash; each nil or an absolute file path.
Set with `rm/bookmark-set', opened with `rm/bookmark-open'.  Persisted via
savehist (see `savehist-additional-variables').")

;; Guard against a stale savehist value of the wrong shape (older length, or
;; not a vector) clobbering the accessors.
(unless (and (vectorp rm/bookmarks) (= (length rm/bookmarks) 9))
  (setq rm/bookmarks (make-vector 9 nil)))

(defun rm/bookmark--slot (n)
  "Return the 0-based index for user-facing slot N, or signal for a bad N."
  (unless (and (integerp n) (<= 1 n 9))
    (user-error "Bookmark slots run 1-9"))
  (1- n))

(defun rm/bookmark--detex (s)
  "Strip common LaTeX title markup from S, leaving plain text.
Drop wrappers such as \\textbf{...}, then any stray braces and bare macros."
  (let ((s s))
    (setq s (replace-regexp-in-string "\\\\[a-zA-Z]+\\*?{" "" s)) ; drop \macro{
    (setq s (replace-regexp-in-string "[{}]" "" s))               ; drop stray braces
    (setq s (replace-regexp-in-string "\\\\[a-zA-Z]+" "" s))      ; drop bare \macro
    (string-trim (replace-regexp-in-string "[ \t]+" " " s))))     ; collapse spaces

(defun rm/bookmark--title (file)
  "Return a display title for FILE, reading only its head so it stays cheap.
Prefer the Org #+title.  Else take a LaTeX \\title{...}, which a paper carries
in an export block, with its markup stripped.  Else fall back to the base name."
  (or (ignore-errors
        (with-temp-buffer
          (let ((case-fold-search t))          ; #+TITLE / \Title both match
            (insert-file-contents file nil 0 4096)
            (or (progn (goto-char (point-min))
                       (and (re-search-forward "^#\\+title:[ \t]*\\(.+?\\)[ \t]*$" nil t)
                            (match-string 1)))
                (progn (goto-char (point-min))
                       (and (re-search-forward "\\\\title{\\(.*\\)}" nil t)
                            (rm/bookmark--detex (match-string 1))))))))
      (file-name-base (directory-file-name file))))

(defun rm/bookmark--line (n)
  "Return the splash line for set slot N: the title, a dot leader, then [N].
The line copies the Tasks block, so [N] lands in the same column (38).
A title wider than 29 characters gets an ellipsis."
  (let* ((title (rm/bookmark--title (aref rm/bookmarks (1- n))))
         (title (if (> (length title) 29)
                    (concat (substring title 0 28) "…")
                  title))
         (dots  (make-string (max 2 (- 31 (length title))) ?.)))
    (format "  %s %s [%d]" title dots n)))

(defconst rm/welcome--block-indent 16
  "Left padding, in columns, that centres a splash block under the logo.
The splash measure (`olivetti-body-width') is 70 -- kept wide for the logo,
which olivetti clips at the margin rather than scaling -- and the blocks are
38 columns, so (70 - 38) / 2 puts them on the logo's centre line.
welcome.org's `commands' line carries the same indent literally.")

(defun rm/welcome--centre (text)
  "Indent every non-empty line of TEXT by `rm/welcome--block-indent' columns."
  (let ((pad (make-string rm/welcome--block-indent ?\s)))
    (mapconcat (lambda (line) (if (string-empty-p line) line (concat pad line)))
               (split-string text "\n")
               "\n")))

(defun rm/bookmark--panel ()
  "Return the splash Bookmarks block: a header, then the entries.
First a fixed website entry (`w' -- the raymondmaung.com sources
sidebar, not a numbered slot), then the set slots only.  An empty slot
does not appear.  Centred under the logo by `rm/welcome--centre'."
  (let* ((hint "set = [M-SPC B]")
         ;; Right-flush the hint so [M-SPC B] ends in the [N] key column (38).
         (header (concat "Bookmarks"
                         (make-string (max 1 (- 38 (length "Bookmarks") (length hint)))
                                      ?\s)
                         hint))
         ;; Same shape as rm/bookmark--line, so [w] lands in the [N] column.
         (website (format "  website %s [w]" (make-string (- 31 7) ?.)))
         (taken (seq-filter (lambda (n) (aref rm/bookmarks (1- n)))
                            (number-sequence 1 9))))
    (rm/welcome--centre
     (concat header "\n\n" website
             (when taken
               (concat "\n" (mapconcat #'rm/bookmark--line taken "\n")))))))

(defun rm/bookmark-open (n)
  "Open the file in bookmark slot N (1-9).
From the splash the bare digit calls this; elsewhere M-SPC N (= C-c N) does."
  (interactive (list (or (and current-prefix-arg (prefix-numeric-value
                                                  current-prefix-arg))
                         (read-number "Open bookmark (1-9): "))))
  (let ((file (aref rm/bookmarks (rm/bookmark--slot n))))
    (cond
     ((null file)
      (message "Bookmark %d is empty -- set it with M-SPC B from a file" n))
     ((file-exists-p file) (find-file file))
     (t (message "Bookmark %d: file is gone -- %s" n file)))))

(defun rm/bookmark-set ()
  "Assign the current file to a bookmark slot.  Reads the slot digit (1-9)."
  (interactive)
  (let ((file (or buffer-file-name
                  (user-error "This buffer is not visiting a file"))))
    (let* ((ch (read-char-choice
                (format "Set bookmark to %s -- slot (1-9): "
                        (file-name-nondirectory file))
                (number-sequence ?1 ?9)))
           (n  (- ch ?0)))
      (aset rm/bookmarks (rm/bookmark--slot n) (expand-file-name file))
      (message "Bookmark %d = %s" n (file-name-nondirectory file)))))

;; M-SPC B (= C-c B) sets; M-SPC 1..9 (= C-c 1..9) open.  Each digit gets a
;; closure over its own N (lexical-binding makes the capture per-iteration).
(keymap-global-set "C-c B" #'rm/bookmark-set)
(dotimes (k 9)
  (let ((n (1+ k)))
    (keymap-global-set (format "C-c %d" n)
                       (lambda () (interactive) (rm/bookmark-open n)))))

;; --- Welcome screen (elegant-emacs style, from welcome.org) -------------
;; Ported from Rougier's elegant-emacs: the startup buffer is an *Org file*
;; (`welcome.org' beside this init) rendered read-only -- the pixel-centered
;; logo (`org-image-align', org 9.7+), a single `commands' line, and the
;; bookmark slots.  Everything else it used to carry -- the find / tasks /
;; vault map and the form/matter taxonomy -- is one keystroke away on `c'
;; (welcome-commands.org, `rm/welcome-commands').  Because it's Org, you edit
;; the page by editing that file.  Shown on `window-setup-hook', skipped when
;; Emacs opens a file.
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
so a half-tile still shows a legible logo rather than a speck.

Also capped at the window's TEXT AREA: olivetti centres by setting
margins, and an image wider than the measure is clipped at the right
margin, not scaled down (2026-08-02: the splash lost its wide blocks,
the measure narrowed with them, and the logo came back sheared down its
right-hand side).  `window-body-width' excludes the margins, so this
reads the real room once olivetti has run."
  (let* ((text-px   (* (count-lines (point-min) (point-max))
                       (default-line-height)))
         (budget    (- (window-pixel-height) text-px))
         (by-height (round (* budget (/ 270.0 217.0))))
         ;; one character of cushion, so a rounding hair never clips
         (by-width  (- (window-body-width nil t) (default-font-width))))
    (max 250 (min 500 by-height by-width))))

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
  "Show the Commands page (welcome-commands.org) full-window, in place of
the splash; any key returns to the splash.  The page carries BOTH the
alphabetical command list and the system map -- find / tasks / vault and the
form/matter taxonomy, which lived on the splash until 2026-08-02 (his ask:
the splash is a logo and the bookmarks, the reference is one keystroke away).
This is a clean buffer SWAP in the
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
                              '(("^\\(?:commands\\|find\\|tasks\\|vault\\|llm\\)\\b" 0 'bold)
                                ("\\_<\\(?:form\\|matter\\)\\_>" 0 'bold)
                                ("C = Ctrl.*$" 0 'italic)
                                ("^vault  \\(file = .*\\)$" 1 'italic)
                                ("^llm  \\(\\S-+\\)" 1 'italic)
                                ("any key to dismiss" 0 'italic)
                                ("\\[[^][()]*\\]" 0 'nano-face-salient prepend))
                              t)
      (font-lock-flush) (font-lock-ensure)
      (when (fboundp 'olivetti-mode)
        (setq-local olivetti-body-width 80)
        (olivetti-mode 1))
      ;; Same reason the splash truncates: olivetti turns on visual-line-mode,
      ;; which word-wraps a two-column row in a narrow frame and shears the
      ;; map's columns apart.  Truncate instead.
      (visual-line-mode -1)
      (setq-local truncate-lines t)
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
            (insert-file-contents file)
            ;; Swap the {{bookmarks}} token for the live slot list, before
            ;; org-mode + font-lock run so it styles like the rest.  Build the
            ;; panel FIRST: rm/bookmark--title runs its own search, so calling
            ;; it between the token match and replace-match would clobber the
            ;; match data and drop the panel at the wrong place.
            (let ((panel (rm/bookmark--panel)))
              (goto-char (point-min))
              (when (re-search-forward "^{{bookmarks}}$" nil t)
                (replace-match panel t t))))
          (setq default-directory dir)             ; so [[file:welcome-logo.svg]] resolves
          (let ((org-mode-hook nil)) (org-mode))   ; Org WITHOUT the prose hooks
          (setq-local org-hide-emphasis-markers t
                      org-image-align 'center)     ; logo pixel-centered (org 9.7+)
          ;; Style with font-lock, NOT org emphasis (whose marker-hiding is
          ;; unreliable on a fresh daemon frame -- it showed raw *asterisks*):
          ;; the Bookmarks header bold, [bracketed keys] salient (the [^][()]
          ;; class skips [[elisp:(...)]]).  The find / tasks / vault and
          ;; form/matter rules moved with those blocks to the Commands page.
          ;; The header regex tolerates leading space: the panel is indented
          ;; to centre it (see `rm/welcome--block-indent').
          (font-lock-add-keywords nil
                                  '(("^ *Bookmarks\\b" 0 'bold)
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

            ;; Bare digits open bookmark slots 1-9 (M-SPC N works globally).
            (dotimes (k 9)
              (let ((n (1+ k)))
                (define-key map (kbd (number-to-string n))
                            (lambda () (interactive) (rm/bookmark-open n)))))

            (define-key map (kbd "n") #'rm/denote-note)         ; new note
            (define-key map (kbd "p") #'rm/papers-sidebar)      ; papers
            (define-key map (kbd "f") #'rm/denote-find)         ; the note picker
            (define-key map (kbd "g") #'rm/denote-grep)         ; grep bodies
            (define-key map (kbd "a") #'rm/agenda-projects)     ; todos, grouped by
                                        ; project heading (agenda views: C-c a)
            (define-key map (kbd "t") #'rm/capture-task)        ; new todo, directly
                                        ; (no c/capture menu: t and n ARE capture)
            (define-key map (kbd "h") #'rm/denote-hubs)         ; hub catalog
            (define-key map (kbd "l") #'llm-project-tree)       ; llm project tree
                                        ; (side window, like p and w)
            (define-key map (kbd "d") #'rm/denote-list)         ; list by words
                                        ; (was l until 2026-08-16)
            (define-key map (kbd "s") #'rm/scratch)             ; scratch
            (define-key map (kbd "w") #'rm/website-sidebar)     ; website pages
                                        ; (sidebar, like p; listed first in
                                        ; the Bookmarks block)
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
          (org-remove-inline-images)          ; drop any stale overlay from a prior render
          (org-display-inline-images)
          (add-hook 'window-size-change-functions #'rm/welcome--refit nil t)
          (when (fboundp 'olivetti-mode)
            ;; Stays 70 even though the widest text is now 38 cols: the
            ;; measure is what the LOGO gets to be wide (an image past it is
            ;; clipped, see `rm/welcome--logo-width'), so narrowing it to fit
            ;; the bookmark block sheared the logo.  The block is centred
            ;; under the logo by its own indent instead.
            (setq-local olivetti-body-width 70)
            (olivetti-mode 1))
          ;; olivetti turns on visual-line-mode; in a narrowed window (sidebar
          ;; open) that word-wraps the aligned bookmark lines by a hair.
          ;; Truncate instead -- they stay sane at any window width.
          (visual-line-mode -1)
          (setq-local truncate-lines t))))))

;; In a daemon, `window-setup-hook' fires on the non-graphic startup frame
;; (F1, ~25px tall): the splash would build THERE, floor its logo to the 250px
;; minimum, and never reach the GUI client frames you actually open (the reason
;; the logo "went missing" after a daemon restart).  Defer to the first GUI
;; frame instead, one-shot.  A plain (non-daemon) Emacs keeps the direct path.
(defun rm/welcome--on-first-gui-frame ()
  "Show the splash once the first graphical client frame exists, then unhook."
  (when (display-graphic-p)
    (remove-hook 'server-after-make-frame-hook #'rm/welcome--on-first-gui-frame)
    (rm/welcome)))
(if (daemonp)
    (add-hook 'server-after-make-frame-hook #'rm/welcome--on-first-gui-frame)
  (add-hook 'window-setup-hook #'rm/welcome))
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
;; The splash's single keys that fit under M-SPC (= C-c) without a clash
;; are global too, so the splash need not be visited for them (his ask,
;; 2026-08-18): n note, p papers, s scratch, a agenda, d list, 1-9
;; bookmarks were already; f find, t todo, c commands join.  l is the
;; llm map (its l l opens the project tree); g h w stay splash-only.
(keymap-global-set "C-c f" #'rm/denote-find)
(keymap-global-set "C-c t" #'rm/capture-task)
(keymap-global-set "C-c c" #'rm/welcome-commands)
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
   ;; the llm project tree (splash l) is a popup like a sidebar: while it
   ;; shows, ESC dismisses it first, wherever point is -- a file opened
   ;; from it goes home on the NEXT ESC (his ask, 2026-08-16)
   ((and (fboundp 'llm-project-tree-hide) (llm-project-tree-hide)))
   ;; the same for a dired sidebar (splash p / w, f8): while it shows, ESC
   ;; dismisses it first, from the paper as much as from the tree itself
   ;; (his ask, 2026-08-17)
   ((rm/escape--sidebar-visible-p) (dired-sidebar-hide-sidebar))
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
   ;; an excursion window -- the agenda `a' popped, which `e' reuses for a
   ;; narrowed edit view.  What ESC does depends on what the window shows:
   ;; on an `e' edit clone it restores the agenda IN PLACE (discarding the
   ;; clone; its edits live on in the base file) then REDRAWS it, so a renamed
   ;; heading or a new note shows at once without closing and reopening -- `e'
   ;; ESC lands back on the fresh agenda, and `e' again repeats the trip; on
   ;; the agenda itself it closes the window, back to wherever `a' launched.
   ;; Guarded so the frame's last real window is never deleted -- that walks
   ;; back / floors.
   ((window-parameter (selected-window) 'rm-excursion)
    (let ((origin (and (local-variable-p 'rm/edit-origin) rm/edit-origin)))
      (cond
       ((buffer-live-p origin)
        (let ((clone (current-buffer)))
          (switch-to-buffer origin)
          (kill-buffer clone)
          (when (derived-mode-p 'org-agenda-mode)
            (rm/agenda-rebuild))))    ; redo keeps the project grouping + sort
       ((not (rm/escape--last-real-window-p)) (delete-window))
       (t (rm/escape--back)))))
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
                          (not (derived-mode-p 'dired-sidebar-mode
                                               'llm-view-tree-mode)))))
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
;; M-c: classify the thing at hand (note -> form/matter, task -> project).
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
    "Toggle a dired sidebar rooted at the note vault."
    (interactive)
    (let ((default-directory rm/notes-directory))
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
  (defun rm/website-sidebar ()
    "Toggle a dired sidebar rooted at the website sources (splash `w').
The pages of raymondmaung.com, one .org each -- `l' visits; saving a
page re-exports its HTML into research-public."
    (interactive)
    (let ((default-directory
           (expand-file-name "~/scholarship/website/")))
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
