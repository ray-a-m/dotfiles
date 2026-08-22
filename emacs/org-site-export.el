;;; org-site-export.el --- HTML export for the org-authored website -*- lexical-binding: t; -*-

;; The website (raymondmaung.com) is authored in Org, one file per page,
;; in ~/scholarship/website (a private repo, sibling of research-wip).
;; Export writes finished HTML pages STRAIGHT into the research-public
;; working tree, which GitHub Pages serves -- no generated artifact ever
;; lands in the website repo, and the research-public tree doubles as
;; the local preview root (where the relative PDF links resolve):
;;
;;   website/about.org        -> research-public/index.html
;;   website/<name>.org       -> research-public/<name>/index.html
;;   website/<dir>/<name>.org -> research-public/<dir>/<name>/index.html
;;
;; The /<name>/index.html shape preserves the WordPress-era URLs
;; (/research/, /teaching/, ...); the <dir> case costs nothing now and
;; lets a section grow subpages later with no exporter change.  The
;; home page is the About page: its source is named for what it says
;; (about.org, so the sidebar reads right) and `rm/org-site-home-page'
;; maps it to the root index.html the server needs.
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

(defconst rm/org-sites
  '(("site"
     :source "~/scholarship/website/"
     :output "~/scholarship/research-public/"
     :home   "about")
    ("ring"
     :source "~/projects/philwebring/site/"
     :output "~/projects/philwebring/public/"
     :home   "index"))
  "Every org-authored site, keyed by the name `publish' takes.

Each entry carries three paths:

  :source  root of the .org page sources
  :output  where the generated HTML lands
  :home    basename of the page that becomes the site root index.html

The two sites differ in what serves the output.  raymondmaung.com
exports into the research-public working tree, which GitHub Pages
serves, so its output is committed.  philwebring.org exports into a
gitignored build directory that `publish ring' rsyncs to the homelab,
so its output is never committed -- the server is the only consumer.

One exporter covers both because a page is only its body: everything
site-specific lives in that site's own shared/template.html and
shared/style.css.  The published-papers and cv-body tokens are
personal-site features, but they are token-driven, so a page that
does not emit the token is simply unaffected.")

;; The three paths of the site currently exporting.  Every entry point
;; binds them from `rm/org-sites' (see `rm/org-site--with-site'), so the
;; mapping and template code below reads one site's paths without
;; knowing which site it is.
(defvar rm/org-site-source-root nil
  "Root of the org page sources for the site currently exporting.")

(defvar rm/org-site-output-root nil
  "Where the generated pages land for the site currently exporting.")

(defvar rm/org-site-home-page nil
  "Basename of the top-level page that exports to the site root.
That page becomes /index.html; every other <name>.org becomes
/<name>/index.html.  Mirrored in the publish shell function.")

(defun rm/org-site-root (site key)
  "Expanded KEY path (`:source' or `:output') of SITE in `rm/org-sites'."
  (let ((entry (or (cdr (assoc site rm/org-sites))
                   (user-error "site: no such site %S" site))))
    (expand-file-name (plist-get entry key))))

(defun rm/org-site-for-file (file)
  "Name of the site whose :source root contains FILE, or nil.
shared/ holds config -- template, css, fonts -- not pages, so a file
under it belongs to no site."
  (and file
       (string-match-p "\\.org\\'" file)
       (not (string-match-p "/shared/" file))
       (car (seq-find (lambda (entry)
                        (string-prefix-p (rm/org-site-root (car entry) :source)
                                         (expand-file-name file)))
                      rm/org-sites))))

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

;; --- CV page: the CV body, translated from its LaTeX source -------------

(defconst rm/org-site--cv-org
  (expand-file-name "~/scholarship/research-wip/documents/cv/cv.org")
  "The CV's authored source.  The website CV page embeds this content
as HTML, so the page cannot drift from the published PDF -- the
\\papertitle mechanism, extended to a whole document body.")

(defun rm/org-site--cv-latex ()
  "The LaTeX body of the CV: the content of cv.org's export block."
  (unless (file-readable-p rm/org-site--cv-org)
    (user-error "site: no CV source at %s" rm/org-site--cv-org))
  (with-temp-buffer
    (insert-file-contents rm/org-site--cv-org)
    (goto-char (point-min))
    (unless (re-search-forward "^#\\+begin_export latex$" nil t)
      (user-error "site: no latex export block in %s" rm/org-site--cv-org))
    (let ((start (1+ (point))))
      (unless (re-search-forward "^#\\+end_export" nil t)
        (user-error "site: unterminated export block in %s" rm/org-site--cv-org))
      (buffer-substring-no-properties start (match-beginning 0)))))

(defun rm/org-site--cv-args (n)
  "Read N brace-delimited arguments, starting at point.
Whitespace may precede each argument (a stripped %-continuation leaves
a newline).  Leaves point after the last closing brace."
  (let (args)
    (dotimes (_ n)
      (skip-chars-forward " \t\n")
      (unless (eq (char-after) ?{)
        (user-error "site: CV translator expected a { argument at %d" (point)))
      (forward-char 1)
      (push (rm/org-site--brace-content) args))
    (nreverse args)))

(defun rm/org-site--cv-rr (regexp rep &optional literal)
  "Replace every match of REGEXP in the buffer with REP.
LITERAL as in `replace-match' -- pass t when REP contains & or \\."
  (goto-char (point-min))
  (while (re-search-forward regexp nil t)
    (replace-match rep t literal)))

(defun rm/org-site--cv-html ()
  "The CV's LaTeX body as an HTML fragment.
Translates exactly the vocabulary the CV is known to use -- the
\\entry family of cv/preamble.tex plus standard inline LaTeX -- and
refuses anything else loudly, like the title translation above: a
silently mangled CV on the public site is worse than a failed export.
A new macro in cv.org must get a clause here before it publishes."
  (with-temp-buffer
    (insert (rm/org-site--cv-latex))
    ;; comments, including the %-continuations before wrapped arguments
    (rm/org-site--cv-rr "\\([^\\\n]\\|^\\)%.*" "\\1")
    ;; the centered name/contact header is print furniture: on paper the
    ;; CV travels alone; on the site the nav and Contact page carry it,
    ;; and the linked PDF keeps the full header
    (rm/org-site--cv-rr "\\\\begin{center}\\(?:.\\|\n\\)*?\\\\end{center}" "" t)
    ;; print-only formatting: page style, glue, and the
    ;; {\setlength{\parskip}{..} .. \par} spacing groups
    (rm/org-site--cv-rr "\\\\thispagestyle{[^{}]*}" "" t)
    (rm/org-site--cv-rr "\\\\vspace\\*?{[^{}]*}" "" t)
    (rm/org-site--cv-rr "\\\\medskip\\_>" "" t)
    (rm/org-site--cv-rr "{\\\\setlength{\\\\parskip}{[^{}]*}" "" t)
    (rm/org-site--cv-rr "\\\\par[ \t]*}" "" t)
    ;; environments
    (rm/org-site--cv-rr "\\\\begin{detaillist}" "<ul class=\"cv-details\">" t)
    (rm/org-site--cv-rr "\\\\end{detaillist}" "</ul>" t)
    ;; items; \hfill splits an item into a left part and a date column
    (rm/org-site--cv-rr
     "^[ \t]*\\\\item[ \t]+\\(.*?\\)[ \t]*\\\\hfill[ \t]*\\(.*\\)$"
     "<li><span>\\1</span><span class=\"cv-date\">\\2</span></li>")
    (rm/org-site--cv-rr "^[ \t]*\\\\item[ \t]+\\(.*\\)$" "<li>\\1</li>")
    ;; the \entry family: brace-aware, arguments may nest braces
    (goto-char (point-min))
    (while (re-search-forward
            "\\\\\\(section\\|entry\\|plainentry\\|wipentry\\|presentation\\|subline\\)\\_>"
            nil t)
      (let* ((cmd (match-string 1))
             (start (match-beginning 0))
             (args (rm/org-site--cv-args
                    (pcase cmd ("presentation" 3)
                          ((or "section" "subline") 1) (_ 2))))
             (html
              (pcase cmd
                ("section" (format "<h2>%s</h2>" (car args)))
                ("subline" (format "<p class=\"cv-subline\">%s</p>" (car args)))
                ("entry"
                 (format "<p class=\"cv-entry\"><span>%s</span><span class=\"cv-date\">%s</span></p>"
                         (nth 0 args) (nth 1 args)))
                ("plainentry"
                 (format "<p class=\"cv-entry cv-sub\"><span>%s</span><span class=\"cv-date\">%s</span></p>"
                         (nth 0 args) (nth 1 args)))
                ("wipentry"
                 (format "<p class=\"cv-entry cv-sub\"><span>%s</span><span class=\"cv-date\"><em>%s</em></span></p>"
                         (nth 0 args) (nth 1 args)))
                ("presentation"
                 (format "<div class=\"cv-pres\"><p class=\"cv-entry\"><span>%s</span><span class=\"cv-date\">%s</span></p><p class=\"cv-venue\">%s</p></div>"
                         (nth 0 args) (nth 1 args) (nth 2 args))))))
        (delete-region start (point))
        (goto-char start)
        (insert html)))
    ;; inline LaTeX: \papertitle resolves like the Research page titles
    (goto-char (point-min))
    (while (re-search-forward "\\\\papertitle[ \t]*{\\([^{}]+\\)}" nil t)
      ;; not replace-match: the title lookup runs searches of its own,
      ;; which clobber the match data
      (let ((beg (match-beginning 0))
            (end (match-end 0))
            (title (rm/org-site--paper-title (match-string 1))))
        (delete-region beg end)
        (goto-char beg)
        (insert title)))
    (rm/org-site--cv-rr "\\\\href{\\([^{}]*\\)}{\\([^{}]*\\)}"
                        "<a href=\"\\1\">\\2</a>")
    (rm/org-site--cv-rr "\\\\textbf{\\([^{}]*\\)}" "<strong>\\1</strong>")
    (rm/org-site--cv-rr "\\\\\\(?:emph\\|textit\\){\\([^{}]*\\)}" "<em>\\1</em>")
    ;; breaks and glue -- \\ before \SPACE, or the pair matches wrong
    (rm/org-site--cv-rr "\\\\\\\\\\(?:\\[[0-9]+pt\\]\\)?" "<br>" t)
    (rm/org-site--cv-rr "\\\\quad\\_>" "&emsp;" t)
    (rm/org-site--cv-rr "\\\\ " " " t)
    (rm/org-site--cv-rr "\\\\\\([&%$#_]\\)" "\\1")
    ;; bare {..} groups that remain are pure grouping: unwrap.  A group
    ;; that still holds a backslash stays, so the guard names it.
    (rm/org-site--cv-rr "{\\([^{}\\]*\\)}" "\\1")
    ;; typography, as LaTeX would print it
    (rm/org-site--cv-rr "---" "&mdash;" t)
    (rm/org-site--cv-rr "--" "&ndash;" t)
    (rm/org-site--cv-rr "``" "&ldquo;" t)
    (rm/org-site--cv-rr "''" "&rdquo;" t)
    ;; the loud refusal
    (goto-char (point-min))
    (when (search-forward "\\" nil t)
      (user-error "site: unhandled LaTeX in CV body: %s"
                  (string-trim
                   (buffer-substring-no-properties
                    (line-beginning-position) (line-end-position)))))
    ;; the wrapper is style.css's hook for CV-wide styling (font step-down)
    (concat "<div class=\"cv\">\n" (string-trim (buffer-string)) "\n</div>")))

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

(defun rm/org-site--expand-cv-body (output _backend _info)
  "Replace the <!-- cv-body --> token with the translated CV body."
  (if (string-match-p "<!-- cv-body -->" output)
      (replace-regexp-in-string "<!-- cv-body -->"
                                (rm/org-site--cv-html)
                                output t t)
    output))

(defun rm/org-site--filter-final-output (output backend info)
  "The backend's single final-output pass, order explicit: strip the
random ids, expand the published-papers and cv-body tokens, normalise
to exactly one trailing newline."
  (concat (string-trim-right
           (rm/org-site--expand-cv-body
            (rm/org-site--expand-published-papers
             (rm/org-site--strip-random-ids output backend info)
             backend info)
            backend info))
          "\n"))

(org-export-define-derived-backend 'site-html 'html
  :filters-alist '((:filter-final-output . rm/org-site--filter-final-output)))

;; --- source -> output mapping -------------------------------------------

(defun rm/org-site-buffer-p ()
  "Name of the site the current buffer is a page of, or nil.
Pages only -- shared/ holds config (template, css, fonts), not pages.
Returns the site NAME rather than t, so callers that must bind the
site's roots get them from the same test that gated them."
  (rm/org-site-for-file buffer-file-name))

(defun rm/org-site--output-file (org-file)
  "The generated HTML page ORG-FILE exports to.
The home page (`rm/org-site-home-page') becomes the root index.html;
any other name becomes a directory with an index.html inside, so /name/
serves it (the WordPress-era URLs)."
  (let* ((rel (file-relative-name org-file rm/org-site-source-root))
         (sans (file-name-sans-extension rel)))
    (expand-file-name
     (if (string= sans rm/org-site-home-page)
         "index.html"
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
written to its own site's output location (uncommitted -- the matching
`publish' target is the gate that deploys)."
  (interactive)
  (let* ((site (or (rm/org-site-buffer-p)
                   (user-error "Not a website page (%s)" buffer-file-name)))
         ;; Dynamic: the mapping and template helpers below read these
         ;; rather than taking the site as an argument.
         (rm/org-site-source-root (rm/org-site-root site :source))
         (rm/org-site-output-root (rm/org-site-root site :output))
         (rm/org-site-home-page
          (plist-get (cdr (assoc site rm/org-sites)) :home))
         (src buffer-file-name)
         (out (rm/org-site--output-file src))
         (rm/org-site--current-root (rm/org-site--root src))
         (rel (file-relative-name out rm/org-site-output-root))
         ;; the page's site path: "" for the front page, "research/" ...
         (nav-path (if (string= rel "index.html") "" (file-name-directory rel)))
         (title (or (cadr (assoc "TITLE" (org-collect-keywords '("TITLE"))))
                    (user-error "site: %s needs a #+TITLE" src)))
         (body (org-export-as 'site-html nil nil t))
         (html (rm/org-site--template)))
    ;; mark the nav link that targets this page (before the token
    ;; substitution, so the href still carries the ROOT token exactly);
    ;; style.css underlines the marked link.  A subpage with no nav
    ;; link simply matches nothing.
    (setq html (replace-regexp-in-string
                (concat "href=\"{{ROOT}}" (regexp-quote nav-path) "\"")
                (concat "aria-current=\"page\" href=\"{{ROOT}}" nav-path "\"")
                html t t))
    ;; literal substitution (t t): titles and bodies may contain \ or &
    (dolist (pair `(("{{TITLE}}" . ,title)
                    ("{{ROOT}}"  . ,rm/org-site--current-root)
                    ("{{BODY}}"  . ,body)))
      (setq html (replace-regexp-in-string (regexp-quote (car pair))
                                           (cdr pair) html t t)))
    (make-directory (file-name-directory out) t)
    (write-region html nil out nil 'silent)
    (message "%s: %s" site (file-relative-name out rm/org-site-output-root))))

(defun rm/org-site-export-file (file)
  "Batch entry point (used by the publish shell function): export FILE."
  (with-current-buffer (find-file-noselect file)
    (rm/org-site-export)))

(provide 'org-site-export)
;;; org-site-export.el ends here
