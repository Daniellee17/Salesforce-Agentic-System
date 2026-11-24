---
name: apex-clean-code
description: In-depth clean code review and refactor of the crm-coe repo's changed Apex classes and triggers - naming, doing one thing per level of abstraction, boolean logic, method depth, null and empty handling, guard clauses, exception boundaries and atomicity in triggers, OOP, SOLID/DRY/YAGNI, coupling and cohesion, dependency injection, test design and where business logic belongs. It reviews in several passes, explains the reasoning, impact and risk of every finding, applies the safe behaviour-preserving fixes in src/main/default, re-copies the files into deploy/, and proposes larger design changes with a concrete sketch for the user to decide. Fully self-contained, with no outside source needed. Apex only. Use it when the user asks for clean code, a clean code review, to refactor or tidy Apex, to make Apex more readable or maintainable, or to apply clean code principles.
---

# Apex clean code

An in-depth clean code review of the Apex the current user story touches. Everything needed is in this folder: this file runs the review, and the files in `references/` hold the depth (why each principle matters, the signals to look for, how to decide, worked Apex examples and when to leave code alone). Never look for or read an outside source.

| Reference | Read it when the code has |
|---|---|
| `references/naming-and-logic.md` | unclear names, collections, maps, magic numbers, compound or negated conditions |
| `references/methods.md` | long or mixed methods, extracted helpers, boolean or many parameters, side effects, growing `if`/`switch` chains |
| `references/nulls-and-errors.md` | null or empty checks, nested validation, try/catch, DML on several objects, trigger after-logic, async work |
| `references/design.md` | several classes, inheritance, interfaces, duplication, utility classes, dependencies, callouts |
| `references/tests-and-architecture.md` | test classes, trigger handlers, record-type or status branching, logging, unfinished features |

Read every reference that matches what is in scope before writing findings. They are short and the review depends on them.

## Repo rules come first

These override any clean code guideline they conflict with:

- No comments of any kind, including "why", reference and to-do comments. Express intent through names, constants and small methods instead.
- Match the style of the surrounding code.
- Do not rename or change the signature of public or global methods, classes, fields, `@AuraEnabled`, `@InvocableMethod` or `@TestVisible` members that other code, Flows, LWCs or integrations may use. Report those instead.
- Do not change behaviour. Refactoring keeps the same inputs, outputs, records written, queries, DML order and exceptions.

## Scope

1. Check the branch and `git status` in `C:\Users\espiritd\Documents\Repos\crm-coe`.
2. List the changed Apex and whether each file is new on the branch:

   ```powershell
   & "$HOME\.claude\skills\apex-pmd-rules\Run-ApexPmd.ps1" -ListOnly
   ```

3. **NEW** files: review the whole file. **EXISTING** files: review the code this branch changed (`git diff origin/develop...HEAD -- <file>` plus uncommitted changes) and the methods that code sits in. Read the rest of the file for context, but do not clean up untouched legacy code, because that widens the diff and the test effort. Mention a serious legacy problem in one line at most.
4. If the user names files or classes, use those instead.

## Review passes

Do the passes in order. Earlier passes decide what later findings mean, so do not jump straight to line-level nits.

1. **Understand the intent.** Read each class, its test class, and who calls it (search `src/main/default` for the class name in Apex, Flows, LWC and triggers). Write a two or three sentence summary of what the code is for in business terms and how it runs (trigger context, batch, queueable, invocable, controller). If you cannot state the intent, that is the first finding.
2. **Structure.** List each method with its one-line responsibility and level of abstraction (orchestration, business rule, data access, low-level detail). Look for mixed levels, wrong splits, shallow pass-through layers, god methods, and logic in the wrong class. See `methods.md` and `design.md`.
3. **Runtime and platform.** Follow the transaction: bulk safety, SOQL and DML inside loops, governor limits, sharing and access mode, which records are written in which order, what happens when one record fails, and whether a failure here can roll back an unrelated save. See `nulls-and-errors.md`.
4. **Line level.** Names, conditions, magic values, null and empty handling, guard clauses. See `naming-and-logic.md` and `nulls-and-errors.md`.
5. **Tests.** Whether tests check observable behaviour, cover the bulk and failure paths, and would survive a refactor. See `tests-and-architecture.md`.
6. **Sanity check.** Drop any finding that is purely taste, that conflicts with the surrounding style, or whose fix costs more than it saves. Say plainly when code is already clean.

## Findings

Report one table per file, NEW files marked, most important first:

| # | LINE | AREA | FINDING | WHY IT MATTERS | FIX | TYPE | RISK |
|---|---|---|---|---|---|---|---|

- **AREA:** Naming, Logic, Methods, Nulls, Errors, Design, Tests or Architecture.
- **WHY IT MATTERS:** the concrete consequence in this code (a bug it invites, a change it makes harder, a limit it could hit), not the name of a principle.
- **TYPE:** **Safe fix** (local, behaviour-preserving, one class, no public signature change) or **Proposal** (new or split classes, interfaces, injected dependencies, trigger or async changes, moving logic across classes, public API changes).
- **RISK:** what could break if the fix is done wrong, and how it would show up.
- **Severity order:** first anything that risks wrong data, failed saves or limit errors, then anything that makes the next change hard or error-prone, then readability.

For every **Proposal**, add a short sketch below the table: the target shape of the code (class and method signatures, how callers change) and the trade-off. Keep sketches original and in the repo's style, without comments.

## Applying fixes

1. Before editing, follow CLAUDE.md: compare each file with QA by retrieving into a temp folder (`sf project retrieve start --metadata ApexClass:<Name> --target-metadata-dir <temp> --unzip --target-org qa`), never into `src`. Tell the user if QA differs from the branch in a way that is not part of this story.
2. Apply the safe fixes in `src/main/default`, one finding at a time. Keep each file's line endings and encoding.
3. Re-read the full diff and confirm behaviour is unchanged: the same queries, the same DML in the same order, the same exceptions and the same return values. Revert any fix you cannot prove is behaviour-preserving and report it as a Proposal instead.
4. Copy each changed file into `deploy/classes` or `deploy/triggers` so they are byte-identical, but only for files that already belong in `deploy/`.
5. Apply a Proposal only when the user agrees to that specific one.
6. If the `apex-pmd-rules` skill is available, run its check so the refactor adds no PMD violations.
7. Report what changed, what was left as a Proposal and why, that the tests have not run unless they did, and `git diff --stat`.

## Rules

- Apex only. Never touch LWC, Aura, JavaScript, Flows or metadata XML other than an Apex file's own `-meta.xml`.
- Never commit, stage, deploy or validate as part of this skill. Never retrieve into `src`.
- Page layouts never go in `deploy/`.
- Principles are guidelines, not violations. Prefer a few clearly useful changes over a large stylistic rewrite.
