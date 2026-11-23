/* =====================================================================
   PROYECTO PL/SQL - SISTEMA DE GESTION DE CITAS MEDICAS
   PRUEBAS DE HU05 - Prescripcion y descuento de stock (PKG_FARMACIA)
   ---------------------------------------------------------------------
   Ejecucion : conectado como PROYECTOPLSQL, con F5 (Ejecutar script).
               Se ve el resultado en la pestana "Salida de script".
   Requisito : PKG_CONSTANTES, PKG_CONTEXTO y PKG_FARMACIA compilados.
   ---------------------------------------------------------------------
   Que hace:
     PARTE 1. Un bloque que ejecuta unas 80 comprobaciones (OK / FALLO):
              - casos que deben funcionar (crear, agregar, entregar)
              - casos que deben fallar con un codigo de error exacto
              - permisos por rol, validacion de datos y descuento de stock
              Elige solo sus datos de prueba (historias SIN receta y los
              medicamentos con mas stock), los marca con la dosis
              'PRUEBA_HU05...' y AL FINAL LOS BORRA y devuelve el stock
              que haya descontado. Debe quedar la BD como estaba.
     PARTE 2. Consultas de coherencia: cada fila debe tener FILAS = 0.
   Lo que NO prueba (necesita dos sesiones): concurrencia -> ver
   concurrencia_hu05.sql.
   Si el bloque se interrumpe a la mitad, ejecute limpieza_hu05.sql.
   ===================================================================== */

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF

PROMPT
PROMPT ==================== PARTE 1: PRUEBAS DE PKG_FARMACIA ====================

DECLARE
  ---------------------------------------------------------------------
  -- Contadores y datos de prueba
  ---------------------------------------------------------------------
  vn_ok       NUMBER := 0;
  vn_fallos   NUMBER := 0;

  -- Constantes (se cargan una sola vez)
  vn_r1       NUMBER := PKG_CONSTANTES.receta_no_entregada;
  vn_r2       NUMBER := PKG_CONSTANTES.receta_entregada;
  vn_r3       NUMBER := PKG_CONSTANTES.receta_parcial;
  vn_d1       NUMBER := PKG_CONSTANTES.detalle_no_entregado;
  vn_d2       NUMBER := PKG_CONSTANTES.detalle_parcial;
  vn_d3       NUMBER := PKG_CONSTANTES.detalle_entregado;
  vd_ref      DATE   := PKG_CONSTANTES.fecha_sistema;

  -- Medico A y medico B (distintos), cada uno con una historia SIN receta
  vn_med_a    NUMBER;  vn_usr_a   NUMBER;  vn_hist_a  NUMBER;
  vn_med_b    NUMBER;  vn_usr_b   NUMBER;  vn_hist_b  NUMBER;
  -- Farmaceutico
  vn_usr_f    NUMBER;  vn_farm    NUMBER;
  -- Medicamentos: tres con mucho stock y uno con poco
  vn_m1       NUMBER;  vn_m2      NUMBER;  vn_m3      NUMBER;  vn_mlow   NUMBER;
  -- Stock y conteos iniciales (para verificar que todo queda como estaba)
  vn_s1_ini   NUMBER;  vn_s2_ini  NUMBER;  vn_s3_ini  NUMBER;  vn_slow_ini NUMBER;
  vn_nrec_ini NUMBER;  vn_ndet_ini NUMBER;

  -- Ids creados por las pruebas
  vn_rec_a    NUMBER;  vn_rec_b   NUMBER;
  vn_det1     NUMBER;  vn_det2    NUMBER;  vn_det_low NUMBER;

  -- Receptores de las llamadas (resultado de la ultima operacion)
  g_receta    NUMBER;
  g_detalle   NUMBER;
  g_pend      NUMBER;
  g_est_det   VARCHAR2(100);
  g_est_rec   VARCHAR2(100);
  g_filas     NUMBER;
  g_visto     BOOLEAN;

  -- Variables de trabajo
  vn_cod      NUMBER;
  vn_a        NUMBER;
  vn_b        NUMBER;
  vn_c        NUMBER;
  vd_e        DATE;
  vn_esperado NUMBER;
  vn_i        NUMBER;

  TYPE t_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
  vt_recetas  t_ids;   -- recetas creadas por este bloque (para la limpieza)

  ---------------------------------------------------------------------
  -- Utilidades
  ---------------------------------------------------------------------
  PROCEDURE chk(p_nombre IN VARCHAR2, p_ok IN BOOLEAN, p_info IN VARCHAR2 DEFAULT NULL) IS
  BEGIN
    IF p_ok THEN
      vn_ok := vn_ok + 1;
      DBMS_OUTPUT.PUT_LINE('  OK     ' || p_nombre);
    ELSE
      vn_fallos := vn_fallos + 1;
      DBMS_OUTPUT.PUT_LINE('  FALLO  ' || p_nombre || '   [' || p_info || ']');
    END IF;
  END chk;

  PROCEDURE ctx(p_usuario IN NUMBER, p_rol IN VARCHAR2, p_entidad IN NUMBER) IS
  BEGIN
    PKG_CONTEXTO.SET_USUARIO(p_usuario, p_rol, p_entidad);
  END ctx;

  FUNCTION f_stock(p_med IN NUMBER) RETURN NUMBER IS
    vn NUMBER;
  BEGIN
    SELECT CANTIDAD_DISPONIBLE INTO vn
    FROM   TBL_STOCK_FARMACIA
    WHERE  ID_MEDICAMENTO = p_med;
    RETURN vn;
  END f_stock;

  FUNCTION f_valor(p_id_param IN NUMBER) RETURN VARCHAR2 IS
    va VARCHAR2(100);
  BEGIN
    SELECT VALOR INTO va FROM TBL_PARAMETROS WHERE ID_PARAM = p_id_param;
    RETURN va;
  END f_valor;

  FUNCTION f_estado_receta(p_receta IN NUMBER) RETURN NUMBER IS
    vn NUMBER;
  BEGIN
    SELECT ID_ESTADO INTO vn FROM TBL_RECETAS_MEDICAS WHERE ID_RECETA = p_receta;
    RETURN vn;
  END f_estado_receta;

  ---------------------------------------------------------------------
  -- Envoltorios: devuelven 0 si la operacion funciono o el SQLCODE del
  -- error (por ejemplo -20080). Asi cada prueba compara un solo numero.
  ---------------------------------------------------------------------
  FUNCTION f_crear(p_hist IN NUMBER) RETURN NUMBER IS
  BEGIN
    g_receta := NULL;
    PKG_FARMACIA.PRO_CREAR_RECETA(p_hist, g_receta);
    IF g_receta IS NOT NULL THEN
      vt_recetas(vt_recetas.COUNT + 1) := g_receta;
    END IF;
    RETURN 0;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN SQLCODE;
  END f_crear;

  FUNCTION f_detalle(p_receta IN NUMBER, p_med IN NUMBER, p_cant IN NUMBER,
                     p_dosis IN VARCHAR2) RETURN NUMBER IS
  BEGIN
    g_detalle := NULL;
    PKG_FARMACIA.PRO_AGREGAR_DETALLE(p_receta, p_med, p_cant, p_dosis, g_detalle);
    RETURN 0;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN SQLCODE;
  END f_detalle;

  FUNCTION f_entrega(p_detalle IN NUMBER, p_cant IN NUMBER) RETURN NUMBER IS
  BEGIN
    g_pend := NULL;  g_est_det := NULL;  g_est_rec := NULL;
    PKG_FARMACIA.PRO_REGISTRAR_ENTREGA(p_detalle, p_cant, g_pend, g_est_det, g_est_rec);
    RETURN 0;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN SQLCODE;
  END f_entrega;

  -- Consultas: cuentan las filas del cursor (g_filas) y, en pendientes,
  -- indican si aparecio un detalle concreto (g_visto).
  FUNCTION f_listar_meds RETURN NUMBER IS
    c SYS_REFCURSOR;
    v1 NUMBER;  v2 VARCHAR2(4000);  v3 VARCHAR2(4000);
    v4 VARCHAR2(4000);  v5 NUMBER;  v6 NUMBER;
  BEGIN
    g_filas := 0;
    PKG_FARMACIA.PRO_LISTAR_MEDICAMENTOS(c);
    LOOP
      FETCH c INTO v1, v2, v3, v4, v5, v6;
      EXIT WHEN c%NOTFOUND;
      g_filas := g_filas + 1;
    END LOOP;
    CLOSE c;
    RETURN 0;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN SQLCODE;
  END f_listar_meds;

  FUNCTION f_pendientes(p_busca IN NUMBER) RETURN NUMBER IS
    c SYS_REFCURSOR;
    v1 NUMBER;  v2 NUMBER;  v3 DATE;  v4 VARCHAR2(4000);  v5 VARCHAR2(4000);
    v6 VARCHAR2(4000);  v7 NUMBER;  v8 NUMBER;  v9 VARCHAR2(4000);
    v10 NUMBER;  v11 VARCHAR2(4000);
  BEGIN
    g_filas := 0;
    g_visto := FALSE;
    PKG_FARMACIA.PRO_DETALLES_PENDIENTES(c);
    LOOP
      FETCH c INTO v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11;
      EXIT WHEN c%NOTFOUND;
      g_filas := g_filas + 1;
      IF v1 = p_busca THEN
        g_visto := TRUE;
      END IF;
    END LOOP;
    CLOSE c;
    RETURN 0;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN SQLCODE;
  END f_pendientes;

  FUNCTION f_det_receta(p_receta IN NUMBER) RETURN NUMBER IS
    c SYS_REFCURSOR;
    v1 NUMBER;  v2 NUMBER;  v3 VARCHAR2(4000);  v4 VARCHAR2(4000);
    v5 NUMBER;  v6 NUMBER;  v7 NUMBER;  v8 VARCHAR2(4000);
    v9 VARCHAR2(4000);  v10 DATE;
  BEGIN
    g_filas := 0;
    PKG_FARMACIA.PRO_DETALLE_RECETA(p_receta, c);
    LOOP
      FETCH c INTO v1, v2, v3, v4, v5, v6, v7, v8, v9, v10;
      EXIT WHEN c%NOTFOUND;
      g_filas := g_filas + 1;
    END LOOP;
    CLOSE c;
    RETURN 0;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN SQLCODE;
  END f_det_receta;

BEGIN
  ---------------------------------------------------------------------
  -- Cuerpo de las pruebas. Si algo inesperado revienta, se informa y
  -- se pasa igual a la limpieza.
  ---------------------------------------------------------------------
  BEGIN
    ------------------------------------------------------------------
    -- 0. Datos de prueba (se eligen solos)
    ------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('== 0. Datos de prueba');

    SELECT u.ID_USUARIO, u.ID_ENTIDAD
    INTO   vn_usr_f, vn_farm
    FROM   TBL_USUARIOS u
    WHERE  u.ID_ROL = 4 AND u.ID_ENTIDAD IS NOT NULL
    ORDER  BY u.ID_USUARIO
    FETCH FIRST 1 ROW ONLY;

    SELECT h.ID_HISTORIA, ag.ID_MEDICO
    INTO   vn_hist_a, vn_med_a
    FROM   TBL_HISTORIA_CLINICA h
    JOIN   TBL_CITAS_MEDICAS c  ON c.ID_CITA    = h.ID_CITA
    JOIN   TBL_AGENDA_MEDICO ag ON ag.ID_AGENDA = c.ID_AGENDA
    WHERE  NOT EXISTS (SELECT 1 FROM TBL_RECETAS_MEDICAS r WHERE r.ID_HISTORIA = h.ID_HISTORIA)
    AND    EXISTS     (SELECT 1 FROM TBL_USUARIOS u WHERE u.ID_ROL = 2 AND u.ID_ENTIDAD = ag.ID_MEDICO)
    ORDER  BY h.ID_HISTORIA
    FETCH FIRST 1 ROW ONLY;

    SELECT h.ID_HISTORIA, ag.ID_MEDICO
    INTO   vn_hist_b, vn_med_b
    FROM   TBL_HISTORIA_CLINICA h
    JOIN   TBL_CITAS_MEDICAS c  ON c.ID_CITA    = h.ID_CITA
    JOIN   TBL_AGENDA_MEDICO ag ON ag.ID_AGENDA = c.ID_AGENDA
    WHERE  NOT EXISTS (SELECT 1 FROM TBL_RECETAS_MEDICAS r WHERE r.ID_HISTORIA = h.ID_HISTORIA)
    AND    ag.ID_MEDICO <> vn_med_a
    AND    EXISTS     (SELECT 1 FROM TBL_USUARIOS u WHERE u.ID_ROL = 2 AND u.ID_ENTIDAD = ag.ID_MEDICO)
    ORDER  BY h.ID_HISTORIA
    FETCH FIRST 1 ROW ONLY;

    SELECT ID_USUARIO INTO vn_usr_a FROM TBL_USUARIOS
    WHERE  ID_ROL = 2 AND ID_ENTIDAD = vn_med_a
    FETCH FIRST 1 ROW ONLY;

    SELECT ID_USUARIO INTO vn_usr_b FROM TBL_USUARIOS
    WHERE  ID_ROL = 2 AND ID_ENTIDAD = vn_med_b
    FETCH FIRST 1 ROW ONLY;

    vn_i := 0;
    FOR r IN (SELECT ID_MEDICAMENTO
              FROM   TBL_STOCK_FARMACIA
              ORDER  BY CANTIDAD_DISPONIBLE DESC, ID_MEDICAMENTO
              FETCH FIRST 3 ROWS ONLY) LOOP
      vn_i := vn_i + 1;
      IF    vn_i = 1 THEN vn_m1 := r.ID_MEDICAMENTO;
      ELSIF vn_i = 2 THEN vn_m2 := r.ID_MEDICAMENTO;
      ELSE                vn_m3 := r.ID_MEDICAMENTO;
      END IF;
    END LOOP;

    SELECT ID_MEDICAMENTO INTO vn_mlow
    FROM   TBL_STOCK_FARMACIA
    ORDER  BY CANTIDAD_DISPONIBLE ASC, ID_MEDICAMENTO
    FETCH FIRST 1 ROW ONLY;

    vn_s1_ini := f_stock(vn_m1);   vn_s2_ini := f_stock(vn_m2);
    vn_s3_ini := f_stock(vn_m3);   vn_slow_ini := f_stock(vn_mlow);
    SELECT COUNT(*) INTO vn_nrec_ini FROM TBL_RECETAS_MEDICAS;
    SELECT COUNT(*) INTO vn_ndet_ini FROM TBL_DETALLE_RECETA;

    DBMS_OUTPUT.PUT_LINE('   Medico A: id ' || vn_med_a || ' (usuario ' || vn_usr_a || '), historia ' || vn_hist_a);
    DBMS_OUTPUT.PUT_LINE('   Medico B: id ' || vn_med_b || ' (usuario ' || vn_usr_b || '), historia ' || vn_hist_b);
    DBMS_OUTPUT.PUT_LINE('   Farmaceutico: id ' || vn_farm || ' (usuario ' || vn_usr_f || ')');
    DBMS_OUTPUT.PUT_LINE('   Medicamentos con stock: ' || vn_m1 || ' (' || vn_s1_ini || '), '
                         || vn_m2 || ' (' || vn_s2_ini || '), ' || vn_m3 || ' (' || vn_s3_ini || ')');
    DBMS_OUTPUT.PUT_LINE('   Medicamento con poco stock: ' || vn_mlow || ' (' || vn_slow_ini || ')');

    ------------------------------------------------------------------
    -- 1. Crear receta
    ------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('== 1. PRO_CREAR_RECETA');

    ctx(vn_usr_a, 'MEDICO', vn_med_a);
    vn_cod := f_crear(vn_hist_a);
    vn_rec_a := g_receta;
    chk('T01 el medico crea la receta de su historia', vn_cod = 0 AND vn_rec_a IS NOT NULL, 'codigo=' || vn_cod);

    SELECT r.ID_ESTADO, r.FECHA_EMISION INTO vn_a, vd_e
    FROM   TBL_RECETAS_MEDICAS r WHERE r.ID_RECETA = vn_rec_a;
    chk('T02 la receta nace en estado No entregada', vn_a = vn_r1, 'estado=' || vn_a);
    chk('T03 la fecha de emision es la fecha de referencia del sistema', TRUNC(vd_e) = vd_ref,
        TO_CHAR(vd_e, 'DD/MM/YYYY HH24:MI'));

    vn_cod := f_crear(vn_hist_a);
    chk('T04 segunda receta de la misma historia -> 20080', vn_cod = -20080, 'codigo=' || vn_cod);

    vn_cod := f_crear(vn_hist_b);
    chk('T05 historia de otro medico -> 20005', vn_cod = -20005, 'codigo=' || vn_cod);

    vn_cod := f_crear(999999999);
    chk('T06 historia inexistente -> 20002', vn_cod = -20002, 'codigo=' || vn_cod);

    vn_cod := f_crear(NULL);
    chk('T07 historia nula -> 20085', vn_cod = -20085, 'codigo=' || vn_cod);

    ctx(vn_usr_f, 'FARMACEUTICO', vn_farm);
    vn_cod := f_crear(vn_hist_b);
    chk('T08 un farmaceutico no crea recetas -> 20005', vn_cod = -20005, 'codigo=' || vn_cod);

    ctx(12, 'RECEPCIONISTA', NULL);
    vn_cod := f_crear(vn_hist_b);
    chk('T09 una recepcionista no crea recetas -> 20005', vn_cod = -20005, 'codigo=' || vn_cod);

    PKG_CONTEXTO.LIMPIAR;
    vn_cod := f_crear(vn_hist_b);
    chk('T10 sin contexto de usuario -> 20005', vn_cod = -20005, 'codigo=' || vn_cod);

    ------------------------------------------------------------------
    -- 2. Agregar medicamentos
    ------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('== 2. PRO_AGREGAR_DETALLE');

    ctx(vn_usr_a, 'MEDICO', vn_med_a);
    vn_cod := f_detalle(vn_rec_a, vn_m1, 10, 'PRUEBA_HU05 detalle 1');
    vn_det1 := g_detalle;
    chk('T11 agrega el primer medicamento', vn_cod = 0 AND vn_det1 IS NOT NULL, 'codigo=' || vn_cod);

    SELECT CANTIDAD, CANTIDAD_PENDIENTE, ID_ESTADO, ID_FARMACEUTICO, FECHA_ENTREGA
    INTO   vn_a, vn_b, vn_c, vn_esperado, vd_e
    FROM   TBL_DETALLE_RECETA WHERE ID_DETALLE = vn_det1;
    chk('T12 el detalle nace con pendiente = cantidad, No entregado, sin farmaceutico ni fecha',
        vn_a = 10 AND vn_b = 10 AND vn_c = vn_d1 AND vn_esperado IS NULL AND vd_e IS NULL,
        'cant=' || vn_a || ' pend=' || vn_b || ' estado=' || vn_c);
    chk('T13 prescribir NO descuenta stock', f_stock(vn_m1) = vn_s1_ini, 'stock=' || f_stock(vn_m1));

    vn_cod := f_detalle(vn_rec_a, vn_m2, 20, 'PRUEBA_HU05 detalle 2');
    vn_det2 := g_detalle;
    chk('T14 agrega el segundo medicamento', vn_cod = 0 AND vn_det2 IS NOT NULL, 'codigo=' || vn_cod);

    vn_cod := f_detalle(vn_rec_a, vn_m1, 5, 'PRUEBA_HU05 repetido');
    chk('T15 medicamento repetido en la receta -> 20081', vn_cod = -20081, 'codigo=' || vn_cod);

    vn_cod := f_detalle(vn_rec_a, 999999, 5, 'PRUEBA_HU05 inexistente');
    chk('T16 medicamento inexistente -> 20002', vn_cod = -20002, 'codigo=' || vn_cod);

    vn_cod := f_detalle(999999999, vn_m3, 5, 'PRUEBA_HU05 receta inexistente');
    chk('T17 receta inexistente -> 20002', vn_cod = -20002, 'codigo=' || vn_cod);

    vn_cod := f_detalle(vn_rec_a, vn_m3, 0, 'PRUEBA_HU05 cantidad 0');
    chk('T18 cantidad 0 -> 20085', vn_cod = -20085, 'codigo=' || vn_cod);

    vn_cod := f_detalle(vn_rec_a, vn_m3, -5, 'PRUEBA_HU05 cantidad negativa');
    chk('T19 cantidad negativa -> 20085', vn_cod = -20085, 'codigo=' || vn_cod);

    vn_cod := f_detalle(vn_rec_a, vn_m3, 2.5, 'PRUEBA_HU05 cantidad decimal');
    chk('T20 cantidad con decimales -> 20085 (no se redondea en silencio)', vn_cod = -20085, 'codigo=' || vn_cod);

    vn_cod := f_detalle(vn_rec_a, vn_m3, 1000000, 'PRUEBA_HU05 cantidad enorme');
    chk('T21 cantidad mayor a 999999 -> 20085', vn_cod = -20085, 'codigo=' || vn_cod);

    vn_cod := f_detalle(vn_rec_a, vn_m3, 5, '   ');
    chk('T22 dosis en blanco -> 20085', vn_cod = -20085, 'codigo=' || vn_cod);

    vn_cod := f_detalle(vn_rec_a, vn_m3, 5, NULL);
    chk('T23 dosis nula -> 20085', vn_cod = -20085, 'codigo=' || vn_cod);

    vn_cod := f_detalle(vn_rec_a, vn_m3, 5, 'PRUEBA_HU05 ' || RPAD('x', 250, 'x'));
    chk('T24 dosis de mas de 200 caracteres -> 20085', vn_cod = -20085, 'codigo=' || vn_cod);

    ctx(vn_usr_b, 'MEDICO', vn_med_b);
    vn_cod := f_detalle(vn_rec_a, vn_m3, 5, 'PRUEBA_HU05 de otro medico');
    chk('T25 otro medico no agrega a una receta ajena -> 20005', vn_cod = -20005, 'codigo=' || vn_cod);

    ctx(vn_usr_f, 'FARMACEUTICO', vn_farm);
    vn_cod := f_detalle(vn_rec_a, vn_m3, 5, 'PRUEBA_HU05 de farmaceutico');
    chk('T26 un farmaceutico no prescribe -> 20005', vn_cod = -20005, 'codigo=' || vn_cod);

    SELECT COUNT(*) INTO vn_a FROM TBL_DETALLE_RECETA WHERE ID_RECETA = vn_rec_a;
    chk('T27 los intentos fallidos no dejaron detalles de mas (quedan 2)', vn_a = 2, 'detalles=' || vn_a);

    ------------------------------------------------------------------
    -- 3. Consultas
    ------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('== 3. Consultas');

    SELECT COUNT(*) INTO vn_esperado FROM TBL_MEDICAMENTOS;
    ctx(vn_usr_f, 'FARMACEUTICO', vn_farm);
    vn_cod := f_listar_meds;
    chk('T28 el farmaceutico lista todos los medicamentos', vn_cod = 0 AND g_filas = vn_esperado,
        'codigo=' || vn_cod || ' filas=' || g_filas || ' esperadas=' || vn_esperado);
    ctx(vn_usr_a, 'MEDICO', vn_med_a);
    vn_cod := f_listar_meds;
    chk('T29 el medico lista los medicamentos', vn_cod = 0 AND g_filas = vn_esperado, 'codigo=' || vn_cod);
    ctx(1, 'ADMINISTRADOR', NULL);
    vn_cod := f_listar_meds;
    chk('T30 el administrador lista los medicamentos', vn_cod = 0 AND g_filas = vn_esperado, 'codigo=' || vn_cod);
    ctx(12, 'RECEPCIONISTA', NULL);
    vn_cod := f_listar_meds;
    chk('T31 la recepcionista no lista medicamentos -> 20005', vn_cod = -20005, 'codigo=' || vn_cod);
    ctx(18, 'PACIENTE', 1);
    vn_cod := f_listar_meds;
    chk('T32 el paciente no lista medicamentos -> 20005', vn_cod = -20005, 'codigo=' || vn_cod);

    SELECT COUNT(*) INTO vn_esperado FROM TBL_DETALLE_RECETA WHERE CANTIDAD_PENDIENTE > 0;
    ctx(vn_usr_f, 'FARMACEUTICO', vn_farm);
    vn_cod := f_pendientes(vn_det1);
    chk('T33 el farmaceutico ve los pendientes (incluidos los dos nuevos)',
        vn_cod = 0 AND g_filas = vn_esperado AND g_visto,
        'codigo=' || vn_cod || ' filas=' || g_filas || ' esperadas=' || vn_esperado);
    ctx(vn_usr_a, 'MEDICO', vn_med_a);
    vn_cod := f_pendientes(vn_det1);
    chk('T34 el medico no consulta pendientes de entrega -> 20005', vn_cod = -20005, 'codigo=' || vn_cod);

    vn_cod := f_det_receta(vn_rec_a);
    chk('T35 el medico dueno ve los 2 medicamentos de su receta', vn_cod = 0 AND g_filas = 2,
        'codigo=' || vn_cod || ' filas=' || g_filas);
    ctx(vn_usr_b, 'MEDICO', vn_med_b);
    vn_cod := f_det_receta(vn_rec_a);
    chk('T36 otro medico no ve la receta -> 20005', vn_cod = -20005, 'codigo=' || vn_cod);
    ctx(vn_usr_f, 'FARMACEUTICO', vn_farm);
    vn_cod := f_det_receta(vn_rec_a);
    chk('T37 el farmaceutico ve la receta', vn_cod = 0 AND g_filas = 2, 'codigo=' || vn_cod);
    vn_cod := f_det_receta(999999999);
    chk('T38 receta inexistente -> 20002', vn_cod = -20002, 'codigo=' || vn_cod);
    ctx(12, 'RECEPCIONISTA', NULL);
    vn_cod := f_det_receta(vn_rec_a);
    chk('T39 la recepcionista no ve recetas -> 20005', vn_cod = -20005, 'codigo=' || vn_cod);

    ------------------------------------------------------------------
    -- 4. Entregas
    ------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('== 4. PRO_REGISTRAR_ENTREGA');

    ctx(vn_usr_a, 'MEDICO', vn_med_a);
    vn_cod := f_entrega(vn_det1, 1);
    chk('T40 un medico no registra entregas -> 20005', vn_cod = -20005, 'codigo=' || vn_cod);
    ctx(12, 'RECEPCIONISTA', NULL);
    vn_cod := f_entrega(vn_det1, 1);
    chk('T41 una recepcionista no registra entregas -> 20005', vn_cod = -20005, 'codigo=' || vn_cod);
    PKG_CONTEXTO.LIMPIAR;
    vn_cod := f_entrega(vn_det1, 1);
    chk('T42 sin contexto de usuario -> 20005', vn_cod = -20005, 'codigo=' || vn_cod);
    ctx(vn_usr_f, 'FARMACEUTICO', 999999);
    vn_cod := f_entrega(vn_det1, 1);
    chk('T43 farmaceutico que no existe en la tabla -> 20005', vn_cod = -20005, 'codigo=' || vn_cod);
    ctx(vn_usr_f, 'FARMACEUTICO', NULL);
    vn_cod := f_entrega(vn_det1, 1);
    chk('T44 farmaceutico sin id de entidad -> 20005', vn_cod = -20005, 'codigo=' || vn_cod);

    ctx(vn_usr_f, 'FARMACEUTICO', vn_farm);
    vn_cod := f_entrega(vn_det1, 0);
    chk('T45 cantidad 0 -> 20085', vn_cod = -20085, 'codigo=' || vn_cod);
    vn_cod := f_entrega(vn_det1, 1.5);
    chk('T46 cantidad con decimales -> 20085', vn_cod = -20085, 'codigo=' || vn_cod);
    vn_cod := f_entrega(999999999, 1);
    chk('T47 detalle inexistente -> 20002', vn_cod = -20002, 'codigo=' || vn_cod);

    -- Entrega parcial: 4 de 10
    vn_cod := f_entrega(vn_det1, 4);
    chk('T48 entrega parcial (4 de 10) funciona', vn_cod = 0, 'codigo=' || vn_cod);
    chk('T49 devuelve pendiente = 6', g_pend = 6, 'pendiente=' || g_pend);
    chk('T50 el estado del detalle devuelto es Entregado parcialmente', g_est_det = f_valor(vn_d2), 'estado=' || g_est_det);
    chk('T51 el estado de la receta devuelto es Parcial', g_est_rec = f_valor(vn_r3), 'estado=' || g_est_rec);

    SELECT CANTIDAD_PENDIENTE, ID_ESTADO, ID_FARMACEUTICO, FECHA_ENTREGA
    INTO   vn_a, vn_b, vn_c, vd_e
    FROM   TBL_DETALLE_RECETA WHERE ID_DETALLE = vn_det1;
    chk('T52 el detalle quedo con pendiente 6, estado parcial, el farmaceutico del contexto y fecha',
        vn_a = 6 AND vn_b = vn_d2 AND vn_c = vn_farm AND vd_e IS NOT NULL AND TRUNC(vd_e) = vd_ref,
        'pend=' || vn_a || ' estado=' || vn_b || ' farm=' || vn_c);
    chk('T53 el stock bajo exactamente 4', f_stock(vn_m1) = vn_s1_ini - 4, 'stock=' || f_stock(vn_m1));
    chk('T54 la receta paso a Parcial en la base', f_estado_receta(vn_rec_a) = vn_r3, 'estado=' || f_estado_receta(vn_rec_a));

    -- Con entregas, la receta se cierra a nuevos medicamentos
    ctx(vn_usr_a, 'MEDICO', vn_med_a);
    vn_cod := f_detalle(vn_rec_a, vn_m3, 5, 'PRUEBA_HU05 tarde');
    chk('T55 receta con entregas no admite mas medicamentos -> 20082', vn_cod = -20082, 'codigo=' || vn_cod);

    -- Rechazos que no deben tocar nada
    ctx(vn_usr_f, 'FARMACEUTICO', vn_farm);
    vn_cod := f_entrega(vn_det1, 7);
    chk('T56 entregar mas de lo pendiente (7 > 6) -> 20084', vn_cod = -20084, 'codigo=' || vn_cod);
    chk('T57 el rechazo no cambio el stock', f_stock(vn_m1) = vn_s1_ini - 4, 'stock=' || f_stock(vn_m1));
    SELECT CANTIDAD_PENDIENTE INTO vn_a FROM TBL_DETALLE_RECETA WHERE ID_DETALLE = vn_det1;
    chk('T58 el rechazo no cambio el pendiente', vn_a = 6, 'pend=' || vn_a);

    -- Completar el primer detalle
    vn_cod := f_entrega(vn_det1, 6);
    chk('T59 entrega del resto (6) funciona', vn_cod = 0, 'codigo=' || vn_cod);
    chk('T60 pendiente 0 y detalle Entregado', g_pend = 0 AND g_est_det = f_valor(vn_d3),
        'pend=' || g_pend || ' estado=' || g_est_det);
    chk('T61 la receta sigue Parcial (falta el segundo medicamento)', g_est_rec = f_valor(vn_r3), 'estado=' || g_est_rec);
    chk('T62 el stock bajo 10 en total', f_stock(vn_m1) = vn_s1_ini - 10, 'stock=' || f_stock(vn_m1));

    vn_cod := f_entrega(vn_det1, 1);
    chk('T63 detalle ya entregado completo -> 20083', vn_cod = -20083, 'codigo=' || vn_cod);
    chk('T64 el rechazo no cambio el stock', f_stock(vn_m1) = vn_s1_ini - 10, 'stock=' || f_stock(vn_m1));

    vn_cod := f_pendientes(vn_det1);
    chk('T65 el detalle entregado ya no aparece en pendientes', vn_cod = 0 AND NOT g_visto, 'codigo=' || vn_cod);
    vn_cod := f_pendientes(vn_det2);
    chk('T66 el detalle sin entregar sigue en pendientes', vn_cod = 0 AND g_visto, 'codigo=' || vn_cod);

    -- Completar la receta
    vn_cod := f_entrega(vn_det2, 20);
    chk('T67 entrega total del segundo medicamento (20)', vn_cod = 0 AND g_pend = 0, 'codigo=' || vn_cod);
    chk('T68 la receta queda Entregada', g_est_rec = f_valor(vn_r2) AND f_estado_receta(vn_rec_a) = vn_r2,
        'estado=' || g_est_rec);
    chk('T69 el stock del segundo medicamento bajo 20', f_stock(vn_m2) = vn_s2_ini - 20, 'stock=' || f_stock(vn_m2));

    SELECT COUNT(*) INTO vn_a FROM TBL_DETALLE_RECETA WHERE ID_RECETA = vn_rec_a AND CANTIDAD_PENDIENTE > 0;
    chk('T70 la receta entregada no tiene pendientes', vn_a = 0, 'con pendiente=' || vn_a);

    ------------------------------------------------------------------
    -- 5. Stock insuficiente (el caso que se defiende)
    ------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('== 5. Stock insuficiente');

    ctx(vn_usr_b, 'MEDICO', vn_med_b);
    vn_cod := f_crear(vn_hist_b);
    vn_rec_b := g_receta;
    chk('T71 el medico B crea su receta', vn_cod = 0 AND vn_rec_b IS NOT NULL, 'codigo=' || vn_cod);

    vn_cod := f_detalle(vn_rec_b, vn_mlow, vn_slow_ini + 1, 'PRUEBA_HU05 mas de lo que hay');
    vn_det_low := g_detalle;
    chk('T72 se puede RECETAR mas de lo que hay en stock (no se valida al prescribir)',
        vn_cod = 0 AND vn_det_low IS NOT NULL, 'codigo=' || vn_cod);

    ctx(vn_usr_f, 'FARMACEUTICO', vn_farm);
    vn_cod := f_entrega(vn_det_low, vn_slow_ini + 1);
    chk('T73 entregar mas de lo que hay en stock -> 20004', vn_cod = -20004, 'codigo=' || vn_cod);
    chk('T74 el rechazo dejo el stock intacto', f_stock(vn_mlow) = vn_slow_ini, 'stock=' || f_stock(vn_mlow));
    SELECT CANTIDAD_PENDIENTE, ID_ESTADO INTO vn_a, vn_b FROM TBL_DETALLE_RECETA WHERE ID_DETALLE = vn_det_low;
    chk('T75 el rechazo dejo el detalle intacto (pendiente completo, No entregado)',
        vn_a = vn_slow_ini + 1 AND vn_b = vn_d1, 'pend=' || vn_a || ' estado=' || vn_b);
    chk('T76 la receta sigue No entregada', f_estado_receta(vn_rec_b) = vn_r1, 'estado=' || f_estado_receta(vn_rec_b));

    IF vn_slow_ini > 0 THEN
      vn_cod := f_entrega(vn_det_low, vn_slow_ini);
      chk('T77 entregar exactamente el stock disponible funciona', vn_cod = 0, 'codigo=' || vn_cod);
      chk('T78 el stock queda en 0 (nunca negativo)', f_stock(vn_mlow) = 0, 'stock=' || f_stock(vn_mlow));
      chk('T79 queda 1 pendiente y el detalle es Parcial', g_pend = 1 AND g_est_det = f_valor(vn_d2),
          'pend=' || g_pend || ' estado=' || g_est_det);
      vn_cod := f_entrega(vn_det_low, 1);
      chk('T80 con el stock en 0, entregar 1 -> 20004', vn_cod = -20004, 'codigo=' || vn_cod);
      chk('T81 el stock sigue en 0', f_stock(vn_mlow) = 0, 'stock=' || f_stock(vn_mlow));
    ELSE
      DBMS_OUTPUT.PUT_LINE('  (omitidas T77-T81: el medicamento ' || vn_mlow || ' ya tenia stock 0)');
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      vn_fallos := vn_fallos + 1;
      DBMS_OUTPUT.PUT_LINE('  ERROR INESPERADO, se interrumpen las pruebas: ' || SQLERRM);
  END;

  ---------------------------------------------------------------------
  -- Limpieza: borra lo creado por este bloque y devuelve el stock que
  -- se desconto con las entregas de prueba.
  ---------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('== Limpieza de los datos de prueba');
  PKG_CONTEXTO.LIMPIAR;
  BEGIN
    FOR i IN 1 .. vt_recetas.COUNT LOOP
      FOR d IN (SELECT ID_MEDICAMENTO, CANTIDAD - CANTIDAD_PENDIENTE AS ENTREGADO
                FROM   TBL_DETALLE_RECETA
                WHERE  ID_RECETA = vt_recetas(i)) LOOP
        UPDATE TBL_STOCK_FARMACIA
        SET    CANTIDAD_DISPONIBLE = CANTIDAD_DISPONIBLE + d.ENTREGADO
        WHERE  ID_MEDICAMENTO = d.ID_MEDICAMENTO;
      END LOOP;
      DELETE FROM TBL_DETALLE_RECETA   WHERE ID_RECETA = vt_recetas(i);
      DELETE FROM TBL_RECETAS_MEDICAS  WHERE ID_RECETA = vt_recetas(i);
    END LOOP;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      vn_fallos := vn_fallos + 1;
      DBMS_OUTPUT.PUT_LINE('  ERROR EN LA LIMPIEZA: ' || SQLERRM || '  -> ejecute limpieza_hu05.sql');
  END;

  IF vn_m1 IS NOT NULL THEN
    SELECT COUNT(*) INTO vn_a FROM TBL_RECETAS_MEDICAS;
    SELECT COUNT(*) INTO vn_b FROM TBL_DETALLE_RECETA;
    chk('L1 el stock de los 4 medicamentos quedo como al empezar',
        f_stock(vn_m1) = vn_s1_ini AND f_stock(vn_m2) = vn_s2_ini
        AND f_stock(vn_m3) = vn_s3_ini AND f_stock(vn_mlow) = vn_slow_ini,
        'revise TBL_STOCK_FARMACIA');
    chk('L2 el numero de recetas y de detalles quedo como al empezar',
        vn_a = vn_nrec_ini AND vn_b = vn_ndet_ini,
        'recetas ' || vn_a || '/' || vn_nrec_ini || ' detalles ' || vn_b || '/' || vn_ndet_ini);
  END IF;

  ---------------------------------------------------------------------
  -- Resumen
  ---------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('==================== RESUMEN ====================');
  DBMS_OUTPUT.PUT_LINE('  Pruebas OK    : ' || vn_ok);
  DBMS_OUTPUT.PUT_LINE('  Pruebas FALLO : ' || vn_fallos);
  IF vn_fallos = 0 THEN
    DBMS_OUTPUT.PUT_LINE('  RESULTADO: TODO CORRECTO');
  ELSE
    DBMS_OUTPUT.PUT_LINE('  RESULTADO: HAY FALLOS (revise las lineas FALLO de arriba)');
  END IF;
END;
/

PROMPT
PROMPT ================ PARTE 2: COHERENCIA (todas las filas deben dar 0) ================

SET FEEDBACK ON

SELECT 'C1 detalle con pendiente negativo o mayor que la cantidad' AS VERIFICACION,
       COUNT(*) AS FILAS_CON_PROBLEMA
FROM   TBL_DETALLE_RECETA
WHERE  CANTIDAD_PENDIENTE < 0 OR CANTIDAD_PENDIENTE > CANTIDAD
UNION ALL
SELECT 'C2 estado del detalle que no cuadra con lo pendiente / farmaceutico / fecha',
       COUNT(*)
FROM   TBL_DETALLE_RECETA d
JOIN   TBL_PARAMETROS p ON p.ID_PARAM = d.ID_ESTADO
WHERE  (p.ID_TIPO = 'D3' AND (d.CANTIDAD_PENDIENTE <> 0
                              OR d.ID_FARMACEUTICO IS NULL OR d.FECHA_ENTREGA IS NULL))
   OR  (p.ID_TIPO = 'D2' AND (d.CANTIDAD_PENDIENTE = 0 OR d.CANTIDAD_PENDIENTE = d.CANTIDAD
                              OR d.ID_FARMACEUTICO IS NULL OR d.FECHA_ENTREGA IS NULL))
   OR  (p.ID_TIPO = 'D1' AND (d.CANTIDAD_PENDIENTE <> d.CANTIDAD
                              OR d.ID_FARMACEUTICO IS NOT NULL OR d.FECHA_ENTREGA IS NOT NULL))
UNION ALL
SELECT 'C3 estado de la receta que no cuadra con el de sus detalles',
       COUNT(*)
FROM   TBL_RECETAS_MEDICAS r
JOIN   TBL_PARAMETROS p ON p.ID_PARAM = r.ID_ESTADO
WHERE  EXISTS (SELECT 1 FROM TBL_DETALLE_RECETA d WHERE d.ID_RECETA = r.ID_RECETA)
AND    p.ID_TIPO <> (SELECT CASE
                               WHEN SUM(CASE WHEN d.CANTIDAD_PENDIENTE = d.CANTIDAD THEN 0 ELSE 1 END) = 0 THEN 'R1'
                               WHEN SUM(d.CANTIDAD_PENDIENTE) = 0 THEN 'R2'
                               ELSE 'R3'
                             END
                      FROM   TBL_DETALLE_RECETA d
                      WHERE  d.ID_RECETA = r.ID_RECETA)
UNION ALL
SELECT 'C4 stock negativo', COUNT(*)
FROM   TBL_STOCK_FARMACIA
WHERE  CANTIDAD_DISPONIBLE < 0
UNION ALL
SELECT 'C5 medicamento repetido dentro de una misma receta', COUNT(*)
FROM  (SELECT ID_RECETA, ID_MEDICAMENTO
       FROM   TBL_DETALLE_RECETA
       GROUP  BY ID_RECETA, ID_MEDICAMENTO
       HAVING COUNT(*) > 1)
UNION ALL
SELECT 'C6 historia con mas de una receta', COUNT(*)
FROM  (SELECT ID_HISTORIA
       FROM   TBL_RECETAS_MEDICAS
       GROUP  BY ID_HISTORIA
       HAVING COUNT(*) > 1)
UNION ALL
SELECT 'C7 detalle sin registro de stock para su medicamento', COUNT(*)
FROM   TBL_DETALLE_RECETA d
WHERE  NOT EXISTS (SELECT 1 FROM TBL_STOCK_FARMACIA s WHERE s.ID_MEDICAMENTO = d.ID_MEDICAMENTO)
UNION ALL
SELECT 'C8 restos de pruebas sin borrar (dosis PRUEBA_HU05)', COUNT(*)
FROM   TBL_DETALLE_RECETA
WHERE  DOSIS LIKE 'PRUEBA_HU05%';

PROMPT
PROMPT Informativo (puede ser > 0 si se crearon recetas desde la pantalla y todavia no tienen medicamentos):
SELECT 'I1 recetas sin ningun medicamento (estado transitorio)' AS VERIFICACION, COUNT(*) AS FILAS
FROM   TBL_RECETAS_MEDICAS r
WHERE  NOT EXISTS (SELECT 1 FROM TBL_DETALLE_RECETA d WHERE d.ID_RECETA = r.ID_RECETA);

/* ======================= FIN DE LAS PRUEBAS DE HU05 ======================= */
