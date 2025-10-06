param(
  [Parameter(Mandatory=$true)][string]$Username,
  [string]$Host = 'slurm.elixir-hpc.si',
  [int]$Port = 22,
  [string]$KeyPath = "$env:USERPROFILE\.ssh\id_elixir",
  [string]$HostAlias = 'elixir'
)

$ErrorActionPreference = 'Stop'

function Write-Info($m){ Write-Host $m -ForegroundColor Cyan }
function Write-Warn($m){ Write-Host $m -ForegroundColor Yellow }
function Write-Ok($m){ Write-Host $m -ForegroundColor Green }

Write-Info "Setting up SSH key and VS Code Remote-SSH for ELIXIR"

# 1) Ensure .ssh folder
$sshDir = Join-Path $env:USERPROFILE '.ssh'
if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir | Out-Null }

# 2) Create ed25519 key if missing
if (-not (Test-Path $KeyPath)) {
  Write-Info "Generating SSH key at $KeyPath"
  $keyDir = Split-Path -Parent $KeyPath
  if (-not (Test-Path $keyDir)) { New-Item -ItemType Directory -Path $keyDir | Out-Null }
  & ssh-keygen -t ed25519 -C 'elixir-hpc' -f $KeyPath | Out-Null
} else {
  Write-Info "Reusing existing key: $KeyPath"
}

# 3) Ensure Windows OpenSSH agent is running and key is loaded
try {
  $svc = Get-Service ssh-agent -ErrorAction Stop
  if ($svc.StartType -ne 'Automatic') { Set-Service ssh-agent -StartupType Automatic }
  if ($svc.Status -ne 'Running') { Start-Service ssh-agent }
} catch {
  Write-Warn "OpenSSH agent not found. Ensure OpenSSH client is installed (Windows Optional Features)."
}
try {
  & ssh-add $KeyPath | Out-Null
} catch {
  Write-Warn "Could not add key to agent (will still work, but you may be prompted for passphrase)."
}

# 4) Append SSH config host entry if not present
$configPath = Join-Path $sshDir 'config'
$hostBlock = @(
  "Host $HostAlias",
  "  HostName $Host",
  "  User $Username",
  "  Port $Port",
  "  IdentityFile $KeyPath",
  "  ServerAliveInterval 60",
  "  ServerAliveCountMax 5"
) -join [Environment]::NewLine

$needWrite = $true
if (Test-Path $configPath) {
  $cfg = Get-Content -Raw $configPath
  if ($cfg -match "(?m)^Host\s+$([regex]::Escape($HostAlias))\s*$") {
    Write-Info "SSH config already contains Host '$HostAlias' — leaving as-is."
    $needWrite = $false
  }
}
if ($needWrite) {
  Write-Info "Adding Host '$HostAlias' to $configPath"
  Add-Content -Path $configPath -Value ("`r`n" + $hostBlock + "`r`n")
}

# 5) Create ~/.ssh on server and append public key (prompts for ELIXIR password once)
$pub = "$KeyPath.pub"
if (-not (Test-Path $pub)) { throw "Public key not found: $pub" }
Write-Info "Creating ~/.ssh on server and installing public key (you will be prompted for your ELIXIR password)"
& ssh -p $Port "$Username@$Host" "mkdir -p ~/.ssh && chmod 700 ~/.ssh" | Out-Null
type $pub | & ssh -p $Port "$Username@$Host" "cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

Write-Ok "Key installed. Test connection: ssh $HostAlias"
Write-Info "In VS Code: Remote-SSH → Connect to Host… → $HostAlias"

# 6) Optional: write a tiny Slurm test job in the current repo for convenience
$repoRoot = Get-Location
$slurmDir = Join-Path $repoRoot 'slurm'
if (-not (Test-Path $slurmDir)) { New-Item -ItemType Directory -Path $slurmDir | Out-Null }
$testPath = Join-Path $slurmDir 'test.sbatch'
if (-not (Test-Path $testPath)) {
  @"
#!/usr/bin/env bash
#SBATCH -J hello
#SBATCH -p <partition_name>
#SBATCH -c 4
#SBATCH --mem=4G
#SBATCH --time=00:05:00
#SBATCH -o logs/%x-%j.out
#SBATCH -e logs/%x-%j.err
mkdir -p logs
echo "Node: \\$(hostname)"
echo "CPUs: \\${SLURM_CPUS_ON_NODE}"
lscpu | egrep 'Model name|CPU\\(s\\):'
"@ | Set-Content -Encoding UTF8 $testPath
}
Write-Info "A Slurm test job template was created at slurm/test.sbatch (edit partition, then 'sbatch test.sbatch')."

