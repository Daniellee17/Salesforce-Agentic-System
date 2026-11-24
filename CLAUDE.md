# Salesforce agentic system

These rules apply when working in the Salesforce CRM repository `crm-coe` (`C:\Users\espiritd\Documents\Repos\crm-coe`). Ignore them in other projects. Source lives in `src/main/default` (SFDX source format).

This file, the agents in `agents/` and the skills in `skills/` are kept in `C:\Users\espiritd\Documents\salesforce_agentic_system`, outside the repo, so they never show up as changes in a pull request. Claude Code loads them through `~/.claude/CLAUDE.md`, the `~/.claude/agents` link and the `~/.claude/skills/tech-description` link.

## Orgs

- QA org: alias `qa` (the default in `.sf/config.json`). `qa20206` is another alias for the same user and org.
- Run `sf` through PowerShell on Windows; Git Bash fails on the `C:\Program Files` path.
- Never deploy to production. Deploying or validating against QA is fine when the task asks for it.

## Before changing anything

- Retrieve the latest version of every component you are about to change from QA first, and build the change on that version. Do this every time, even for small edits.
- Check the branch and `git status` before retrieving. A retrieve into `src` overwrites local work, so when the branch has uncommitted changes, retrieve into a temp folder instead (`sf project retrieve start --target-metadata-dir <temp> --unzip`) and compare.

## The deploy/ folder

- `deploy/` holds exactly what the current feature branch ships. The Bitbucket pipeline validates and deploys it.
- It uses flat metadata-type folders directly under `deploy/`, mirroring `src/main/default`: `deploy/classes`, `deploy/triggers`, `deploy/flows`, `deploy/lwc/<bundle>`, `deploy/permissionsets`, `deploy/objects/<Object>/fields`, and so on.
- `src/main/default` is the source of truth. Edit `src`, then copy the full files (including `-meta.xml`) into `deploy/` so they are byte-identical. Re-copy after every later edit.
- Always include the test classes for every Apex class in `deploy/classes`. The pipeline runs `RunSpecifiedTests` built from every `deploy/classes/*Test.cls`.
- Never put page layouts in `deploy/`. Keep them in `src/main/default/layouts` only.
- Deletions go through `delete/destructiveChangesPre.xml` or `delete/destructiveChangesPost.xml`, not `deploy/`.
- For pull requests to `develop`, the pipeline runs Code Analyzer on `deploy/`, so fixes for its findings must land in both `src` and `deploy/`.
- After a merge, the pipeline clears `deploy/` with a `[skip ci]` commit. Merging `develop` into a feature branch can leave orphaned files in `deploy/`; rebuild it from `git diff --name-only origin/develop...HEAD` under `src`, adding meta files and whole LWC bundles.

## Code conventions

- Do not add comments (`//` or `/* */`) to any code, including test classes.
- Match the style of the surrounding code.
- In Apex tests, `Mock.sObject(Type, Map)` ignores dotted parent paths such as `'OpportunityLineItem.Field__c'`. Nest the parent instead: `'OpportunityLineItem' => new OpportunityLineItem(Field__c = ...)`.

## Agents and skills

Use the project agents in `.claude/agents` for these jobs instead of doing them inline:

| Request | Use |
|---|---|
| Compare `deploy/`, `src` and QA, before or after a deploy | `apex-deploy-qa-comparer` |
| Check Apex code coverage | `apex-coverage-checker` |
| Review Apex changes before a PR | `apex-reviewer` |
| Write test steps or a test plan for a change | `test-steps-writer` |
| Analyse a pasted user story or ticket | `user-story-analyst` |
| Write the Technical Description / TYPE-NAME-CHANGES table | `tech-description` skill |
