#!/usr/bin/env bash
# paperdiff -- a marked-up PDF of what changed between two versions of a
# paper: deletions struck through in red, additions underlined in blue,
# everything else set exactly as the paper always is.  For sending an
# advisor a draft they can read for what is NEW instead of re-reading
# the whole thing.
#
# The call this exists for:
#
#   paperdiff <slug> <the copy he has>
#
# The slug is the paper as it stands now; the second argument is the
# version to compare against, which is whatever copy the reader still
# has.  That may be the PDF that was sent, an .org kept from then, or
# just the date it went out:
#
#   paperdiff symmetry-reality ~/paper-doublespaced.pdf
#   paperdiff symmetry-reality ~/Downloads/paper-july.org
#   paperdiff symmetry-reality @2026-08-03
#   paperdiff symmetry-reality                 # the last draft sent
#   paperdiff old/paper.org new/paper.org      # two versions, oldest first
#
# A slug always means the CURRENT paper, so it may be typed either side;
# two paths are read oldest first, the way diff takes them.  Each side
# may be a paper.org, a body.tex, a full .tex, a paper directory, a
# slug, a PDF, or @<date>.
#
# The result is built the way `doublespace' builds what actually gets
# sent -- double spaced, 1.25in side margins -- and lands beside it in
# ~/Documents/<slug>/.  --single builds it at the paper's own spacing.
#
# Where an old version comes from, in order.  `doublespace' keeps the
# source of every PDF it builds under sources/ beside the PDF, so a PDF
# that was sent names real source and the markup holds up.  A PDF with
# none -- one built before that was kept -- falls back to the pushed
# history of research-wip: the paper as it stood when that PDF was
# typeset, by the date the PDF itself carries.  @<date> asks the history
# the same question directly.  The history is read from a local blobless
# mirror of the GitHub repo, because research-wip has no .git on this
# laptop -- it is a Syncthing tree, and the sync cron on services owns
# its git.  A PDF's own text is never used: it has to be guessed back
# out of the typesetting, which returns math, citations and footnotes
# wrong.
#
# How it works: both sides are exported (org) or wrapped (tex) into
# throwaway trees that mirror documents/papers/<slug>/ exactly, with
# shared/ and dissertation/ symlinked two levels up so the preamble and
# the bib resolve the way they do in the real tree.  latexdiff --flatten
# then diffs the two generated drivers and latexmk builds the result.
# The real paper directory is never written to, and the org is never
# diffed directly: latexdiff compares words inside a paragraph, so the
# generated LaTeX diffs cleanly even when an org edit reflows the file.

set -euo pipefail

WIP="$HOME/scholarship/research-wip"
PAPERS="$WIP/documents/papers"

EXPORTER="$HOME/.config/emacs/runtime/lisp/org-paper-export.el"
# The pre-refactor location, in case this runs against an older config.
[ -f "$EXPORTER" ] || EXPORTER="$HOME/.config/emacs/lisp/org-paper-export.el"

# What `doublespace' passes latexmk.  The marked-up copy goes to the same
# reader as the doublespaced build, so it is set the same way: one diff
# to read, one format to read it in, and room in the margin to write.
DOUBLESPACE_PRETEX='\def\paperspacing{\doublespacing}\def\paperleftmargin{1.25in}\def\paperrightmargin{1.25in}'

# The pushed history, for an old version that exists nowhere on disk.
# Mirrored locally, blobless, fetched only when a date asks for
# something newer than the mirror holds.
HISTORY_URL="git@github.com:ray-a-m/research-wip.git"
HISTORY_CACHE="$HOME/.cache/paperdiff/research-wip.git"
hist_tmp=""

die() { printf 'paperdiff: %s\n' "$1" >&2; exit 1; }

# The drafts `doublespace' kept for a paper, newest first.  Dated copies
# only: the undated one is a mirror of the latest build, kept so a PDF
# can be resolved to its source, and naming it as a baseline would say
# nothing about which draft it holds.
kept_drafts() {
  local slug="$1"
  [ -n "$slug" ] || return 0
  ls -t "$HOME/Documents/$slug/sources"/*-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].* \
    2>/dev/null || true
}

usage() {
  cat >&2 <<'EOF'
usage: paperdiff [options] <slug> <the copy he has>
       paperdiff [options] <slug>            the last draft you sent
       paperdiff [options] <old> <new>       two versions, oldest first

  <slug>         a paper in research-wip, e.g. symmetry-reality; always
                 the CURRENT version, so it may be typed either side
  <the copy>     a PDF that was sent | @<date>, e.g. @2026-08-03
                 | a paper.org | a body.tex | a full .tex | a paper dir
  -o out.pdf     where to write it
                 (default: ~/Documents/<slug>/<slug>-diff.pdf)
  --single       build at the paper's own spacing, not doublespace's
  --no-open      do not open the result in zathura
  --keep         keep the scratch build tree and print its path
EOF
  exit 1
}

out=""; open=1; keep=0; spacing=double; args=()
while [ $# -gt 0 ]; do
  case "$1" in
    -o|--output) out="${2:-}"; [ -n "$out" ] || usage; shift 2 ;;
    --single)    spacing=single; shift ;;
    --no-open)   open=0; shift ;;
    --keep)      keep=1; shift ;;
    -h|--help)   usage ;;
    -*)          die "unknown option $1" ;;
    *)           args+=("$1"); shift ;;
  esac
done
case "${#args[@]}" in 1|2) ;; *) usage ;; esac

for t in latexdiff latexmk emacs; do
  command -v "$t" >/dev/null || die "$t is not installed"
done

# The date a PDF was typeset, which is what to ask the history for.
pdf_date() {
  local d
  d="$(pdfinfo "$1" 2>/dev/null | awk -F': +' '/^CreationDate:/{print $2}' || true)"
  [ -n "$d" ] || d="$(date -r "$1" '+%Y-%m-%d %H:%M:%S %z')"
  date -d "$d" '+%Y-%m-%d %H:%M:%S %z' 2>/dev/null || printf '%s\n' "$d"
}

# The local mirror of research-wip's pushed history, cloned on first use.
history_repo() {
  if [ ! -d "$HISTORY_CACHE" ]; then
    mkdir -p "$(dirname "$HISTORY_CACHE")"
    git clone --bare --filter=blob:none -q "$HISTORY_URL" "$HISTORY_CACHE" \
      2>/dev/null || { rm -rf "$HISTORY_CACHE"; return 1; }
  fi
  printf '%s\n' "$HISTORY_CACHE"
}

# SLUG's paper.org as it stood at WHEN, written to a scratch file whose
# path is echoed.  The commit is the last one that touched the paper at or
# before WHEN, which for a PDF is the state it was typeset from -- the
# sync cron commits on an interval, so it can trail the build slightly.
source_at() {
  local slug="$1" when="$2" repo sha path out newest
  [ -n "$slug" ] || return 1
  repo="$(history_repo)" || return 1
  # Only reach for the network when the mirror cannot already answer.
  newest="$(git -C "$repo" log -1 --format=%cI 2>/dev/null || true)"
  if [ -n "$newest" ] &&
     [ "$(date -d "$when" +%s 2>/dev/null || echo 0)" -gt "$(date -d "$newest" +%s)" ]; then
    git -C "$repo" fetch -q --filter=blob:none origin \
      '+refs/heads/*:refs/heads/*' 2>/dev/null || true
  fi
  path="documents/papers/$slug/paper.org"
  sha="$(git -C "$repo" log -1 --format=%H --before="$when" -- "$path" 2>/dev/null || true)"
  [ -n "$sha" ] || return 1
  [ -n "$hist_tmp" ] || hist_tmp="$(mktemp -d "${TMPDIR:-/tmp}/paperdiff-hist.XXXXXX")"
  out="$hist_tmp/$slug-$(printf '%.7s' "$sha").org"
  git -C "$repo" show "$sha:$path" > "$out" 2>/dev/null || return 1
  printf 'paperdiff: history %s as of %s (commit %.7s)\n' \
    "$path" "$(git -C "$repo" log -1 --format=%cd --date=format:'%Y-%m-%d %H:%M' "$sha")" \
    "$sha" >&2
  printf '%s\n' "$out"
}

# A side's argument, resolved to the one file that stands for it.  A
# bare word is a research-wip slug; a directory is a paper directory.
resolve() {
  local a="$1"
  case "$a" in
    @*)
      # @<date>: the paper as it stood then, from the pushed history.
      # `paperdiff symmetry-reality @2026-08-03' -- for a copy whose date
      # is known but whose file is gone.
      local when="${a#@}" cand
      cand="$(source_at "$slug_hint" "$when")" ||
        die "no history for ${slug_hint:-that paper} at $when.
    A date needs the paper named too, and the mirror of research-wip's
    pushed history needs to be reachable (github.com)."
      printf '%s\n' "$cand"
      return
      ;;
    *.pdf)
      # A PDF holds no diffable source -- its text has to be guessed back
      # out of the typesetting, and math, citations and footnotes all come
      # back wrong. `doublespace' keeps the source it built each PDF from,
      # under sources/ beside it, so pointing at the file that was
      # actually sent works and loses nothing.
      local dir stem cand kept
      [ -f "$a" ] || die "no such file: $a"
      dir="$(dirname "$a")"; stem="$(basename "${a%.pdf}")"
      for cand in "$dir/sources/$stem.org" "$dir/sources/$stem.tex"; do
        [ -f "$cand" ] && { printf '%s\n' "$cand"; return; }
      done
      # Nothing beside it -- a PDF built before doublespace kept sources,
      # or one built elsewhere.  Its own text cannot stand in: that has to
      # be guessed back out of the typesetting, which returns math,
      # citations and footnotes wrong.  The history can, though: take the
      # paper as it stood when this PDF was typeset.
      if cand="$(source_at "$slug_hint" "$(pdf_date "$a")")"; then
        printf '%s\n' "$cand"; return
      fi
      # Neither: say what CAN be used instead.
      kept="$(kept_drafts "$slug_hint" | head -5 | sed 's|^|      |')"
      if [ -n "$kept" ]; then
        die "no source kept beside $(basename "$a") (looked in $dir/sources/).
    A PDF cannot be diffed directly, but these drafts of $slug_hint were
    kept, newest first -- name one of them instead:
$kept"
      fi
      die "no source kept beside $(basename "$a") (looked in $dir/sources/).
    A PDF cannot be diffed directly.  doublespace keeps the source of
    every PDF it builds, so drafts you send from now on have a baseline.
    This one predates that, so point at an .org you still have."
      ;;
  esac
  if [ -d "$a" ]; then
    [ -f "$a/paper.org" ] && { printf '%s\n' "$a/paper.org"; return; }
    [ -f "$a/paper.tex" ] && { printf '%s\n' "$a/paper.tex"; return; }
    die "$a holds no paper.org or paper.tex"
  fi
  if [ -f "$a" ]; then printf '%s\n' "$a"; return; fi
  case "$a" in
    */*) die "no such file: $a" ;;
    *)   [ -f "$PAPERS/$a/paper.org" ] ||
           die "no such file, and no paper '$a' in research-wip"
         printf '%s\n' "$PAPERS/$a/paper.org" ;;
  esac
}

# A bare word naming a paper in research-wip: the current version, and
# so always the new side.  Typing the slug first reads naturally when
# the question is "what has changed since the copy he has", which is
# the usual one, so both orders are accepted and mean the same thing.
is_slug() {
  case "$1" in */*) return 1 ;; esac
  [ -e "$1" ] && return 1
  [ -f "$PAPERS/$1/paper.org" ]
}
# One argument, a slug: against the newest draft `doublespace' kept for
# it -- "what has changed since I last sent this", which is the question
# most often being asked.
if [ "${#args[@]}" -eq 1 ]; then
  is_slug "${args[0]}" ||
    die "one argument must be a paper slug; give two versions otherwise"
  sent_dir="$HOME/Documents/${args[0]}/sources"
  baseline="$(kept_drafts "${args[0]}" | head -1)"
  [ -n "$baseline" ] ||
    baseline="$(ls -t "$sent_dir"/*.org "$sent_dir"/*.tex 2>/dev/null | head -1 || true)"
  [ -n "$baseline" ] ||
    die "nothing kept in $sent_dir to compare against.
    doublespace saves its source there, so the next draft you build has
    a baseline; until then, name the old version yourself."
  args=("$baseline" "${args[0]}")
fi

if is_slug "${args[0]}" && ! is_slug "${args[1]}"; then
  set -- "${args[1]}" "${args[0]}"        # slug given first: it is the new side
  args=("$1" "$2")
fi

# Which paper this is about, where one side names it: the PDF branch
# above reports that paper's kept drafts when a PDF has no source.
slug_hint=""
is_slug "${args[1]}" && slug_hint="${args[1]}"
is_slug "${args[0]}" && slug_hint="${args[0]}"

old_src="$(resolve "${args[0]}")"
new_src="$(resolve "${args[1]}")"
old_src="$(cd "$(dirname "$old_src")" && pwd)/$(basename "$old_src")"
new_src="$(cd "$(dirname "$new_src")" && pwd)/$(basename "$new_src")"
[ "$old_src" != "$new_src" ] || die "both sides are the same file"

# The slug names the output and the scratch directories.  The new side's
# directory is the paper's real name when it came from research-wip; a
# loose file in ~/Downloads falls back to its own basename.
slug="$(basename "$(dirname "$new_src")")"
case "$slug" in .|/|Downloads|Desktop|tmp) slug="$(basename "${new_src%.*}")" ;; esac
# Beside the doublespaced build of the same paper, which is the file
# this one is sent with (`doublespace' writes ~/Documents/<slug>/).
[ -n "$out" ] || out="$HOME/Documents/$slug/$slug-diff.pdf"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/paperdiff.XXXXXX")"
cleanup() {
  [ "$keep" -eq 1 ] && return 0
  rm -rf "${tmp:-}" "${hist_tmp:-}"
}
trap cleanup EXIT

# Build one side's tree and echo the driver .tex it compiles from.  The
# directory shape matters twice over: the generated drivers say
# ../../shared/preamble.tex, and the exporter only recognizes a file as
# a paper when its path ends in documents/papers/<slug>/paper.org.
build_side() {
  local side="$1" src="$2" dir bib body
  dir="$tmp/$side/documents/papers/$slug"
  mkdir -p "$dir"
  ln -sfn "$WIP/documents/shared"       "$tmp/$side/documents/shared"
  ln -sfn "$WIP/documents/dissertation" "$tmp/$side/documents/dissertation"

  # Whatever else the source directory carries that a build needs: a
  # paper-local .bib (the standalone papers keep their own) and figure
  # directories.  Linked, never copied -- this tree is read-only input.
  local res
  for res in "$(dirname "$src")"/*.bib; do
    [ -e "$res" ] && ln -sfn "$res" "$dir/$(basename "$res")"
  done
  for res in "$(dirname "$src")"/*/; do
    case "$(basename "$res")" in auto|ltximg|_minted*) continue ;; esac
    [ -d "$res" ] && ln -sfn "${res%/}" "$dir/$(basename "$res")"
  done

  case "$src" in
    *.org)
      cp "$src" "$dir/paper.org"
      [ -f "$EXPORTER" ] || die "the org exporter is missing: $EXPORTER"
      emacs -Q --batch -l "$EXPORTER" \
        --eval "(rm/org-paper-export-file \"$dir/paper.org\")" \
        >"$tmp/$side-export.log" 2>&1 ||
        { sed -n '$p' "$tmp/$side-export.log" >&2
          die "the $side side failed to export (log: $tmp/$side-export.log)"; }
      [ -f "$dir/paper.tex" ] || die "the $side export wrote no driver"
      printf '%s\n' "$dir/paper.tex"
      ;;
    *.tex)
      # Copy every .tex beside the source: a hand-written driver reaches
      # for its body, and the pre-org papers are exactly that pair.
      cp "$(dirname "$src")"/*.tex "$dir/" 2>/dev/null || cp "$src" "$dir/"
      body="$(basename "$src")"
      if grep -q '\\begin{document}' "$dir/$body"; then
        printf '%s\n' "$dir/$body"        # already a whole document
      else
        # A body alone: give it the same driver the exporter writes, so
        # both sides reach the same preamble and the diff is prose only.
        bib="$(ls "$dir"/*.bib 2>/dev/null | head -1 || true)"
        if [ -n "$bib" ]; then bib="$(basename "$bib")"
        else bib="../../dissertation/references.bib"; fi
        { echo '\input{../../shared/preamble.tex}'
          echo "\\addbibresource{$bib}"
          echo; echo '\begin{document}'; echo
          echo "\\input{$body}"
          echo; echo '\end{document}'
        } > "$dir/paperdiff-driver.tex"
        printf '%s\n' "$dir/paperdiff-driver.tex"
      fi
      ;;
    *) die "$src is neither .org nor .tex" ;;
  esac
}

printf 'paperdiff: old  %s\n' "$old_src"
printf 'paperdiff: new  %s\n' "$new_src"
old_tex="$(build_side old "$old_src")"
new_tex="$(build_side new "$new_src")"
# Where it is going, before latexmk goes quiet for half a minute: the
# run prints nothing while it builds, and a silent terminal reads like
# a hang rather than a compile.
printf 'paperdiff: building %s ...\n' "$out"
new_dir="$(dirname "$new_tex")"

# Three attempts, each looser than the last.  Marking up changed math
# word by word reads best and breaks most often, so a failed build
# retries with whole formulas marked, then with headings left alone --
# markup inside a \section is the other reliable way to break hyperref.
build() {
  local label="$1"; shift
  rm -f "$new_dir/diff.tex"
  ( cd "$new_dir" && latexdiff --flatten "$@" "$old_tex" "$new_tex" ) \
    > "$new_dir/diff.tex" 2>"$tmp/latexdiff.log" ||
    { sed -n '$p' "$tmp/latexdiff.log" >&2; return 1; }
  local pretex=()
  [ "$spacing" = double ] && pretex=(-usepretex="$DOUBLESPACE_PRETEX")
  ( cd "$new_dir" && latexmk -pdf -interaction=nonstopmode -halt-on-error \
      "${pretex[@]}" diff.tex ) >"$tmp/latexmk-$label.log" 2>&1
}

if   build coarse    --math-markup=coarse; then :
elif build whole     --math-markup=whole;  then
  echo "paperdiff: note -- changed formulas are marked whole (fine markup would not compile)"
elif build headings  --math-markup=whole \
       --exclude-textcmd="section,subsection,subsubsection,paragraph"; then
  echo "paperdiff: note -- formulas marked whole and headings left unmarked (the build needed it)"
else
  keep=1
  echo "paperdiff: the marked-up document would not compile." >&2
  tail -20 "$tmp/latexmk-headings.log" >&2 2>/dev/null || true
  die "scratch tree kept at $tmp"
fi

[ -f "$new_dir/diff.pdf" ] || die "latexmk reported success but wrote no PDF"
mkdir -p "$(dirname "$out")"
cp "$new_dir/diff.pdf" "$out"
printf 'paperdiff: wrote %s (%s pages, %s)\n' "$out" \
  "$(pdfinfo "$out" 2>/dev/null | awk '/^Pages:/{print $2}')" \
  "$([ "$spacing" = double ] && echo 'double spaced' || echo "the paper's own spacing")"
if [ "$keep" -eq 1 ]; then printf 'paperdiff: scratch tree at %s\n' "$tmp"; fi

if [ "$open" -eq 1 ] && command -v zathura >/dev/null && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
  zathura "$out" >/dev/null 2>&1 &
  disown 2>/dev/null || true
fi
