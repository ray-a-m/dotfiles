# TODO

## CV

- [ ] **CV.** Build a LaTeX template/class for the CV (analogous to maungstyle but CV-shaped) and a compile pipeline. Destination PDF eventually lives at `research-public/cv.pdf`.

## install.sh — broader platform support

- [ ] **Linux, any distro.** Detect package manager (`pacman`, `apt`, `dnf`, `zypper`) and map to equivalent packages. Currently macOS-only (Homebrew + MacTeX).
  - Handle TeX Live install path variation (`texlive-most` on Arch, `texlive-full` on Debian/Ubuntu, `texlive-scheme-full` on Fedora).
  - Ghostty config path: `~/.config/ghostty/config` on Linux instead of `~/Library/Application Support/...`.
  - Skip macOS-only tools (Skim). Pick a Linux PDF viewer default (zathura?).
- [ ] **Windows compatibility.** Probably WSL2 + Linux branch, or native PowerShell script. Decide approach.

The `latex/*.sty` install block already handles macOS/Linux paths correctly — nothing to do there for the TeX tree itself.
