# TODO

## CV

- [ ] **CV.** Build a LaTeX template/class for the CV (analogous to maungstyle but CV-shaped) and a compile pipeline. Destination PDF eventually lives at `research-public/cv.pdf`.

## install.sh — broader platform support

- [x] **Linux, any distro.** Dispatch on `uname -s`. Detects `apt`/`dnf`/`pacman`/`zypper` and installs equivalents; `zathura` as the default PDF viewer; Ghostty symlink goes to `~/.config/ghostty/config`. Ghostty itself and the Nerd Font print a manual-install URL since they aren't in standard distro repos.
- [ ] **Windows compatibility.** Probably WSL2 + Linux branch, or native PowerShell script. Decide approach.

The `latex/*.sty` install block already handles macOS/Linux paths correctly — nothing to do there for the TeX tree itself.
