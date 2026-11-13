# Clips de video de los tutoriales

Los videos que se ven en la libreta de cada tutorial son partidas reales del juego grabadas con el **Movie Maker** de Godot.

Cada clip es un script `demo_X.gd` (en `niveles/<nivel>/tutorial/clips/`) que hace lo siguiente:
1. Abre el nivel.
2. Ubica a los jugadores.
3. Los maneja "apretando" las mismas acciones que el mando (`p1_grab`, `p1_throw`, etc.).

Al terminar el guion se corta la grabación y queda `X.ogv` al lado del script.

## Volver a grabar

Desde Git Bash, en la carpeta del proyecto:

```bash
bash niveles/comun/tutorial/clips/grabar_clips.sh                 # todos
bash niveles/comun/tutorial/clips/grabar_clips.sh niveles/1_patio/tutorial/clips/demo_bota.gd
```

Notas:
- Si Godot está en otra ruta, primero hacé `export GODOT="C:/ruta/a/Godot_..._console.exe"`.
- Hay que volver a grabar cuando cambia cómo se ve o cómo funciona algo que aparece en un clip, por ejemplo el laberinto o una trampa.
- Los clips del nivel 2 usan siempre el mismo laberinto (semilla fija en `demo_ferreteria.gd`).

Para revisar un clip sin grabarlo, sacá capturas cada medio segundo:

```bash
Godot_console.exe --path . res://niveles/comun/tutorial/clips/grabar.tscn -- res://niveles/1_patio/tutorial/clips/demo_bota.gd --capturas=C:/alguna/carpeta
```

## Hacer un clip nuevo

1. Copiá un `demo_X.gd` del nivel. Extienden `DemoPatio`, `DemoFerreteria` o `DemoCarrera`, que a su vez extienden `Demo`.
2. En `preparar()` ubicá a los jugadores y los items, y elegí la cámara:
   - `fijar_camara()`: cámara quieta;
   - `seguir()`: sigue el punto medio de varios nodos;
   - `detras_de()`: va detrás, como en la carrera.
3. En `guion()` escribí lo que pasa:
   - `mover(id, dirección, segundos)`;
   - `apretar(id, "grab")`;
   - `esperar(segundos)`;
   - `empezar_a_mover()`.
4. Grabalo con `grabar_clips.sh`.
5. En la escena del tutorial agregá un nodo con `ventana_video.gd` (la foto pegada en la libreta). Pasale el `.ogv` en "Video" y un epígrafe corto con los botones del mando, por ejemplo `Bota  {CUADRADO}`.

## Formato

- Los clips se graban a 480x270 y 30 cuadros por segundo, con calidad baja para que pesen poco. `grabar_clips.sh` pone esa configuración con un `override.cfg` temporal.
- Los clips con la cámara quieta pesan alrededor de 100 KB. Si la cámara se mueve sobre el pasto, pesan cerca de 1,5 MB.
