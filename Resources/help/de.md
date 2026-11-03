# MarkTheRoughcut

MarkTheRoughcut ist ein einfacher Player zum Abnehmen eines Schnitts. Du schaust das Video, setzt Marker mit Kommentaren und schickst sie an den Schnitt, der sie in Avid Media Composer importiert.

## Video öffnen

- Zieh das Video ins Fenster oder wähle **Ablage → Video öffnen…** (⌘O).
- MarkTheRoughcut spielt alles, was der QuickTime Player spielt, z. B. MOV und MP4 mit H.264, HEVC oder ProRes.
- Der Timecode kommt aus der Datei. Er lässt sich nicht ändern – so landet jeder Marker in Avid genau an der richtigen Stelle. Hat eine Datei keinen Timecode, beginnt sie bei 00:00:00:00, und ein Hinweis sagt es dir.

## Durch das Video bewegen

- Die **Übersichtsleiste** zeigt das ganze Video. Klicken oder Ziehen springt an jede Stelle.
- Die **Timeline** darunter zeigt einen Ausschnitt um die Abspielposition, mit Timecode, Markern und dem Ton als Waveform. Ziehen oder Wischen auf dem Trackpad spult Bild für Bild.
- **↑ / ↓** zoomen die Timeline um die Abspielposition hinein und hinaus.

## Tasten

- **Leertaste** – abspielen / anhalten
- **J K L** – rückwärts / Stopp / vorwärts; J oder L noch einmal drücken = doppelte Geschwindigkeit
- **← →** – ein Bild zurück / vor
- **⇧← ⇧→** – eine Sekunde zurück / vor
- **⌥← ⌥→** – voriger / nächster Marker
- **↑ ↓** – Timeline zoomen
- **M** – Marker an der Abspielposition setzen
- **I / O** – In / Out für einen Marker mit Dauer setzen; **G** löscht beide
- **⌫** – ausgewählten Marker löschen
- **Esc** oder **Enter** – Kommentar beenden (ein Klick irgendwo anders tut dasselbe)

## Marker

- Drück **M**, um an der Abspielposition einen Marker zu setzen. Das Kommentarfeld öffnet sich sofort – einfach lostippen.
- Beim ersten Mal fragt MarkTheRoughcut nach deinem Namen. Er steht in Avid bei jedem Marker, damit der Schnitt weiß, von wem er ist. Dein Name steht über der Markerliste; mit dem Stift änderst du ihn.
- Ein Klick auf einen Marker in der Liste oder in der Timeline springt dorthin. Ein Klick auf den Kommentar bearbeitet ihn.
- **Marker mit Dauer:** am Anfang **I**, am Ende **O** drücken, dann **M**. Der Marker reicht von In bis Out: ein Marker am Anfang und am Ende, verbunden durch eine dünne Linie. **G** löscht In und Out.
- Ein Klick auf den farbigen Punkt wählt die Farbe. Neue Marker bekommen die zuletzt gewählte Farbe.
- Marker werden automatisch neben dem Video gespeichert (als „<Videoname>.markers.json“). Öffnest du das Video später wieder, sind alle wieder da.

## Marker an den Schnitt schicken

- Wähle **Marker → Avid-Marker exportieren…** (⌘E) und speichere die Liste.
- In Avid öffnet der Schnitt das Marker-Fenster und wählt **Import Markers**.
- Manche Zeichen lassen Avid den Import abbrechen (z. B. „/“), Umlaute kommen verstümmelt an, und Zeilenumbrüche zerteilen einen Marker. MarkTheRoughcut ersetzt sie beim Export – aus ä wird ae, aus „/“ wird „ - “, Anführungszeichen werden zu ', Zeilenumbrüche zu Leerzeichen –, damit jeder Marker vollständig ankommt.

## Marker vom Schnitt bekommen

- Wähle **Marker → Avid-Marker importieren…** (⇧⌘I) und eine aus Avid exportierte Liste (Marker-Fenster → Export Markers).
- Marker außerhalb des Video-Timecodes werden ausgelassen; MarkTheRoughcut sagt dir, wie viele.

## Einstellungen

- **MarkTheRoughcut → Einstellungen…** (⌘,): helles oder dunkles Erscheinungsbild und die Sprache (English, Deutsch, Français, Español). Beim Sprachwechsel startet die App neu; deine Marker sind gespeichert.
- **Updates:** MarkTheRoughcut sucht selbst auf GitHub nach neuen Versionen und zeigt oben im Fenster einen Hinweis – **Update installieren** ersetzt die App und startet sie neu. In den Einstellungen kannst du auch auf **Nach Updates suchen** klicken.

## Probleme

- **„Apple konnte nicht überprüfen …“ beim ersten Start:** Öffne Systemeinstellungen → Datenschutz & Sicherheit und klicke auf **Trotzdem öffnen** (nur einmal).
- **Die Datei spielt nicht:** MarkTheRoughcut spielt, was der QuickTime Player spielt. Bitte um einen Export als MOV oder MP4 (H.264 oder ProRes).
- **Die Marker sitzen in Avid an der falschen Stelle:** Das Video in Avid muss denselben Timecode haben wie die Datei, die du angeschaut hast – frag nach, ob mit Quell-Timecode exportiert wurde.
