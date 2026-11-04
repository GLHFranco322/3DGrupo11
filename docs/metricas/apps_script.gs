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
const CLAVE = 'nostrostudio';

// Pestañas que arma "configurar": columnas que llena el juego y columnas de
// observación que llena a mano quien mira el testeo.
const HOJAS = {
  'Nivel 1 - Corta el pasto': {
    columnas: [
      'partida_id', 'sesion', 'fecha', 'duracion_s', 'promedio_puntos', 'ganador',
      'j1_personaje', 'j1_puntos', 'j1_piedras', 'j1_pozos', 'j1_botas_agarradas', 'j1_patadas', 'j1_patadas_acertadas', 'j1_trampas_total', 'j1_seg_con_maquina',
      'j2_personaje', 'j2_puntos', 'j2_piedras', 'j2_pozos', 'j2_botas_agarradas', 'j2_patadas', 'j2_patadas_acertadas', 'j2_trampas_total', 'j2_seg_con_maquina',
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
  'Nivel 3 - Carrera': {
    columnas: ['partida_id', 'sesion', 'fecha', 'duracion_s', 'fin', 'ganador'].concat(
      columnasCarrera('j1'), columnasCarrera('j2')),
    observaciones: ['obs_notas'],
  },
};

// Columnas de cada jugador en la carrera: items (usos, aciertos y fallos) y
// trampas del mapa en las que cayó
function columnasCarrera(j) {
  return [
    'personaje', 'puntos', 'metros', 'vueltas',
    'cortadoras', 'cortadoras_acertadas', 'cortadoras_fallidas',
    'pozos', 'pozos_acertados', 'pozos_fallidos',
    'canas', 'canas_acertadas', 'canas_fallidas',
    'trampas_total', 'trampas_acertadas',
    'cayo_en_pozos', 'huecos', 'rejas', 'barro', 'caidas_mapa',
  ].map((columna) => j + '_' + columna);
}

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
 * Se puede volver a correr: no borra ni mueve nada; en las pestañas que ya
 * existen solo agrega al final las columnas que falten, y rehace el resumen.
 */
function configurar() {
  for (const nombre in HOJAS) {
    const hoja = obtenerHoja(nombre);
    const { columnas, observaciones } = HOJAS[nombre];
    const encabezado = leerEncabezado(hoja);
    for (const columna of columnas.concat(observaciones)) {
      if (encabezado.indexOf(columna) >= 0) continue;
      encabezado.push(columna);
      asegurarColumnas(hoja, encabezado.length);
      const celda = hoja.getRange(1, encabezado.length).setValue(columna).setFontWeight('bold');
      if (observaciones.indexOf(columna) >= 0) celda.setBackground('#fff2cc');
    }
    hoja.setFrozenRows(1);
    hoja.setFrozenColumns(1);
  }
  armarResumen();
}

// Encabezados de la fila 1 (sin las celdas vacías del final)
function leerEncabezado(hoja) {
  if (hoja.getLastColumn() === 0) return [];
  const encabezado = hoja.getRange(1, 1, 1, hoja.getLastColumn()).getValues()[0];
  while (encabezado.length > 0 && encabezado[encabezado.length - 1] === '') encabezado.pop();
  return encabezado;
}

// Rango de una columna (buscada por su encabezado) de una pestaña, desde la fila 2 hacia abajo
function col(nombreHoja, columna) {
  const hoja = obtenerHoja(nombreHoja);
  const indice = leerEncabezado(hoja).indexOf(columna) + 1;
  if (indice === 0) throw new Error('No existe la columna ' + columna + ' en ' + nombreHoja);
  const letra = hoja.getRange(1, indice).getA1Notation().replace(/\d+/g, '');
  return "'" + nombreHoja + "'!" + letra + '2:' + letra;
}

// Arma la pestaña "Resumen": una fila por dato, con la fórmula en la columna B.
// En las fórmulas, {clave} se reemplaza por la celda de la fila con esa clave
// (así se pueden agregar filas sin romper las cuentas de abajo).
function armarResumen() {
  const hoja = obtenerHoja(HOJA_RESUMEN);
  hoja.clear();
  const filas = [];
  const claves = {};
  const titulos = [];
  const formatos = [];

  function fila(clave, texto, formula, formato) {
    filas.push([texto, formula || '']);
    if (clave) claves[clave] = filas.length;
    if (formato) formatos.push([filas.length, formato]);
  }
  function titulo(texto) {
    fila(null, texto);
    titulos.push(filas.length);
  }
  function blanco() {
    fila(null, '');
  }
  // Suma de la columna de los dos jugadores ("piedras" -> j1_piedras + j2_piedras)
  function ambos(nombreHoja, columna) {
    return 'SUM(' + col(nombreHoja, 'j1_' + columna) + ')+SUM(' + col(nombreHoja, 'j2_' + columna) + ')';
  }
  function promedio(nombreHoja, columna) {
    return '=IFERROR(AVERAGE(' + col(nombreHoja, columna) + '),0)';
  }

  const n1 = 'Nivel 1 - Corta el pasto';
  titulo('NIVEL 1 - CORTA EL PASTO');
  fila('n1_partidas', 'Partidas jugadas', '=COUNTA(' + col(n1, 'partida_id') + ')');
  blanco();
  titulo('Hipótesis 1: puntos por partida');
  fila(null, 'Promedio de puntos jugador 1', promedio(n1, 'j1_puntos'), '0.0');
  fila(null, 'Promedio de puntos jugador 2', promedio(n1, 'j2_puntos'), '0.0');
  fila(null, 'Promedio final (ambos jugadores)', promedio(n1, 'promedio_puntos'), '0.0');
  blanco();
  titulo('Hipótesis 2: uso de trampas');
  fila('n1_piedras', 'Piedras usadas', '=' + ambos(n1, 'piedras'));
  fila('n1_pozos', 'Pozos usados', '=' + ambos(n1, 'pozos'));
  fila('n1_patadas', 'Patadas (veces que apretó R2 o □ con la bota)', '=' + ambos(n1, 'patadas'));
  fila(null, 'Patadas que conectaron', '=' + ambos(n1, 'patadas_acertadas'));
  fila(null, 'Trampas usadas en total', '=' + ambos(n1, 'trampas_total'));
  fila(null, 'Trampa más usada',
    '=IF(AND({n1_piedras}>={n1_pozos},{n1_piedras}>={n1_patadas}),"Piedra",IF({n1_pozos}>={n1_patadas},"Pozo","Patada"))');
  blanco();
  titulo('Hipótesis 3: tiempo con la máquina');
  fila('n1_maquina1', 'Promedio de segundos con la máquina (jugador 1)', promedio(n1, 'j1_seg_con_maquina'), '0.0');
  fila('n1_maquina2', 'Promedio de segundos con la máquina (jugador 2)', promedio(n1, 'j2_seg_con_maquina'), '0.0');
  fila('n1_duracion', 'Promedio de duración de la partida (s)', promedio(n1, 'duracion_s'), '0.0');
  fila(null, '% del tiempo con la máquina', '=IFERROR(AVERAGE({n1_maquina1},{n1_maquina2})/{n1_duracion},0)', '0%');
  blanco();

  const n2 = 'Nivel 2 - Laberinto';
  titulo('NIVEL 2 - LABERINTO');
  fila('n2_partidas', 'Partidas jugadas', '=COUNTA(' + col(n2, 'partida_id') + ')');
  fila('n2_lista', 'Veces que se ganó completando la lista', '=COUNTIF(' + col(n2, 'fin') + ',"lista")');
  fila(null, '% de partidas ganadas por lista', '=IFERROR({n2_lista}/{n2_partidas},0)', '0%');
  blanco();
  titulo('Uso de trampas');
  fila('n2_trampas', 'Trampas usadas en total', '=' + ambos(n2, 'trampas_total'));
  fila(null, 'Promedio de trampas por partida', '=IFERROR({n2_trampas}/{n2_partidas},0)', '0.0');
  fila('n2_pinas', 'Piñas', '=' + ambos(n2, 'pinas'));
  fila(null, 'Piñas que pegaron', '=' + ambos(n2, 'pinas_acertadas'));
  fila('n2_bananas', 'Bananas', '=' + ambos(n2, 'bananas'));
  fila('n2_hielos', 'Hielos', '=' + ambos(n2, 'hielos'));
  fila(null, 'Trampa más usada',
    '=IF(AND({n2_pinas}>={n2_bananas},{n2_pinas}>={n2_hielos}),"Piña",IF({n2_bananas}>={n2_hielos},"Banana","Hielo"))');
  blanco();

  const n3 = 'Nivel 3 - Carrera';
  titulo('NIVEL 3 - CARRERA DE CARRETILLAS');
  fila('n3_partidas', 'Partidas jugadas', '=COUNTA(' + col(n3, 'partida_id') + ')');
  fila(null, 'Victorias del jugador 1', '=COUNTIF(' + col(n3, 'ganador') + ',1)');
  fila(null, 'Victorias del jugador 2', '=COUNTIF(' + col(n3, 'ganador') + ',2)');
  fila(null, 'Carreras terminadas en la meta (no por tiempo)', '=COUNTIF(' + col(n3, 'fin') + ',"meta")');
  blanco();
  titulo('Uso de trampas (items)');
  fila('n3_cortadoras', 'Cortadoras tiradas', '=' + ambos(n3, 'cortadoras'));
  fila('n3_pozos', 'Pozos dejados', '=' + ambos(n3, 'pozos'));
  fila('n3_canas', 'Cañas usadas', '=' + ambos(n3, 'canas'));
  fila('n3_trampas', 'Trampas usadas en total', '=' + ambos(n3, 'trampas_total'));
  fila(null, 'Promedio de trampas por partida', '=IFERROR({n3_trampas}/{n3_partidas},0)', '0.0');
  fila(null, 'Trampa más usada',
    '=IF(AND({n3_cortadoras}>={n3_pozos},{n3_cortadoras}>={n3_canas}),"Cortadora",IF({n3_pozos}>={n3_canas},"Pozo","Caña"))');
  blanco();
  titulo('Éxito de las trampas');
  fila(null, 'Cortadoras que pegaron', '=' + ambos(n3, 'cortadoras_acertadas'));
  fila(null, 'Cortadoras que fallaron', '=' + ambos(n3, 'cortadoras_fallidas'));
  fila(null, 'Pozos en los que cayó el rival', '=' + ambos(n3, 'pozos_acertados'));
  fila(null, 'Pozos que no hicieron caer al rival', '=' + ambos(n3, 'pozos_fallidos'));
  fila(null, 'Cañas que pescaron al rival', '=' + ambos(n3, 'canas_acertadas'));
  fila(null, 'Cañas tiradas al aire', '=' + ambos(n3, 'canas_fallidas'));
  fila('n3_aciertos', 'Trampas con éxito en total', '=' + ambos(n3, 'trampas_acertadas'));
  fila(null, 'Trampas sin éxito en total', '={n3_trampas}-{n3_aciertos}');
  fila(null, '% de éxito de las trampas', '=IFERROR({n3_aciertos}/{n3_trampas},0)', '0%');
  blanco();
  titulo('Caídas en trampas del mapa');
  fila(null, 'Caídas en huecos de la pista', '=' + ambos(n3, 'huecos'));
  fila(null, 'Descargas de rejas eléctricas', '=' + ambos(n3, 'rejas'));
  fila('n3_caidas', 'Caídas en trampas del mapa (huecos + rejas)', '=' + ambos(n3, 'caidas_mapa'));
  fila(null, 'Promedio de caídas del mapa por partida', '=IFERROR({n3_caidas}/{n3_partidas},0)', '0.0');
  fila(null, 'Veces que pasaron por el barro', '=' + ambos(n3, 'barro'));
  fila(null, 'Caídas en pozos (de cualquiera)', '=' + ambos(n3, 'cayo_en_pozos'));

  const valores = filas.map(([texto, formula]) => [
    texto,
    formula.replace(/\{(\w+)\}/g, (_, clave) => {
      if (!(clave in claves)) throw new Error('No existe la fila ' + clave);
      return 'B' + claves[clave];
    }),
  ]);
  hoja.getRange(1, 1, valores.length, 2).setValues(valores);
  for (const numero of titulos) {
    hoja.getRange(numero, 1).setFontWeight('bold');
  }
  for (const [numero, formato] of formatos) {
    hoja.getRange(numero, 2).setNumberFormat(formato);
  }
  hoja.autoResizeColumn(1);
}
