# Scholarship shortcuts
alias scholarship="cd ~/scholarship"
alias wip="cd ~/scholarship/research-wip"
alias pub="cd ~/scholarship/research-public"
alias dots="cd ~/code/dotfiles"
alias v="nvim"

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

# zoxide - smarter cd
eval "$(zoxide init zsh)"
