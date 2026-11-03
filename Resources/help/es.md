# MarkTheRoughcut

MarkTheRoughcut es un reproductor sencillo para revisar un montaje. Ves el vídeo, pones marcadores con comentarios y se los envías al montador, que los importa en Avid Media Composer.

## Abrir un vídeo

- Arrastra el vídeo a la ventana o elige **Archivo → Abrir vídeo…** (⌘O).
- MarkTheRoughcut reproduce todo lo que reproduce QuickTime Player, p. ej. MOV y MP4 con H.264, HEVC o ProRes.
- El timecode se toma del archivo. No se puede cambiar – así cada marcador cae exactamente en su sitio en Avid. Si un archivo no tiene timecode, empieza en 00:00:00:00 y un aviso te lo indica.

## Moverse por el vídeo

- La **vista general** muestra todo el vídeo. Haz clic o arrastra para saltar a cualquier punto.
- La **línea de tiempo** de abajo muestra un tramo alrededor del cabezal, con timecode, marcadores y el sonido como forma de onda. Arrastra o desliza en el trackpad para avanzar fotograma a fotograma.
- **↑ / ↓** acercan y alejan la línea de tiempo alrededor del cabezal.

## Teclas

- **Espacio** – reproducir / pausar
- **J K L** – atrás / parar / adelante; vuelve a pulsar J o L para doble velocidad
- **← →** – un fotograma atrás / adelante
- **⇧← ⇧→** – un segundo atrás / adelante
- **⌥← ⌥→** – marcador anterior / siguiente
- **↑ ↓** – zoom de la línea de tiempo
- **M** – poner un marcador en el cabezal
- **I / O** – entrada / salida para un marcador con duración; **G** borra ambas
- **⌫** – eliminar el marcador seleccionado
- **Esc** o **Intro** – terminar un comentario (un clic en cualquier otro sitio hace lo mismo)

## Marcadores

- Pulsa **M** para poner un marcador en el cabezal. El campo de comentario se abre al momento – solo tienes que escribir.
- La primera vez, MarkTheRoughcut te pide tu nombre. Aparece con cada marcador en Avid, para que el montador sepa quién lo escribió. Tu nombre se muestra encima de la lista; haz clic en el lápiz para cambiarlo.
- Haz clic en un marcador de la lista o de la línea de tiempo para saltar a él. Haz clic en su comentario para editarlo.
- **Marcador con duración:** pulsa **I** al principio y **O** al final, después **M**. El marcador va de la entrada a la salida: un marcador al principio y otro al final, unidos por una línea fina. **G** borra la entrada y la salida.
- Haz clic en el punto de color para elegir un color. Los marcadores nuevos llevan el último color elegido.
- Los marcadores se guardan automáticamente junto al vídeo (como «<nombre del vídeo>.markers.json»). Si vuelves a abrir el vídeo más tarde, estarán todos.

## Enviar los marcadores al montador

- Elige **Marcadores → Exportar marcadores de Avid…** (⌘E) y guarda la lista.
- En Avid, el montador abre la ventana Markers y elige **Import Markers**.
- Algunos caracteres hacen que Avid deje de importar (por ejemplo «/»), las tildes llegan deformadas y los saltos de línea parten un marcador. MarkTheRoughcut los sustituye al exportar – á pasa a ser a, ñ pasa a ser n, «/» pasa a ser « - », las comillas pasan a ser ', los saltos de línea espacios – para que cada marcador llegue completo.

## Recibir marcadores del montador

- Elige **Marcadores → Importar marcadores de Avid…** (⇧⌘I) y una lista exportada desde Avid (ventana Markers → Export Markers).
- Los marcadores fuera del timecode del vídeo se omiten; MarkTheRoughcut te dice cuántos.

## Ajustes

- **MarkTheRoughcut → Ajustes…** (⌘,): aspecto claro u oscuro y el idioma (English, Deutsch, Français, Español). Al cambiar el idioma, la app se reinicia; tus marcadores están guardados.
- **Actualizaciones:** MarkTheRoughcut busca por sí mismo nuevas versiones en GitHub y muestra un aviso arriba en la ventana – **Instalar actualización** reemplaza la app y la reinicia. En Ajustes también puedes hacer clic en **Buscar actualizaciones**.

## Problemas

- **«Apple no ha podido verificar …» al abrirla por primera vez:** abre Ajustes del Sistema → Privacidad y seguridad y haz clic en **Abrir igualmente** (solo una vez).
- **El archivo no se reproduce:** MarkTheRoughcut reproduce lo que reproduce QuickTime Player. Pide una exportación en MOV o MP4 (H.264 o ProRes).
- **Los marcadores caen en el sitio equivocado en Avid:** el vídeo en Avid debe tener el mismo timecode que el archivo revisado – comprueba que se exportó con el timecode de origen.
