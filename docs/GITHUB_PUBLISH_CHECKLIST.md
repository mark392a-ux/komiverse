# GitHub Publish Checklist (KomiVerse)

Use this checklist to publish the full project as one clean GitHub repository.

## 1. Decide Repo Structure

You have a nested Git repo at:
- `Huang/api.consumet.org/.git`

For internship showcase, a single monorepo is usually easier for reviewers.

## 2. Prepare Nested Repo (Recommended)

From repo root (`komiverse`), back up nested Git metadata instead of deleting it:

```powershell
Rename-Item -Path .\Huang\api.consumet.org\.git -NewName .git_backup_consumet
```

This keeps old history files locally while allowing a normal single-repo push.

## 3. Initialize Git at Root

```powershell
cd C:\Users\admin\komiverse
git init
git branch -M main
```

## 4. Stage and Commit

```powershell
git add .
git status
git commit -m "Initial commit: KomiVerse full-stack monorepo"
```

## 5. Create Remote Repo on GitHub

Create a new empty repo, for example:
- `komiverse`

Do not initialize it with README or .gitignore on GitHub (keep it empty).

## 6. Connect and Push

```powershell
git remote add origin https://github.com/<your-username>/komiverse.git
git push -u origin main
```

## 7. Verify Before Sharing

- README renders correctly
- `docs/` links open
- No secrets are committed (`.env`, tokens, keys)
- `node_modules`, `build`, and `dist` folders are not tracked

## 8. Optional: Better Commit Hygiene

If you want cleaner history for internship review:

1. `docs:` commit (README + docs)
2. `feat:` commit (core code)
3. `chore:` commit (config/cleanup)

## 9. If You Want Separate Repo Histories Instead

Alternative approach:
- Keep `Huang/api.consumet.org` as a Git submodule
- Publish root + submodule references

For internship applications, monorepo is usually simpler to review.
