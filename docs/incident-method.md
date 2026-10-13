# Incident method

Every lab is worked through the same seven steps, and every `answer.md` follows them.

| # | Step | Question | Habit |
|---|---|---|---|
| 1 | **Impact** | Who is affected, how badly? Is there a fast mitigation (rollback, failover)? | Restore users first, then find the cause — but know what a rollback actually rolls back |
| 2 | **Request path** | Which layers does a request cross? | Write it down: client → LB → proxy → port → process → app → dependencies |
| 3 | **Observe (read-only)** | Is each layer healthy? | First commands change nothing: `status`, `logs`, `ss`, `curl -v`, `describe`, `get` |
| 4 | **Hypothesis → proof** | "X is broken because Y; command Z will show it" | Say what you expect before you run it; build a timeline (`stat`, journal, events, history) |
| 5 | **Smallest safe fix** | Is it reversible? Does it expose a secret? Will automation undo it? | One change at a time; secrets never on screen, in history or in argv |
| 6 | **Verify end to end** | Does the user-visible behaviour work again? | Inside-out, layer by layer, `curl -fsS`, watch for a few minutes, alert resolved |
| 7 | **Root cause & prevention** | Why did it happen, why wasn't it caught, how can it not recur? | Fix it in code: pipeline gate, IaC, policy, alert — not in a runbook note |

## Habits that come up again and again
- `curl -fsS`: without `-f` an HTTP 5xx is a successful command.
- List secret **keys**, never values: `cut -d= -f1`, `jq 'keys'`, `wc -c`.
- `--no-pager` on `systemctl`/`journalctl` so output can be copied into notes.
- A deploy that restarts a service can *expose* a problem that was introduced earlier — check what changed before the deploy too.
