---
name: apex-clean-code
description: Reviews and cleans the crm-coe repo's changed Apex classes and triggers against the principles of the book Clean Apex Code (Pablo Gonzalez, 2025) - naming, doing one thing per level of abstraction, boolean logic, method depth, null and empty handling, guard clauses, exception boundaries in triggers, OOP, SOLID/DRY/YAGNI, coupling and cohesion, dependency injection and testing observable behaviour. It reports findings as a table, applies the safe local fixes in src/main/default, re-copies the files into deploy/, and proposes larger design changes for the user to decide. Apex only. Use it when the user asks for clean code, a clean code review, to refactor or tidy Apex, to make Apex more readable or maintainable, or to apply the Clean Apex Code book.
---

# Apex clean code

Apply the principles of *Clean Apex Code* to the Apex the current user story touches. The book is at `C:\Users\espiritd\Documents\salesforce_agentic_system\resources\Clean_Apex_Code.pdf`. The checklist below is a summary in our own words. When a finding needs more depth, read the relevant chapter (see the chapter map) instead of guessing. Never copy text or code from the book into the repo or the chat.

## Repo rules come first

These override the book wherever they conflict:

- No comments of any kind. The book allows "why", reference and to-do comments; this repo does not. Express intent through names, constants and small methods instead.
- Match the style of the surrounding code.
- Do not rename or change the signature of public or global methods, classes, fields, `@AuraEnabled`, `@InvocableMethod` or `@TestVisible` members that other code, Flows, LWCs or integrations may use. Report those instead.
- Do not change behaviour. Clean code is refactoring: same inputs, same outputs, same DML, same queries.

## Scope

1. Check the branch and `git status` in `C:\Users\espiritd\Documents\Repos\crm-coe`.
2. List the changed Apex and whether each file is new on the branch:

   ```powershell
   & "$HOME\.claude\skills\apex-pmd-rules\Run-ApexPmd.ps1" -ListOnly
   ```

3. **NEW** files: review the whole file. **EXISTING** files: review only the code this branch changed (`git diff origin/develop...HEAD -- <file>` plus uncommitted changes) and the methods that code sits in. Do not clean up untouched legacy code, because that widens the diff and the test effort.
4. If the user names files or classes, use those instead.

## Steps

1. Read every in-scope file and its test class.
2. Go through the checklist and collect findings. For each one, decide whether it is a **safe fix** or a **design proposal**:
   - **Safe fix:** local, behaviour-preserving, inside one class, does not touch a public signature. Examples: rename a local variable, extract a magic number to a constant, name a boolean expression, add a guard clause, use `String.isBlank`, extract a private method that is a real subtask.
   - **Design proposal:** anything that adds or splits classes, adds interfaces, injects dependencies, changes trigger architecture, moves logic across classes, or changes a public API.
3. Show the user one table: FILE / LINE / PRINCIPLE / FINDING / FIX TYPE (safe fix or proposal), grouped by file, with NEW files marked.
4. Before editing, follow CLAUDE.md: compare each file with QA by retrieving into a temp folder (`sf project retrieve start --metadata ApexClass:<Name> --target-metadata-dir <temp> --unzip --target-org qa`), never into `src`. Tell the user if QA differs from the branch in a way that is not part of this story.
5. Apply the safe fixes in `src/main/default`. Keep each file's line endings and encoding. Then copy each changed file into `deploy/classes` or `deploy/triggers` so they are byte-identical, but only for files that already belong in `deploy/`.
6. Do not apply design proposals unless the user agrees to each one.
7. If the user has the `apex-pmd-rules` skill, run its check afterwards so the refactor introduces no new PMD violations.
8. Report what changed, what was left as a proposal and why, that the tests have not run unless they did, and `git diff --stat`.

## Checklist

### N - Naming (chapter 2)

- **N1** Names reveal intent and answer "what is this for", not just "what type is it". Avoid abbreviations nobody can pronounce or search for (`acctRecs`, `paTk`, `cs`).
- **N2** Lists and sets use the plural of what they hold (`accounts`, `closedOpportunities`), not the type (`accountList`). Maps are named `<values>By<key>` (`accountsById`, `contactsByAccountId`). Be consistent with the surrounding code.
- **N3** Variables of the same type differ by meaning (`oldOpportunity` / `newOpportunity`, `parentCase` / `childCase`), never `o1` / `o2` or `opportunity1` / `opportunity2`.
- **N4** Names stay true after a requirement change. If a variable now holds a subset, the name says so.
- **N5** Use the platform's own vocabulary (`TriggerHandler`, `afterUpdate`, `bc`, `Batchable`) instead of invented terms.
- **N6** camelCase for variables and methods, PascalCase for classes. Do not name a variable the same as a class or sObject type when it reads ambiguously.
- **N7** Short names are fine for short-lived, low-impact variables (`i` in a loop). A short-lived variable that changes behaviour (for example an all-or-none flag) still gets a clear name.
- **N8** No magic numbers or strings in business logic. Use a named constant, or the `Limits` class for governor limits. Names should be searchable.
- **N9** Boolean variables and methods read as a question or a state (`isGoldTier`, `hasStageChanged`), consistently.

### B - Boolean logic (chapters 1-2)

- **B1** Name compound conditions. Pull them into well-named Boolean variables or private methods so the `if` reads like the acceptance criteria.
- **B2** No double negatives or redundant comparisons (`!= false`, `== true` on a non-null Boolean field). Use the field itself or `!field`.
- **B3** Logic that decides a business concept used in several places (tier, partner account, eligibility) belongs in one reusable method.

### M - Methods: one thing, depth and subtasks (chapters 3-4)

- **M1** A method does not mix levels of abstraction. High-level steps sit next to each other, and low-level details (string building, crypto, maths, parsing) live in their own method or class.
- **M2** Extract a subtask when it makes sense on its own: it can be named, read and tested without knowing the parent. Do not extract a piece that only works because the parent set up hidden state. That is the wrong split.
- **M3** Do not chop methods into chains of one-line pass-through methods just to make them short. A longer method that coordinates clear steps is fine. Public methods should be deep: lots of value behind a simple signature.
- **M4** Very short methods are worth it when they give an action a name, hide an implementation detail, or simplify the API for callers.
- **M5** Boolean parameters: allowed only when there is one, it refines the main behaviour at the same level of abstraction, and it is well named. Otherwise split into two methods, or use an options object or enum.
- **M6** Side effects: a method must not secretly do something its name does not say (callouts, DML on unrelated objects, deleting children). Move unrelated work out.
- **M7** A long `if`/`switch` on a type or operation that keeps growing is a candidate for an enum plus a map of strategy classes. This is a design proposal, not a safe fix. Only suggest it when variations really exist (YAGNI).

### V - Null, empty, validation and guard clauses (chapter 6)

- **V1** Use guard clauses at the top of a method to exit early instead of nesting the main logic several levels deep. Avoid scattering `return` statements through the middle of complex logic.
- **V2** Validate parameters in their own method when that keeps the parent at one level of abstraction. Fail fast on invalid input.
- **V3** Use `String.isBlank` / `String.isNotBlank` instead of manual `null` / `''` checks.
- **V4** Use `isEmpty()` instead of `size() > 0` / `size() == 0`. Check `isEmpty()` before DML on a list you built: an empty DML costs no limits but noticeably more CPU.
- **V5** Do not null-check a collection you just instantiated in the same method. It hides bugs. Do null-check collections and objects that come in as parameters.
- **V6** Use `containsKey` before `get` on a map you did not build yourself from a query.
- **V7** Prefer `??` for defaults. Use `?.` sparingly: it often only moves the null problem further down.
- **V8** Return `null` when a single lookup finds nothing, an empty list when a list is expected, and throw only for exceptional conditions.

### E - Exceptions and trigger boundaries (chapter 7)

- **E1** Do not swallow exceptions. A `catch` must log through the org's logger (here `Logger` / `Log`), rethrow, or recover deliberately.
- **E2** When several DML steps must succeed or fail together, make that explicit with a savepoint and rollback in one deep method, rather than spreading one business process across several triggers.
- **E3** After-trigger work on other objects that belongs to a different business process should not be able to fail the parent save. Consider async isolation (Queueable or platform event), with logging. This is a design proposal.
- **E4** Handle exceptions at entry points (trigger handlers, LWC/Aura controllers, batch `execute`, invocables). Letting an error reach the UI is fine when the user's own action caused it.

### O - Object-oriented design (chapter 8)

- **O1** Expose behaviour, not raw state. Avoid getters and setters that only leak a private field.
- **O2** Use inheritance only for a real "is a" family with shared and specialised behaviour. Prefer composition ("has a"), for example a class takes a logger rather than extending one.
- **O3** Use an abstract class (template method) when several classes share an algorithm but differ in steps, for example common re-queue or limit logic for Queueables.
- **O4** Interfaces are contracts. Keep them small and use them for real variations, mocking or boundaries.

### D - Design principles, modularity and dependencies (chapters 9-11)

- **D1** Single responsibility: separate logic that changes for different groups of users or reasons. Avoid god classes per object.
- **D2** DRY, but not too early. Remove duplication once the abstraction is clear, usually after two or three copies. A wrong shared abstraction is worse than a little duplication.
- **D3** YAGNI: no "just in case" parameters, interfaces, factories or layers.
- **D4** Keep modules somewhat general-purpose. A class must not know too much about its callers or surroundings.
- **D5** Cohesion: keep things that change together close together, and split only when the split reduces overall complexity.
- **D6** Inject a dependency when it is a real boundary (callouts, the Database class, external systems), has real variations, or must be faked in tests. Hard-code simple utilities with no variation.
- **D7** Design errors out of existence where possible. Choose semantics where the edge case simply does nothing, instead of adding branches.

### T - Tests (chapter 12)

- **T1** Test observable behaviour through the public entry points, not private internals made `@TestVisible`. Flag new `@TestVisible` methods that exist only to test internals.
- **T2** No `Test.isRunningTest()` branches or test-only flags in business logic.
- **T3** Each test has a clear name for the behaviour it checks, arrange / act / assert structure, and assertions with messages.
- **T4** At least one integration test per behaviour covers the happy path with real DML. Variations may use stubs or mocks where the class allows it.
- **T5** Tests are deterministic and independent of execution order and existing org data.

### A - Architecture in this repo (chapter 13)

- **A1** Trigger handlers route records and hold only filtering logic, such as comparing old and new values. The business logic lives in its own class that does not depend on `Trigger.new`.
- **A2** Write business logic from the inside out: the core class takes plain records and parameters so it can be called from triggers, batches or Flows.
- **A3** When a record type or status drives a lot of branching, consider a class that represents that state (for example `ClosedCases`). This is a design proposal.
- **A4** Use `System.debug` only for local troubleshooting. Production diagnostics go through the logger.
- **A5** Comment out nothing. Delete dead code. Gate unfinished work behind configuration if the org has a feature-flag mechanism.

## Chapter map (for deeper lookup)

| Topic | Chapter |
|---|---|
| Refactoring walk-through, formatting, side effects | 1 |
| Naming, magic numbers | 2 |
| One thing, abstraction levels, boolean parameters, enums, strategy pattern | 3 |
| Method length, deep vs shallow modules, subtasks | 4 |
| Comments, dead code (repo rule: no comments) | 5 |
| Null, empty, validation, guard clauses, returning null | 6 |
| Exceptions, atomicity, cascading trigger failures, async isolation | 7 |
| OOP: encapsulation, inheritance, interfaces, abstract classes, polymorphism | 8 |
| SOLID, DRY, YAGNI, designing errors out of existence | 9 |
| Modularity, coupling, cohesion | 10 |
| Dependency injection, boundaries, late binding | 11 |
| Unit vs integration tests, stubs, mocking DML and SOQL | 12 |
| Apex Well-Architected Framework: business logic placement, trigger filtering, state classes | 13 |

To read a chapter, extract the text once with Git's bundled `pdftotext` into the scratchpad and search it:

```powershell
& "$env:LOCALAPPDATA\Programs\Git\mingw64\bin\pdftotext.exe" -enc UTF-8 "C:\Users\espiritd\Documents\salesforce_agentic_system\resources\Clean_Apex_Code.pdf" "<scratchpad>\clean-apex-code.txt"
```

## Rules

- Apex only. Never touch LWC, Aura, JavaScript, Flows or metadata XML other than an Apex file's own `-meta.xml`.
- Never commit, stage, deploy or validate as part of this skill. Never retrieve into `src`.
- Page layouts never go in `deploy/`.
- Principles are guidelines, not violations. Prefer fewer, clearly useful changes over a large stylistic rewrite, and say when the existing code is already fine.
