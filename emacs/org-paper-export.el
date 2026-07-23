;;; org-paper-export.el --- LaTeX export for org-authored research documents -*- lexical-binding: t; -*-

;; Every document in research-wip is authored in Org; the .tex it
;; compiles from are generated build artifacts (gitignored, regenerated
;; on save and by the publish pipeline):
;;
;;   papers/<slug>/paper.org        -> body.tex + paper.tex driver
;;   dissertation/dissertation.org  -> body.tex + dissertation.tex driver
;;   dissertation/frontmatter/*.org -> <name>.tex (\input'ed; no driver)
;;   cv/cv.org                      -> body.tex + maung_cv.tex driver
;;
;; Drivers are templates below -- config, like the hand-written
;; preambles they \input (shared/preamble.tex, dissertation/preamble.tex,
;; cv/preamble.tex stay hand-written LaTeX on purpose).  Per-document
;; facts come from keywords in the org file: #+PAPER_BIB: is the
;; \addbibresource argument (papers), #+LATEX_HEADER: lines are placed
;; verbatim before \begin{document} (the dissertation's title-page
;; fields live there so hyperref's pdfusetitle still sees them).
;;
;; Bodies export through the paper-latex backend, which undoes the two
;; places stock ox-latex rewrites what the hand-written bodies contain:
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

(defun rm/org-paper--doc-type ()
  "Which org-authored research document the current buffer is, or nil."
  (when buffer-file-name
    (let ((f buffer-file-name))
      (cond
       ((string-match-p "/documents/papers/[^/]+/paper\\.org\\'" f) 'paper)
       ((string-match-p "/documents/dissertation/dissertation\\.org\\'" f) 'dissertation)
       ((string-match-p "/documents/dissertation/frontmatter/[^/]+\\.org\\'" f) 'frontmatter)
       ((string-match-p "/documents/cv/cv\\.org\\'" f) 'cv)))))

(defun rm/org-paper-buffer-p ()
  "Non-nil when the current buffer is an org-authored research document."
  (rm/org-paper--doc-type))

(defun rm/org-paper--output-name ()
  "The generated body .tex this buffer exports to.
Driver'd documents write body.tex (the name their driver \\input's);
frontmatter files write their own basename (dedication.org ->
dedication.tex).  The name is derived, never from EXPORT_FILE_NAME:
it can't clobber a source."
  (if (eq (rm/org-paper--doc-type) 'frontmatter)
      (concat (file-name-base buffer-file-name) ".tex")
    "body.tex"))

(defun rm/org-paper--driver-name (type)
  "The driver artifact TYPE compiles from, nil for driverless types."
  (pcase type
    ('paper "paper.tex")
    ('dissertation "dissertation.tex")
    ('cv "maung_cv.tex")))

(defun rm/org-paper--keyword-values (key)
  "All values of the buffer keyword KEY, in order."
  (cdr (assoc key (org-collect-keywords (list key)))))

(defun rm/org-paper--driver-content (type)
  "The driver .tex for TYPE: template + this buffer's keywords."
  (let* ((headers (rm/org-paper--keyword-values "LATEX_HEADER"))
         (header-block (and headers
                            (concat (mapconcat #'identity headers "\n") "\n\n")))
         (document "\\begin{document}\n\n\\input{body.tex}\n\n\\end{document}\n"))
    (pcase type
      ('paper
       (let ((bib (car (rm/org-paper--keyword-values "PAPER_BIB"))))
         (unless bib
           (user-error "paper.org needs #+PAPER_BIB: <\\addbibresource argument>"))
         (concat "\\input{../../shared/preamble.tex}\n"
                 (format "\\addbibresource{%s}\n" bib)
                 "\n" (or header-block "") document)))
      ('dissertation
       (concat "\\documentclass[12pt, reqno, oneside]{amsbook}\n\n"
               "\\input{preamble.tex}\n\n"
               (or header-block "") document))
      ('cv
       (concat "\\input{preamble.tex}\n\n" (or header-block "") document)))))

(defun rm/org-paper--write-driver ()
  "Write this document's driver artifact beside the org file.
Skips driverless types and unchanged content (no mtime churn, so
latexmk -pvc doesn't rebuild for nothing)."
  (let ((type (rm/org-paper--doc-type)))
    (when-let* ((name (rm/org-paper--driver-name type)))
      (let ((path (expand-file-name name (file-name-directory buffer-file-name)))
            (content (rm/org-paper--driver-content type)))
        (unless (and (file-exists-p path)
                     (string= content (with-temp-buffer
                                        (insert-file-contents path)
                                        (buffer-string))))
          (write-region content nil path))))))

(defun rm/org-paper-export ()
  "Export the current org document to its generated .tex artifacts:
the body (through the paper-latex backend) and, for driver'd types,
the driver."
  (interactive)
  (org-export-to-file 'paper-latex (rm/org-paper--output-name) nil nil nil t)
  (rm/org-paper--write-driver))

(defun rm/org-paper-export-file (file)
  "Batch entry point (used by the publish shell function): export FILE."
  (with-current-buffer (find-file-noselect file)
    (rm/org-paper-export)))

(defun rm/org-paper--build-target ()
  "(DIR . DRIVER) latexmk should build for the current buffer.
Frontmatter files build the dissertation one level up."
  (let ((type (rm/org-paper--doc-type))
        (dir (file-name-directory buffer-file-name)))
    (if (eq type 'frontmatter)
        (cons (file-name-directory (directory-file-name dir)) "dissertation.tex")
      (cons dir (rm/org-paper--driver-name type)))))

(defun rm/org-paper-compile ()
  "Export the generated .tex, then latexmk the driver (C-c C-c parity
with the AUCTeX latexmk binding).  For `org-ctrl-c-ctrl-c-final-hook':
returns non-nil in research-document buffers so the fallthrough stops
here."
  (when (rm/org-paper-buffer-p)
    (rm/org-paper-export)
    (pcase-let* ((`(,dir . ,driver) (rm/org-paper--build-target))
                 (default-directory dir))
      (compile (format "latexmk -pdf -interaction=nonstopmode -halt-on-error %s"
                       driver)))
    t))

(defun rm/org-paper-watch ()
  "Continuous preview: latexmk -pvc on this document's driver.
Each save re-exports the artifacts (after-save hook), -pvc notices and
rebuilds, the PDF viewer refreshes -- the vimtex flow, one indirection
deeper.  Kill the *paper-watch* buffer to stop."
  (interactive)
  (unless (rm/org-paper-buffer-p)
    (user-error "Not an org-authored research document"))
  (rm/org-paper-export)
  (pcase-let* ((`(,dir . ,driver) (rm/org-paper--build-target))
               (default-directory dir))
    (async-shell-command
     (format "latexmk -pvc -pdf -interaction=nonstopmode %s" driver)
     (format "*paper-watch: %s*"
             (file-name-nondirectory (directory-file-name dir))))))

(provide 'org-paper-export)
;;; org-paper-export.el ends here
