[CmdletBinding()]
param(
    [string[]]$Paths,
    [string]$RepoRoot = 'C:\Users\espiritd\Documents\Repos\crm-coe',
    [string]$BaseBranch = 'origin/develop',
    [switch]$Check,
    [switch]$ConvertTabs,
    [int]$TabWidth = 4,
    [switch]$NoDeploySync
)

$ErrorActionPreference = 'Stop'
$extensions = @('.cls', '.trigger', '.js', '.html', '.css', '.xml', '.json', '.page', '.component', '.cmp', '.yml', '.yaml', '.txt', '.soql', '.apex')
$srcPrefix = 'src/main/default/'
$deployPrefix = 'deploy/'

Push-Location $RepoRoot
try {
    if (-not $Paths -or $Paths.Count -eq 0) {
        $committed = @(git diff --name-only --diff-filter=d "$BaseBranch...HEAD" -- src deploy)
        $working = @(git diff --name-only --diff-filter=d HEAD -- src deploy)
        $untracked = @(git ls-files --others --exclude-standard -- src deploy)
        $Paths = @($committed + $working + $untracked)
    }

    $targets = New-Object System.Collections.Generic.List[string]
    foreach ($p in $Paths) {
        if (-not $p) { continue }
        $rel = ($p -replace '\\', '/').Trim()
        if ([System.IO.Path]::IsPathRooted($rel)) {
            $full = [System.IO.Path]::GetFullPath($rel)
            $root = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\') + '\'
            if ($full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
                $rel = $full.Substring($root.Length) -replace '\\', '/'
            }
        }
        if ($rel.StartsWith($deployPrefix)) {
            $srcRel = $srcPrefix + $rel.Substring($deployPrefix.Length)
            if (Test-Path -LiteralPath $srcRel) { $rel = $srcRel }
        }
        if ($rel -match '/staticresources/') { continue }
        if ($extensions -notcontains [System.IO.Path]::GetExtension($rel).ToLower()) { continue }
        if (-not (Test-Path -LiteralPath $rel -PathType Leaf)) { continue }
        if (-not $targets.Contains($rel)) { $targets.Add($rel) }
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    $changed = 0
    $synced = 0

    foreach ($rel in $targets) {
        $full = Join-Path $RepoRoot $rel
        $bytes = [System.IO.File]::ReadAllBytes($full)
        $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        $text = if ($hasBom) { $utf8NoBom.GetString($bytes, 3, $bytes.Length - 3) } else { $utf8NoBom.GetString($bytes) }
        $nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }

        $lines = $text -split "\r?\n"
        $out = New-Object System.Collections.Generic.List[string]
        $trailing = 0
        $blankRun = 0
        $collapsed = 0
        $tabs = 0
        foreach ($line in $lines) {
            $clean = $line.TrimEnd(' ', "`t", [char]0x00A0)
            if ($clean.Length -ne $line.Length) { $trailing++ }
            if ($ConvertTabs -and $clean -match '^\t') {
                $m = [regex]::Match($clean, '^[ \t]+')
                $clean = $m.Value.Replace("`t", ' ' * $TabWidth) + $clean.Substring($m.Length)
                $tabs++
            }
            if ($clean.Length -eq 0) {
                $blankRun++
                if ($blankRun -gt 1) { $collapsed++; continue }
            } else {
                $blankRun = 0
            }
            $out.Add($clean)
        }
        while ($out.Count -gt 0 -and $out[0].Length -eq 0) { $out.RemoveAt(0); $collapsed++ }
        while ($out.Count -gt 0 -and $out[$out.Count - 1].Length -eq 0) { $out.RemoveAt($out.Count - 1) }

        $newText = ($out -join $nl) + $nl
        $deployRel = $null
        if ($rel.StartsWith($srcPrefix)) {
            $candidate = $deployPrefix + $rel.Substring($srcPrefix.Length)
            if (Test-Path -LiteralPath $candidate) { $deployRel = $candidate }
        }

        if ($newText -ne $text) {
            $changed++
            $parts = @()
            if ($trailing) { $parts += "$trailing trailing" }
            if ($collapsed) { $parts += "$collapsed blank lines removed" }
            if ($tabs) { $parts += "$tabs tab-indented lines" }
            if (-not $parts) { $parts += 'end-of-file newline' }
            $verb = if ($Check) { 'WOULD FIX' } else { 'FIXED' }
            Write-Output ("{0,-9} {1}  ({2})" -f $verb, $rel, ($parts -join ', '))
            if (-not $Check) {
                $enc = if ($hasBom) { $utf8Bom } else { $utf8NoBom }
                [System.IO.File]::WriteAllText($full, $newText, $enc)
            }
        }

        if ($deployRel -and -not $NoDeploySync -and -not $Check) {
            $deployFull = Join-Path $RepoRoot $deployRel
            $a = [System.IO.File]::ReadAllBytes($full)
            $b = [System.IO.File]::ReadAllBytes($deployFull)
            if ([Convert]::ToBase64String($a) -ne [Convert]::ToBase64String($b)) {
                Copy-Item -LiteralPath $full -Destination $deployFull -Force
                $synced++
                Write-Output ("SYNCED    {0}" -f $deployRel)
            }
        } elseif ($deployRel -and $Check -and $newText -ne $text) {
            Write-Output ("WOULD SYNC {0}" -f $deployRel)
        }
    }

    $mode = if ($Check) { 'check only, nothing written' } else { 'written' }
    Write-Output ''
    Write-Output ("Scanned {0} file(s), {1} needed cleaning, {2} deploy/ copies re-synced ({3})." -f $targets.Count, $changed, $synced, $mode)
}
finally {
    Pop-Location
}
