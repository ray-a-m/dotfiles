# TODO

## CV

- [ ] **CV.** Build a LaTeX template/class for the CV (analogous to maungstyle but CV-shaped) and a compile pipeline. Destination PDF eventually lives at `research-public/cv.pdf`.

## install.sh — broader platform support

- [x] **Linux, any distro.** Dispatch on `uname -s`. Detects `apt`/`dnf`/`pacman`/`zypper` and installs equivalents; `zathura` as the default PDF viewer. The Nerd Font prints a manual-install URL since it isn't in standard distro repos.
- [ ] **Windows compatibility.** Probably WSL2 + Linux branch, or native PowerShell script. Decide approach.

The `latex/*.sty` install block already handles macOS/Linux paths correctly — nothing to do there for the TeX tree itself.
