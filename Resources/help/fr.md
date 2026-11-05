# MarkTheRoughcut

MarkTheRoughcut est un lecteur simple pour visionner un montage. Vous regardez la vidéo, placez des marqueurs avec des commentaires et les envoyez au monteur, qui les importe dans Avid Media Composer.

![La fenêtre principale : vidéo, barre d’aperçu, timeline avec marqueurs et forme d’onde, liste des marqueurs](main.png)

## Ouvrir une vidéo

- Faites glisser la vidéo sur la fenêtre ou choisissez **Fichier → Ouvrir une vidéo…** (⌘O).
- MarkTheRoughcut lit tout ce que lit QuickTime Player, p. ex. MOV et MP4 en H.264, HEVC ou ProRes.
- Le timecode provient du fichier. Il ne peut pas être modifié – ainsi chaque marqueur tombe exactement au bon endroit dans Avid. Si un fichier n’a pas de timecode, il commence à 00:00:00:00 et un avis vous le signale.

## Se déplacer dans la vidéo

- La **vue d’ensemble** montre toute la vidéo. Cliquez ou faites glisser pour sauter n’importe où.
- La **timeline** en dessous montre une section autour de la tête de lecture, avec le timecode, les marqueurs et le son en forme d’onde. Faites glisser ou balayez sur le trackpad pour avancer image par image.
- **↑ / ↓** zooment la timeline autour de la tête de lecture.

## Touches

- **Espace** – lecture / pause
- **J K L** – arrière / stop / avant ; appuyez à nouveau sur J ou L pour doubler la vitesse
- **← →** – une image en arrière / en avant
- **⇧← ⇧→** – une seconde en arrière / en avant
- **⌥← ⌥→** – marqueur précédent / suivant
- **↑ ↓** – zoomer la timeline
- **M** – placer un marqueur à la tête de lecture
- **I / O** – entrée / sortie pour un marqueur avec durée ; **G** efface les deux
- **⌫** – supprimer le marqueur sélectionné
- **Échap** ou **Entrée** – terminer un commentaire (un clic ailleurs fait de même)

## Marqueurs

- Appuyez sur **M** pour placer un marqueur à la tête de lecture. Le champ de commentaire s’ouvre aussitôt – il suffit de taper.
- La première fois, MarkTheRoughcut demande votre nom. Il apparaît avec chaque marqueur dans Avid, pour que le monteur sache qui l’a écrit. Votre nom s’affiche au-dessus de la liste ; cliquez sur le crayon pour le changer.
- Cliquez sur un marqueur dans la liste ou dans la timeline pour y sauter. Cliquez sur son commentaire pour le modifier.
- **Marqueur avec durée :** appuyez sur **I** au début et sur **O** à la fin, puis sur **M**. Le marqueur va de l’entrée à la sortie : un marqueur au début et à la fin, reliés par une fine ligne. **G** efface l’entrée et la sortie.
- Cliquez sur le point coloré pour choisir une couleur. Les nouveaux marqueurs prennent la dernière couleur choisie.
- Les marqueurs sont enregistrés automatiquement à côté de la vidéo (« <nom de la vidéo>.markers.json »). Rouvrez la vidéo plus tard : ils sont tous là.

## Envoyer les marqueurs au monteur

- Choisissez **Marqueurs → Exporter des marqueurs Avid…** (⌘E) et enregistrez la liste.
- Dans Avid, le monteur ouvre la fenêtre Markers et choisit **Import Markers**.
- Certains caractères interrompent l’import dans Avid (par exemple « / »), les accents arrivent déformés et les retours à la ligne coupent un marqueur. MarkTheRoughcut les remplace à l’export – é devient e, ä devient ae, « / » devient « - », les guillemets deviennent ', les retours à la ligne des espaces – pour que chaque marqueur arrive complet.

## Recevoir des marqueurs du monteur

- Choisissez **Marqueurs → Importer des marqueurs Avid…** (⇧⌘I) et une liste exportée depuis Avid (fenêtre Markers → Export Markers).
- Les marqueurs hors du timecode de la vidéo sont ignorés ; MarkTheRoughcut vous indique combien.

## Réglages

![Réglages : apparence, langue, mises à jour](settings.png)

- **MarkTheRoughcut → Réglages…** (⌘,) : apparence claire ou sombre et langue (English, Deutsch, Français, Español). Changer de langue redémarre l’app ; vos marqueurs sont enregistrés.
- **Mises à jour :** MarkTheRoughcut recherche lui-même les nouvelles versions sur GitHub et affiche un avis en haut de la fenêtre – **Installer la mise à jour** remplace l’app et la redémarre. Dans les Réglages, vous pouvez aussi cliquer sur **Rechercher des mises à jour**.

## Problèmes

- **« Apple n’a pas pu vérifier … » au premier lancement :** ouvrez Réglages Système → Confidentialité et sécurité et cliquez sur **Ouvrir quand même** (une seule fois).
- **Le fichier ne se lit pas :** MarkTheRoughcut lit ce que lit QuickTime Player. Demandez un export en MOV ou MP4 (H.264 ou ProRes).
- **Les marqueurs sont mal placés dans Avid :** la vidéo dans Avid doit avoir le même timecode que le fichier visionné – vérifiez qu’elle a été exportée avec le timecode source.
