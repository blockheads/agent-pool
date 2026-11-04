---
name: task
description: Start a fire-and-forget worker (own tmux window, worktree, branch) that does one prompt end to end and opens a PR to {{BASE_BRANCH}}. Use when the user types /task <prompt>.
argument-hint: "[-a <account>] [--name <name>] <prompt>"
---

Start one worker for the prompt in the arguments with the `agent` command, then report in one line. Do not do the
work yourself.

1. **Name:** `--name` if given, else 2-3 lowercase words from the prompt joined by dashes (e.g. `fix-login-redirect`).
   It must not match a running worker (`agent status` lists them).
2. **Account:** `-a` if given. Otherwise run `agent status` and pick whichever Claude account (`agent accounts`;
   not `codex`) runs the fewest workers, `a` on a tie.
3. **Spawn:** `agent spawn --no-pr <account> <name> "<prompt>\n\n<footer>"` with the footer below, verbatim.
4. **Report:** `Started <name> on <account>: <prompt, one line>.` If the orchestrator state file exists
   (`{{STATE_FILE}}`), add the task under **Tasks** there.

Footer:

```
How to work (repo rules: CLAUDE.md, if any):
{{NOTES}}
- If you are blocked on a decision only the user can make, say so plainly and stop.
- When the work is done, ship it:
  1. `{{GATE}}` passes.
  2. Commit on your agent/<name> branch, push it, and open a draft PR to {{BASE_BRANCH}} (gh pr create --draft --base
     {{BASE_BRANCH}}) saying what changed and how it was checked. Never commit to or push {{BASE_BRANCH}}.
  3. Start a Codex review: agent spawn --no-pr codex review-<name> "Review draft PR #<n> in {{REPO_SLUG}} (gh pr diff
     <n>) against the repo rules (CLAUDE.md, if any): correctness bugs first, then rule breaks and missing tests. You
     only review: change no repo files, commit nothing, push nothing. Post one review with gh pr review <n> --comment,
     with inline comments where useful; say plainly if you found nothing. Then you must run:
     AGENT_SESSION={{SESSION}} agent send <name> \"Review of PR #<n> posted\" and stop."
  4. Wait for that message (do nothing else meanwhile), then close the reviewer: agent done review-<name>. Read the
     review (gh pr view <n> --comments; gh api for inline comments). Fix what is right, reply on each comment with
     what you did or why not, run `{{GATE}}` again, push. One round only.
  5. Mark it ready: gh pr ready <n>. Then say you are done, with the PR link. The user reviews and merges it.
```
