/* =====================================================================
   PROYECTO PL/SQL - SISTEMA DE GESTION DE CITAS MEDICAS
   PRUEBA DE CONCURRENCIA DE HU05 (PKG_FARMACIA.PRO_REGISTRAR_ENTREGA)
   ---------------------------------------------------------------------
   Que se demuestra:
     - Dos farmaceuticos no pueden entregar el mismo medicamento al mismo
       tiempo: el segundo ESPERA (FOR UPDATE WAIT 5) a que el primero
       termine y, cuando entra, ve el stock ya descontado.
     - Si no alcanza el stock, el segundo recibe 20004 y el stock NUNCA
       queda negativo (sin FOR UPDATE, los dos habrian pasado la validacion
       con el stock inicial).
     - Si la espera pasa de 5 segundos, la operacion responde 20087
       ("operacion en curso, intente de nuevo") y no se queda colgada.

   IMPORTANTE - dos conexiones DISTINTAS
     SQL Developer comparte la conexion entre hojas de trabajo. Para esta
     prueba abra cada pestana con  Ctrl+Shift+N  (hoja de trabajo
     INDEPENDIENTE / "Unshared"), una para TAB 1 y otra para TAB 2, las dos
     conectadas como PROYECTOPLSQL. Con una conexion compartida no hay
     concurrencia y la prueba no demuestra nada.

   NO ejecute el archivo completo con F5. Es una guia: seleccione cada
   bloque con el mouse y ejecute SOLO lo seleccionado (F5 para bloques
   PL/SQL, Ctrl+Enter para una sentencia suelta).

   Orden:
     PASO 0 (una vez, cualquier pestana): prepara los datos y muestra los
            numeros que debe copiar en los DEFINE.
     ESCENARIO 1: timeout 20087 (la espera pasa de 5 s)  - no cambia nada
     ESCENARIO 2: carrera por el ultimo stock            - el importante
     ESCENARIO 3: espera y luego exito (opcional; repita antes limpieza_hu05.sql y PASO 0)
     PASO FINAL: limpieza_hu05.sql
   ===================================================================== */

/* ---------------------------------------------------------------------
   PASO 0. PREPARACION (ejecutar este bloque con F5 en cualquier pestana)
   Crea dos recetas (medicos distintos), cada una con el MISMO
   medicamento de poco stock y una cantidad q tal que  q <= stock  pero
   2*q > stock: solo una de las dos entregas puede salir.
   --------------------------------------------------------------------- */
SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
  vn_med_a NUMBER; vn_usr_a NUMBER; vn_hist_a NUMBER;
  vn_med_b NUMBER; vn_usr_b NUMBER; vn_hist_b NUMBER;
  vn_mlow  NUMBER; vn_stock NUMBER; vn_q NUMBER;
  vn_rec_a NUMBER; vn_rec_b NUMBER; vn_det_a NUMBER; vn_det_b NUMBER;
BEGIN
  SELECT h.ID_HISTORIA, ag.ID_MEDICO INTO vn_hist_a, vn_med_a
  FROM   TBL_HISTORIA_CLINICA h
  JOIN   TBL_CITAS_MEDICAS c  ON c.ID_CITA    = h.ID_CITA
  JOIN   TBL_AGENDA_MEDICO ag ON ag.ID_AGENDA = c.ID_AGENDA
  WHERE  NOT EXISTS (SELECT 1 FROM TBL_RECETAS_MEDICAS r WHERE r.ID_HISTORIA = h.ID_HISTORIA)
  AND    EXISTS     (SELECT 1 FROM TBL_USUARIOS u WHERE u.ID_ROL = 2 AND u.ID_ENTIDAD = ag.ID_MEDICO)
  ORDER  BY h.ID_HISTORIA
  FETCH FIRST 1 ROW ONLY;

  SELECT h.ID_HISTORIA, ag.ID_MEDICO INTO vn_hist_b, vn_med_b
  FROM   TBL_HISTORIA_CLINICA h
  JOIN   TBL_CITAS_MEDICAS c  ON c.ID_CITA    = h.ID_CITA
  JOIN   TBL_AGENDA_MEDICO ag ON ag.ID_AGENDA = c.ID_AGENDA
  WHERE  NOT EXISTS (SELECT 1 FROM TBL_RECETAS_MEDICAS r WHERE r.ID_HISTORIA = h.ID_HISTORIA)
  AND    ag.ID_MEDICO <> vn_med_a
  AND    EXISTS     (SELECT 1 FROM TBL_USUARIOS u WHERE u.ID_ROL = 2 AND u.ID_ENTIDAD = ag.ID_MEDICO)
  ORDER  BY h.ID_HISTORIA
  FETCH FIRST 1 ROW ONLY;

  SELECT ID_USUARIO INTO vn_usr_a FROM TBL_USUARIOS
  WHERE  ID_ROL = 2 AND ID_ENTIDAD = vn_med_a FETCH FIRST 1 ROW ONLY;
  SELECT ID_USUARIO INTO vn_usr_b FROM TBL_USUARIOS
  WHERE  ID_ROL = 2 AND ID_ENTIDAD = vn_med_b FETCH FIRST 1 ROW ONLY;

  -- Medicamento con poco stock (pero al menos 2 unidades)
  SELECT ID_MEDICAMENTO, CANTIDAD_DISPONIBLE INTO vn_mlow, vn_stock
  FROM   TBL_STOCK_FARMACIA
  WHERE  CANTIDAD_DISPONIBLE >= 2
  ORDER  BY CANTIDAD_DISPONIBLE, ID_MEDICAMENTO
  FETCH FIRST 1 ROW ONLY;

  vn_q := FLOOR(vn_stock / 2) + 1;   -- q <= stock y 2*q > stock

  PKG_CONTEXTO.SET_USUARIO(vn_usr_a, 'MEDICO', vn_med_a);
  PKG_FARMACIA.PRO_CREAR_RECETA(vn_hist_a, vn_rec_a);
  PKG_FARMACIA.PRO_AGREGAR_DETALLE(vn_rec_a, vn_mlow, vn_q, 'PRUEBA_HU05 concurrencia A', vn_det_a);

  PKG_CONTEXTO.SET_USUARIO(vn_usr_b, 'MEDICO', vn_med_b);
  PKG_FARMACIA.PRO_CREAR_RECETA(vn_hist_b, vn_rec_b);
  PKG_FARMACIA.PRO_AGREGAR_DETALLE(vn_rec_b, vn_mlow, vn_q, 'PRUEBA_HU05 concurrencia B', vn_det_b);
  PKG_CONTEXTO.LIMPIAR;

  DBMS_OUTPUT.PUT_LINE('=========== COPIE ESTOS NUMEROS EN LOS DEFINE DE ABAJO ===========');
  DBMS_OUTPUT.PUT_LINE('  medicamento = ' || vn_mlow || '   (stock actual: ' || vn_stock || ')');
  DBMS_OUTPUT.PUT_LINE('  cantidad    = ' || vn_q || '   (cada entrega pide ' || vn_q || '; dos no caben en ' || vn_stock || ')');
  DBMS_OUTPUT.PUT_LINE('  detalle_1   = ' || vn_det_a || '   (receta ' || vn_rec_a || ')');
  DBMS_OUTPUT.PUT_LINE('  detalle_2   = ' || vn_det_b || '   (receta ' || vn_rec_b || ')');
  DBMS_OUTPUT.PUT_LINE('  stock_inicial = ' || vn_stock);
EXCEPTION
  WHEN OTHERS THEN
    PKG_CONTEXTO.LIMPIAR;
    DBMS_OUTPUT.PUT_LINE('ERROR en la preparacion: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('Ejecute limpieza_hu05.sql y vuelva a intentar.');
END;
/

/* ---------------------------------------------------------------------
   DEFINE: copie los numeros que mostro el PASO 0. Seleccione estas 5
   lineas y ejecutelas (F5) en TAB 1 y tambien en TAB 2.
     detalle_tab1 = el detalle que entrega TAB 1
     detalle_tab2 = el detalle que entrega TAB 2
   --------------------------------------------------------------------- */
DEFINE medicamento  = 0
DEFINE cantidad     = 0
DEFINE detalle_tab1 = 0
DEFINE detalle_tab2 = 0

/* ---------------------------------------------------------------------
   BLOQUEAR (solo TAB 1). Seleccione SOLO la sentencia y Ctrl+Enter.
   NO haga commit: el medicamento queda "en uso" por TAB 1.
   --------------------------------------------------------------------- */
SELECT CANTIDAD_DISPONIBLE FROM TBL_STOCK_FARMACIA WHERE ID_MEDICAMENTO = &medicamento FOR UPDATE;

/* ---------------------------------------------------------------------
   LIBERAR (solo TAB 1). Seleccione SOLO la palabra ROLLBACK; y ejecute.
   --------------------------------------------------------------------- */
ROLLBACK;

/* ---------------------------------------------------------------------
   ENTREGA DESDE TAB 2 (seleccione el bloque completo, hasta PRINT, y F5)
   Usa detalle_tab2 y el farmaceutico olucumi.farm2.
   --------------------------------------------------------------------- */
VAR p_pend NUMBER
VAR p_edet VARCHAR2(100)
VAR p_erec VARCHAR2(100)
BEGIN
  PKG_CONTEXTO.SET_USUARIO(16, 'FARMACEUTICO', 2);
  PKG_FARMACIA.PRO_REGISTRAR_ENTREGA(&detalle_tab2, &cantidad, :p_pend, :p_edet, :p_erec);
  PKG_CONTEXTO.LIMPIAR;
END;
/
PRINT p_pend p_edet p_erec

/* ---------------------------------------------------------------------
   ENTREGA DESDE TAB 1 (solo escenarios 2 y 3; TAB 1 ya tiene el bloqueo)
   Usa detalle_tab1 y el farmaceutico mjimenez.farm1. Hace COMMIT, que
   libera el bloqueo y deja pasar a TAB 2.
   --------------------------------------------------------------------- */
VAR q_pend NUMBER
VAR q_edet VARCHAR2(100)
VAR q_erec VARCHAR2(100)
BEGIN
  PKG_CONTEXTO.SET_USUARIO(15, 'FARMACEUTICO', 1);
  PKG_FARMACIA.PRO_REGISTRAR_ENTREGA(&detalle_tab1, &cantidad, :q_pend, :q_edet, :q_erec);
  PKG_CONTEXTO.LIMPIAR;
END;
/
PRINT q_pend q_edet q_erec

/* =====================================================================
   ESCENARIO 1 - TIMEOUT 20087 (la espera se pasa de 5 segundos)
   Esperado: TAB 2 falla a los ~5 s con ORA-20087 ("...usados por otra
   operacion, intente de nuevo"). No queda nada a medias.
     1. DEFINE en las dos pestanas: detalle_tab2 = detalle_1 del PASO 0.
     2. TAB 1: BLOQUEAR.
     3. TAB 2: ENTREGA DESDE TAB 2. Espere SIN tocar TAB 1.
        -> a los 5 s: ORA-20087.
     4. TAB 1: LIBERAR (ROLLBACK).
     5. VERIFICACION: el detalle sigue sin entregar y el stock no cambio.

   ESCENARIO 2 - CARRERA POR EL ULTIMO STOCK (el importante)
   Hay stock para UNA entrega, no para las dos. Esperado: una sale bien y
   la otra recibe ORA-20004 ("No hay stock suficiente... Disponible: n").
   El stock NO queda negativo.
     1. DEFINE: detalle_tab1 = detalle_1, detalle_tab2 = detalle_2.
     2. TAB 1: BLOQUEAR.
     3. TAB 2: ENTREGA DESDE TAB 2 (queda esperando).
     4. TAB 1, antes de 5 s: ENTREGA DESDE TAB 1 (sale bien, hace COMMIT).
     5. TAB 2: al soltarse el bloqueo vuelve a leer el stock, ve que ya no
        alcanza y termina con ORA-20004.
     Si TAB 2 alcanza a dar 20087 antes de que usted ejecute el paso 4,
     TAB 1 sigue con su bloqueo: repita el paso 3 y haga el 4 mas rapido.
     6. VERIFICACION: una entrega hecha, otra sin hacer, STOCK_ACTUAL =
        stock_inicial - cantidad, y nunca negativo.

   ESCENARIO 3 - ESPERA Y LUEGO EXITO (opcional)
   Ejecute limpieza_hu05.sql y un PASO 0 nuevo. Luego:
     1. DEFINE: detalle_tab2 = detalle_1.
     2. TAB 1: BLOQUEAR.   3. TAB 2: ENTREGA DESDE TAB 2 (queda esperando).
     4. TAB 1, antes de 5 s: LIBERAR (ROLLBACK).
     5. TAB 2 termina con exito: la espera funciono y no hubo conflicto.
   ===================================================================== */

/* ---------------------------------------------------------------------
   VERIFICACION (despues de cada escenario, en cualquier pestana)
   --------------------------------------------------------------------- */
SELECT d.ID_DETALLE, d.CANTIDAD, d.CANTIDAD_PENDIENTE,
       d.CANTIDAD - d.CANTIDAD_PENDIENTE AS ENTREGADO,
       p.VALOR AS ESTADO,
       (SELECT s.CANTIDAD_DISPONIBLE FROM TBL_STOCK_FARMACIA s
        WHERE  s.ID_MEDICAMENTO = d.ID_MEDICAMENTO) AS STOCK_ACTUAL
FROM   TBL_DETALLE_RECETA d
JOIN   TBL_PARAMETROS p ON p.ID_PARAM = d.ID_ESTADO
WHERE  d.DOSIS LIKE 'PRUEBA_HU05 concurrencia%'
ORDER  BY d.ID_DETALLE;

/* Al terminar, ejecute limpieza_hu05.sql: borra estas recetas y devuelve
   el stock que se desconto. */

/* ======================= FIN DE LA PRUEBA DE CONCURRENCIA ======================= */
