---
description: Review my answer to a lab (or run the next interactive round) and update progress
argument-hint: <lab number, e.g. 07>
---

Lab number: $ARGUMENTS (if empty, use the most recent lab with status OPEN or IN-PROGRESS).

1. Read `CLAUDE.md`, `progress/tracker.md`, the lab's `README.md`, `answer.md`, `rounds.md` (if any) and `.solution.md` (if missing, derive the reference solution from the lab files now).
2. If the learner answered in chat, append that answer to `answer.md` first.
3. For runnable labs, if the cluster `lab-NN` exists, run `bash verify.sh` and use the result as evidence. A passing verify is necessary but not sufficient for a high score; the reasoning and prevention matter too.
4. **Interactive round** — if the learner is mid-investigation (simulated labs, or asked for the next step): append `## Round N` to `rounds.md` with their commands and realistic outputs consistent with `.solution.md`, show the outputs, ask for the next step, set status `IN-PROGRESS`, and stop.
5. **Final review** — write `review.md` in Turkish (technical terms in English):
   - `## Puan: X/10` with the rubric breakdown
   - `## Doğru yaptıkların`
   - `## Eksikler ve hatalar` (reference their own commands)
   - `## Doğru yaklaşım` (concise ordered commands + reasoning)
   - `## Production / güvenlik notları`
   - `## Bir sonraki labda tekrar edilecek`
6. Set the status line to `REVIEWED · Score X/10`.
7. Update `progress/tracker.md`: History row, skill-matrix reviewed count and average, weak areas (add new gaps; remove an area after two good answers), level per `CLAUDE.md`.
8. Commit with message `lab NN: review (X/10)` and push, so the cloud routine sees the updated tracker. If push fails, tell me.
9. In chat: score, the 3 most important gaps, new level.
