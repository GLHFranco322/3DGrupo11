# Métricas de testeo → Google Sheets

Al terminar cada partida de los niveles 1, 2 y 3, el juego (autoload `Metrics`, en
`sistema/metrics.gd`) manda una fila a una planilla de Google Sheets. Las
columnas de observación (en amarillo) se llenan a mano durante el testeo.

## Armar la planilla (una sola vez)

1. Crear una planilla nueva en Google Drive (por ejemplo "Métricas Se busca Gerente").
2. En la planilla: **Extensiones → Apps Script**.
3. Borrar lo que haya en `Código.gs` y pegar todo el contenido de
   `docs/metricas/apps_script.gs`.
4. Cambiar la clave de la línea `const CLAVE = 'cambiar-esta-clave';` por una
   propia (cualquier texto) y guardar (💾).
5. Arriba, en el selector de funciones, elegir **configurar** y apretar
   **Ejecutar**. La primera vez pide permisos: *Revisar permisos* → elegir la
   cuenta → *Configuración avanzada* → *Ir a … (no seguro)* → *Permitir*
   (es un script propio, Google avisa porque no está verificado).
   Esto crea las pestañas "Nivel 1 - Corta el pasto", "Nivel 2 - Laberinto",
   "Nivel 3 - Carrera" y "Resumen".
6. **Implementar → Nueva implementación** → engranaje → **Aplicación web**:
   - Ejecutar como: **Yo**
   - Quién tiene acceso: **Cualquier usuario**
   - **Implementar** y copiar la **URL de la aplicación web** (termina en `/exec`).
7. Probar la URL abriéndola en el navegador: tiene que decir
   `{"ok":true,"mensaje":"La planilla de métricas está lista"}`.

## Conectar el juego

1. En Godot abrir `sistema/metrics.tscn`.
2. En el inspector: **Web App Url** = la URL del paso 6, **Secret Key** = la
   misma clave del paso 4.
3. Jugar una partida del nivel 1: al llegar a resultados aparece una fila nueva.

## Durante el testeo

- En la pantalla de resultados, abajo a la izquierda, aparece **Partida: …**.
  Ese es el `partida_id` de la fila: ahí se anotan las observaciones.
- Sin internet no se pierde nada: cada partida queda guardada en
  `%APPDATA%\Godot\app_userdata\Se busca Gerente\metricas\pendientes` y se
  reenvía al terminar la próxima partida o al abrir el juego. Las que ya
  llegaron pasan a `metricas\enviadas`.
- Si una partida llega dos veces, la planilla la ignora (mismo `partida_id`).

## Si se cambia el script

1. Pegar el script nuevo entero en Apps Script (si la clave no es la del repo,
   volver a poner la propia en `CLAVE`) y guardar.
2. Correr **configurar** otra vez: crea las pestañas nuevas y, en las que ya
   existen, agrega al final las columnas que falten (no mueve ni borra datos).
   Rehace el "Resumen".
3. **Implementar → Gestionar implementaciones** → lápiz → Versión: **Nueva
   versión** → Implementar. Así la URL no cambia (con "Nueva implementación" sí
   cambia y habría que pegarla otra vez en el juego).

## Qué mide cada columna

**Nivel 1 – Corta el pasto** (una fila por partida)

| Columna | Qué es |
|---|---|
| `jX_puntos`, `promedio_puntos` | Puntos de cada jugador y promedio de ambos |
| `jX_piedras` | Piedras tiradas |
| `jX_pozos` | Pozos colocados |
| `jX_botas_agarradas` | Botas agarradas |
| `jX_patadas` / `jX_patadas_acertadas` | Patadas (R2 o □ con la bota) / las que conectaron |
| `jX_trampas_total` | Piedras + pozos + patadas |
| `jX_seg_con_maquina` | Segundos sosteniendo la cortadora |
| `ganador` | 1, 2 o "empate" |
| `obs_…` | Observación (a mano) |

**Nivel 2 – Laberinto**

| Columna | Qué es |
|---|---|
| `fin` | "lista" (alguien completó su lista) o "tiempo" |
| `completo_lista` | Jugador que completó la lista |
| `jX_pinas` / `jX_pinas_acertadas` | Piñas tiradas / que pegaron |
| `jX_bananas`, `jX_hielos` | Trampas colocadas |
| `jX_trampas_total` | Piñas + bananas + hielos |
| `jX_items_entregados` | Herramientas colgadas en el tablero |
| `obs_…` | Observación (a mano) |

**Nivel 3 – Carrera de carretillas**

| Columna | Qué es |
|---|---|
| `fin` | "meta" (alguien completó las vueltas) o "tiempo" |
| `ganador` | 1 o 2 |
| `jX_puntos`, `jX_metros`, `jX_vueltas` | Puntaje (metros + 100 al ganador), metros recorridos y vueltas completas |
| `jX_cortadoras` / `_acertadas` / `_fallidas` | Cortadoras tiradas / que tiraron al rival / que no |
| `jX_pozos` / `jX_pozos_acertados` / `jX_pozos_fallidos` | Pozos dejados / en los que cayó el rival / que no |
| `jX_canas` / `_acertadas` / `_fallidas` | Cañas usadas / que pescaron al rival / tiradas al aire |
| `jX_trampas_total`, `jX_trampas_acertadas` | Suma de los tres items: usados / con éxito |
| `jX_cayo_en_pozos` | Veces que cayó en un pozo (de cualquiera) |
| `jX_huecos`, `jX_rejas` | Caídas en huecos de la pista / descargas de las rejas eléctricas |
| `jX_caidas_mapa` | Huecos + rejas (trampas del mapa) |
| `jX_barro` | Veces que pasó por el barro (frena, no tira) |
| `obs_notas` | Observación (a mano) |

Para medir algo nuevo desde el juego alcanza con `Metrics.add(player_id,
"nombre")`: si la columna no existe, la planilla la agrega sola al final.
