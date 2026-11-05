# bootstrap-windows.ps1 - one-time Clippy setup on the Colliers company laptop.
# Run in a normal (non-admin) PowerShell:
#   powershell -ExecutionPolicy Bypass -File .\bootstrap-windows.ps1
# Safe to re-run (idempotent). If bun was just installed by winget in THIS
# session, the script hunts for bun.exe directly; if it truly can't see it,
# re-run in a NEW PowerShell window to finish.
$ErrorActionPreference = 'Continue'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host '=== 1) bun ==='
$BunExe = $null
$null = Get-Command bun -ErrorAction SilentlyContinue | ForEach-Object { $script:BunExe = $_.Source }
if (-not $BunExe) {
    winget install -e --id Oven-sh.Bun --accept-source-agreements --accept-package-agreements
    # winget updates the user PATH but not this session - find bun.exe directly
    foreach ($d in @("$env:LOCALAPPDATA\Microsoft\WinGet\Links", "$env:LOCALAPPDATA\Microsoft\Bun\bin", "$env:USERPROFILE\.bun\bin")) {
        if (Test-Path (Join-Path $d 'bun.exe')) { $BunExe = (Join-Path $d 'bun.exe'); break }
    }
}
if ($BunExe) {
    Write-Host "bun found: $BunExe"
    & $BunExe -v
} else {
    Write-Host 'WARNING: bun installed but not visible in this session.' -ForegroundColor Yellow
    Write-Host 'Re-run this script in a NEW PowerShell window to finish the remaining steps.' -ForegroundColor Yellow
}

Write-Host '=== 2) clippy source + dependencies ==='
$ClippyDir = Join-Path $env:LOCALAPPDATA 'clippy'
New-Item -ItemType Directory -Force -Path $ClippyDir | Out-Null
if (Test-Path (Join-Path $ClippyDir 'package.json')) {
    Write-Host 'clippy already unpacked - skipping unpack'
} else {
    $SrcTgz = Join-Path $ScriptDir 'clippy-src.tgz'
    if (-not (Test-Path $SrcTgz)) { throw "Missing $SrcTgz - re-download the package: https://github.com/makalan604/clippy-laptop-setup" }
    tar -xzf $SrcTgz -C $ClippyDir
    Write-Host "unpacked to $ClippyDir"
}
if ($BunExe) {
    Push-Location $ClippyDir
    & $BunExe install
    Pop-Location
} else {
    Write-Host 'skipping bun install - it will run on the re-run in a fresh window' -ForegroundColor Yellow
}

Write-Host '=== 3) clippy command on PATH ==='
$BinDir = Join-Path $env:LOCALAPPDATA 'clippy-bin'
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
$BunRef = if ($BunExe) { $BunExe } else { 'bun' }
"echo off
$BunRef run `"$ClippyDir\src\cli.ts`" %*
" | Set-Content (Join-Path $BinDir 'clippy.cmd')
if (($env:Path -split ';') -notcontains $BinDir) {
    [Environment]::SetEnvironmentVariable('Path', ($env:Path.TrimEnd(';') + ';' + $BinDir), 'User')
}
$env:Path = "$env:Path;$BinDir"
Write-Host "clippy shim: $BinDir\clippy.cmd (new terminals will pick it up)"

Write-Host '=== 4) SSH key for makllm ==='
$Pub = Join-Path $ScriptDir 'authorized_key.pub'
if (Test-Path $Pub) {
    New-Item -ItemType Directory -Force -Path (Join-Path $env:USERPROFILE '.ssh') | Out-Null
    $Ak = Join-Path $env:USERPROFILE '.ssh\authorized_keys'
    $Line = (Get-Content $Pub -Raw).Trim()
    if ((Test-Path $Ak) -and ((Get-Content $Ak -Raw) -match [regex]::Escape($Line))) {
        Write-Host 'SSH key already installed'
    } else {
        Add-Content $Ak $Line
        Write-Host 'SSH key installed for makllm'
    }
} else {
    Write-Host 'authorized_key.pub not next to this script - skipped SSH key' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Done. Next steps (in a normal PowerShell):'
Write-Host '  clippy login -i'
Write-Host '  clippy keepalive --headless'
Write-Host 'Then from makllm:  ssh <laptop-user>@<laptop-name> "clippy whoami"'