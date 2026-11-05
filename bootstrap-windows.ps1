# Run in PowerShell (company laptop, Windows). No admin needed for bun.
$ErrorActionPreference = 'Stop'

# 1) Install bun (per-user)
winget install -e --id Oven-sh.Bun --accept-source-agreements --accept-package-agreements
# refresh PATH for this session
$env:Path = "$env:LOCALAPPDATA\Microsoft\Bun\bin;$env:LOCALAPPDATA\Microsoft\WinGet\Links;$env:Path"
bun -v

# 2) Unpack clippy
$src = Split-Path -Parent $MyInvocation.MyCommand.Path
Expand-Archive -Path "$src\clippy-src.zip" -DestinationPath "$env:LOCALAPPDATA\clippy" -Force

Push-Location "$env:LOCALAPPDATA\clippy"
bun install
Pop-Location

# 3) clippy shim on PATH (clippy.cmd)
$bin = "$env:LOCALAPPDATA\clippy-bin"
New-Item -ItemType Directory -Force $bin | Out-Null
@"
@echo off
bun run "$env:LOCALAPPDATA\clippy\src\cli.ts" %*
"@ | Set-Content "$bin\clippy.cmd"
if (";"+$env:Path -notlike "*$bin*") {
  [Environment]::SetEnvironmentVariable("Path", ($env:Path + ";$bin"), "User")
  $env:Path = "$env:Path;$bin"
}

# 4) SSH: install public key so makllm can run clippy over SSH
$pub = Get-Content (Join-Path $src 'authorized_key.pub') -Raw
New-Item -ItemType Directory -Force $env:USERPROFILE\.ssh | Out-Null
Add-Content "$env:USERPROFILE\.ssh\authorized_keys" $pub.Trim()
icacls "$env:USERPROFILE\.ssh" /inheritance:r | Out-Null
icacls "$env:USERPROFILE\.ssh\authorized_keys" /inheritance:r /grant:r "$env:USERNAME:(R)" | Out-Null
Write-Host "SSH key installed. Verify OpenSSH Server is running: Get-Service sshd (start it: Start-Service sshd)"

Write-Host "`nNext steps:"
Write-Host "  1. New terminal:  clippy login -i      (SSO/MFA once)"
Write-Host "  2. clippy keepalive  (keep the window open, or schedule at logon)"
Write-Host "  3. Test from makllm: ssh <laptop-user>@<laptop-name> 'clippy whoami'"