param(
    [string[]]$Paths,
    [string]$BaseBranch = 'origin/develop',
    [string]$RepoRoot = 'C:\Users\espiritd\Documents\Repos\crm-coe',
    [string]$OutDir = (Join-Path $env:TEMP 'apex-pmd-rules'),
    [switch]$ListOnly
)

$ErrorActionPreference = 'Stop'
$alwaysIgnored = @('ApexDoc')
$ignoredUnlessNew = @('CyclomaticComplexity')

Push-Location $RepoRoot
try {
    $mergeBase = (git merge-base $BaseBranch HEAD).Trim()

    $added = @()
    $added += git diff --name-only --diff-filter=A $mergeBase
    $added += git diff --name-only --diff-filter=A
    $added += git diff --name-only --diff-filter=A --cached
    $added += git ls-files --others --exclude-standard

    if ($Paths) {
        $files = foreach ($p in $Paths) {
            $full = if ([IO.Path]::IsPathRooted($p)) { $p } else { Join-Path $RepoRoot $p }
            (Resolve-Path $full).Path.Substring($RepoRoot.Length + 1).Replace('\', '/')
        }
    }
    else {
        $files = @()
        $files += git diff --name-only --diff-filter=d $mergeBase
        $files += git diff --name-only --diff-filter=d
        $files += git ls-files --others --exclude-standard
    }

    $files = $files | Where-Object { $_ -match '^src/.*\.(cls|trigger)$' } | Sort-Object -Unique
    $newSet = @{}
    $added | Where-Object { $_ } | ForEach-Object { $newSet[$_.Replace('\', '/')] = $true }

    if (-not $files) {
        Write-Output 'NO_APEX_FILES'
        return
    }

    foreach ($f in $files) {
        $state = if ($newSet[$f]) { 'NEW' } else { 'EXISTING' }
        Write-Output "FILE $state $f"
    }
    if ($ListOnly) { return }

    $installed = sf plugins --core 2>$null | Select-String -Pattern 'code-analyzer' -Quiet
    if (-not $installed) {
        Write-Output 'ANALYZER_MISSING'
        return
    }

    if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
        $jdk = Get-ChildItem 'C:\Program Files\Java' -Directory -Filter 'jdk-*' -ErrorAction SilentlyContinue |
            Sort-Object { [int](($_.Name -replace '^jdk-(\d+).*$', '$1')) } -Descending |
            Select-Object -First 1
        if (-not $jdk) {
            Write-Output 'JAVA_MISSING'
            return
        }
        $env:JAVA_HOME = $jdk.FullName
        $env:Path = (Join-Path $jdk.FullName 'bin') + ';' + $env:Path
    }

    New-Item -ItemType Directory -Force $OutDir | Out-Null
    $json = Join-Path $OutDir 'apex-pmd-result.json'
    if (Test-Path $json) { Remove-Item $json -Force }

    $sfArgs = @('code-analyzer', 'run', '--rule-selector', 'pmd:Apex', '--output-file', $json)
    foreach ($f in $files) { $sfArgs += @('--workspace', (Join-Path $RepoRoot $f)) }
    & sf @sfArgs | Out-Null

    if (-not (Test-Path $json)) {
        Write-Output 'ANALYZER_FAILED'
        return
    }

    $result = Get-Content $json -Raw | ConvertFrom-Json
    $kept = 0
    $skipped = 0
    foreach ($v in $result.violations) {
        $loc = $v.locations[[int]$v.primaryLocationIndex]
        $rel = ([IO.Path]::GetFullPath($loc.file)).Substring($RepoRoot.Length + 1).Replace('\', '/')
        if ($alwaysIgnored -contains $v.rule) { $skipped++; continue }
        if (($ignoredUnlessNew -contains $v.rule) -and -not $newSet[$rel]) { $skipped++; continue }
        $kept++
        Write-Output ("VIOLATION sev{0} {1} {2}:{3} {4}" -f $v.severity, $v.rule, $rel, $loc.startLine, $v.message)
    }
    Write-Output "SUMMARY files=$($files.Count) violations=$kept ignored=$skipped json=$json"
}
finally {
    Pop-Location
}
