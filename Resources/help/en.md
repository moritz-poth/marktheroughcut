# MarkTheRoughcut

MarkTheRoughcut is a simple player for reviewing a cut. You watch the video, set markers with comments and send them to the editor, who imports them into Avid Media Composer.

![The main window: video, overview bar, timeline with markers and waveform, marker list](main.png)

## Opening a video

- Drag the video onto the window, or choose **File → Open Video…** (⌘O).
- MarkTheRoughcut plays everything QuickTime Player plays, e.g. MOV and MP4 with H.264, HEVC or ProRes.
- The timecode is taken from the file. It cannot be changed – that way every marker lands exactly where it belongs in Avid. If a file has no timecode, it starts at 00:00:00:00 and a notice tells you so.

## Moving through the video

- The **overview bar** shows the whole video. Click or drag in it to jump anywhere.
- The **timeline** below shows a section around the playhead, with timecode, markers and the sound as a waveform. Drag in it or swipe on the trackpad to scrub frame by frame.
- **↑ / ↓** zoom the timeline in and out around the playhead.

## Keys

- **Space** – play / pause
- **J K L** – play backwards / stop / play forwards; press J or L again for double speed
- **← →** – one frame back / forward
- **⇧← ⇧→** – one second back / forward
- **⌥← ⌥→** – previous / next marker
- **↑ ↓** – zoom the timeline
- **M** – set a marker at the playhead
- **I / O** – mark in / out for a marker with a duration; **G** clears both
- **⌫** – delete the selected marker
- **Esc** or **Enter** – finish writing a comment (a click anywhere else does the same)

## Markers

- Press **M** to set a marker at the playhead. A comment field opens right away – just start typing.
- The first time, MarkTheRoughcut asks for your name. It appears with every marker in Avid, so the editor knows who wrote it. Your name is shown above the marker list; click the pencil to change it.
- Click a marker in the list or in the timeline to jump to it. Click its comment to edit it.
- **Marker with a duration:** press **I** at the start and **O** at the end, then **M**. The marker spans from in to out: a marker at the start and the end, joined by a thin line. **G** clears in and out.
- Click the coloured dot to choose a colour. New markers get the colour you chose last.
- Markers are saved automatically next to the video (as “<video name>.markers.json”). Open the video again later and they are all back.

## Sending markers to the editor

- Choose **Markers → Export Avid Markers…** (⌘E) and save the list.
- In Avid the editor opens the Markers window and chooses **Import Markers**.
- Some characters make Avid stop importing (for example “/”), umlauts arrive garbled and line breaks split a marker. MarkTheRoughcut replaces them when exporting – ä becomes ae, “/” becomes “ - ”, quotation marks become ', line breaks become spaces – so every marker arrives complete.

## Getting markers from the editor

- Choose **Markers → Import Avid Markers…** (⇧⌘I) and pick a list exported from Avid (Markers window → Export Markers).
- Markers outside the video’s timecode are left out; MarkTheRoughcut tells you how many.

## Settings

![Settings: appearance, language, updates](settings.png)

- **MarkTheRoughcut → Settings…** (⌘,): light or dark appearance and the language (English, Deutsch, Français, Español). Changing the language restarts the app; your markers are saved.
- **Updates:** MarkTheRoughcut checks GitHub for new versions on its own and shows a notice at the top of the window – **Install update** replaces the app and restarts it. In Settings you can also click **Check for updates**.

## Problems

- **“Apple could not verify …” on first launch:** open System Settings → Privacy & Security and click **Open Anyway** (only once).
- **The file does not play:** MarkTheRoughcut plays what QuickTime Player plays. Ask for an export as MOV or MP4 (H.264 or ProRes).
- **Markers are in the wrong place in Avid:** the video in Avid must have the same timecode as the file you reviewed – check that the editor exported it with source timecode.
