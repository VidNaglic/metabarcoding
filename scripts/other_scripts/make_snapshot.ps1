param(
  [Parameter(Mandatory=$true)][string]$ProjectName,
  [Parameter(Mandatory=$true)][string]$ProjectDataDir
)

$ErrorActionPreference = 'Stop'

function Write-Info($msg) { Write-Host $msg -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host $msg -ForegroundColor Yellow }

# Normalize and define key paths
$proj = $ProjectName.ToLower()
$dataDir = (Resolve-Path $ProjectDataDir).Path
$bioinfo = Join-Path $dataDir 'bioinfo'
$exportFiltered = Join-Path $bioinfo 'exported-filtered'
$exportRep = Join-Path $bioinfo 'exported-rep-seqs'

# Discover latest run_* folder (if present)
# Discover latest run_* folder (if present) and any QIIME log
$runDir = Get-ChildItem -Path $bioinfo -Directory -Filter 'run_*' -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
$runPath = if ($runDir) { $runDir.FullName } else { $null }
$qiimeLog = $null
if ($runPath) {
  $qiimeLogCandidate = Join-Path $runPath 'nextseq_processing.log'
  if (Test-Path $qiimeLogCandidate) { $qiimeLog = $qiimeLogCandidate }
}
if (-not $qiimeLog) {
  $qiimeLogAny = Get-ChildItem -Path $bioinfo -Recurse -File -Filter 'nextseq_processing.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($qiimeLogAny) { $qiimeLog = $qiimeLogAny.FullName }
}

# BOLDigger area
$boldDataDir = Join-Path $exportFiltered 'boldigger3_data'
$boldLog = Join-Path $boldDataDir 'boldigger3_chunked.log'
$boldMergedParq = Join-Path $boldDataDir 'dna-sequences-validated_identification_result.parquet.snappy'

# Canonical QIIME outputs
$coiQza = Join-Path $bioinfo 'COI-table.qza'
$biom = Join-Path $bioinfo 'feature-table.biom'
$tsv = Join-Path $bioinfo 'feature-table.tsv'
$repFasta = Join-Path $exportFiltered 'dna-sequences-validated.fasta'

# Try to get versions (optional)
function Safe-Version($cmd, $args) {
  try { & $cmd $args 2>$null | Select-Object -First 1 } catch { $null }
}
$qiimeVer = Safe-Version 'qiime' '--version'
$biomVer = Safe-Version 'biom' '--version'
$boldVer = Safe-Version 'boldigger3' '--version'

# Parse BOLDigger parameters from the pipeline script (best-effort)
$repoRoot = (Get-Location).Path
$boldScript = Join-Path $repoRoot 'scripts/03_BOLDigger_pipeline.sh'
$boldParams = @{}
if (Test-Path $boldScript) {
  $content = Get-Content -Raw $boldScript
  if ($content -match "(?m)^DB=([0-9]+)") { $boldParams.DB = [int]$Matches[1] }
  if ($content -match "(?m)^MODE=([0-9]+)") { $boldParams.MODE = [int]$Matches[1] }
  if ($content -match "(?m)^THRESHOLDS=\(([^)]+)\)") {
    $ths = $Matches[1].Split(' ',[System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { [int]$_ }
    $boldParams.THRESHOLDS = $ths
  }
  if ($content -match "(?m)^CHUNK_SIZE=([0-9]+)") { $boldParams.CHUNK_SIZE = [int]$Matches[1] }
  if ($content -match "(?m)^WORKERS=([0-9]+)") { $boldParams.WORKERS = [int]$Matches[1] }
}

# Script signatures (hashes) for numbered scripts
$scriptSigs = @()
Get-ChildItem -Path (Join-Path $repoRoot 'scripts') -File -ErrorAction SilentlyContinue | Where-Object { $_.BaseName -match '^[0-9]'} | ForEach-Object {
  try {
    $h = Get-FileHash -Algorithm SHA256 -Path $_.FullName
    $scriptSigs += [ordered]@{ path = $_.FullName; sha256 = $h.Hash }
  } catch { }
}

# Git commit info (if repo present; works without git.exe)
function Get-GitHeadInfo {
  param([string]$Root)
  $gitDir = Join-Path $Root '.git'
  $result = @{}
  $headFile = Join-Path $gitDir 'HEAD'
  if (-not (Test-Path $headFile)) { return $null }
  $head = Get-Content -Raw $headFile
  if ($head -match '^ref: (.+)$') {
    $ref = $Matches[1].Trim()
    $result.branch = ($ref -replace '^refs/heads/','')
    $refFile = Join-Path $gitDir $ref
    if (Test-Path $refFile) { $result.commit = (Get-Content -Raw $refFile).Trim() }
    else {
      $packed = Join-Path $gitDir 'packed-refs'
      if (Test-Path $packed) {
        $line = Select-String -Path $packed -Pattern [regex]::Escape($ref) | Select-Object -First 1
        if ($line) { $result.commit = ($line.Line -split ' ')[0] }
      }
    }
  } else {
    $result.commit = $head.Trim()
  }
  return $result
}
$repoInfo = Get-GitHeadInfo -Root $repoRoot

# Parse params from QIIME log (optional)
$params = $null
if ($qiimeLog -and (Test-Path $qiimeLog)) {
  $python = Get-Command python -ErrorAction SilentlyContinue
  if ($python) {
    try {
      $json = python "scripts/extract_params_from_logs.py" "$qiimeLog" 2>$null
      if ($LASTEXITCODE -eq 0 -and $json) {
        if ($json -is [System.Array]) { $params = ($json -join "`n") } else { $params = $json }
      }
    } catch { }
  } else {
    Write-Warn "Python not found; skipping param extraction from log."
  }
}

# Snapshot destination
$snapRoot = Join-Path (Get-Location) "snapshots"
$snapDir = Join-Path $snapRoot $proj
New-Item -ItemType Directory -Force -Path $snapDir | Out-Null

# Write snapshot.json
$snapshot = [ordered]@{
  project = $ProjectName
  created_utc = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
  data_dir = $dataDir
  bioinfo_dir = $bioinfo
  latest_run_dir = $runPath
  logs = @{
    qiime2 = $qiimeLog
    boldigger = $boldLog
  }
  artifacts = @{
    coi_table_qza = $coiQza
    feature_table_biom = $biom
    feature_table_tsv = $tsv
    rep_seqs_fasta = $repFasta
    boldigger_merged_parquet = $boldMergedParq
  }
  versions = @{
    qiime2 = $qiimeVer
    biom = $biomVer
    boldigger3 = $boldVer
  }
  boldigger_params = $boldParams
  scripts_signatures = $scriptSigs
  repo = $repoInfo
}
if ($params) { $snapshot['params_from_log'] = (ConvertFrom-Json $params) }

$snapshotPath = Join-Path $snapDir 'snapshot.json'
$snapshotJson = $snapshot | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($snapshotPath, $snapshotJson, [System.Text.Encoding]::UTF8)

# Write METHODS.md
$methods = @()
$methods += "Project"
$methods += "- Name: $ProjectName"
$methods += "- Data root: $dataDir"
$methods += ""
$methods += "Pipeline"
$methods += "- Numbered scripts (01-04) executed as per repo."
$methods += "- QIIME 2 concluded with COI table and rep-seqs; exports created."
$methods += "- BOLDigger3 run in chunked mode; results merged to a single parquet."
$methods += ""
$methods += "Key Artifacts"
$methods += "- QIIME table: $coiQza"
$methods += "- Feature table (TSV): $tsv"
$methods += "- Rep-seqs (validated FASTA): $repFasta"
$methods += "- BOLDigger merged parquet: $boldMergedParq"
$methods += ""
$methods += "Logs"
$methods += "- QIIME2 log: $qiimeLog"
$methods += "- BOLDigger log: $boldLog"
$methods += ""
if ($qiimeVer -or $boldVer -or $biomVer) {
  $methods += "Tool Versions"
  if ($qiimeVer) { $methods += "- QIIME2: $qiimeVer" }
  if ($boldVer) { $methods += "- BOLDigger3: $boldVer" }
  if ($biomVer)  { $methods += "- biom: $biomVer" }
  $methods += ""
}
if ($params) {
  $p = (ConvertFrom-Json $params)
  $methods += "Run Parameters"
  if ($p.trunc_len_r1) { $methods += "- trunc-len R1: $($p.trunc_len_r1)" }
  if ($p.max_ee_r1)    { $methods += "- maxEE R1: $($p.max_ee_r1)" }
  if ($p.cutadapt_error_rate) { $methods += "- Cutadapt error rate: $($p.cutadapt_error_rate)" }
  if ($p.cutadapt_min_overlap) { $methods += "- Cutadapt min overlap: $($p.cutadapt_min_overlap)" }
  if ($p.primer_f) { $methods += "- Primer F: $($p.primer_f)" }
  if ($p.primer_r) { $methods += "- Primer R: $($p.primer_r)" }
  $methods += ""
}
$methodsPath = Join-Path $snapDir 'METHODS.md'
$methodsText = [string]::Join([Environment]::NewLine, $methods)
[System.IO.File]::WriteAllText($methodsPath, $methodsText, [System.Text.Encoding]::UTF8)

Write-Info "Snapshot written: $snapDir"
