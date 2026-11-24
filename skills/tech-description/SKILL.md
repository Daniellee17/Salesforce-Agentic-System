---
name: tech-description
description: Writes the High Level Approach and Technical Description for a ticket in this repo, in the user's fixed layout (bold TYPE headings, numbered component names, nested 1./a./i. change lists, Test Class and Coverage lines for Apex), pasted directly in the chat. Use it when the user asks for the technical description, technical documentation, the TYPE / NAME / CHANGES write-up, or the high level approach for their changes or branch.
---

# Technical description

Write the ticket write-up for the changes on the current branch. The output goes **only in the chat**: never write it to a file, never create an HTML page, never send a file.

## 1. Gather what changed

1. If the conversation already discussed or built the changes, use that first. It holds the reasons behind each change, which the code alone does not show.
2. Always confirm against the repo:
   - current branch: `git branch --show-current` (the ticket key is in the name, for example `feature/CRM-10954`)
   - committed changes: `git diff --name-only origin/develop...HEAD`
   - uncommitted changes: `git status --porcelain`
   - the components in `deploy/`
3. For each changed component, read `git diff origin/develop...HEAD -- <file>` (plus `git diff -- <file>` for uncommitted work) and, when needed, the whole file, so every listed change is real.
4. If the user pasted notes, keep their wording, component names and @mentions exactly as given. Do not invent assignees, settings or values.

## 2. What to leave out

- No entries for Apex test classes, even though they are in `deploy/`. Each Apex class ends with its Test Class and Coverage lines instead.
- No code comments, ApexDoc or full methods. Only short inline snippets of a key condition or value.
- Ignore `.claude/` and other non-metadata files.

## 3. Coverage

For every Apex class, add `Test Class: <TestName>` and a nested `Coverage: <n>%`.

- Get the number by running the tests in QA: `sf apex run test -o qa20206 --class-names <TestName> --code-coverage --result-format json --wait 20` (run `sf` through PowerShell, since Git Bash breaks on its path). Read the percentage for the class itself, not the test.
- Only do this when the new code is already in QA. If it is not deployed there yet, or the run fails, write `Coverage: ___%` and say why in one line after the write-up. Never guess or reuse an old number.

## 4. Output layout

Write it exactly in this structure, in Markdown, with no `<br>`, `&nbsp;` or tables:

```
**High Level Approach**

<One or two sentences on the problem and how it is solved.>

- <Short bullet per main part of the solution.>
- <...>

**<TYPE IN CAPITALS>**

1. <Component name>
   1. <What changed>
      * a. <Why, or the effect: "This will ...">
        * i. <Extra detail, only when needed>
   2. <What changed>
2. <Next component of the same type>

**APEX CLASS**

1. <ClassName>
   1. <What changed>
      * a. <This will ...>
   2. Updated the API version from <old> to <new>
   3. Test Class: <TestClassName>
      * a. Coverage: <n>%
```

Rules for the layout:

- **High Level Approach:** short, plain language, written for someone who has not read the code. Two to four bullets.
- **TYPE headings:** bold, in capitals, using the metadata type: CUSTOM LABEL, CUSTOM FIELD, FLOW, PERMISSION SET, RECORD PAGE, FIELD SET, APEX CLASS, and so on. A component that is a single field keeps the user's style, for example `MQX__c.Show_Generate_Trial_Code_Button__c` as its own bold heading.
- **Order:** configuration first (custom labels, custom fields, field sets, permission sets, flows, record pages), then APEX CLASS last.
- **Each change:** a short "what" line, optionally followed by an `a.` line explaining the effect, usually starting with "This will ...". Use `i.` only for a further detail.
- **Values:** put label values, formula snippets and key conditions in backticks.
- **API versions:** mention them when they changed.

After the write-up, add at most two short lines: anything you could not confirm from the repo, any coverage left blank and why, and anything you added that was not in the user's notes.
