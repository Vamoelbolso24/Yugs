# Yugs setup: downloads the card data and installs the packages.
# Safe to run again at any time (it updates instead of re-downloading).
$ErrorActionPreference = 'Continue'
Set-Location -Path $PSScriptRoot

function Step($msg) { Write-Host "`n== $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "`nERROR: $msg" -ForegroundColor Red; exit 1 }

Step 'Checking Node.js and Git'
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Fail 'Node.js not found. Install the LTS version from https://nodejs.org/en/download then run this again.' }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Fail 'Git not found. Install it from https://git-scm.com/install/windows then run this again.' }
Write-Host ("Node " + (node -v) + "  |  " + (git --version))

Step 'Downloading card scripts and card database (Project Ignis)'
New-Item -ItemType Directory -Force -Path vendor | Out-Null
$repos = [ordered]@{
  'CardScripts' = 'https://github.com/ProjectIgnis/CardScripts.git'
  'BabelCDB'    = 'https://github.com/ProjectIgnis/BabelCDB.git'
}
foreach ($name in $repos.Keys) {
  $dir = Join-Path 'vendor' $name
  if (Test-Path (Join-Path $dir '.git')) {
    Write-Host "Updating $name..."
    git -C $dir pull --ff-only
  } else {
    Write-Host "Downloading $name (this can take a minute)..."
    git clone --depth 1 $repos[$name] $dir
  }
  if ($LASTEXITCODE -ne 0) { Fail "Could not download $name." }
}

Step 'Installing packages (duel engine + TypeScript tools)'
npm.cmd install ocgcore-wasm
if ($LASTEXITCODE -ne 0) { Fail 'Installing ocgcore-wasm failed.' }
npm.cmd install --save-dev typescript tsx @types/node
if ($LASTEXITCODE -ne 0) { Fail 'Installing the TypeScript tools failed.' }

Step 'Setting up Git history'
if (-not (Test-Path '.git')) {
  git init -b main | Out-Null
  Write-Host 'Created a new Git repository.'
} else {
  Write-Host 'Git repository already exists.'
}

Step 'Checking that the duel engine loads'
node scripts/check-setup.mjs
if ($LASTEXITCODE -ne 0) { Fail 'The check found problems. Copy the messages above and send them to Claude.' }

Write-Host "`nAll done! Tell Claude: setup finished." -ForegroundColor Green
