# Roadmap

## Collect-then-download pipeline

Refactor `ProcessMessages` and `processWall` into two explicit modes:
- **collect**: scan HTML, gather all URLs needing download into shared queue, render with already-downloaded media
- **apply**: all URLs already downloaded, re-render HTML

Benefits: show "X files to download" before starting, clean separation of download phase, potential for batching/parallelizing.

Significant refactor — both functions currently interleave download+render in one pass.

## Photo cache miss fallback (done in v2.3)

~~Photos referenced as `vk.com/photo...` in messages/wall but not found in photo album cache are silently skipped. Should attempt direct download as fallback.~~

## Progress logging

Add `[X/N]` counters to log lines:
- Message folders: `processing messages for folder ID X [42/694]`
- Wall files, photo albums, video albums

## Video report (done in v2.4)

~~At end of each run, generate `videos-report.html` in profile root with total/ok/error stats and full per-video table (VKID, URL, filename, status, LastChecked). Regenerate without reprocessing via `-ReportOnly`.~~

## Video usage report (done in v2.5)

~~Generate `videos-usage.html` with file sizes and per-video list of dump pages where each video is referenced. Auto-generated on every run; also available as standalone `kenk-vk-video-usage.ps1`.~~

## Processing report

At end of each run, generate a general `.data/report.html` with:
- Total attachments processed by type
- Failed downloads list (URL + error)
- Unknown/unsupported attachment types with counts

## Audio attachments

`Аудиозапись` attachment type currently ignored. Preserve artist + track name as text in HTML. Stretch: attempt yt-dlp download (VK audio often region-locked).

## Avatars (done in dev2)

~~Download and inject sender avatars into message and wall HTML.~~

## Plain URL → hyperlink (done in v2.3)

~~Post/wall body text sometimes contains plain VK URLs (album, photo, video links) as text, not wrapped in `<a>` tags. Parse body text with regex, detect vk.com/... patterns, and wrap them in `<a href="...">` tags. Could also attempt to resolve local copies for vk.com/album... links.~~

## Stories section

Not feasible via yt-dlp: `vk.com/story...` URLs redirect to a JS-rendered page, yt-dlp has no VK story extractor. Would require VK API (`stories.getById`) or browser automation — out of scope.
