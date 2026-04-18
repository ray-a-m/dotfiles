# Workflow Reference

Daily workflow reminders.

## Shell navigation

Zoxide tracks directories visited via cd and lets you jump back by fragment:

    cd ~/scholarship/research-wip/documents/papers/symmetry-reality  # first visit
    # later, from anywhere:
    z symmetry
    z sym-real
    z sym

Shell aliases (in ~/.zshrc):

    alias scholarship="cd ~/scholarship"
    alias wip="cd ~/scholarship/research-wip"
    alias pub="cd ~/scholarship/research-public"
    alias dots="cd ~/code/dotfiles"
    alias v="nvim"

    eval "$(zoxide init zsh)"

Typical: wip -> cd documents/papers/symmetry-reality -> v body.tex.

## Repo architecture

    ~/scholarship/
    ├── research-public/    (public GitHub repo: PDFs, .bib, CV)
    └── research-wip/       (private GitHub repo: .tex sources)

    ~/code/
    └── dotfiles/           (public GitHub repo: this repo; symlinked to ~/.config/nvim)

Day-to-day writing happens in research-wip. When a paper is ready for public release, copy the PDF and bib to the corresponding path in research-public and push.

## Neovim LaTeX workflow

1. cd into the paper's directory, v main.tex.
2. :VimtexCompile starts latexmk in continuous mode. Recompiles on every save.
3. :VimtexView opens Skim. Skim auto-refreshes on every recompile.
4. Write. Save with :w or rely on autosave (fires 1s after leaving insert mode for .tex/.bib/.md).

Citation completion: type inside \cite{ or \textcite{, suggestions appear from any .bib file in the project.

Bibliography browser: <space>cb (Telescope fuzzy-search over bib entries).

## Key Neovim motions

| Purpose | Keys |
|---|---|
| Insert mode | i |
| Normal mode | Esc |
| Save | :w |
| Quit | :qa |
| Half page down/up | Ctrl+d / Ctrl+u |
| Top / bottom of file | gg / G |
| Jump to line N | NG or :N |
| Search forward | /pattern then n/N |
| Retrace jumps | Ctrl+o / Ctrl+i |
| Delete line | dd |
| Paragraph forward/back | } / { |
| Undo / redo | u / Ctrl+r |

## Zotero to bib workflow

In Zotero: right-click a collection -> Export -> Better BibTeX -> *Keep updated* -> save as refs.bib inside the paper's directory. Edits in Zotero automatically update the bib, which git tracks.

## Git rhythm

- Commit early and often, with unit-of-thought messages.
- git push at the end of each writing session for offsite backup.
- Private by default in research-wip; promote to research-public only when ready.
