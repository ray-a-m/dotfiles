# Force Firefox/LibreWolf to use native Wayland when launched from a shell.
# Hyprland's envs.conf already sets this for keybind-launched apps; this
# covers the terminal-launch case.
export MOZ_ENABLE_WAYLAND=1

# Default browser for tools that consult $BROWSER (some CLIs, email/PWA
# clients) instead of xdg-open. xdg-mime already routes http/https to
# librewolf.desktop; this closes the env-var fallback path.
export BROWSER=librewolf

# Route omarchy-capture-screenshot output into a Screenshots/ subdir so
# the parent ~/Pictures/ stays available for other images. The script
# auto-creates the dir if missing.
export OMARCHY_SCREENSHOT_DIR="$HOME/Pictures/Screenshots"

# Point TeX at the dotfiles-tracked texmf tree instead of the default
# ~/texmf location. Keeps every package (currently maungstyle.sty) in
# version control without a per-machine symlink-scaffolding step.
# install.sh runs mktexlsr against this path on each install to refresh
# the gitignored ls-R cache.
export TEXMFHOME="$HOME/code/dotfiles/texmf"

# Per-machine secrets (API keys, etc.) — never tracked in dotfiles. Create
# ~/.config/secrets.env with `export FOO=bar` lines, chmod 600. Sourced
# silently if present; absent on machines where it's not needed.
[ -f "$HOME/.config/secrets.env" ] && source "$HOME/.config/secrets.env"

# Scholarship shortcuts
alias scholarship="cd ~/scholarship"
alias wip="cd ~/scholarship/research-wip"
alias pub="cd ~/scholarship/research-public"
alias dots="cd ~/code/dotfiles"

# eza — modern ls. Dir-first sorting matches muscle memory; ll/la add
# git-status columns so dirty subdirs surface while cd-hopping between
# paper folders. `l` is a plain ls-lite for quick scans. Guarded so
# fresh machines without eza fall through to coreutils ls until eza
# is installed (install.sh's Arch pacman line pulls it in for Arch).
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --group-directories-first'
    alias l='eza'
    alias ll='eza -l --git --group-directories-first'
    alias la='eza -la --git --group-directories-first'
    alias lt='eza --tree --level=2 --group-directories-first'
fi

# Restart the wallpaper (mpvpaper for video themes, swaybg otherwise) by
# re-running the omarchy theme-set hook. Instant recovery when mpvpaper
# crashes; wallpaper-watchdog.timer (systemd user) also auto-heals within ~30s.
alias wallpaper="$HOME/.config/omarchy/hooks/theme-set"

# One-shot: stage all, commit, and push. Message optional; defaults to ".".
# Usage: save [message]
save() {
  git add -A && git commit -m "${1:-.}" && git push
}

# Regenerate a document's .tex build artifacts (body + driver) from its org
# source where one exists — org is the authoring surface for everything in
# research-wip; the .tex are gitignored artifacts.  emacs -Q on purpose: no
# daemon dependency, no init.el -- the export module + the shared
# org-paper.setup carry everything the batch path needs.
_org_export_body() {
  local org="$1"
  [[ -f "$org" ]] || return 0
  emacs -Q --batch \
    -l "$HOME/.config/emacs/org-paper-export.el" \
    --eval "(rm/org-paper-export-file \"$org\")"
}

# Regenerate a website page's HTML into research-public from its org
# source.  Same shape as _org_export_body: emacs -Q, no daemon, the
# export module carries everything the batch path needs.
_org_export_site() {
  local org="$1"
  [[ -f "$org" ]] || return 0
  emacs -Q --batch \
    -l "$HOME/.config/emacs/org-site-export.el" \
    --eval "(rm/org-site-export-file \"$org\")"
}

# Build a research-wip doc and publish its PDF to research-public, or
# rebuild and deploy the website (`publish site`).
# Usage: publish cv | publish dissertation | publish site | publish <paper-name>
publish() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "usage: publish <doc>"
    return 1
  fi
  local src_dir tex_name dest_pdf
  case "$name" in
    cv)
      src_dir="$HOME/scholarship/research-wip/documents/cv"
      tex_name="maung_cv.tex"
      dest_pdf="$HOME/scholarship/research-public/maung_cv.pdf"
      ;;
    dissertation)
      src_dir="$HOME/scholarship/research-wip/documents/dissertation"
      tex_name="dissertation.tex"
      dest_pdf="$HOME/scholarship/research-public/documents/dissertation/dissertation.pdf"
      ;;
    site)
      # The whole website: re-export every page (so template/nav/css
      # changes propagate everywhere), refresh the shared assets, push.
      # GitHub Pages serves research-public, so the push IS the deploy.
      # `site` is a reserved name, like cv/dissertation -- a paper
      # directory cannot use it.
      local site_src="$HOME/scholarship/website"
      local site_dest="$HOME/scholarship/research-public"
      if [[ ! -d "$site_src" ]]; then
        echo "publish: no website sources at $site_src"
        return 1
      fi
      (
        set -e
        # Pages only -- shared/ is config.  Each page is git-added by its
        # derived output path (mirrors rm/org-site--output-file), so the
        # commit stays scoped to what this publish generated.
        find "$site_src" -name '*.org' -not -path '*/shared/*' | sort |
          while IFS= read -r org; do
            _org_export_site "$org" || exit 1
            rel="${org#"$site_src"/}"
            sans="${rel%.org}"
            if [[ "$sans" == about ]]; then   # rm/org-site-home-page
              out="index.html"
            else
              out="$sans/index.html"
            fi
            git -C "$site_dest" add -- "$out"
          done
        cp "$site_src/shared/style.css" "$site_dest/style.css"
        mkdir -p "$site_dest/fonts"
        cp "$site_src/shared/fonts/"*.woff2 "$site_dest/fonts/"
        touch "$site_dest/.nojekyll"    # no Jekyll pass -- pure static
        cd "$site_dest"
        git add -- style.css fonts .nojekyll
        git diff --cached --quiet || { git commit -m "." && git push; }
        # Provenance, same as the documents: tag the website source this
        # deploy was built from.  The sources auto-commit first so the tag
        # always marks the exact built state -- website only; research-wip
        # stays hand-committed (M-SPC g) and keeps its dirty-tree warning.
        # Same-day republish moves the tag.
        git -C "$site_src" add -A
        git -C "$site_src" diff --cached --quiet ||
          git -C "$site_src" commit -m "publish site"
        git -C "$site_src" push
        tag="site-$(date +%F)"
        git -C "$site_src" tag -f "$tag"
        git -C "$site_src" push --force origin "refs/tags/$tag"
      )
      return $?
      ;;
    *)
      src_dir="$HOME/scholarship/research-wip/documents/papers/$name"
      tex_name="paper.tex"
      dest_pdf="$HOME/scholarship/research-public/documents/papers/$name.pdf"
      ;;
  esac
  if [[ ! -d "$src_dir" ]]; then
    echo "publish: no such doc at $src_dir"
    return 1
  fi
  (
    set -e
    cd "$src_dir"
    if [[ "$name" == dissertation ]]; then
      # Chapters \inputpaperbody the papers' body.tex, the frontmatter prose
      # and the dissertation structure are org-authored too -- refresh all of
      # them before building.  find, not a glob: this file is sourced by both
      # zsh and bash (no-match globs differ).
      find "$HOME/scholarship/research-wip/documents/papers" \
           -mindepth 2 -maxdepth 2 -name paper.org |
        while IFS= read -r org; do
          _org_export_body "$org" || exit 1
        done
      find "$src_dir/frontmatter" -maxdepth 1 -name '*.org' |
        while IFS= read -r org; do
          _org_export_body "$org" || exit 1
        done
      _org_export_body "$src_dir/dissertation.org"
    elif [[ "$name" == cv ]]; then
      _org_export_body "$src_dir/cv.org"
    else
      _org_export_body "$src_dir/paper.org"
    fi
    latexmk -pdf -interaction=nonstopmode -halt-on-error "$tex_name"
    mkdir -p "$(dirname "$dest_pdf")"
    cp "${tex_name%.tex}.pdf" "$dest_pdf"
    # Website auto-sync: the Research page lists every PDF in
    # documents/papers/, so a paper publish regenerates it -- the new
    # paper appears on the site in the same push.  No-op for cv and
    # dissertation (the page doesn't list them) and before the website
    # exists.
    if [[ "$dest_pdf" == */documents/papers/* &&
          -f "$HOME/scholarship/website/research.org" ]]; then
      _org_export_site "$HOME/scholarship/website/research.org"
    fi
    # Same for the CV: its page embeds the CV body itself (the cv-body
    # token), so a cv publish regenerates the page in the same push.
    if [[ "$name" == cv && -f "$HOME/scholarship/website/cv.org" ]]; then
      _org_export_site "$HOME/scholarship/website/cv.org"
    fi
    cd "$HOME/scholarship/research-public"
    git add "$dest_pdf"
    if [[ -f research/index.html ]]; then
      git add research/index.html
    fi
    if [[ -f cv/index.html ]]; then
      git add cv/index.html
    fi
    git diff --cached --quiet || { git commit -m "." && git push; }
    # Provenance: tag the wip source this publish was built from, so every
    # public PDF traces back to its exact source. Same-day republish moves
    # the tag (last publish wins).
    tag="${name}-$(date +%F)"
    git -C "$HOME/scholarship/research-wip" diff --quiet HEAD ||
      echo "publish: note — wip tree is dirty; $tag marks the last commit, not the exact built state"
    git -C "$HOME/scholarship/research-wip" tag -f "$tag"
    git -C "$HOME/scholarship/research-wip" push --force origin "refs/tags/$tag"
  )
}

# Clear stale latexmk build artifacts in the cwd. Use when builds fail with
# stale-aux symptoms (runaway argument on a contentsline, biber's "malformed
# bcf", latexmk's "Nothing to do" with a cached error). Keeps the PDF so any
# open viewer doesn't lose its file; reruns latexmk to regenerate.
texclear() {
  if ! ls *.tex >/dev/null 2>&1; then
    echo "texclear: no .tex files in $PWD"
    return 1
  fi
  latexmk -c
  latexmk -pdf -interaction=nonstopmode
}

# Build a double-spaced, narrower-margin copy of a paper for handoff. Runs
# from the paper folder; output goes to ~/Downloads so the paper folder stays
# clean. No wrapper file persists — overrides are passed inline via \def.
# Usage: doublespace [file] [output-name]
#   doublespace                      → the org source in $PWD → <name>-doublespaced.pdf
#   doublespace paper.org            → ~/Downloads/<paper>/paper-doublespaced.pdf
#   doublespace paper.org foo        → ~/Downloads/<paper>/foo.pdf
#   doublespace paper.org foo.pdf    → ~/Downloads/<paper>/foo.pdf  (trailing .pdf optional)
# Org is the authoring surface, so the argument is optional and names the org
# source. A bare name or a .tex still resolves to the same document.
doublespace() {
  local input="$1"
  local out_name="$2"
  local org tex
  if [[ -z "$input" ]]; then
    # No argument: build whichever document this directory holds.
    local candidate
    for candidate in paper.org dissertation.org cv.org; do
      [[ -f "$candidate" ]] && { org="$candidate"; break; }
    done
    if [[ -z "$org" ]]; then
      echo "doublespace: no org source in $PWD (expected paper.org, dissertation.org or cv.org)"
      return 1
    fi
  else
    local base="${input%.tex}"
    base="${base%.org}"
    # maung_cv.tex is the driver cv.org generates; accept either name.
    [[ "$base" == maung_cv ]] && base="cv"
    org="${base}.org"
  fi
  case "$org" in
    cv.org) tex="maung_cv.tex" ;;
    *)      tex="${org%.org}.tex" ;;
  esac
  # The .tex are generated artifacts — refresh from the org source first so a
  # clean tree (or stale artifact) still builds the current content. A .tex
  # with no org beside it is built as-is, for one-off files outside the
  # org-authored set.
  if [[ -f "$org" ]]; then
    _org_export_body "$PWD/$org" || return 1
    if [[ ! -f "$tex" ]]; then
      echo "doublespace: export of $org produced no $tex"
      return 1
    fi
  elif [[ ! -f "$tex" ]]; then
    echo "doublespace: file not found: $org (and no $tex to fall back on)"
    return 1
  fi
  local jobname="${tex%.tex}-doublespaced"
  if [[ -n "$out_name" ]]; then
    out_name="${out_name%.pdf}"
    # Sanitize path separators: filenames with `/` would try to write into a
    # nonexistent subdirectory. Replace with `-` so e.g. "draft-6/28" becomes
    # "draft-6-28". Also strip leading dots so we don't create hidden files.
    out_name="${out_name//\//-}"
    out_name="${out_name#.}"
  else
    out_name="$jobname"
  fi
  local paper_slug
  paper_slug=$(basename "$PWD")
  local out_dir="$HOME/Downloads/$paper_slug"
  local build_dir
  build_dir=$(mktemp -d -t doublespace.XXXXXX)
  mkdir -p "$out_dir"
  latexmk -pdf -interaction=nonstopmode \
    -outdir="$build_dir" -jobname="$jobname" \
    -usepretex='\def\paperspacing{\doublespacing}\def\paperleftmargin{1.25in}\def\paperrightmargin{1.25in}' \
    "$tex"
  local rc=$?
  if [[ $rc -eq 0 && -f "$build_dir/${jobname}.pdf" ]]; then
    local dest="$out_dir/${out_name}.pdf"
    if cp "$build_dir/${jobname}.pdf" "$dest"; then
      echo "doublespace: wrote $dest"
    else
      echo "doublespace: build succeeded but copy to $dest failed"
      rc=1
    fi
  else
    echo "doublespace: build failed (rc=$rc)"
  fi
  rm -rf "$build_dir"
  return $rc
}

# Split a PDF into 20-page chunks. Prompts for output directory each time.
# Original file is never modified. Usage: pdfsplit foo.pdf
pdfsplit() {
  if [[ -z "$1" ]]; then
    echo "usage: pdfsplit <file.pdf>"
    return 1
  fi
  local input="$1"
  local outdir
  read "outdir?Output directory: "
  if [[ -z "$outdir" ]]; then
    echo "pdfsplit: no output directory given, aborting"
    return 1
  fi
  outdir="${outdir/#\~/$HOME}"
  mkdir -p "$outdir" || return 1
  qpdf --split-pages=20 "$input" "$outdir/$(basename "$input")"
}

# fzf shell integration — Ctrl-T (file picker), Ctrl-R (history), Alt-C
# (cd into subdir), plus fuzzy tab-completion. Arch ships the integration
# scripts in /usr/share/fzf/; guarded so machines without fzf installed
# fall through silently.
if [ -n "${ZSH_VERSION:-}" ]; then
    [ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
    [ -f /usr/share/fzf/completion.zsh ]   && source /usr/share/fzf/completion.zsh
elif [ -n "${BASH_VERSION:-}" ]; then
    [ -f /usr/share/fzf/key-bindings.bash ] && source /usr/share/fzf/key-bindings.bash
    [ -f /usr/share/fzf/completion.bash ]   && source /usr/share/fzf/completion.bash
fi

# zoxide - smarter cd. Pick the init flavor matching the running shell so
# this file works under bash too (the filename says zshrc for historical
# reasons; ~/.bashrc also sources it). `zoxide init zsh` emits zsh-only
# array-slicing syntax (${(@)precmd_functions:#__zoxide_hook}) that bash
# chokes on with "bad substitution" at every prompt.
if [ -n "${ZSH_VERSION:-}" ]; then
    eval "$(zoxide init zsh)"
elif [ -n "${BASH_VERSION:-}" ]; then
    eval "$(zoxide init bash)"
fi
