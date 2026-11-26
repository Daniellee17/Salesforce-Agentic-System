---
name: apex-pmd-rules
description: Applies the PMD Apex rules (PMD 7.26.0, as run by Salesforce Code Analyzer) to the crm-coe repo's changed Apex classes and triggers - finds every violation, fixes it in src/main/default, re-copies the file into deploy/, and re-checks until clean. ApexDoc is never written; it is suppressed with a class-level @SuppressWarnings('PMD.ApexDoc') annotation. CyclomaticComplexity is ignored for existing classes but enforced for classes newly created on the branch. Apex only, never LWC or JavaScript. Use it when the user asks to apply PMD rules, fix PMD or Code Analyzer violations in Apex, or make Apex pass the pipeline's code analysis.
---

# Apex PMD rules

Make the current branch's Apex pass the PMD Apex rules, with two exceptions:

| Rule | Treatment |
|---|---|
| `ApexDoc` | Never write ApexDoc or any other comments (CLAUDE.md forbids comments). Instead, suppress it with the class-level annotation `@SuppressWarnings('PMD.ApexDoc')` on every changed class and trigger that has ApexDoc violations (see "ApexDoc suppression" below). |
| `CyclomaticComplexity` | Ignored for classes and triggers that already exist on `origin/develop`. Enforced for files **newly created** on this branch. |

Every other PMD Apex rule applies to every changed file. Only `.cls` and `.trigger` files are in scope.

## Steps

1. Check the branch and `git status` in `C:\Users\espiritd\Documents\Repos\crm-coe`.
2. Run the check through the PowerShell tool:

   ```powershell
   & "$HOME\.claude\skills\apex-pmd-rules\Run-ApexPmd.ps1"
   ```

   It prints one `FILE NEW|EXISTING <path>` line per changed Apex file (changed against the merge base with `origin/develop`, plus uncommitted and untracked files), then one `VIOLATION sev<n> <Rule> <path>:<line> <message>` line per finding, already filtered by the table above, one `APEXDOC <path> count=<n>` line per file that still has ApexDoc violations, and a `SUMMARY` line.

   Options: `-Paths <file>, <file>` to check only those files, `-BaseBranch <ref>` to compare against another branch, `-ListOnly` to show the files and their NEW/EXISTING state without running the analyzer.

3. The script uses Java from PATH, or else the newest `C:\Program Files\Java\jdk-*` for its own process only. If it prints `JAVA_MISSING`, `ANALYZER_MISSING` or `ANALYZER_FAILED`, tell the user once that the PMD engine is not available (it needs the Code Analyzer plugin, `sf plugins install code-analyzer`, and Java 11 or newer), then review each listed file by hand against the rule list below, applying the same table. Say in the result that the check was manual.
4. Show the user the violations as a table: FILE / LINE / RULE / MESSAGE, grouped by file, and note which files are NEW.
5. Before editing, follow CLAUDE.md: compare each file with QA by retrieving into a temp folder (`sf project retrieve start --metadata ApexClass:<Name> --target-metadata-dir <temp> --unzip --target-org qa`), never into `src`, and tell the user if QA differs from the branch in a way that is not part of this story.
6. Fix the violations in `src/main/default`. Then copy each changed file and its `-meta.xml` into `deploy/classes` or `deploy/triggers` so they are byte-identical, but only for files that already belong in `deploy/`. If a test class changes, its class's tests still have to pass.
7. Run the script again. Repeat until `violations=0` and `apexdoc_files=0`, or until only violations remain that need the user's decision.
8. Report what was fixed, what was left and why, and run `git diff --stat`.

## How to fix

- Change behaviour as little as possible. Do not rename public or global methods, classes or fields that other code, Flows, LWCs or integrations may call; report those instead of fixing them.
- Match the surrounding code style. No comments.
- `CyclomaticComplexity` / `CognitiveComplexity` / `NcssMethodCount` in a NEW class: split the method into smaller private methods with clear names. Do not do this to EXISTING classes for `CyclomaticComplexity`.
- `ApexCRUDViolation`: use `WITH USER_MODE` or `Security.stripInaccessible` / `AccessLevel.USER_MODE`, matching what the class already does. If the class is meant to run in system mode, report it rather than changing it.
- `ApexSharingViolations`: add `with sharing` (or `inherited sharing`) only when that does not change who can see the data. If unsure, ask.
- `OperationWithLimitsInLoop` (SOQL/DML in loops): bulkify with collections and maps.
- `ApexUnitTestClassShouldHaveAsserts` / `ApexAssertionsShouldIncludeMessage`: use `Assert.areEqual(expected, actual, 'message')` style.
- If a violation is a false positive, say so. Add a `@SuppressWarnings('PMD.<Rule>')` only when the user agrees. `PMD.ApexDoc` is the exception: always add it, no need to ask.

## ApexDoc suppression

For each file with an `APEXDOC` line, put `@SuppressWarnings('PMD.ApexDoc')` on its own line directly above the top-level class declaration (after any other annotation such as `@IsTest`). A class-level annotation also covers the class's methods, properties and inner classes, so add it once per file, never on methods.

- If the class already has `@SuppressWarnings('PMD.X')`, add to it in the same string instead of adding a second annotation: `@SuppressWarnings('PMD.X, PMD.ApexDoc')`.
- Only add it to files that have an `APEXDOC` line. Never add it to a class that has no ApexDoc violations.
- When the analyzer cannot run (manual check), add it only to classes that have a `public` or `global` class, method, constructor or property, because the ApexDoc rule only reports those. Never add it to `private` test classes whose members are all `private`.
- Triggers cannot take annotations. Report ApexDoc on a trigger instead of fixing it.
- This is an annotation, not a comment, so it does not break the no-comments rule.

## PMD Apex rules (fallback checklist)

**Best Practices:** ApexAssertionsShouldIncludeMessage, ApexUnitTestClassShouldHaveAsserts, ApexUnitTestClassShouldHaveRunAs, ApexUnitTestMethodShouldHaveIsTestAnnotation, ApexUnitTestShouldNotUseSeeAllDataTrue, AvoidGlobalModifier, AvoidLogicInTrigger, DebugsShouldUseLoggingLevel, QueueableWithoutFinalizer, UnusedLocalVariable.

**Code Style:** AnnotationsNamingConventions, ClassNamingConventions, FieldDeclarationsShouldBeAtStart, FieldNamingConventions, ForLoopsMustUseBraces, FormalParameterNamingConventions, IfElseStmtsMustUseBraces, IfStmtsMustUseBraces, LocalVariableNamingConventions, MethodNamingConventions, OneDeclarationPerLine, PropertyNamingConventions, WhileLoopsMustUseBraces.

**Design:** AvoidBooleanMethodParameters, AvoidDeeplyNestedIfStmts, CognitiveComplexity, CyclomaticComplexity (NEW files only), ExcessiveClassLength, ExcessiveParameterList, ExcessivePublicCount, NcssConstructorCount, NcssMethodCount, NcssTypeCount, StdCyclomaticComplexity, TooManyFields, UnusedMethod.

**Documentation:** ApexDoc (suppressed with the class-level `@SuppressWarnings('PMD.ApexDoc')`).

**Error Prone:** ApexCSRF, AvoidDirectAccessTriggerMap, AvoidHardcodingId, AvoidNonExistentAnnotations, AvoidStatefulDatabaseResult, EmptyCatchBlock, EmptyIfStmt, EmptyStatementBlock, EmptyTryOrFinallyBlock, EmptyWhileStmt, InaccessibleAuraEnabledGetter, MethodWithSameNameAsEnclosingClass, OverrideBothEqualsAndHashcode, TestMethodsMustBeInTestClasses, TypeShadowsBuiltInNamespace.

**Performance:** AvoidDebugStatements, AvoidNonRestrictiveQueries, EagerlyLoadedDescribeSObjectResult, OperationWithHighCostInLoop, OperationWithLimitsInLoop.

**Security:** ApexBadCrypto, ApexCRUDViolation, ApexDangerousMethods, ApexInsecureEndpoint, ApexOpenRedirect, ApexSharingViolations, ApexSOQLInjection, ApexSuggestUsingNamedCred, ApexXSSFromEscapeFalse, ApexXSSFromURLParam.

## Rules

- Apex only. Never touch LWC, Aura, JavaScript, Flows or metadata XML other than an Apex file's own `-meta.xml`.
- Never commit, stage, deploy or validate as part of this skill. Never retrieve into `src`.
- Page layouts never go in `deploy/`.
