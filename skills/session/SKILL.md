---
name: session
description: Start an interactive worker (own tmux window, worktree, branch) that plans with the user first, builds only after approval, and opens a PR only when told. Use when the user types /session <name> [topic].
argument-hint: "[-a <account>] <name> [topic]"
---

Start one worker that the user will drive in its own tmux window. Do not plan or build anything yourself.

1. **Name:** the first argument (lowercase, dashes). It must not match a running worker (`agent status`).
2. **Account:** `-a` if given. Otherwise run `agent status` and pick whichever Claude account (`agent accounts`;
   not `codex`) runs the fewest workers, `a` on a tie.
3. **Spawn:** `agent spawn --no-pr <account> <name> "<topic>\n\n<footer>"` with the footer below, verbatim. With no
   topic, use `The user will describe the work when they attach.` as the topic.
4. **Report:** `Started session <name> on <account>. Attach: tmux window <name>.` If the orchestrator state file
   exists (`{{STATE_FILE}}`), add it under **Tasks** marked as an interactive session.

Footer:

```
This is an interactive session: the user will attach to this window and work with you.
- Start by reading what the topic needs (docs, the code), then write a plan the user's way: ASCII flow diagrams and
  pseudocode per piece first, files and tests after, little prose. Then stop and wait.
- Build nothing until the user approves the plan. Discuss and revise as asked.
- When building, follow the repo rules (CLAUDE.md, if any):
{{NOTES}}
- Leave the changes uncommitted for the user to review and iterate on. Never commit to or push {{BASE_BRANCH}}.
- If the user asks for a review without shipping, do steps 1-4 below and stop, leaving the PR a draft.
- When the user says "ship it" (or similar), finish without them:
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
