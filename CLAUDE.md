# Claude Code instructions for kenk-vk-enricher

## .ps1 files are UTF-16 LE (Unicode)

**Never use the Edit tool on .ps1 files.** They are saved as UTF-16 LE with BOM — Edit tool works on UTF-8 bytes and will corrupt them.

Always read and modify .ps1 files via PowerShell:

```powershell
$content = Get-Content $file -Raw -Encoding Unicode
$content = $content.Replace($old, $new)
Set-Content $file -Value $content -Encoding Unicode -NoNewline
```

Always verify the replacement was found before replacing:

```powershell
if ($content.Contains($old)) {
    $content = $content.Replace($old, $new)
    Set-Content $file -Value $content -Encoding Unicode -NoNewline
    Write-Host "replaced"
} else {
    Write-Host "NOT FOUND"
}
```

The Read tool displays UTF-16 files with spaces between every character — that is expected, it does not mean the file is corrupted.

## Commit messages in Russian

All git commit messages in Russian — subject, body, everything.

## Code style

- No comments unless WHY is non-obvious
- Minimal fixes — don't add defensive patterns for theoretical edge cases
- Propose simple solution first, ask before adding complexity
