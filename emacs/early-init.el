;;; early-init.el --- Loaded before package.el and the first frame  -*- lexical-binding: t; -*-
;;
;; Emacs 27+ reads this file *before* init.el, before the package system
;; is brought up, and before the first GUI frame is drawn.  Two kinds of
;; thing belong here:
;;
;;   1. Startup performance tuning.  Emacs startup time is dominated by
;;      garbage collection and by running every filename through
;;      `file-name-handler-alist'.  We switch both off for the duration
;;      of startup and restore sane values on `emacs-startup-hook'.  This
;;      is the same trick that makes frameworks like Doom start quickly.
;;
;;   2. Anything that must happen before a frame exists (UI chrome), so
;;      it is never drawn and then removed -- no flash on screen.

;;; Code:

;; --- Startup performance -------------------------------------------------

;; Never stop to collect garbage while loading; restored below.
(setq gc-cons-threshold most-positive-fixnum)

;; Consulted for *every* file Emacs touches, including each .el/.elc it
;; loads at startup.  Stash it, empty it, restore it afterwards.
(defvar rm--file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)

;; Prefer a newer .el over a stale .elc.
(setq load-prefer-newer t)

(add-hook 'emacs-startup-hook
          (lambda ()
            ;; Steady-state GC: 16 MiB balances pause length vs. frequency.
            (setq gc-cons-threshold (* 16 1024 1024)
                  gc-cons-percentage 0.1)
            (setq file-name-handler-alist rm--file-name-handler-alist)))

;; --- Keep runtime junk out of the (git-tracked) config dir --------------
;;
;; ~/.config/emacs is a symlink into the dotfiles repo, so Emacs must not
;; write installed packages or caches into it.  Redirect the two big ones
;; here; `no-littering' (in init.el) handles the long tail.

(setq package-user-dir
      (expand-file-name "emacs/elpa/"
                        (or (getenv "XDG_DATA_HOME") "~/.local/share")))

(when (fboundp 'startup-redirect-eln-cache)   ; native-comp cache (Emacs 29+)
  (startup-redirect-eln-cache
   (expand-file-name "emacs/eln-cache/"
                     (or (getenv "XDG_CACHE_HOME") "~/.cache"))))

;; We drive package.el from init.el via use-package, so don't also let it
;; auto-activate every installed package at startup (init.el re-inits it).
(setq package-enable-at-startup nil)

;; --- Frame / UI chrome (set before the first frame is drawn) ------------

(setq default-frame-alist '((menu-bar-lines . 0)
                            (tool-bar-lines . 0)
                            (vertical-scroll-bars . nil)
                            (horizontal-scroll-bars . nil)))
(setq menu-bar-mode nil
      tool-bar-mode nil
      scroll-bar-mode nil)

;; Don't resize the frame when UI pixel dimensions change during startup.
(setq frame-inhibit-implied-resize t)

;;; early-init.el ends here
