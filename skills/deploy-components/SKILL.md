---
name: deploy-components
description: Lists every component changed for the current user story in the crm-coe repo as one table (TYPE / NAME / SUMMARY OF CHANGE / IN DEPLOY), so nothing is forgotten before a PR or deploy. It covers components in deploy/ and components changed only in src, flags what looks missing or out of sync, and pastes the result in the chat. Use it when the user asks for the deploy list, the list of components to deploy, what they changed for a story or ticket, a deployment checklist, or says they are done with a story or about to open a PR.
---

# Deploy components

List every component changed on the current branch for the user story, so the user does not forget any. The output goes **only in the chat**: never write it to a file, never create an HTML page, never send a file. This skill only reads: never edit, copy, stage, commit, retrieve or deploy anything.

## 1. Collect the components

Run these from the repo root (`git` works in PowerShell or Bash):

1. Branch and ticket: `git branch --show-current` (the ticket key is in the name, for example `feature/CRM-10954`).
2. Committed changes on the branch: `git diff --name-status origin/develop...HEAD -- src deploy delete`
3. Uncommitted and new files: `git status --porcelain -- src deploy delete`
4. Everything currently in `deploy/`: list all files under it.
5. Deletions: read `delete/destructiveChangesPre.xml` and `delete/destructiveChangesPost.xml` if they exist and list their members.

Ignore `.claude/`, `CLAUDE.md`, `coverage/`, `node_modules/`, `.sf/`, `.sfdx/` and other non-metadata files.

## 2. Turn files into components

Group files into one component each, using the folder under `src/main/default` or `deploy/`:

| Path | TYPE | NAME |
|---|---|---|
| `classes/<Name>.cls` (+ `-meta.xml`) | Apex Class | `<Name>` |
| `triggers/<Name>.trigger` | Apex Trigger | `<Name>` |
| `flows/<Name>.flow-meta.xml` | Flow | `<Name>` |
| `lwc/<bundle>/...` (all files) | Lightning Web Component | `<bundle>` |
| `aura/<bundle>/...` | Aura Component | `<bundle>` |
| `objects/<Object>/fields/<Field>.field-meta.xml` | Custom Field | `<Object>.<Field>` |
| `objects/<Object>/validationRules/<Rule>...` | Validation Rule | `<Object>.<Rule>` |
| `objects/<Object>/fieldSets/<Set>...` | Field Set | `<Object>.<Set>` |
| `objects/<Object>/listViews/<View>...` | List View | `<Object>.<View>` |
| `objects/<Object>/recordTypes/<Type>...` | Record Type | `<Object>.<Type>` |
| `objects/<Object>/webLinks/<Link>...` | Button / Link | `<Object>.<Link>` |
| `objects/<Object>/<Object>.object-meta.xml` | Custom Object | `<Object>` |
| `layouts/<Name>.layout-meta.xml` | Page Layout | `<Name>` |
| `flexipages/<Name>...` | Record Page | `<Name>` |
| `permissionsets/<Name>...` | Permission Set | `<Name>` |
| `profiles/<Name>...` | Profile | `<Name>` |
| `labels/CustomLabels.labels-meta.xml` | Custom Label | each changed label name (read the diff) |
| `customMetadata/<Type>.<Record>...` | Custom Metadata Record | `<Type>.<Record>` |
| `quickActions/<Name>...` | Quick Action | `<Name>` |
| `staticresources/<Name>...` | Static Resource | `<Name>` |
| anything else | the folder name in title case | the file or folder name |

Apex test classes are listed as their own rows, with TYPE **Apex Test Class**, directly under the class they test.

## 3. Write the summary for each component

- Prefer what the conversation already says about the change and why. Keep the user's wording and names.
- Otherwise read the diff (`git diff origin/develop...HEAD -- <file>` and `git diff -- <file>`; for a new file, read the file) and summarise in one short line what changed: added, removed or changed logic, fields, conditions, values, `apiVersion` or `status`.
- Mark new components with **New:** and deleted ones with **Deleted:** at the start of the summary.
- No code, only short inline snippets of a key value or condition in backticks.

## 4. Check deploy/ against src

For every component, compare `src/main/default/<path>` with `deploy/<path>` (`git diff --no-index --ignore-cr-at-eol --quiet <src file> <deploy file>`) and set the IN DEPLOY column:

- **✅ Yes**: in `deploy/` and identical to `src`.
- **⚠️ Differs**: in `deploy/` but different from `src`. `src` is the source of truth, so `deploy/` needs re-copying.
- **➖ src only**: changed in `src` but not in `deploy/`. This is often intentional (page layouts never go in `deploy/`; some components are changed or retrieved in `src` only). Do not call it an error; list it so the user can confirm.
- **❓ deploy only**: in `deploy/` but not changed or not present in `src`.
- **🗑️ Delete file**: listed in a destructive changes file.

## 5. Output

Start with one line: the branch, the ticket key, and the number of components.

Then one table, ordered configuration first (Custom Label, Custom Field, Field Set, Validation Rule, Permission Set, Flow, Record Page, Page Layout, Lightning Web Component, and so on), then Apex Trigger, Apex Class and Apex Test Class last:

| TYPE | NAME | SUMMARY OF CHANGE | IN DEPLOY |
|---|---|---|---|

Then a short **Check before deploying** list, only with items that apply:

- components marked **➖ src only**, asking the user to confirm each one should stay out of `deploy/` (say "expected" for page layouts)
- components marked **⚠️ Differs** or **❓ deploy only**
- Apex classes in `deploy/` without their test class in `deploy/`, or test classes without their class
- metadata files in `deploy/` missing their `-meta.xml`, or LWC/Aura bundles missing files compared with `src`
- page layouts found in `deploy/` (they must not be there)
- deleted components that are not in a `delete/destructiveChanges*.xml` file

If nothing needs checking, say so in one line.
