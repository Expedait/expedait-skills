# Skill eval battery

A local test battery for the Expedait skills. It exists because these skills' whole job
is to make an agent pick the right `expedait` commands, flags, and order — and avoid
destructive ones. So the battery evaluates **which tool calls the agent makes**, not
prose quality, and it does so **hermetically**: a mock CLI shadows `uvx --from
expedait-cli expedait …`, records every invocation, and returns canned fixtures. No auth,
no network, no live Expedait backend.

## Layout

```
evals/
  lint.py                 # Tier 1: static frontmatter/body checks (no agent)
  runner.py               # Tier 2: install skill -> claude -p -> grade command log
  grade.py                # deterministic grader (pure functions)
  test_lint.py            # agent-free pytest for lint.py
  test_grade.py           # agent-free pytest for grade.py
  mock/
    uvx                    # shim: forwards `--from expedait-cli expedait` to ./expedait
    expedait               # fake CLI: logs argv to $EXPEDAIT_MOCK_LOG, prints fixtures
    fixtures/*.json        # canned responses keyed by `<group>_<command>.json`
  <skill>/evals.json       # eval cases per skill (Anthropic skill-creator schema + assertions)
```

## Tiers

| Tier | Command | Agent? | Backend | Runs |
|------|---------|--------|---------|------|
| 1 — static lint | `python3 evals/lint.py` | no | none | CI, every PR |
| 1 — unit tests | `uv run --with pytest pytest evals/` | no | none | CI, every PR |
| 2 — battery | `python3 evals/runner.py` | yes (`claude`) | mock | local only |
| 3 — latency probe | `python3 evals/perf.py --deliverable ID` | no | **live** | local only |

Only the deterministic Tier 1 runs in CI (`.github/workflows/check-evals.yml`) — fast, no
secrets, no model tokens. The agent battery and latency probe are **local dev tools**: run
them yourself when iterating on a skill. The battery records each eval's wall-clock
(`duration_ms`) so you can watch for skills that make the agent take more/longer steps.

Tiers 1 need nothing but Python. Tier 2 needs the `claude` CLI on PATH (and credentials).
If `claude` is absent, `runner.py` skips the agent runs and exits 0, so an unconfigured CI
job stays green.

## Running the battery

```bash
python3 evals/runner.py                       # all skills, default model
python3 evals/runner.py --skill expedait-comment
python3 evals/runner.py --model claude-haiku-4-5-20251001   # cheaper/faster for iteration
python3 evals/runner.py --discover            # measure auto-trigger instead of invoking
python3 evals/runner.py --dry-run             # validate schema + wiring, no agent
python3 evals/runner.py --keep                # keep workspaces under evals/.results/
```

Multi-model coverage (the best-practices checklist asks for Haiku/Sonnet/Opus): loop the
`--model` flag.

### Invoke vs. discover mode

These skills are `user-invocable`, so users run them explicitly (`/expedait-author …`).
Two things can go wrong, and they are different failures:

- **Usability** — once loaded, can the model follow the skill and run the right commands?
- **Discovery** — from a bare natural-language prompt, does the model auto-trigger the
  skill by its description at all?

By **default the runner invokes the skill explicitly** (`/<skill> <prompt>`), isolating
usability — this is the gating signal and mirrors real use. `--discover` uses the raw
prompt to measure auto-trigger; small models under-trigger in headless mode, so treat
discover-mode results as a softer signal for tuning descriptions, not a hard gate.

On Haiku, the skills score full marks in invoke mode; discover mode is lower and is what
front-loading the description and a "Commands at a glance" table improve.

## Eval schema

`<skill>/evals.json` follows Anthropic's skill-creator format (`skill_name`, `evals[]`
with `id`, `prompt`, `expected_output`, `files`, `assertions`) and adds one field,
`command_assertions`, for the deterministic grader:

```jsonc
{
  "id": 1,
  "prompt": "Download the specs for project 1 so I can review them.",
  "files": {},                          // optional: relative path -> file contents
  "setup": {"git": true},               // optional: init a git repo + feature branch
  "assertions": [                       // for an optional LLM grader (not wired by default)
    {"name": "downloads-project", "description": "Fetches the deliverables to disk"}
  ],
  "command_assertions": {
    "must_call":     [{"args_contain": ["projects", "download"]}, {"args_contain": ["--output-dir"]}],
    "must_not_call": [{"args_contain": ["deliverables", "delete"]}],
    "order":         [{"args_contain": ["deliverables", "get", "5"]}, {"args_contain": ["comments", "create"]}]
  }
}
```

Matchers:
- `{"args_contain": [t...]}` — every token is a member of the command's argv (order-insensitive).
- `{"args_subseq":  [t...]}` — tokens appear as an ordered subsequence of argv.

Grading rules: every `must_call` matcher must match ≥1 logged command; every
`must_not_call` must match 0; `order` matchers must appear as a relative subsequence.

## Adding fixtures

The mock keys off the first two positional tokens: `expedait deliverables get 5` looks
for `fixtures/deliverables_get.json`, falling back to a generic `{"status": "ok"}`. Add a
fixture only when the agent needs realistic data to proceed. `projects download` also
writes sample deliverable files into its `--output-dir` so downstream reads have content.

## What this does not do

- It does not hit the real Expedait backend. High-fidelity checks against a seeded
  staging tenant (real `uvx expedait`, assert on backend state) are a local exercise —
  not the PR path.
- The `assertions` (name/description) field is carried for skill-creator compatibility
  and an optional LLM-as-judge pass; the default grader uses `command_assertions` only.
