# agent-pool

You talk to an orchestrator (Claude in tmux). It splits work into tasks and starts Claude or Codex workers, each in
its own tmux window and git worktree. Workers open PRs; `@claude` in a PR comment fixes it (GitHub Action).

```
you ⇄ orchestrator (window 0)
        │ agent spawn / status / send / done
        ▼
  workers: one tmux window + worktree + branch agent/<name> each
        │ gh pr create
        ▼
  you review → @claude in a comment → the Action pushes fixes and replies
```

## Setup

1. `gh` installed and logged in (`gh auth login`): workers open PRs with it.
2. A second Claude account: `agent profile b`, then `cl b` and `/login` with that account. The profile shares
   `~/.claude`'s instructions, settings, skills, plugins, hooks, memory and conversations; only the login and
   `.claude.json` (trusted folders, user-scope MCP servers) are its own.
3. Open each repo once with each account (`claude`, `cl b`, `codex`) and accept "trust this folder". Worktrees of
   a trusted repo are trusted, so workers start without asking.
4. Optional, per repo: copy `github/claude.yml` to `.github/workflows/` (see its header for the secret).

## Use

```bash
agent start ~/code/myrepo     # tmux session agents-myrepo, orchestrator on account a
agent start b ~/code/myrepo   # the same, orchestrator on account b
```

`agent start` is also how you get back in: it restores whatever is missing (the orchestrator, every worker with a
worktree) before attaching. A closed window whose Claude is still running in the background is reattached
(`claude attach`); otherwise its conversation is resumed (the orchestrator by its recorded session id, a worker by
the newest conversation in its worktree). Records live in `~/.agent-pool/agents-<repo>/agents/`.

Then talk to the orchestrator. `Ctrl-b w` lists the windows; switch to a worker to work with it directly
(the orchestrator won't type into a window you're in).

The orchestrator hit its limit? Run `agent orch b` from any shell inside the session. It continues the same
conversation on the other account (`--fresh` starts over from its state file instead; `agent orch codex` works too).
`agent start b` does the same from outside: a running orchestrator on another account is switched to `b` (same
chat), and `b` is recorded, so later restores use it.

`agent help` lists the commands. `cl <account>` runs Claude Code as an account anywhere.

## Settings

- `AGENT_CLAUDE_ARGS` / `AGENT_CODEX_ARGS`: extra flags for every launch (e.g. a model or permission mode).
  The orchestrator is a good place for a cheaper model: `AGENT_CLAUDE_ARGS="--model sonnet" agent orch a`
  (note it applies to every claude launch in that shell).
- `AGENT_REMOTE_CONTROL=0`: don't join Remote Control. By default every Claude session (orchestrator and workers)
  shows up in the Claude app as `<repo> orchestrator` / `<repo> <worker>`.
- `AGENT_STATE_ROOT` (default `~/.agent-pool`): state files and worktrees.
