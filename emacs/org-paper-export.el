;;; org-paper-export.el --- body-only LaTeX export for research papers -*- lexical-binding: t; -*-

;; Papers in research-wip are authored in Org (paper.org) and exported
;; body-only to the body.tex their 8-line paper.tex driver \input's -- the
;; driver, shared preamble, bibs, dissertation \inputpaperbody, and the
;; publish pipeline never change.  The whole point is byte-comparable
;; output, so this backend undoes the two places stock ox-latex rewrites
;; what the hand-written bodies contain:
;;
;;   * inline math: org-latex-math-block re-wraps $x$ as \(x\) -- the
;;     bodies are written with $...$, so emit that instead
;;   * section labels: org-latex-headline unconditionally appends a
;;     RANDOM \label{sec:orgNNNNNNN} (org-latex--label with FORCE) --
;;     absent from the bodies and nondeterministic across exports, so a
;;     headline filter strips them
;;
;; Shared export options (tasks:nil, ':nil, -:nil, ^:nil, ...) live in
;; research-wip/documents/shared/org-paper.setup, mirroring the shared
;; preamble.tex philosophy.  Loaded by init.el for interactive use and by
;; `emacs -Q --batch' from the publish shell function -- keep it free of
;; init.el dependencies.

(require 'ox-latex)

(defun rm/org-paper--math-block (_math-block contents _info)
  "Transcode an inline math block back to $...$ (stock emits \\(...\\))."
  (when (org-string-nw-p contents)
    (format "$%s$" (org-trim contents))))

(defun rm/org-paper--strip-section-labels (headline _backend _info)
  "Drop the auto-generated \\label{sec:orgNNN} line from HEADLINE."
  (replace-regexp-in-string "\\\\label{sec:org[0-9a-f]+}\n" "" headline))

(org-export-define-derived-backend 'paper-latex 'latex
  :translate-alist '((latex-math-block . rm/org-paper--math-block))
  :filters-alist '((:filter-headline . rm/org-paper--strip-section-labels)))

(defun rm/org-paper-buffer-p ()
  "Non-nil when the current buffer is a research-wip paper.org."
  (and buffer-file-name
       (string-match-p "/documents/papers/[^/]+/paper\\.org\\'"
                       buffer-file-name)))

(defun rm/org-paper-export ()
  "Export the current paper.org to body.tex beside it, body only.
The output name is hardcoded: it can never clobber the paper.tex
driver, whatever EXPORT_FILE_NAME says."
  (interactive)
  (org-export-to-file 'paper-latex "body.tex" nil nil nil t))

(defun rm/org-paper-export-file (file)
  "Batch entry point (used by the publish shell function): export FILE."
  (with-current-buffer (find-file-noselect file)
    (rm/org-paper-export)))

(defun rm/org-paper-compile ()
  "Export body.tex, then latexmk the paper.tex driver (C-c C-c parity
with the AUCTeX latexmk binding).  For `org-ctrl-c-ctrl-c-final-hook':
returns non-nil in paper buffers so the fallthrough stops here."
  (when (rm/org-paper-buffer-p)
    (rm/org-paper-export)
    (let ((default-directory (file-name-directory buffer-file-name)))
      (compile "latexmk -pdf -interaction=nonstopmode -halt-on-error paper.tex"))
    t))

(provide 'org-paper-export)
;;; org-paper-export.el ends here
