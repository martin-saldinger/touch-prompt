# touch-prompt

When git signs a commit with a YubiKey or another FIDO security key, the key blinks and waits a few seconds for a touch. If you miss the blink, the signature times out and the commit fails. This happens often when a coding agent runs `git commit` for you.

touch-prompt dims every screen and shows "Touch your YubiKey" while git waits for the touch. It closes as soon as the signature is done. If you miss the touch, it tries again, up to 4 times. It also plays a chime, which you only hear when the Mac isn't muted.

If ssh-keygen can't find the key, touch-prompt shows "Reconnect your YubiKey" for 10 seconds before the next attempt. This happens when the key is unplugged, and also when a cancelled signature (for example, Ctrl+C during a commit) leaves the key stuck. Unplugging the key and plugging it back in fixes both.

Clicks pass through the overlay, and it closes on its own after 60 seconds.

## Prerequisites

- macOS 14 or later, with the Xcode Command Line Tools (`xcode-select --install`) for `swiftc`.
- OpenSSH from Homebrew (`brew install openssh`), at `/opt/homebrew/bin/ssh-keygen`.
- git already set up to sign with an SSH security key: `gpg.format ssh` and `user.signingkey` pointing at your `sk-ssh-ed25519` key.

## Install

1. Clone this repo.
2. Run `./install.sh`.

The script builds `touch-prompt` into `~/.local/bin`, copies `git-ssh-sign` next to it, and sets `gpg.ssh.program` in your global git config to `~/.local/bin/git-ssh-sign`.

Installation is done when a signed commit in any repo (`git commit --allow-empty -m test`) shows the overlay, and the commit succeeds after you touch the key.

## Uninstall

1. Run `git config --global gpg.ssh.program /opt/homebrew/bin/ssh-keygen`.
2. Delete `~/.local/bin/touch-prompt` and `~/.local/bin/git-ssh-sign`.
