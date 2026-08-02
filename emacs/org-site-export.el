;;; org-site-export.el --- HTML export for the org-authored website -*- lexical-binding: t; -*-

;; The website (raymondmaung.com) is authored in Org, one file per page,
;; in ~/scholarship/website (a private repo, sibling of research-wip).
;; Export writes finished HTML pages STRAIGHT into the research-public
;; working tree, which GitHub Pages serves -- no generated artifact ever
;; lands in the website repo, and the research-public tree doubles as
;; the local preview root (where the relative PDF links resolve):
;;
;;   website/index.org        -> research-public/index.html
;;   website/<name>.org       -> research-public/<name>/index.html
;;   website/<dir>/<name>.org -> research-public/<dir>/<name>/index.html
;;
;; The /<name>/index.html shape preserves the WordPress-era URLs
;; (/research/, /teaching/, ...); the <dir> case costs nothing now and
;; lets a section grow subpages later with no exporter change.
;;
;; A page is its body only.  The document shell -- head, nav, footer --
;; is the hand-written website/shared/template.html (the preamble.tex
;; analog; presentation config stays hand-written on purpose, like
;; shared/style.css beside it).  The exporter substitutes three tokens:
;; {{TITLE}} (the page's #+TITLE), {{ROOT}} (relative prefix back to the
;; site root, so one template serves every depth), {{BODY}}.
;;
;; Bodies export through the site-html backend, derived from stock
;; ox-html with the same determinism rule as the paper-latex backend:
;; ox-html stamps every section with a RANDOM id="orgNNNNNNN" (fresh
;; each export -- `publish site' twice would always diff), so a filter
;; strips them; a CUSTOM_ID survives, exactly like the LaTeX side.
;;
;; Research-page auto-sync: the literal token <!-- published-papers -->
;; (emitted by an #+HTML: line in research.org) is replaced at export
;; time with a list of every PDF in research-public/documents/papers/,
;; each linking the PDF and titled from its paper.org's real \title (the
;; \papertitle mechanism, ported).  Publishing a paper thus updates the
;; page with zero editing; zero published PDFs renders the page bare,
;; matching the old empty WordPress page.
;;
;; Loaded by init.el for interactive use (save-hook re-export, C-c C-c)
;; and by `emacs -Q --batch' from the publish shell function -- keep it
;; free of init.el dependencies.

(require 'ox-html)

(defconst rm/org-site-source-root
  (expand-file-name "~/scholarship/website/")
  "Root of the org-authored website sources.")

(defconst rm/org-site-output-root
  (expand-file-name "~/scholarship/research-public/")
  "Where the generated pages land (the tree GitHub Pages serves).")

(defvar rm/org-site--current-root ""
  "The {{ROOT}} prefix of the page currently exporting.
Bound around the export so output filters (the published-papers list)
can build hrefs relative to the page's own depth.")

;; --- paper titles: research-public PDFs, titled from their paper.org ----

(defun rm/org-site--brace-content ()
  "Content of the brace group whose opening { point sits just after.
Leaves point past the matching }.  Counts nesting, so \\textbf{...} is
safe.  (Duplicated from org-paper-export.el so the batch path stays a
single -l load, like that module's.)"
  (let ((start (point)) (depth 1))
    (while (and (> depth 0) (not (eobp)))
      (pcase (char-after)
        (?{ (setq depth (1+ depth)))
        (?} (setq depth (1- depth))))
      (forward-char 1))
    (buffer-substring-no-properties start (1- (point)))))

(defun rm/org-site--latex-title-to-html (title slug)
  "LaTeX TITLE (from SLUG's paper.org) as an HTML fragment.
Handles exactly what the titles are known to contain -- \\emph{} and
the common escaped characters -- and refuses anything else loudly: a
silently mangled title on the public site is worse than a failed
export."
  (let ((s title))
    ;; \emph{...} -> placeholders (real tags would be eaten by the
    ;; entity-escaping below); non-greedy, no nesting -- a nested brace
    ;; leaves a backslash behind and trips the guard, on purpose.
    (setq s (replace-regexp-in-string
             "\\\\\\(?:emph\\|textit\\){\\([^{}]*\\)}" "\C-a\\1\C-b" s))
    ;; escaped LaTeX specials back to plain characters
    (setq s (replace-regexp-in-string "\\\\\\([&%$#_]\\)" "\\1" s))
    (when (string-match-p "\\\\" s)
      (user-error "site: unhandled LaTeX in \\title of %s: %s" slug s))
    ;; now entity-escape, then let the placeholders become tags
    (setq s (replace-regexp-in-string "&" "&amp;" s))
    (setq s (replace-regexp-in-string "<" "&lt;" s))
    (setq s (replace-regexp-in-string ">" "&gt;" s))
    (setq s (replace-regexp-in-string "\C-a" "<em>" s))
    (setq s (replace-regexp-in-string "\C-b" "</em>" s))
    s))

(defun rm/org-site--paper-title (slug)
  "The \\title of research-wip's papers/SLUG/paper.org, as HTML.
One enclosing \\textbf{...} (which the titles carry) is peeled off --
the same resolution \\papertitle{slug} does on the LaTeX side, so the
site can never drift from the papers."
  (let ((file (expand-file-name
               (format "~/scholarship/research-wip/documents/papers/%s/paper.org"
                       slug))))
    (unless (file-readable-p file)
      (user-error "site: published PDF %s.pdf has no paper.org at %s" slug file))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (unless (re-search-forward "\\\\title[ \t]*{" nil t)
        (user-error "site: no \\title in %s" file))
      (let ((inner (string-trim (rm/org-site--brace-content))))
        (when (string-match "\\`\\\\textbf[ \t]*{" inner)
          (setq inner (with-temp-buffer
                        (insert inner)
                        (goto-char (point-min))
                        (re-search-forward "\\\\textbf[ \t]*{")
                        (string-trim (rm/org-site--brace-content)))))
        (rm/org-site--latex-title-to-html inner slug)))))

(defun rm/org-site--published-papers ()
  "The Research page's list: every published paper PDF, titled from source.
Empty string when nothing is published yet -- the page renders bare,
like the WordPress page it replaces.  Sorted by slug: deterministic,
and the order never depends on filesystem mtime."
  (let ((pdfs (sort (file-expand-wildcards
                     (expand-file-name "documents/papers/*.pdf"
                                       rm/org-site-output-root))
                    #'string<)))
    (if (null pdfs)
        ""
      (concat
       "<ul class=\"papers\">\n"
       (mapconcat
        (lambda (pdf)
          (let ((slug (file-name-base pdf)))
            (format "<li><a href=\"%sdocuments/papers/%s.pdf\">%s</a></li>"
                    rm/org-site--current-root slug
                    (rm/org-site--paper-title slug))))
        pdfs "\n")
       "\n</ul>"))))

;; --- the site-html backend ----------------------------------------------

(defun rm/org-site--strip-random-ids (output _backend _info)
  "Drop ox-html's auto-generated id=\"orgNNN\" attributes from OUTPUT.
Fresh random ids every export would make every `publish site' run
diff; nothing links to them (toc is off).  CUSTOM_ID-derived ids
don't match the org[0-9a-f]+ shape and survive."
  (replace-regexp-in-string
   " id=\"\\(?:outline-container-\\|text-\\)?org[0-9a-f]+\"" "" output))

(defun rm/org-site--expand-published-papers (output _backend _info)
  "Replace the <!-- published-papers --> token with the generated list."
  (if (string-match-p "<!-- published-papers -->" output)
      (replace-regexp-in-string "<!-- published-papers -->"
                                (rm/org-site--published-papers)
                                output t t)
    output))

(defun rm/org-site--filter-final-output (output backend info)
  "The backend's single final-output pass, order explicit: strip the
random ids, expand the published-papers token, normalise to exactly
one trailing newline."
  (concat (string-trim-right
           (rm/org-site--expand-published-papers
            (rm/org-site--strip-random-ids output backend info)
            backend info))
          "\n"))

(org-export-define-derived-backend 'site-html 'html
  :filters-alist '((:filter-final-output . rm/org-site--filter-final-output)))

;; --- source -> output mapping -------------------------------------------

(defun rm/org-site-buffer-p ()
  "Non-nil when the current buffer is a website page source.
Pages only -- shared/ holds config (template, css, fonts), not pages."
  (and buffer-file-name
       (string-prefix-p rm/org-site-source-root buffer-file-name)
       (string-match-p "\\.org\\'" buffer-file-name)
       (not (string-match-p "/shared/" buffer-file-name))))

(defun rm/org-site--output-file (org-file)
  "The generated HTML page ORG-FILE exports to.
index.org keeps its directory; any other name becomes a directory with
an index.html inside, so /name/ serves it (the WordPress-era URLs)."
  (let* ((rel (file-relative-name org-file rm/org-site-source-root))
         (sans (file-name-sans-extension rel)))
    (expand-file-name
     (if (string= (file-name-nondirectory sans) "index")
         (concat sans ".html")
       (concat sans "/index.html"))
     rm/org-site-output-root)))

(defun rm/org-site--root (org-file)
  "The {{ROOT}} prefix for ORG-FILE's page: ../ per directory of depth."
  (let ((rel (file-relative-name (rm/org-site--output-file org-file)
                                 rm/org-site-output-root)))
    (apply #'concat
           (make-list (1- (length (split-string rel "/"))) "../"))))

;; --- export --------------------------------------------------------------

(defun rm/org-site--template ()
  "The shared page shell, as a string."
  (let ((file (expand-file-name "shared/template.html" rm/org-site-source-root)))
    (unless (file-readable-p file)
      (user-error "site: no template at %s" file))
    (with-temp-buffer
      (insert-file-contents file)
      (buffer-string))))

(defun rm/org-site-export ()
  "Export the current page: body through site-html, into the shell,
written to its research-public location (uncommitted -- `publish site'
is the gate that commits and pushes)."
  (interactive)
  (unless (rm/org-site-buffer-p)
    (user-error "Not a website page (%s)" buffer-file-name))
  (let* ((src buffer-file-name)
         (out (rm/org-site--output-file src))
         (rm/org-site--current-root (rm/org-site--root src))
         (title (or (cadr (assoc "TITLE" (org-collect-keywords '("TITLE"))))
                    (user-error "site: %s needs a #+TITLE" src)))
         (body (org-export-as 'site-html nil nil t))
         (html (rm/org-site--template)))
    ;; literal substitution (t t): titles and bodies may contain \ or &
    (dolist (pair `(("{{TITLE}}" . ,title)
                    ("{{ROOT}}"  . ,rm/org-site--current-root)
                    ("{{BODY}}"  . ,body)))
      (setq html (replace-regexp-in-string (regexp-quote (car pair))
                                           (cdr pair) html t t)))
    (make-directory (file-name-directory out) t)
    (write-region html nil out nil 'silent)
    (message "site: %s" (file-relative-name out rm/org-site-output-root))))

(defun rm/org-site-export-file (file)
  "Batch entry point (used by the publish shell function): export FILE."
  (with-current-buffer (find-file-noselect file)
    (rm/org-site-export)))

(provide 'org-site-export)
;;; org-site-export.el ends here
