# agent-pool

Run several Claude Code (and Codex) agents on one repo in parallel, from one chat.

You talk to an **orchestrator**: Claude in window 0 of a tmux session. It starts **workers**. Each worker is a
Claude or Codex agent in its own tmux window, git worktree and `agent/<name>` branch. A shell script, `agent`,
does the plumbing. Five Claude Code skills (`/task`, `/session`, `/quick-task`, `/tasks`, `/sync`) define the
workflow.

```
you ⇄ orchestrator (tmux window 0, in the main checkout)
        │  /task  /session  /quick-task  /tasks  /sync
        │  → agent spawn / status / send / done
        ▼
workers: one tmux window + worktree + branch agent/<name> each
        │  draft PR → Codex reviewer (review-<name>) → one fix round
        ▼
gh pr ready → you review and merge → /sync closes the worker
```

It's a personal tool that grew out of daily use on one project. It works on Linux, but it isn't polished: read
[Known gaps](#known-gaps).

## Requirements

- Linux (see Known gaps)
- bash 4+. macOS ships bash 3.2, so install a newer one (`brew install bash`) and put it first on `PATH`.
- `tmux`, `git`, `python3`
- [`claude`](https://docs.claude.com/en/docs/claude-code) (Claude Code), logged in
- [`gh`](https://cli.github.com), logged in (`gh auth login`): workers open and review PRs with it
- `codex` (optional): only needed for Codex reviewers

`agent` checks these when it starts and says what's missing.

## Install

```bash
git clone <this repo> ~/agent-pool
ln -s ~/agent-pool/bin/agent ~/.local/bin/agent                 # anywhere on PATH
echo 'source ~/agent-pool/shell/cl.sh' >> ~/.bashrc             # optional: cl <account>
agent help
```

## Accounts

`a` is your default `~/.claude`. Any other name is a profile at `~/.claude-<name>`. `codex` is the Codex CLI.

```bash
agent profile b      # creates ~/.claude-b, sharing ~/.claude's settings, skills, memory and conversations
cl b                 # run Claude as b, then /login with the other account
agent accounts
```

Open each repo once with each account (`claude`, `cl b`, `codex`) and accept "trust this folder". Worktrees of a
trusted repo are trusted, so workers start without asking.

One account is enough. More than one only matters for spreading load and for [rebalancing](#usage-limits).
First read the note on multiple accounts in [Known gaps](#known-gaps).

## Set up a repo

```bash
agent init ~/code/myrepo   # first run: writes ~/.agent-pool/agents-myrepo/config
$EDITOR ~/.agent-pool/agents-myrepo/config
agent init ~/code/myrepo   # writes the five skills into myrepo/.claude/skills/
```

The config is a small bash file. `agent init` fills these values into the templates in `skills/`:

- `REPO_SLUG`: GitHub `owner/name`, used in the Codex review task
- `BASE_BRANCH`: what PRs target, and what `/quick-task` and `/sync` push to
- `GATE`: the command that must pass before every push (e.g. `make test`)
- `NOTES`: repo rules and setup for workers, one `- ` line each (build steps, test rules, ...)

`agent init` never overwrites a skill. Delete one to regenerate it, or edit the generated skills freely: they're
yours now. Commit `.claude/skills/`.

## Daily use

```bash
agent start ~/code/myrepo     # tmux session agents-myrepo, orchestrator on account a
agent start b ~/code/myrepo   # the same, orchestrator on account b
```

`agent start` is also how you get back in. Before attaching, it restores whatever is missing: the orchestrator,
and every worker that still has a worktree. A window closed while its Claude still runs in the background is
reattached. Otherwise its conversation is resumed. Records live in `~/.agent-pool/agents-<repo>/`.

In the orchestrator:

- `/task <prompt>`: fire-and-forget. The worker does the work and ships it through the PR flow below.
- `/session <name> [topic]`: an interactive worker. It writes a plan and waits. You attach (`Ctrl-b w`, pick the
  window), discuss, approve, iterate, and say "ship it".
- `/quick-task <prompt>`: a small change that skips the PR and review. The worker rebases, runs `GATE` and pushes
  straight to `BASE_BRANCH`.
- `/tasks`: one line per worker (working / idle / waiting for you / usage limit) and its PR.
- `/sync`: pulls and pushes `BASE_BRANCH` in the main checkout, closes finished workers (merged or closed PR,
  landed quick task) and tells workers whose PRs conflict to merge.

You can also just talk to the orchestrator. It uses `agent spawn`, `status`, `send` and `done` itself
(`orchestrator/CLAUDE.md` is its system prompt). It won't type into a window you're in.

The skills spawn their workers with `agent spawn --no-pr`, because the skill's own footer says how to finish. A
plain `agent spawn` adds a "commit, push, `gh pr create`" ending.

### The PR flow (`/task`, and `/session` after "ship it")

1. `GATE` passes.
2. The worker commits on `agent/<name>`, pushes, and opens a **draft** PR to `BASE_BRANCH`.
3. It spawns a Codex reviewer (`review-<name>`), which posts one `gh pr review` and messages the worker back.
4. The worker closes the reviewer, fixes what's right, replies to each comment, runs `GATE` and pushes.
   One round only.
5. `gh pr ready`. The worker reports the link.
6. You review and merge. `/sync` then removes the worker's window and worktree. The branch is kept.

No Codex? Edit step 3 out of the generated skills.

## Usage limits

When a Claude agent shows a usage-limit message, `agent rebalance` resumes its conversation on the account with
the fewest agents that isn't limited, then tells it to continue. Agents that are still working stay put. The
orchestrator moves too.

`agent start` and `agent spawn` start a background watcher, `agent watch`. It's a plain shell loop with no model
and no tokens, that runs rebalance every 90 s while the session exists. Its log is
`~/.agent-pool/agents-<repo>/rebalance.log`. Use `agent watch --stop` to stop it, or `AGENT_AUTO_REBALANCE=0` to
not start it.

You can also move the orchestrator by hand: `agent orch b` continues the same chat on `b` (`--fresh` starts a new
chat from its state file).

## Remote Control

Every Claude session (orchestrator and workers) joins Remote Control, so it shows up in the Claude app as
`<repo> orchestrator` or `<repo> <worker>`, and you can follow or answer it from your phone. Set
`AGENT_REMOTE_CONTROL=0` to turn that off.

## Worktree hooks

New worktrees have no build directory, no untracked caches, nothing that isn't in git. Two optional executables
in `~/.agent-pool/agents-<repo>/` fix that:

- `setup-worktree <worktree> <name> <repo>`: run by `agent spawn` after creating the worktree (e.g. give the
  worker its own build dir and symlink shared toolchains into it). If it fails, the spawn fails.
- `teardown-worktree <worktree> <name> <repo>`: run by `agent done` before removing the worktree (undo the setup).

`agent done` refuses to remove a worktree with uncommitted changes. It ignores untracked symlinks, since the
setup hook typically makes those.

Example `setup-worktree`, sharing one big dependency folder:

```bash
#!/usr/bin/env bash
set -euo pipefail
wt="$1" name="$2" repo="$3"
ln -sfn "$repo/node_modules" "$wt/node_modules"
```

## Permissions

By default, workers ask for permissions like any Claude Code session. You approve them in the worker's window or
from the Claude app.

To let workers run unattended, put this in the repo's config:

```bash
AGENT_SKIP_PERMISSIONS=1
```

Claude workers then get `--dangerously-skip-permissions` and Codex workers get `--yolo`. The orchestrator never
does. `agent start` prints a reminder when this is on.

> **Warning:** with this on, workers run any command, edit any file and push without asking. A confused agent or
> a prompt injection (from an issue, a PR comment or a web page) can do real damage. Only turn it on for repos you
> trust, on a machine where that's acceptable.

## Settings

Set these in the environment, or per repo in `~/.agent-pool/agents-<repo>/config`. The config wins.

- `AGENT_SKIP_PERMISSIONS=1`: workers skip permission prompts (see above). Default `0`.
- `AGENT_CLAUDE_ARGS` / `AGENT_CODEX_ARGS`: extra flags for every launch, e.g. `--model sonnet`.
- `AGENT_REMOTE_CONTROL=0`: don't join Remote Control.
- `AGENT_AUTO_REBALANCE=0`: no background watcher. `AGENT_WATCH_EVERY`: its interval in seconds (default 90).
- `AGENT_LIMIT_RE`: the regex that detects a usage-limit message (see Known gaps).
- `AGENT_STATUS_LINES`: how many last lines `agent status` shows per worker (default 5).
- `AGENT_STATE_ROOT` (default `~/.agent-pool`): state files and worktrees.
- `AGENT_NO_ATTACH=1`: `agent start` sets everything up but doesn't attach.

## Files

- `bin/agent`: the CLI (`agent help`)
- `orchestrator/CLAUDE.md`: the orchestrator's system prompt
- `skills/`: skill templates for `agent init`
- `shell/cl.sh`: `cl <account>`, to run Claude as an account anywhere
- `~/.agent-pool/agents-<repo>/`: config, hooks, `state.md` (the orchestrator's notes), `agents/` (records),
  `rebalance.log`
- `~/.agent-pool/worktrees/<repo>/<name>/`: worker worktrees

## Known gaps

- **Rebalance has never seen a real usage limit.** `AGENT_LIMIT_RE` is a guess at Claude's wording. If it doesn't
  match, nothing moves. If it matches something else, a working agent gets restarted. Check
  `rebalance.log` and adjust the regex.
- **No tests.** Everything has been checked by hand.
- **Linux only so far.** It uses `/proc` for uuids and `readlink -f`, and has never run on macOS. Even with a newer
  bash, expect fixes to be needed there.
- **Multiple Claude accounts:** check your plan's terms before using several accounts, and before using the
  rebalance feature, which moves work between accounts when one hits its limit. Whether that's allowed is up to
  your plan, not this tool.
- Screen-scraping: `agent status`, rebalance and "is it ready" all read the tmux pane. A Claude Code UI change can
  break them.

## License

MIT, see [LICENSE](LICENSE).
