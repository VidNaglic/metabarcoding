param(
  [string]$Message = $("chore: sync on " + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
)

$ErrorActionPreference = 'Stop'

function Fail($msg) { Write-Host $msg -ForegroundColor Red; exit 1 }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Fail "Git is not installed or not on PATH. Install Git for Windows first."
}

# Ensure we are in a Git repo
try {
  git rev-parse --is-inside-work-tree *> $null
} catch {
  Fail "This folder is not a Git repository. Initialize it or open the repo root."
}

# Detect current branch
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if (-not $branch) { $branch = 'main' }

# Stage all changes
git add -A

# Commit only if there are changes
$status = git status --porcelain
if ([string]::IsNullOrWhiteSpace($status)) {
  Write-Host "No changes to commit." -ForegroundColor Yellow
} else {
  git commit -m $Message
}

# Ensure remote 'origin' exists
$hasOrigin = (git remote) -contains 'origin'
if (-not $hasOrigin) {
  Write-Host "Remote 'origin' is not set. Add it with:" -ForegroundColor Yellow
  Write-Host "  git remote add origin https://github.com/<user>/<repo>.git" -ForegroundColor Yellow
  exit 0
}

# Push to origin
git push -u origin $branch
Write-Host "Pushed $branch to origin." -ForegroundColor Green

