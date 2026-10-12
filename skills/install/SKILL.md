---
description: Install touch-prompt, the full-screen "Touch your YubiKey" prompt for git commit signing on macOS. Use when the user asks to install or set up touch-prompt.
---

Install touch-prompt on this Mac.

1. Check the prerequisites and stop with a clear message if one is missing:
   - macOS 14 or later (`sw_vers -productVersion`).
   - `swiftc` from the Xcode Command Line Tools (`xcode-select --install` provides it).
   - OpenSSH from Homebrew at `/opt/homebrew/bin/ssh-keygen` (`brew install openssh` provides it).
   - git signs with an SSH security key: `git config --global gpg.format` is `ssh` and `git config --global user.signingkey` is set.
2. Run `install.sh` from the plugin root, two directories above this skill's base directory. It builds the prompt into `~/.local/bin`, installs the `git-ssh-sign` wrapper next to it, and sets `gpg.ssh.program` in the global git config.
3. Tell the user that installation is done when the next signed commit shows the prompt and succeeds after they touch the key. If they want Claude to run commits without a permission prompt each time, they can allow `Bash(git commit:*)` in `/permissions`.

To uninstall, run `git config --global gpg.ssh.program /opt/homebrew/bin/ssh-keygen` and delete `~/.local/bin/touch-prompt` and `~/.local/bin/git-ssh-sign`.
