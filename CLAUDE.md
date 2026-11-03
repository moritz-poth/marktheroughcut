# MarkTheRoughcut – notes for working on the project

Native Mac video player (Swift, SwiftUI + AVKit, macOS 13+, universal) for directors: watch a rough cut, set markers with comments, export them as an Avid Media Composer marker list; import lists exported from Avid. Sister project of MediaFiles Ferry and Mountpoint (same look). GPL-3.0, public on GitHub (account moritz-poth) once released. Users: directors without a technical background – the editor sends them the file and (optionally) a marker list.

## Fixed rules
- Plays what QuickTime plays (AVFoundation). No MXF.
- Timecode always comes from the file (tmcd track via `VideoInfo.load`); it can never be set by hand. No timecode track → 00:00:00:00 and a notice.
- Marker frames are timecode frames (frames since 00:00:00:00 in the file's counting), so they match Avid 1:1. Video frame index = tc frame − start.
- Avid marker list (`AvidMarkers`): tab-separated `user, TC, track, colour, comment, duration, (empty), colour`, one line per marker. Avid writes Mac Roman and keeps line breaks inside comments → import finds records by the `user\tTC\t` pattern and decodes UTF-8 or Mac Roman.
- Export must import completely into Avid: ASCII only (umlauts → ae/oe/ue/ss), no "/" "\" "|" (they cut the rest off), quotes → ', no line breaks or tabs in fields (`AvidMarkers.safe`). New markers go on track V1.
- Markers save automatically as `<video>.markers.json` next to the video; read-only folders → Application Support (file name with a stable SHA-256 of the path – never `hashValue`, it changes per launch).
- `Marker.txt` in the project folder is a real, private Avid export (names, comments): git-ignored, never commit it. `LocalSampleTests` uses it when present.

## UI / keys
- Dark only (Theme in Theme.swift, JetBrains Mono, Ferry colours).
- Overview bar (thumbnails, all markers, playhead, detail range) + detail timeline (zoom ↑/↓ around the playhead, TC ruler, marker flags, span bars; drag or swipe to scrub; click a flag to select).
- Keys (Keys in App.swift, a local NSEvent monitor): Space, J/K/L, ←/→ frame, ⇧←/→ second, ⌥←/→ previous/next marker, ↑/↓ zoom, M marker, ⌫ delete selected, Esc/Enter leave a comment. Plain keys only act when no text field is edited; sheets and panels get every key.
- Marker list rows are bound by marker id (`PlayerModel.binding(for:)`), never position-based `ForEach($array)` – that wrote comments into the neighbour after an insert.
- UI strings English in code, German in `Resources/de.lproj/Localizable.strings` (app follows the system language).

## Build / test
`swift test` (VideoInfoTests generate test videos with Homebrew ffmpeg, skipped without it), `scripts/build-app.sh` → `dist/MarkTheRoughcut.app` + zip (ad-hoc signed). Visual check: launch the app with a test video and `screencapture -l <window id>`; keys can be sent with `osascript … System Events key code`. Reset test settings afterwards (`defaults delete io.github.moritz-poth.marktheroughcut`).

## Open
App icon, span markers set in the app (I/O), README screenshots, first release.
