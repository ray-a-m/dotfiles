# Force Firefox/LibreWolf to use native Wayland when launched from a shell.
# Hyprland's envs.conf already sets this for keybind-launched apps; this
# covers the terminal-launch case.
export MOZ_ENABLE_WAYLAND=1

# Scholarship shortcuts
alias scholarship="cd ~/scholarship"
alias wip="cd ~/scholarship/research-wip"
alias pub="cd ~/scholarship/research-public"
alias dots="cd ~/code/dotfiles"

# Restart the wallpaper (mpvpaper for video themes, swaybg otherwise) by
# re-running the omarchy theme-set hook. Use when mpvpaper crashes and the
# screen goes blank — no respawn watchdog is in place by design.
alias wallpaper="$HOME/.config/omarchy/hooks/theme-set"

# One-shot: stage all, commit with "." message, and push
save() {
  git add -A && git commit -m "." && git push
}

# Build a research-wip doc and publish its PDF to research-public.
# Usage: publish cv | publish dissertation | publish <paper-name>
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
    latexmk -pdf -interaction=nonstopmode -halt-on-error "$tex_name"
    mkdir -p "$(dirname "$dest_pdf")"
    cp "${tex_name%.tex}.pdf" "$dest_pdf"
    cd "$HOME/scholarship/research-public"
    git add "$dest_pdf"
    git diff --cached --quiet || { git commit -m "." && git push; }
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
# Usage: doublespace <file.tex> [output-name]
#   doublespace paper.tex            → ~/Downloads/paper-doublespaced.pdf
#   doublespace paper.tex foo        → ~/Downloads/foo.pdf
#   doublespace paper.tex foo.pdf    → ~/Downloads/foo.pdf  (trailing .pdf optional)
doublespace() {
  local input="$1"
  local out_name="$2"
  if [[ -z "$input" ]]; then
    echo "usage: doublespace <file.tex> [output-name]"
    return 1
  fi
  [[ "$input" != *.tex ]] && input="${input}.tex"
  if [[ ! -f "$input" ]]; then
    echo "doublespace: file not found: $input"
    return 1
  fi
  local jobname="${input%.tex}-doublespaced"
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
    "$input"
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
