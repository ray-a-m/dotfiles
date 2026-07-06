" Biblatex cite commands as spell-safe reference zones.
"
" Vim's default tex syntax (/usr/share/nvim/runtime/syntax/tex.vim:678) covers
" natbib-era \cite / \citet / \citep only. biblatex adds \parencite, \textcite,
" \autocite, \footcite, \supercite, \smartcite, \citeauthor, \citeyear, and
" plural variants (\parencites, \textcites, …) — none of them registered as
" texRefZone by default, so their {key} arguments get spellchecked and the
" citation key surfaces as a misspelling. vimtex's syntax package doesn't fill
" this in either (grep vimtex/syntax/tex.vim for `cite` — no hits).
"
" Fix mirrors the pattern vim uses for \pageref{} / \eqref{} at line 673 of the
" default tex.vim: region matching the whole `\foocite[…]{…}` invocation, marked
" as texRefZone (which is in the @NoSpell cluster). Covers the biblatex family
" via `\w*cite\w*` so any prefixed or suffixed cite variant Raymond might use
" later — \parencites, \citeauthors, \fullcite — is picked up without editing.

syn region texRefZone matchgroup=texStatement
      \ start="\\\w*cite\w*\*\?\%(\[[^]]*\]\)*{"
      \ end="}\|%stopzone\>"
      \ contains=@texRefGroup
