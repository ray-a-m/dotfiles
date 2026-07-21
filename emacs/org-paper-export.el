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

(defun rm/org-paper--final-newlines (output _backend _info)
  "End the generated body with exactly one blank line.
The final paragraph must terminate INSIDE the generated file: ending
flush at EOF leaves the paragraph open, and the driver's newline after
\\input contributes a stray space token that can reflow the last line
\(observed on friedman's Conclusion, 2026-07-20)."
  (concat (string-trim-right output) "\n\n"))

(org-export-define-derived-backend 'paper-latex 'latex
  :translate-alist '((latex-math-block . rm/org-paper--math-block))
  :filters-alist '((:filter-headline . rm/org-paper--strip-section-labels)
                   (:filter-final-output . rm/org-paper--final-newlines)))

(defun rm/org-paper-buffer-p ()
  "Non-nil when the current buffer is an org-authored research document:
a paper's paper.org, or the dissertation's frontmatter/introduction.org."
  (and buffer-file-name
       (string-match-p
        "/documents/\\(?:papers/[^/]+/paper\\|dissertation/frontmatter/introduction\\)\\.org\\'"
        buffer-file-name)))

(defun rm/org-paper--output-name ()
  "The generated .tex this buffer exports to: papers write body.tex
\(the name their paper.tex driver \\input's), anything else writes its
own basename (introduction.org -> introduction.tex)."
  (if (string= (file-name-nondirectory buffer-file-name) "paper.org")
      "body.tex"
    (concat (file-name-base buffer-file-name) ".tex")))

(defun rm/org-paper-export ()
  "Export the current org document to its generated .tex, body only.
The output name is derived, never from EXPORT_FILE_NAME: it can't
clobber a driver."
  (interactive)
  (org-export-to-file 'paper-latex (rm/org-paper--output-name) nil nil nil t))

(defun rm/org-paper-export-file (file)
  "Batch entry point (used by the publish shell function): export FILE."
  (with-current-buffer (find-file-noselect file)
    (rm/org-paper-export)))

(defun rm/org-paper-compile ()
  "Export the generated .tex, then latexmk its driver (C-c C-c parity
with the AUCTeX latexmk binding).  Papers build paper.tex beside the
org file; the introduction builds dissertation.tex one level up.  For
`org-ctrl-c-ctrl-c-final-hook': returns non-nil in paper buffers so
the fallthrough stops here."
  (when (rm/org-paper-buffer-p)
    (rm/org-paper-export)
    (let* ((dir (file-name-directory buffer-file-name))
           (default-directory (if (file-exists-p (expand-file-name "paper.tex" dir))
                                  dir
                                (expand-file-name ".." dir)))
           (driver (if (file-exists-p (expand-file-name "paper.tex" dir))
                       "paper.tex"
                     "dissertation.tex")))
      (compile (format "latexmk -pdf -interaction=nonstopmode -halt-on-error %s"
                       driver)))
    t))

(provide 'org-paper-export)
;;; org-paper-export.el ends here
