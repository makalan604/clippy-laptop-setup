#!/usr/bin/env bash
# Run on the Colliers company laptop (macOS). Per-user, no sudo needed.
set -euo pipefail
cd "$(dirname "$0")"

# 1) bun
if ! command -v bun >/dev/null; then
  brew install oven-sh/bun/bun || curl -fsSL https://bun.sh/install | bash
fi
bun --version

# 2) clippy
rm -rf ~/local/clippy && mkdir -p ~/local
tar -xzf clippy-src.tgz -C ~/local/clippy
( cd ~/local/clippy && bun install )

# shim
mkdir -p ~/bin
printf '#!/bin/sh\nexec bun run %s/src/cli.ts "$@"\n' "$HOME/local/clippy" > ~/bin/clippy
chmod +x ~/bin/clippy
command -v clippy >/dev/null || echo "note: ensure ~/bin is on your PATH"

# 3) SSH key for makllm
mkdir -p ~/.ssh && chmod 700 ~/.ssh
cat authorized_key.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
# macOS: System Settings > General > Sharing > Remote Login (OpenSSH server) must be ON

echo
echo "Next steps:"
echo "  1. clippy login -i        (SSO/MFA once in Chrome)"
echo "  2. nohup clippy keepalive --headless >> ~/.config/clippy/keepalive.log 2>&1 &"
echo "  3. from makllm: ssh <laptop-user>@<laptop-hostname> 'clippy whoami'"