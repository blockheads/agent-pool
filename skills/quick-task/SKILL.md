---
name: quick-task
description: Start a worker for a small change that lands straight on {{BASE_BRANCH}}, with no PR and no review. Use when the user types /quick-task <prompt>.
argument-hint: "[-a <account>] [--name <name>] <prompt>"
---

Start one worker for the prompt in the arguments with the `agent` command, then report in one line. Do not do the
work yourself. The user asked for this path: a quick task pushing to `{{BASE_BRANCH}}` is authorized.

1. **Name:** `--name` if given, else `quick-` plus 1-3 lowercase words from the prompt, joined by dashes. It must not
   match a running worker (`agent status` lists them).
2. **Account:** `-a` if given. Otherwise run `agent status` and pick whichever Claude account (`agent accounts`;
   not `codex`) runs the fewest workers, `a` on a tie.
3. **Spawn:** `agent spawn --no-pr <account> <name> "<prompt>\n\n<footer>"` with the footer below, verbatim.
4. **Report:** `Started <name> on <account>: <prompt, one line>.` If the orchestrator state file exists
   (`{{STATE_FILE}}`), add the task under **Tasks** there.

Footer:

```
This is a quick task: a small change that lands straight on {{BASE_BRANCH}}, with no PR and no review.
{{NOTES}}
- Do only what was asked. Add a fast test if behaviour changes.
- Stop and say so, without pushing, if it turns out to need a design decision or more than a small change: the user
  will rerun it as /task or /session.
- To land it:
  1. Commit on your agent/<name> branch, one commit.
  2. git fetch origin && git rebase origin/{{BASE_BRANCH}}. If a conflict's intent isn't clear, stop and say so.
  3. `{{GATE}}` passes. If it fails, fix it and run it again.
  4. git push origin HEAD:{{BASE_BRANCH}} (never --no-verify). If it is rejected because {{BASE_BRANCH}} moved, repeat
     from step 2. This is the only push you may make.
  5. touch "$(git rev-parse --git-dir)/quick-task-landed", then say you are done, with the commit hash.
```
