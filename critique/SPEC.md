> **Status: DRAFT** — Phase 1 of `spec-driven-development` complete; Phase 2 (Plan) deferred to a future session. Do not begin implementation against this draft until it is reviewed and finalized.

# Spec: `critique`

## Objective

A command-line tool that delivers sharp peer-review-style feedback on selected passages from in-progress philosophy of physics manuscripts. The user is the sole writer; the tool fills the role of an absent senior collaborator on a per-passage basis.

Each invocation is a pure function: passage in, critique out, with no conversation memory across calls. Output is streamed and appended to a per-paper log. The Neovim integration is a single keymap; the underlying tool is editor-agnostic and works equally well from any shell.

Success looks like: during a writing push, the user highlights a paragraph in nvim, hits `<leader>cc`, glances at a `tail -f` in the adjacent kitty pane, and either trusts the writing more or revises. Cost stays under ~$1/day with prompt caching. PDFs in `.sources/` are read directly by Claude (no client-side extraction), so math, multi-column layouts, and the occasional scan all come through faithfully.

## Tech Stack

- **Language:** Python 3.11+, single-file script
- **Runtime:** `uv` via PEP 723 inline metadata (no system pip; first invocation creates an isolated env)
- **Sole dependency:** `anthropic` SDK
- **No system binaries.** PDFs go to the API as document attachments; no `pdftotext`, no `poppler`.
- **API:** Anthropic Messages API, model `claude-opus-4-7`, prompt caching (`cache_control: ephemeral`) on system prompt + each PDF document block

## Commands

```sh
# Default catch-all critique
echo "passage" | critique

# Capability hint (first word matched against prompts/capabilities/*.md)
echo "passage" | critique steelman the realist about hidden variables
echo "passage" | critique compress
echo "passage" | critique stress the load-bearing claims
echo "passage" | critique technical focus on gauge invariance

# From nvim, visual-select then:
:'<,'>w !critique >> .critique.md
:'<,'>w !critique steelman the realist >> .critique.md
```

No build step. No test runner. No lint config.

## Project Structure

**Dotfiles repo (versioned):**

```
~/code/dotfiles/
├── bin/critique                              # PEP 723 script (executable, on $PATH)
├── critique/
│   ├── SPEC.md                               # this document
│   └── prompts/
│       ├── system.md                         # base prompt; always loaded; contains "Be concise."
│       └── capabilities/
│           ├── compress.md
│           ├── steelman.md
│           ├── stress.md
│           └── technical.md
├── shell/zshrc-additions.sh                  # PATH += $HOME/code/dotfiles/bin
├── nvim/lua/plugins/critique.lua             # ~5 lines of keymap
└── install.sh                                # ensures uv present
```

**Per-paper layout (in `research-wip`):**

```
~/scholarship/research-wip/documents/papers/<slug>/
├── paper.tex
├── refs.bib
├── .sources/        → symlink to ~/Dropbox/Papers/<slug>/   (gitignored)
└── .critique.md                              (tracked in git; off-site backup, audit trail)
```

Long books in `.sources/` are pre-cut by the user (e.g., via Preview.app's page-range export) so each PDF is ≤ ~100 pages of relevant material.

## Code Style

Single-file Python, type hints on function signatures, no classes unless they earn their keep, f-strings, stdlib `pathlib`, `base64`, `json`, `os`, `sys`, `datetime`. Anthropic SDK for the API call. Errors print to stderr; `sys.exit(1)`. No defensive `try/except` for cases that shouldn't happen — solo project, trust the environment.

Representative shape (the heart of the API call):

```python
def build_messages(passage: str, sources: list[Path]) -> list[dict]:
    content: list[dict] = []
    for pdf in sources:
        data = base64.standard_b64encode(pdf.read_bytes()).decode()
        content.append({
            "type": "document",
            "source": {
                "type": "base64",
                "media_type": "application/pdf",
                "data": data,
            },
            "cache_control": {"type": "ephemeral"},
        })
    content.append({"type": "text", "text": passage})
    return [{"role": "user", "content": content}]


def load_sources(cwd: Path) -> list[Path]:
    sources_dir = cwd / ".sources"
    if not sources_dir.exists():
        return []
    pdfs = sorted(sources_dir.glob("*.pdf"))
    for pdf in pdfs:
        page_count = estimate_page_count(pdf)  # quick header parse, no full read
        if page_count > 100:
            print(f"warning: {pdf.name} is ~{page_count} pages; "
                  "quality may degrade", file=sys.stderr)
    return pdfs
```

## Testing Strategy

**No automated tests, no CI.** Solo project; the cost of writing tests exceeds the benefit at this scale. Manual verification consists of:

- A small set of sample passages in `~/code/dotfiles/critique/samples/` (created later, ad hoc) — re-run after prompt edits to compare outputs.
- A "smoke" check: `echo "trivial passage" | critique` returns a critique without crashing on a fresh install.

Revisit only if the tool ever gets two users or grows past ~500 lines.

## Boundaries

**Always do:**
- Each invocation is stateless. Inputs: stdin + cwd-discovered sources + optional hint argv. Outputs: stdout (and, when redirected, the log file).
- System prompt and each PDF document block get `cache_control: {"type": "ephemeral"}` on every call.
- Stream output line-buffered to stdout (`flush=True`) so `tail -f` shows tokens incrementally.
- Each `.critique.md` entry is self-contained: header (timestamp, paper slug from `cwd.name`, hint, list of source filenames) + blockquoted passage + response. Separated by `---` from prior entries.
- Include `Be concise.` in `prompts/system.md`.
- First-word hint match against capability filenames; no match → catch-all only.
- Warn on stderr if any PDF exceeds ~100 pages; proceed anyway.

**Ask first:**
- Adding a new file under `prompts/capabilities/`.
- Changing the default model.
- Changing the log entry format.
- Adding any CLI flag (e.g., `--model`, `--no-cache`, `--no-sources`).

**Never do:**
- Read `.critique.md` as input. It is write-only from the CLI's perspective. (Prevents critique-of-critique feedback loops.)
- Read `paper.tex` or any manuscript file from the CLI. Only stdin is the passage source.
- Persist conversation history between invocations.
- Auto-include sources from sibling or parent directories of `cwd`.
- Write a partial entry to `.critique.md` on API failure. Failure → stderr + exit 1, log untouched.
- Commit the `~/.env` file or any API key into the dotfiles repo.
- Manipulate PDF files (split, merge, extract pages). Source curation is the user's responsibility.

## Success Criteria

- [ ] `echo "test" | critique` on a fresh machine (after `install.sh` and setting `ANTHROPIC_API_KEY`) returns a streamed critique within a few seconds, exits 0.
- [ ] `:'<,'>w !critique >> .critique.md` from nvim appends a well-formed entry; `tail -f .critique.md` in another kitty pane shows tokens streaming in real time.
- [ ] In a paper dir with `.sources/` containing 3 moderate PDFs, second invocation within 5 minutes hits the Anthropic prompt cache (verifiable in response usage metadata) and runs noticeably faster and cheaper than the first.
- [ ] Hint `steelman ...` causes `prompts/capabilities/steelman.md` to be appended to the system prompt; hint `gobbledygook ...` does not match any capability and falls back to catch-all behavior.
- [ ] A scanned PDF in `.sources/` produces a coherent critique informed by its content (proves Claude's OCR path works, no client-side extraction needed).
- [ ] Missing `ANTHROPIC_API_KEY` (env and `~/.env`) → clear stderr error, exit 1, no partial output written.
- [ ] A PDF exceeding 32 MB triggers a clear stderr error from the API path and exit 1, with no partial log entry.
- [ ] A PDF over 100 pages produces a stderr warning but still runs.
- [ ] `.critique.md` is tracked in `research-wip`; `.sources/` is ignored.
- [ ] New-machine bring-up: `git clone dotfiles && ./install.sh && echo 'ANTHROPIC_API_KEY=…' >> ~/.env` is the entire setup.

## Open Questions

1. **Capability prompt contents.** `system.md` and the four capability files need real prose. The base prompt is the most engineering-heavy; the capability appendices are short refinements. Defer to Phase 3 (Tasks) so prompt-writing is a real task with a real iteration budget.
2. **Multi-machine `.critique.md` conflicts.** If you write on two machines and both append before pushing, you get a merge conflict. Acceptable: text merges are easy. Don't engineer around it.

---

## Resumption notes

Pick up at Phase 2 (Plan) of `spec-driven-development`. Do not re-litigate decisions in the spec without explicit cue from the user — the back-and-forth that produced this draft was deliberate and discarded several earlier shapes (a Neovim plugin, named modes, a chat sister tool, client-side PDF extraction with `pdftotext`).
