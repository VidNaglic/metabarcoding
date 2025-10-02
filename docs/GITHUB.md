GitHub Update Guide

Prereqs

- Install Git and sign in (`git config --global user.name` / `user.email`).
- Create a new empty GitHub repo (no README/license) and note its URL.

Initialize and Commit

git init
git add -A
git commit -m "init: metabarcoding pipeline + trait tools"

Add Remote and Push

git remote add origin <YOUR_GITHUB_REPO_URL>
git branch -M main
git push -u origin main

Notes

- `.gitignore` excludes large data, logs, and exports; numbered scripts remain tracked.
- If you later need to publish sample data, prefer Git LFS or a separate data repo.

