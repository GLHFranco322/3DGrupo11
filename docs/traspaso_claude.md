# Traspaso: estado del proyecto (para seguir en otra PC)

Resumen de lo trabajado con Claude Code hasta el 1/11/2026, rama `rama-nivel4`.
Para seguir en otra PC: hacer `git pull`, abrir un chat nuevo de Claude Code en
VS Code y pedirle que lea este archivo y el `README.md`.

## El juego

"Se busca Gerente": juego de fiesta en Godot 4.6 (renderer **GL Compatibility**)
para 2 jugadores con pantalla dividida. Estilo **caricatura** (decidido: no se
busca iluminación realista).

**Objetivo nuevo:** llegar a **10 minijuegos**. Antes de jugar se elige **al
mejor de 3 o al mejor de 5**, y cada partida usa 3 o 5 niveles al azar entre
los 10. Ese sistema de partidas **todavía no está hecho**.

## Niveles

| # | Nivel | Escena | Estado |
|---|---|---|---|
| 1 | El patio (cortadora de pasto) | `niveles/1_patio/patio.tscn` | Jugable |
| 2 | La ferretería (laberinto aleatorio) | `niveles/2_ferreteria/store_level.tscn` | Jugable |
| 3 | Carrera de carretillas (circuito, 3 vueltas) | `niveles/3_carrera/race_level.tscn` | Jugable |
| 4 | Los rompecabezas (1 minuto) | `niveles/4_rompecabezas/puzzle_level.tscn` | Jugable, faltan imágenes y sonidos |

### Nivel 4: rompecabezas
- Primera persona, los dos jugadores frente a frente en la mesa principal del
  taller, cada uno con su tablero. Pantalla dividida **arriba/abajo**.
- Rompecabezas cuadrados en grilla: 2x2, 3x3, 4x4… (cada uno completado suma
  una fila y una columna). Gana el que completa más; si empatan, el que tiene
  más piezas puestas en el que estaba armando.
- Palanca izquierda mueve un cursor; ✕ agarra y suelta. Encastre automático
  cerca de su lugar. Efectos de pop al aparecer y desaparecer.
- Pista: a los 6 s sin agarrar ni soltar piezas, una lucecita salta de la pieza
  a su lugar (opción `Cursor Resets Hint` del jugador si mover el cursor
  también tiene que contar).
- **Falta:** las imágenes del artista (lista "Images" del nodo `PuzzleLevel`;
  mientras esté vacía usa 6 dibujos de prueba hechos por código) y los sonidos
  del grupo "Rompecabezas" en `sistema/audio.tscn`.

### Lugares del laberinto
- `lugares/maze_room.gd` (`MazeRoom`): habitación con paredes, puertas y techo.
  `MazeBuilder` (nodo `Maze` de la ferretería, propiedad **Places**) la ubica
  en un lugar al azar del laberinto con 2 puertas.
- `lugares/workshop_room.tscn` (`WorkshopRoom`): el taller. Es el escenario del
  nivel 4 y también aparece dentro del laberinto. La idea es ir agregando más
  lugares.

## Carpetas

Ver `README.md`. En resumen: `sistema/` (autoloads), `menus/`, `personajes/`,
`lugares/`, `niveles/comun/` y una carpeta por nivel en `niveles/`. Los packs
de modelos quedaron en `assets/` sin tocar.

## Hecho en esta etapa

- Nivel 3: manejo tipo kart (R1 acelera, □ frena, ○ marcha atrás), rampas de
  turbo, rejas eléctricas, huecos en el piso, items en filas.
- Nivel 4 completo (salvo imágenes y sonidos).
- Taller y sistema de "lugares" en el laberinto.
- Reorganización de carpetas por nivel.
- Arreglos visuales de paredes y góndolas (ver "Cosas a tener en cuenta").
- Animaciones nuevas de Carlos (modelo `Carlos Carretilla - Golpes`, sumado
  como animaciones extra en `personajes/carlos.tres`): `golpear`, `patear`,
  `carretilla`, `caer_carretilla` y `tirar_carretilla`. Triángulo no las
  tiene: usa las de antes.
- Menú de pausa (`menus/pause_menu.gd`, autoload `PauseMenu`) en los 4
  niveles: Volver, Opciones (volúmenes) y Menú principal. Start/Options del
  mando, **Esc** (J1) o **P** (J2). Solo el que pausó lo maneja y lo cierra.
- El laberinto escribe su semilla en la consola (`Laberinto: semilla N`): para
  repetir uno, poner ese número en `Maze Seed`.

## Pendiente

1. Sistema de partidas: mejor de 3 o de 5, con niveles al azar.
2. Niveles 5 a 10.
3. Imágenes de los rompecabezas y todos los sonidos (en `sistema/audio.tscn`
   solo hay dos músicas cargadas; ningún efecto).
4. Animación `remar` para la carretilla (ningún personaje la tiene) y las
   animaciones nuevas para Triángulo.
5. Decidir si el laberinto se puede editar a mano. Opciones: un botón que
   "hornee" el laberinto generado en nodos editables, o varios mapas dibujados
   y uno al azar por partida.
6. `show_dev_level_select` del menú principal (selector de niveles para
   desarrollo): apagarlo en la versión final.

## Cosas a tener en cuenta (aprendidas a la fuerza)

- **MultiMesh y bases espejadas:** en un MultiMesh, una transformación con
  determinante negativo dibuja las caras de atrás (paredes "huecas" que
  desaparecen según el ángulo). Los `box_transform` de `maze_room.gd` y
  `maze_builder.gd` ya lo corrigen; mantenerlo en cualquier MultiMesh nuevo.
- **Caras en el mismo plano:** dos caras superpuestas en el mismo plano
  parpadean (z-fighting). Las piezas de las góndolas están armadas para que
  ninguna coincida; al tocar `_add_wall` hay que cuidarlo.
- **Temporizadores y pausa:** `get_tree().create_timer(x)` sigue corriendo en
  pausa. Dentro de los niveles usar `create_timer(x, false)`. Solo el cartel
  final usa `true`, porque el nivel se pausa al terminar.
- **Mover archivos:** hacerlo desde el panel Sistema de archivos de Godot. Si
  se mueven por fuera, que sea con el editor cerrado (y sin guardar al
  cerrarlo), o puede reescribir rutas viejas.
- **Probar sin abrir el editor:** Godot está en
  `C:\Users\Franco\OneDrive\Documents\Godot_v4.6.1-stable_win64.exe\`. Con
  `Godot_..._console.exe --path <proyecto> -s prueba.gd` se corren scripts de
  prueba (`extends SceneTree`). En esos scripts los autoloads no se ven por
  nombre (usar `root.get_node("Audio")`) y conviene no tipar con clases del
  proyecto. Para leer posiciones de MultiMesh correr **con ventana** (sin
  `--headless`). Para simular botones usar `Input.parse_input_event` con un
  `InputEventAction`.
- **Teclado:** S (J1) y flecha abajo (J2) son a la vez "abajo" y "marcha
  atrás"; no usar "marcha atrás" para volver en menús.
