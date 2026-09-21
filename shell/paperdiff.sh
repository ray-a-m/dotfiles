#!/usr/bin/env bash
# paperdiff -- a marked-up PDF of what changed between two versions of a
# paper: deletions struck through in red, additions underlined in blue,
# everything else set exactly as the paper always is.  For sending an
# advisor a draft they can read for what is NEW instead of re-reading
# the whole thing.
#
#   paperdiff <old> <new>
#
# Each side is a paper.org, a body.tex, a full .tex, a paper directory,
# or a bare slug from research-wip.  Arbitrary paths are the point: the
# old side is usually whatever copy the advisor still has, sitting in
# ~/Downloads with a name like paper-july.org.  Nothing here reads git
# -- research-wip is a pure Syncthing tree on this laptop and has no
# .git at all.
#
#   paperdiff ~/Downloads/paper-july.org symmetry-reality
#   paperdiff old/paper.org new/paper.org -o ~/Desktop/for-advisor.pdf
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

die() { printf 'paperdiff: %s\n' "$1" >&2; exit 1; }

usage() {
  cat >&2 <<'EOF'
usage: paperdiff [-o out.pdf] [--no-open] [--keep] <old> <new>

  <old>, <new>   paper.org | body.tex | a full .tex | a paper directory
                 | a research-wip slug (e.g. symmetry-reality)
  -o out.pdf     where to write it (default: ./<slug>-diff.pdf)
  --no-open      do not open the result in zathura
  --keep         keep the scratch build tree and print its path
EOF
  exit 1
}

out=""; open=1; keep=0; args=()
while [ $# -gt 0 ]; do
  case "$1" in
    -o|--output) out="${2:-}"; [ -n "$out" ] || usage; shift 2 ;;
    --no-open)   open=0; shift ;;
    --keep)      keep=1; shift ;;
    -h|--help)   usage ;;
    -*)          die "unknown option $1" ;;
    *)           args+=("$1"); shift ;;
  esac
done
[ "${#args[@]}" -eq 2 ] || usage

for t in latexdiff latexmk emacs; do
  command -v "$t" >/dev/null || die "$t is not installed"
done

# A side's argument, resolved to the one file that stands for it.  A
# bare word is a research-wip slug; a directory is a paper directory.
resolve() {
  local a="$1"
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
[ -n "$out" ] || out="$PWD/$slug-diff.pdf"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/paperdiff.XXXXXX")"
cleanup() { [ "$keep" -eq 1 ] || rm -rf "$tmp"; }
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
        bib="$(ls "$dir"/*.bib 2>/dev/null | head -1)"
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
  ( cd "$new_dir" && latexmk -pdf -interaction=nonstopmode -halt-on-error \
      diff.tex ) >"$tmp/latexmk-$label.log" 2>&1
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
printf 'paperdiff: wrote %s (%s pages)\n' "$out" \
  "$(pdfinfo "$out" 2>/dev/null | awk '/^Pages:/{print $2}')"
if [ "$keep" -eq 1 ]; then printf 'paperdiff: scratch tree at %s\n' "$tmp"; fi

if [ "$open" -eq 1 ] && command -v zathura >/dev/null && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
  zathura "$out" >/dev/null 2>&1 &
  disown 2>/dev/null || true
fi
