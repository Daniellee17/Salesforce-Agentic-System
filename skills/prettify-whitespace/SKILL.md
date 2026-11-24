---
name: prettify-whitespace
description: Cleans whitespace in the crm-coe repo's changed files - strips trailing spaces and tabs, collapses runs of blank lines into one, removes blank lines at the start and end of a file and ends it with exactly one newline - then re-copies each cleaned src file into deploy/ so both stay byte-identical. By default it only touches the current branch's changed files (against origin/develop, plus uncommitted and new files), never the whole repo. Use it when the user asks to prettify, clean up whitespace, remove trailing spaces, tidy files, or fix blank lines before a commit or PR.
---

# Prettify whitespace

Clean whitespace in the files the current user story touches, without reformatting code and without touching unrelated files.

All the work is done by `Clean-Whitespace.ps1`, in this skill's folder. Run it through the PowerShell tool, not Bash, and do not hand-edit whitespace with Edit or sed instead.

## What it changes

- Trailing spaces, tabs and non-breaking spaces at the end of every line, including lines that hold only whitespace.
- Two or more blank lines in a row become one.
- Blank lines at the top of the file are removed. The file ends with exactly one newline.
- Leading tabs become spaces only when `-ConvertTabs` is passed (4 spaces, change with `-TabWidth`). Do this only when the user asks for it, because it touches every indented line.

It keeps each file's line endings (CRLF or LF) and its UTF-8 BOM if it had one. It skips `staticresources`, Markdown and files that are not Salesforce source (`.cls`, `.trigger`, `.js`, `.html`, `.css`, `.xml`, `.json`, `.page`, `.component`, `.cmp`, `.yml`, `.yaml`, `.txt`, `.soql`, `.apex`).

It does not wrap lines, change quotes or reindent code. If the user wants full formatting, run Prettier on the same files only, `npx prettier --write <files>`, never the repo-wide `npm run prettier`.

## Steps

1. Check the branch and `git status` in `C:\Users\espiritd\Documents\Repos\crm-coe`. Tell the user if there are uncommitted changes, since the script edits files in place.
2. Do a dry run first and show the user the list:

   ```powershell
   & "$HOME\.claude\skills\prettify-whitespace\Clean-Whitespace.ps1" -Check
   ```

3. If the list looks right, or the user already asked to just do it, run it for real:

   ```powershell
   & "$HOME\.claude\skills\prettify-whitespace\Clean-Whitespace.ps1"
   ```

4. Report the `FIXED` and `SYNCED` lines and the summary line. Then run `git diff --stat` so the user sees the size of the change.

## Options

- `-Paths <file>, <file>`: clean only these files (repo-relative or absolute). A path under `deploy/` is cleaned in `src/main/default` and copied back.
- `-BaseBranch <ref>`: compare against something other than `origin/develop`.
- `-Check`: list what would change, write nothing.
- `-NoDeploySync`: do not re-copy cleaned files into `deploy/`.

## Rules

- The script only cleans files under `src` and `deploy`. Whatever is in `src/main/default` is the source of truth, and the `deploy/` copy is overwritten from it.
- A `deploy/` copy is only refreshed when that file already exists in `deploy/`. The skill never adds new files to `deploy/`. Page layouts stay out of `deploy/`.
- Never commit, stage, retrieve or deploy as part of this skill.
