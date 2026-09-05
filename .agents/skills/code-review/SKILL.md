---
name: code-review
description: Review the changes since a fixed point (commit, branch, tag, or merge-base) along two axes — Standards (does the code follow this repo's documented coding standards?) and Spec (does the code match what the originating issue/PRD asked for?). Runs both reviews in parallel sub-agents and reports them side by side. Use when the user wants to review a branch, a PR, work-in-progress changes, or asks to "review since X".
---

Two-axis review of the user's requested branch, commit range, or working changes:

- **Standards** — does the code conform to this repo's documented coding standards?
- **Spec** — does the code faithfully implement the originating issue / PRD / spec?

Both axes run as **parallel sub-agents** so they don't pollute each other's context, then this skill aggregates their findings.

This is a read-only review. Use existing repository and conversation context; tracker setup is not a prerequisite.

## Process

### 1. Capture the requested review target

Infer the target from the request and current task. Ask only if materially different interpretations remain. Record `git status --short`, relevant commit identities, and the exact file scope before reviewing.

- **Working changes / pre-commit review:** include tracked staged and unstaged changes with `git diff HEAD -- <task paths>` and read in-scope untracked files listed by `git ls-files --others --exclude-standard`. A diff of committed history alone cannot review this work. For an unborn branch, inspect the index, unstaged diff, and untracked files without requiring HEAD.
- **Staged-only or unstaged-only:** honor that scope using `git diff --cached` or `git diff`; include untracked files only when within the requested scope.
- **Branch / PR:** resolve the requested base and compare its merge-base with the branch tip. Capture the corresponding commit list.
- **Since a specific commit or tag:** compare that exact revision with the requested endpoint unless the user asks for merge-base semantics. For a single commit, review its patch; resolve a material merge-parent ambiguity before choosing a parent.

An invalid reference needs correction. An empty selected diff means there are no changes in that scope; do not silently substitute another target. Exclude unrelated pre-existing work, but inspect surrounding code where needed to understand impact. Give reviewers the captured patch and new-file contents or precise commands and scope. Check for material target changes before finalizing.

When assessing reported checks, use [verification evidence](references/verification-evidence.md) to distinguish current execution, justified reuse, and unexecuted work. Share the same evidence record with reviewers so they do not independently repeat the same check. Review stays read-only: use non-mutating checks or an isolated copy when execution is needed, and disclose limitations.

### 2. Identify the spec source

Use the user's current explicit intent and accepted conversation requirements first. Supplement them with a supplied spec, linked originating issue/PRD, and relevant repository documents. Fetch tracker context through an existing configured tool when available; do not start setup merely to review.

Distinguish accepted requirements from inferred assumptions. If no spec can be established, report that the Spec axis is unavailable and continue Standards and correctness review. Ask about a missing requirement only when it materially affects the conclusion.

### 3. Identify the standards sources

Anything in the repo that documents how code should be written, such as `CODING_STANDARDS.md` or `CONTRIBUTING.md`.

On top of whatever the repo documents, the Standards axis always carries the **smell baseline** below — a fixed set of Fowler code smells (_Refactoring_, ch.3) that applies even when a repo documents nothing. Two rules bind it:

- **The repo overrides.** A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell.
- **Always a judgement call.** Each smell is a labelled heuristic ("possible Feature Envy"), never a hard violation — and, like any standard here, skip anything tooling already enforces.

Each smell reads *what it is* → *how to fix*; match it against the diff:

- **Mysterious Name** — a function, variable, or type whose name doesn't reveal what it does or holds. → rename it; if no honest name comes, the design's murky.
- **Duplicated Code** — the same logic shape appears in more than one hunk or file in the change. → extract the shared shape, call it from both.
- **Feature Envy** — a method that reaches into another object's data more than its own. → move the method onto the data it envies.
- **Data Clumps** — the same few fields or params keep travelling together (a type wanting to be born). → bundle them into one type, pass that.
- **Primitive Obsession** — a primitive or string standing in for a domain concept that deserves its own type. → give the concept its own small type.
- **Repeated Switches** — the same `switch`/`if`-cascade on the same type recurs across the change. → replace with polymorphism, or one map both sites share.
- **Shotgun Surgery** — one logical change forces scattered edits across many files in the diff. → gather what changes together into one module.
- **Divergent Change** — one file or module is edited for several unrelated reasons. → split so each module changes for one reason.
- **Speculative Generality** — abstraction, parameters, or hooks added for needs the spec doesn't have. → delete it; inline back until a real need shows.
- **Message Chains** — long `a.b().c().d()` navigation the caller shouldn't depend on. → hide the walk behind one method on the first object.
- **Middle Man** — a class or function that mostly just delegates onward. → cut it, call the real target direct.
- **Refused Bequest** — a subclass or implementer that ignores or overrides most of what it inherits. → drop the inheritance, use composition.

### 4. Spawn both sub-agents in parallel

Use the host's available collaboration tools for independent reviewers within available slots while the parent checks context and target integrity. If delegation is unavailable, perform both axes sequentially and report that limitation. Keep briefs and messages legible.

**Standards sub-agent prompt** — include:

- The captured review target, patch including in-scope new files, and relevant commit identities.
- The list of standards-source files you found in step 3, **plus the smell baseline from step 3** pasted in full — the sub-agent has no other access to it.
- The brief: "Check correctness and regressions independently of spec availability, including affected control flow and failure cases. Report concrete bugs with supporting evidence. Also report — per file/hunk where relevant — (a) every place the diff violates a documented standard: cite the standard (file + the rule); and (b) any baseline smell you spot: name it and quote the hunk. Distinguish hard violations from judgement calls — documented-standard breaches can be hard, but baseline smells are always judgement calls, and a documented repo standard overrides the baseline. Skip anything tooling enforces. Be concise without omitting actionable findings."

**Spec sub-agent prompt** — include:

- The same captured review target and complete patch.
- The path or fetched contents of the spec.
- The brief: "Report: (a) requirements the spec asked for that are missing or partial; (b) behaviour in the diff that wasn't asked for (scope creep); (c) requirements that look implemented but where the implementation looks wrong. Quote the spec line for each finding. Be concise without omitting actionable findings."

If the spec is missing, skip the Spec sub-agent and note this in the final report.

### 5. Aggregate

Verify findings against the actual target and accepted intent, remove false positives and duplicates, then present them under `## Standards` and `## Spec`. Preserve the distinction between axes; the parent owns the final assessment.

End with a one-line summary: total findings per axis, and the worst issue _within each axis_ (if any). Don't pick a single winner across axes — that's the reranking the separation exists to prevent.

## Why two axes

A change can pass one axis and fail the other:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**

Reporting them separately stops one axis from masking the other.
