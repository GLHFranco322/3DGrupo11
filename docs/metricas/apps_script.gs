/**
 * Script de la planilla de métricas de "Se busca Gerente".
 *
 * El juego (autoload Metrics) manda cada partida por POST como JSON:
 *   { clave, hoja, columnas: [...], fila: { columna: valor } }
 * y este script la agrega como una fila en la pestaña "hoja", acomodando cada
 * valor bajo su encabezado. Si llega una columna nueva, la agrega al final.
 *
 * Cómo instalarlo: ver docs/metricas/LEEME.md.
 */

// La misma clave que "Secret Key" en sistema/metrics.tscn
const CLAVE = 'cambiar-esta-clave';

// Pestañas que arma "configurar": columnas que llena el juego y columnas de
// observación que llena a mano quien mira el testeo.
const HOJAS = {
  'Nivel 1 - Corta el pasto': {
    columnas: [
      'partida_id', 'sesion', 'fecha', 'duracion_s', 'promedio_puntos', 'ganador',
      'j1_personaje', 'j1_puntos', 'j1_piedras', 'j1_pozos', 'j1_botas_agarradas', 'j1_patadas', 'j1_patadas_acertadas', 'j1_seg_con_maquina',
      'j2_personaje', 'j2_puntos', 'j2_piedras', 'j2_pozos', 'j2_botas_agarradas', 'j2_patadas', 'j2_patadas_acertadas', 'j2_seg_con_maquina',
    ],
    observaciones: ['obs_emocion_al_final', 'obs_debates_al_usar_trampas', 'obs_notas'],
  },
  'Nivel 2 - Laberinto': {
    columnas: [
      'partida_id', 'sesion', 'fecha', 'duracion_s', 'fin', 'completo_lista', 'ganador',
      'j1_personaje', 'j1_puntos', 'j1_items_entregados', 'j1_pinas', 'j1_pinas_acertadas', 'j1_bananas', 'j1_hielos', 'j1_trampas_total',
      'j2_personaje', 'j2_puntos', 'j2_items_entregados', 'j2_pinas', 'j2_pinas_acertadas', 'j2_bananas', 'j2_hielos', 'j2_trampas_total',
    ],
    observaciones: ['obs_tension', 'obs_esconden_objetos', 'obs_dialogan', 'obs_notas'],
  },
};

const HOJA_RESUMEN = 'Resumen';


// --- Recibir partidas desde el juego -------------------------------------------

function doPost(e) {
  let datos;
  try {
    datos = JSON.parse(e.postData.contents);
  } catch (error) {
    return responder({ ok: false, error: 'JSON inválido' });
  }
  if (datos.clave !== CLAVE) {
    return responder({ ok: false, error: 'clave incorrecta' });
  }
  // Que dos envíos al mismo tiempo no se pisen
  const lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    const hoja = obtenerHoja(datos.hoja);
    agregarFila(hoja, datos.fila, datos.columnas || Object.keys(datos.fila));
  } finally {
    lock.releaseLock();
  }
  return responder({ ok: true });
}

// Para probar que la URL anda (abrirla en el navegador)
function doGet() {
  return responder({ ok: true, mensaje: 'La planilla de métricas está lista' });
}

function responder(objeto) {
  return ContentService.createTextOutput(JSON.stringify(objeto)).setMimeType(ContentService.MimeType.JSON);
}

function obtenerHoja(nombre) {
  const libro = SpreadsheetApp.getActiveSpreadsheet();
  return libro.getSheetByName(nombre) || libro.insertSheet(nombre);
}

// Las pestañas nuevas traen 26 columnas: agrega las que falten
function asegurarColumnas(hoja, cantidad) {
  const faltan = cantidad - hoja.getMaxColumns();
  if (faltan > 0) hoja.insertColumnsAfter(hoja.getMaxColumns(), faltan);
}

function agregarFila(hoja, fila, columnas) {
  let encabezado = hoja.getLastColumn() > 0
    ? hoja.getRange(1, 1, 1, hoja.getLastColumn()).getValues()[0]
    : [];
  // Si esta partida ya llegó (por un reintento), no se repite
  const columnaId = encabezado.indexOf('partida_id') + 1;
  if (columnaId > 0 && hoja.getLastRow() > 1) {
    const ids = hoja.getRange(2, columnaId, hoja.getLastRow() - 1, 1).getValues().flat();
    if (ids.indexOf(fila.partida_id) >= 0) return;
  }
  // Columnas que todavía no existen: se agregan al final
  for (const columna of columnas) {
    if (encabezado.indexOf(columna) < 0) {
      encabezado.push(columna);
      asegurarColumnas(hoja, encabezado.length);
      hoja.getRange(1, encabezado.length).setValue(columna).setFontWeight('bold');
    }
  }
  hoja.appendRow(encabezado.map((columna) => (columna in fila ? fila[columna] : '')));
}


// --- Armar la planilla (correr una vez a mano) ---------------------------------

/**
 * Crea las pestañas de cada nivel con sus encabezados (las de observación en
 * amarillo) y la pestaña "Resumen" con las fórmulas de cada hipótesis.
 * Se puede volver a correr: no borra filas, solo rehace encabezados y resumen.
 */
function configurar() {
  for (const nombre in HOJAS) {
    const hoja = obtenerHoja(nombre);
    const { columnas, observaciones } = HOJAS[nombre];
    const todas = columnas.concat(observaciones);
    asegurarColumnas(hoja, todas.length);
    hoja.getRange(1, 1, 1, todas.length).setValues([todas]).setFontWeight('bold');
    hoja.getRange(1, columnas.length + 1, 1, observaciones.length).setBackground('#fff2cc');
    hoja.setFrozenRows(1);
    hoja.setFrozenColumns(1);
  }
  armarResumen();
}

// Rango de una columna (por nombre) de una pestaña, desde la fila 2 hacia abajo
function col(nombreHoja, columna) {
  const indice = HOJAS[nombreHoja].columnas.indexOf(columna) + 1;
  if (indice === 0) throw new Error('No existe la columna ' + columna);
  const letra = obtenerHoja(nombreHoja).getRange(1, indice).getA1Notation().replace(/\d+/g, '');
  return "'" + nombreHoja + "'!" + letra + '2:' + letra;
}

function armarResumen() {
  const hoja = obtenerHoja(HOJA_RESUMEN);
  hoja.clear();
  const n1 = 'Nivel 1 - Corta el pasto';
  const n2 = 'Nivel 2 - Laberinto';
  const filas = [
    ['NIVEL 1 - CORTA EL PASTO', ''],
    ['Partidas jugadas', '=COUNTA(' + col(n1, 'partida_id') + ')'],
    ['', ''],
    ['Hipótesis 1: puntos por partida', ''],
    ['Promedio de puntos jugador 1', '=IFERROR(AVERAGE(' + col(n1, 'j1_puntos') + '),0)'],
    ['Promedio de puntos jugador 2', '=IFERROR(AVERAGE(' + col(n1, 'j2_puntos') + '),0)'],
    ['Promedio final (ambos jugadores)', '=IFERROR(AVERAGE(' + col(n1, 'promedio_puntos') + '),0)'],
    ['', ''],
    ['Hipótesis 2: uso de trampas', ''],
    ['Piedras usadas', '=SUM(' + col(n1, 'j1_piedras') + ')+SUM(' + col(n1, 'j2_piedras') + ')'],
    ['Pozos usados', '=SUM(' + col(n1, 'j1_pozos') + ')+SUM(' + col(n1, 'j2_pozos') + ')'],
    ['Patadas (veces que apretó R2 con la bota)', '=SUM(' + col(n1, 'j1_patadas') + ')+SUM(' + col(n1, 'j2_patadas') + ')'],
    ['Patadas que conectaron', '=SUM(' + col(n1, 'j1_patadas_acertadas') + ')+SUM(' + col(n1, 'j2_patadas_acertadas') + ')'],
    ['Trampa más usada', '=IF(AND(B10>=B11,B10>=B12),"Piedra",IF(B11>=B12,"Pozo","Patada"))'],
    ['', ''],
    ['Hipótesis 3: tiempo con la máquina', ''],
    ['Promedio de segundos con la máquina (jugador 1)', '=IFERROR(AVERAGE(' + col(n1, 'j1_seg_con_maquina') + '),0)'],
    ['Promedio de segundos con la máquina (jugador 2)', '=IFERROR(AVERAGE(' + col(n1, 'j2_seg_con_maquina') + '),0)'],
    ['Promedio de duración de la partida (s)', '=IFERROR(AVERAGE(' + col(n1, 'duracion_s') + '),0)'],
    ['% del tiempo con la máquina', '=IFERROR(AVERAGE(B17,B18)/B19,0)'],
    ['', ''],
    ['NIVEL 2 - LABERINTO', ''],
    ['Partidas jugadas', '=COUNTA(' + col(n2, 'partida_id') + ')'],
    ['Veces que se ganó completando la lista', '=COUNTIF(' + col(n2, 'fin') + ',"lista")'],
    ['% de partidas ganadas por lista', '=IFERROR(B24/B23,0)'],
    ['', ''],
    ['Uso de trampas', ''],
    ['Trampas usadas en total', '=SUM(' + col(n2, 'j1_trampas_total') + ')+SUM(' + col(n2, 'j2_trampas_total') + ')'],
    ['Promedio de trampas por partida', '=IFERROR(B28/B23,0)'],
    ['Piñas', '=SUM(' + col(n2, 'j1_pinas') + ')+SUM(' + col(n2, 'j2_pinas') + ')'],
    ['Piñas que pegaron', '=SUM(' + col(n2, 'j1_pinas_acertadas') + ')+SUM(' + col(n2, 'j2_pinas_acertadas') + ')'],
    ['Bananas', '=SUM(' + col(n2, 'j1_bananas') + ')+SUM(' + col(n2, 'j2_bananas') + ')'],
    ['Hielos', '=SUM(' + col(n2, 'j1_hielos') + ')+SUM(' + col(n2, 'j2_hielos') + ')'],
    ['Trampa más usada', '=IF(AND(B30>=B32,B30>=B33),"Piña",IF(B32>=B33,"Banana","Hielo"))'],
  ];
  hoja.getRange(1, 1, filas.length, 2).setValues(filas);
  for (const fila of [1, 4, 9, 16, 22, 27]) {
    hoja.getRange(fila, 1).setFontWeight('bold');
  }
  hoja.getRange('B5:B7').setNumberFormat('0.0');
  hoja.getRange('B17:B19').setNumberFormat('0.0');
  hoja.getRange('B20').setNumberFormat('0%');
  hoja.getRange('B25').setNumberFormat('0%');
  hoja.getRange('B29').setNumberFormat('0.0');
  hoja.autoResizeColumn(1);
}
