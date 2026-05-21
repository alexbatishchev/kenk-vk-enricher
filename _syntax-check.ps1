#Requires -Version 5.1
# Temporary syntax check; delete after run.
# Repo .ps1 are UTF-16 LE; ParseFile without BOM mis-detects encoding � use ParseInput + Unicode.
$files = @(
    (Join-Path $PSScriptRoot 'kenk-vk-enricher.ps1'),
    (Join-Path $PSScriptRoot 'kenk-vk-enricher-functions.ps1')
)
$enc = [System.Text.Encoding]::Unicode
$ok = $true
foreach ($f in $files) {
    $tokens = $null
    $errors = $null
    $src = [System.IO.File]::ReadAllText($f, $enc)
    [void][System.Management.Automation.Language.Parser]::ParseInput($src, $f, [ref]$tokens, [ref]$errors)
    Write-Host ""
    Write-Host "=== $f ==="
    if ($errors.Count -eq 0) {
        Write-Host "OK: 0 syntax errors"
    } else {
        $ok = $false
        foreach ($e in $errors) {
            Write-Host ($e.ToString())
        }
    }
}
exit ([int](-not $ok))
