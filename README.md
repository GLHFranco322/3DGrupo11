# Se busca Gerente

Juego de fiesta en Godot 4.6 para 2 jugadores con pantalla dividida.

## Carpetas

Cada nivel tiene su carpeta con todo lo suyo junto: escenas (`.tscn`), scripts (`.gd`), shaders y recursos.

```
sistema/          Autoloads: Audio, GameSettings, Controls, MatchResult, SceneLoader
menus/            Menú principal, selección de personaje, resultados
personajes/       Carlos y Triángulo (.tres), CharacterData, nombres de animaciones, script de importación
lugares/          Habitaciones que aparecen en el laberinto (MazeRoom) y el taller del nivel 4
niveles/
  comun/          Lo que usan varios niveles: cámara en tercera persona, ItemTimer, ModelUtils
  1_patio/        El patio (patio.tscn)
    cortadora/    La cortadora de pasto y sus partículas
    items/        Piedra, pozo y bota
    jugador/      Player y su máquina de estados
  2_ferreteria/   El laberinto de la ferretería (store_level.tscn)
    herramientas/ Las herramientas que se piden (.tres de ItemData)
    trampas/      Banana y hielo
  3_carrera/      La carrera de carretillas (race_level.tscn)
    items/        Piedra, pozo, caña y el spawner
    pista/        Rampas de turbo, rejas eléctricas, huecos, barro, conos
    shaders/
    materiales/
  4_rompecabezas/ Los rompecabezas (puzzle_level.tscn)
mesh_libraries/   MeshLibrary y las escenas con las que se arma
assets/           Modelos, texturas y packs de terceros (compartidos entre niveles)
music/            Música
```

Para mover un archivo, conviene hacerlo desde el panel Sistema de archivos del editor de Godot, que actualiza solo las referencias.
