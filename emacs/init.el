;;; init.el --- Raymond's Emacs configuration  -*- lexical-binding: t; -*-
;;
;; A small, deliberately hand-written config.  The goal is to *learn*
;; Emacs, not to hide it behind a framework -- so every block is here on
;; purpose and commented.  Package management is `use-package' (built in
;; since Emacs 29) over the standard package.el archives.
;;
;; State layout (see early-init.el for the redirects):
;;   ~/.config/emacs/       this file -- symlink into dotfiles, git-tracked
;;   ~/.local/share/emacs/  installed packages + no-littering var/
;;   ~/.cache/emacs/        native-compilation cache
;;
;; Modelled loosely on Doom's module choices, minus the framework:
;;   :emacs    dired, undo, vc      :checkers  spell, syntax
;;   :tools    magit                :lang      latex (+cdlatex), org
;; Intentionally omitted for now: evil, and the vertico/orderless/
;; marginalia completion stack -- learning the built-ins first.

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
  (load custom-file 'noerror 'nomessage))

;; --- Sensible built-in defaults -----------------------------------------
;; No packages here -- this is Emacs teaching you what Emacs is.

(setq inhibit-startup-screen t
      initial-scratch-message nil
      ring-bell-function #'ignore         ; no beep
      use-short-answers t                 ; y/n instead of yes/no
      sentence-end-double-space nil)      ; prose: single space ends a sentence

(setq-default indent-tabs-mode nil
              fill-column 80)

;; Native-comp is on in the Arch emacs-wayland build; don't pop its async
;; warnings buffer while you write.
(setq native-comp-async-report-warnings-errors 'silent)

(electric-pair-mode 1)                    ; auto-close brackets and $...$
(savehist-mode 1)                         ; persist minibuffer history
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

;; --- Undo (:emacs undo) -------------------------------------------------
;; Linear, predictable undo/redo instead of Emacs's undo-ring.

(use-package undo-fu
  :init (global-unset-key (kbd "C-z"))    ; was suspend-frame; reclaim it
  :bind (("C-z"   . undo-fu-only-undo)
         ("C-S-z" . undo-fu-only-redo)))

;; --- Spell + syntax checking (:checkers spell / syntax) -----------------
;; Both are built in.  Flyspell needs `aspell' (+ a dictionary) on PATH.

(setq ispell-program-name (or (executable-find "aspell")
                              (executable-find "hunspell")))
(add-hook 'text-mode-hook #'flyspell-mode)
(add-hook 'prog-mode-hook #'flyspell-prog-mode)
(add-hook 'prog-mode-hook #'flymake-mode)

;; --- Git (:tools magit) -------------------------------------------------

(use-package magit
  :defer t
  :bind ("C-x g" . magit-status))

;; --- LaTeX (:lang latex +cdlatex) ---------------------------------------
;; AUCTeX + CDLaTeX, wired to latexmk and zathura so it matches your
;; existing nvim/latexmk/zathura flow.

(use-package tex
  :ensure auctex
  :defer t                                ; loads on first .tex file
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

;; --- Live math preview (xenops) -----------------------------------------
;; Renders every math fragment ($...$, \(...\), \[...\], and equation
;; environments) as an inline SVG, and re-renders as you type -- the "live
;; preview" you wanted, in *both* LaTeX and Org.  Move point into a fragment
;; and it reveals the source to edit; move out and it re-renders.  Needs
;; dvisvgm (already on PATH).  If it ever feels heavy on a big .tex file,
;; drop the LaTeX-mode hook and toggle it by hand with `M-x xenops-mode'.
(use-package xenops
  :hook ((LaTeX-mode . xenops-mode)
         (org-mode   . xenops-mode))
  :config
  (setq xenops-math-image-scale-factor 1.4))   ; a touch larger than the text

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
  (setq org-directory "~/org/"
        org-agenda-files '("~/org/")      ; scan every .org in here for the agenda
        org-startup-folded 'overview      ; files open collapsed to top headings
        org-startup-with-inline-images t  ; render ![[image]] embeds inline (Obsidian-like)
        org-image-actual-width '(500)     ; cap oversized inline images at 500px
        org-hide-emphasis-markers t       ; show *bold* / italic rendered, hide the markers
        org-log-done 'time                ; stamp the time when a TODO -> DONE
        org-todo-keywords
        '((sequence "TODO" "NEXT" "WAITING" "|" "DONE" "CANCELLED")))
  :config
  (setq org-capture-templates
        '(("t" "Task" entry (file+headline "~/org/inbox.org" "Tasks")
           "* TODO %?\n  %U\n" :empty-lines 1)
          ("n" "Note" entry (file+headline "~/org/inbox.org" "Notes")
           "* %?\n  %U\n" :empty-lines 1))))

;; org-appear complements `org-hide-emphasis-markers' above: the markers are
;; hidden for clean, rendered text, but re-appear around the span your cursor
;; is on so you can still edit them -- Obsidian-style live preview.
(use-package org-appear
  :hook (org-mode . org-appear-mode)
  :init (setq org-appear-autolinks t))    ; also reveal [[link]] syntax on entry

;; --- Prose writing environment (variable-pitch + centered) --------------
;; Goal: Org, Markdown and LaTeX read like a page, not a terminal.
;;   * a proportional (variable-pitch) body font -- Noto Serif
;;   * mixed-pitch keeps code, tables, verbatim and math monospaced so they
;;     still align; only prose text goes proportional
;;   * olivetti centers the text in a comfortable measure
;; Line numbers are already off in these modes (only prog-mode turns them on).

;; The proportional face used for prose.  Swap the :family to taste.
(set-face-attribute 'variable-pitch nil :family "Noto Serif" :height 1.0)

(use-package mixed-pitch
  :hook ((org-mode      . mixed-pitch-mode)
         (markdown-mode . mixed-pitch-mode)
         (LaTeX-mode    . mixed-pitch-mode)))

(use-package olivetti
  :hook ((org-mode      . olivetti-mode)
         (markdown-mode . olivetti-mode)
         (LaTeX-mode    . olivetti-mode))
  :init (setq olivetti-body-width 72))    ; text column width, in columns

;; The "slight gray vertical bars" beside the text are the window fringes;
;; blend them into the background so they disappear (indicators still work).
(set-face-attribute 'fringe nil :background 'unspecified)

;; --- Notes navigator (treemacs) -----------------------------------------
;; A collapsible file-tree side pane, like Obsidian's explorer, for the
;; ~/Dropbox/notes vault.  Rendered in the proportional font (not monospace),
;; with pixel-based indentation so nesting stays aligned under a variable-
;; width font.  C-c t opens the vault; <f8> is a plain toggle.
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
        treemacs-indentation '(6 px))     ; pixel indent: aligns under Noto Serif
  (treemacs-follow-mode 1)                ; keep the tree on the file you're editing
  ;; Proportional font inside the tree buffer.
  (add-hook 'treemacs-mode-hook
            (lambda () (buffer-face-set 'variable-pitch))))

;; --- Markdown (any notes you keep as .md) -------------------------------
;; The vault is Org now, but markdown-mode covers any stray .md.  It inherits
;; the proportional font + centering from the hooks above.
(use-package markdown-mode
  :mode ("\\.md\\'" . markdown-mode)
  :init (setq markdown-command "pandoc"))

;; --- Optional next steps (left off on purpose) --------------------------
;; When you want them:
;;   * citar      -- richer bibliography UI than RefTeX          (:tools biblio)
;;   * pdf-tools  -- view/annotate PDFs in Emacs; compiles epdfinfo on
;;                   first use, needs poppler-glib.  zathura already
;;                   covers viewing, so this is optional.
;;   * vertico + orderless + marginalia -- the completion stack, once
;;     you've outgrown the built-in *Completions* buffer.
;;   * a theme that follows Omarchy -- Emacs won't auto-track the omarchy
;;     theme; wiring that up is its own small project.

;;; init.el ends here
