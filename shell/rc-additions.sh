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
