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
- Dark by default, light optional (`AppSettings.dark`, Theme in Theme.swift, JetBrains Mono, Ferry colours). Settings window (⌘,): appearance switch, language dropdown, version + Check for updates. Updater (`Updater.swift`) is Mountpoint's: GitHub releases API, asset `MarkTheRoughcut-<version>.zip`, tag `v<version>`, Info.plist `MarkTheRoughcutRelease` must equal the tag, codesign verify, old app to Trash, relaunch; `UpdateBanner` at the top of the main window. Volume: `LineSlider` in the top bar (UserDefaults `volume`). App icon: `scripts/make-icon.swift` (play in a ring, marker in playhead blue). About is its own window (`AboutView`, App menu → About; GPL notice, source, license, third-party). `Switch` and `Dropdown` are the same components as in Mountpoint.
- Languages en (default, not the system language), de, fr, es: `AppleLanguages` is set from UserDefaults `language` at launch; switching restarts the app. Every UI string goes into all three `.lproj` files (`LocalizationTests` fails otherwise); the manual lives in `Resources/help/<code>.md` (Help → Manual, rendered by `ManualView`; `ManualTests` checks all four).
- Overview bar: thumbnails, playhead, detail range (2 px outline kept inside the bar so it looks the same at the edges) – no markers (the user found lines over the pictures too busy). Detail timeline: TC ruler, grey marker lane with short slim upright coloured bars, 8 × 4 pt with round ends (selected = pressed look + thin outline: white on dark colours, dark on light ones, `MarkerColor.isLight`) (spans: a marker at start and end joined by a thin line slightly above the middle; overlapping markers move into up to 3 rows, `place()`/`Lane`), quiet waveform below (`Waveform`, 200 peaks/s from 8 kHz mono); zoom ↑/↓ around the playhead (a new video opens fully zoomed out); playhead blue 0x226e8e (user's Avid reference); drag or swipe to scrub; click a marker to select (pointing-hand cursor over markers, `onContinuousHover`).
- The user's name is always shown above the marker list with a pencil to change it.
- Selected row: `Theme.selection` plus a 3 px bar in the marker colour. Comment editing shows a quiet input box (`Theme.field` / `fieldLine`, clearly lighter than the selected row). Any click outside the edited text view ends editing (mouse-down monitor in `Keys`), so "M" never types into a comment.
- Keys (Keys in App.swift, a local NSEvent monitor): Space, J/K/L, ←/→ frame, ⇧←/→ second, ⌥←/→ previous/next marker, ↑/↓ zoom, M marker (with I and O set: a spanned marker from in to out inclusive, duration = out − in + 1; G clears marks), ⌫ delete selected, Esc/Enter leave a comment. Plain keys only act when no text field is edited; sheets and panels get every key.
- Marker list rows are bound by marker id (`PlayerModel.binding(for:)`), never position-based `ForEach($array)` – that wrote comments into the neighbour after an insert.

## Build / test
`swift test` (VideoInfoTests generate test videos with Homebrew ffmpeg, skipped without it), `scripts/build-app.sh` → `dist/MarkTheRoughcut.app` + zip (ad-hoc signed). Visual check: launch the app with a test video and `screencapture -l <window id>`; keys can be sent with `osascript … System Events key code`. Synthetic clicks via System Events do not reach the app like real ones – post CGEvents for click tests.

## Open
README screenshots, user test of the export in real Avid.
Deferred by the user (2026-11-03): "check all comments for friendly wording" button. Options were Apple Writing Tools via a review window (macOS 15), Foundation Models per marker (macOS 26, fully local) or a simple rule check. The rewrite users see in the comment field is Apple's Writing Tools, not ours.
Testing note: the user uses the app on this Mac (name in UserDefaults) – never `defaults delete` the whole domain; restore single keys you change.
