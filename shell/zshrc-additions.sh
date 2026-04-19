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

# zoxide - smarter cd
eval "$(zoxide init zsh)"
