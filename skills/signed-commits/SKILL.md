---
description: How to run git commits when touch-prompt handles YubiKey signing. Use before running git commit, git commit --amend, git tag -s, or a rebase that re-signs commits.
---

When `git config --global gpg.ssh.program` ends in `git-ssh-sign`, touch-prompt is installed and commits are signed with a hardware key that needs a touch.

- Run `git commit` yourself with a 5-minute Bash timeout (300000 ms). touch-prompt shows a full-screen prompt until the user touches the key, retries missed touches, and asks them to reconnect the key if it isn't found.
- Tell the user to touch the key when the prompt appears, in the same message as the commit.
- Don't print commit commands for the user to run instead.
- Never pass `--no-gpg-sign` or `-c commit.gpgsign=false`, and never turn signing off to get past a failure.
- If the commit fails after all retries, report the error output and stop. Don't retry in a loop.

If `gpg.ssh.program` doesn't end in `git-ssh-sign`, touch-prompt isn't installed. Offer `/touch-prompt:install`.
