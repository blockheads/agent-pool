---
name: tasks
description: Show every running worker in one line each (account, task or session, PR and state). Use when the user types /tasks or asks how the workers are doing.
---

1. Run `agent status`.
2. Print one line per worker: `<name> (<account>): <working | idle | waiting for you | usage limit> · PR <link and
   state (a draft is still in review, not ready for the user), or none>`. Judge the state from its last lines: a
   question or plan awaiting approval is "waiting for you". Read deeper only for a worker that looks stuck or
   erroring, and say what is wrong. Show a `review-<name>` Codex worker under its worker (`reviewing` or `posted`),
   not as its own line.
3. List workers whose PR is MERGED or CLOSED as ready for `/sync`, and any worker that hit a usage limit (the
   background watcher moves it to another account; its log is `rebalance.log` next to the state file). Do not close
   or restart anything yourself.
4. If the orchestrator state file exists (`{{STATE_FILE}}`), bring its PR links and states up to date.
