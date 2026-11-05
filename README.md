# Clippy on the Colliers laptop (CA-friendly device)

This folder makes the Colliers Outlook `clippy` CLI work on your **company laptop**
(Entra Conditional Access passes on a company-managed device), while the cron jobs
on `makllm` keep calling `clippy` over SSH to the laptop.

## What's in here
- `clippy-src/`  – the clippy source (bun + playwright; `bun install` pulls deps)
- `bootstrap-windows.ps1` – one-shot setup for Windows
- `bootstrap-macos.sh`    – one-shot setup for macOS
- `authorized_key.pub`   – the public key to install so `makllm` can run `clippy`
                           on the laptop over SSH (private key: `~/.ssh/clippy_laptop`
                           on makllm)

## After the bootstrap
1. Open a terminal/PowerShell, run `clippy login -i` → a Chrome window opens, do
   SSO/MFA once. On the company device this passes Conditional Access and the
   token + cookies are saved.
2. Start the keep-alive (keeps the token/session fresh every 10 min):
   - Windows: `Start-Process powershell -ArgumentList '-NoExit','-Command','clippy keepalive --headless'`
    (or set it up as a Task Scheduler task at logon)
   - macOS: `nohup clippy keepalive --headless >> ~/.config/clippy/keepalive.log 2>&1 &`
3. Verify from `makllm`: `ssh alan@<laptop> clippy whoami` — if that works, the
   `clippy` shim on makllm makes all existing cron jobs work unchanged.

## Notes
- `bun install` is run inside the bootstrap; the Chrome used is the laptop's
  installed Chrome (`channel: 'chrome'`), no extra browser download needed.
- If the company laptop blocks new browsers, check IT policy on Playwright-driven
  Chrome — it's a normal Chrome process with a temp profile, nothing exotic.