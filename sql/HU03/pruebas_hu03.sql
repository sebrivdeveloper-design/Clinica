
/* =====================================================================
   HU03 - PRUEBAS DE PKG_HISTORIA.REGISTRAR_CONSULTA
   ---------------------------------------------------------------------
   Ejecucion: conectado como PROYECTOPLSQL, con F5.
   Requisitos:
     - PKG_HISTORIA compilado y VALID.
     - PKG_CONSTANTES y PKG_CONTEXTO compilados.
     - Trigger TRG_HISTORIA_VALIDAR_CITA habilitado.
     - Datos de medicos y usuarios cargados.
   ---------------------------------------------------------------------
   Las pruebas crean un paciente, una agenda y citas temporales con
   identificadores exclusivos HU03. Al terminar, los elimina.

   IMPORTANTE:
     El procedimiento probado realiza COMMIT internamente. Por eso estas
     pruebas crean datos marcados y los eliminan explícitamente.
     Si el script se interrumpe, ejecutar limpieza_hu03.sql.
   ===================================================================== */

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF

PROMPT
PROMPT ==================== PRUEBAS HU03 ====================

DECLARE
  ---------------------------------------------------------------------
  -- Contadores
  ---------------------------------------------------------------------
  vn_ok       NUMBER := 0;
  vn_fallos   NUMBER := 0;

  ---------------------------------------------------------------------
  -- Datos de medicos y usuarios
  ---------------------------------------------------------------------
  vn_medico_a NUMBER;
  vn_usuario_a NUMBER;
  vn_medico_b NUMBER;
  vn_usuario_b NUMBER;

  ---------------------------------------------------------------------
  -- Datos temporales HU03
  ---------------------------------------------------------------------
  vn_paciente NUMBER;
  vn_agenda   NUMBER;

  vn_cita_ok       NUMBER;
  vn_cita_notas_null NUMBER;
  vn_cita_otro_medico NUMBER;
  vn_cita_otro_rol NUMBER;
  vn_cita_cancelada NUMBER;
  vn_cita_inexistente NUMBER;

  vn_historia      NUMBER;
  vn_historia_null NUMBER;
  vn_estado        NUMBER;
  vn_total         NUMBER;
  vn_codigo        NUMBER;

  vn_diagnostico_largo VARCHAR2(2000);
  vn_notas_largas     VARCHAR2(5000);

  ---------------------------------------------------------------------
  -- Marcadores exclusivos de pruebas
  ---------------------------------------------------------------------
  vc_documento CONSTANT VARCHAR2(20) := 'HU03TEST0001';
  vd_inicio    CONSTANT DATE := DATE '2099-12-31';

  ---------------------------------------------------------------------
  -- Verificacion de cada caso
  ---------------------------------------------------------------------
  PROCEDURE chk(
    p_nombre IN VARCHAR2,
    p_ok     IN BOOLEAN,
    p_info   IN VARCHAR2 DEFAULT NULL
  ) IS
  BEGIN
    IF p_ok THEN
      vn_ok := vn_ok + 1;
      DBMS_OUTPUT.PUT_LINE('  OK     ' || p_nombre);
    ELSE
      vn_fallos := vn_fallos + 1;
      DBMS_OUTPUT.PUT_LINE('  FALLO  ' || p_nombre || ' [' || p_info || ']');
    END IF;
  END chk;

  ---------------------------------------------------------------------
  -- Configurar contexto de usuario
  ---------------------------------------------------------------------
  PROCEDURE ctx(
    p_usuario IN NUMBER,
    p_rol     IN VARCHAR2,
    p_entidad IN NUMBER
  ) IS
  BEGIN
    PKG_CONTEXTO.SET_USUARIO(p_usuario, p_rol, p_entidad);
  END ctx;

  ---------------------------------------------------------------------
  -- Crear cita temporal
  ---------------------------------------------------------------------
  PROCEDURE crear_cita(
    p_estado IN NUMBER,
    p_id_cita OUT NUMBER
  ) IS
  BEGIN
    INSERT INTO TBL_CITAS_MEDICAS (
      ID_PACIENTE,
      ID_AGENDA,
      ID_ESTADO
    )
    VALUES (
      vn_paciente,
      vn_agenda,
      p_estado
    )
    RETURNING ID_CITA INTO p_id_cita;
  END crear_cita;

  ---------------------------------------------------------------------
  -- Verificar que una llamada falle con un SQLCODE concreto
  ---------------------------------------------------------------------
  PROCEDURE esperar_error(
    p_nombre      IN VARCHAR2,
    p_id_cita    IN NUMBER,
    p_diagnostico IN VARCHAR2,
    p_notas       IN VARCHAR2,
    p_codigo      IN NUMBER
  ) IS
    vn_historia_prueba NUMBER;
    vn_error           NUMBER := 0;
  BEGIN
    BEGIN
      PKG_HISTORIA.registrar_consulta(
        p_id_cita       => p_id_cita,
        p_diagnostico   => p_diagnostico,
        p_notas_medicas => p_notas,
        p_id_historia   => vn_historia_prueba
      );
    EXCEPTION
      WHEN OTHERS THEN
        vn_error := SQLCODE;
    END;

    chk(
      p_nombre,
      vn_error = p_codigo,
      'Esperado ' || p_codigo || ', recibido ' || vn_error
    );
  END esperar_error;

  ---------------------------------------------------------------------
  -- Limpieza de datos temporales
  ---------------------------------------------------------------------
  PROCEDURE limpiar_datos IS
  BEGIN
    DELETE FROM TBL_HISTORIA_CLINICA h
    WHERE h.ID_CITA IN (
      SELECT c.ID_CITA
      FROM TBL_CITAS_MEDICAS c
      WHERE c.ID_PACIENTE IN (
        SELECT p.ID_PACIENTE
        FROM TBL_PACIENTES p
        WHERE p.DOCUMENTO = vc_documento
      )
      OR c.ID_AGENDA IN (
        SELECT a.ID_AGENDA
        FROM TBL_AGENDA_MEDICO a
        WHERE a.FECHA_HORA_INICIO = vd_inicio
      )
    );

    DELETE FROM TBL_CITAS_MEDICAS c
    WHERE c.ID_PACIENTE IN (
      SELECT p.ID_PACIENTE
      FROM TBL_PACIENTES p
      WHERE p.DOCUMENTO = vc_documento
    )
    OR c.ID_AGENDA IN (
      SELECT a.ID_AGENDA
      FROM TBL_AGENDA_MEDICO a
      WHERE a.FECHA_HORA_INICIO = vd_inicio
    );

    DELETE FROM TBL_AGENDA_MEDICO
    WHERE FECHA_HORA_INICIO = vd_inicio;

    DELETE FROM TBL_PACIENTES
    WHERE DOCUMENTO = vc_documento;

    COMMIT;
  END limpiar_datos;

BEGIN
  ---------------------------------------------------------------------
  -- 0. Limpiar restos de una ejecucion anterior
  ---------------------------------------------------------------------
  limpiar_datos;

  ---------------------------------------------------------------------
  -- 1. Verificar package y trigger
  ---------------------------------------------------------------------
  SELECT COUNT(*)
  INTO vn_total
  FROM USER_OBJECTS
  WHERE OBJECT_NAME = 'PKG_HISTORIA'
    AND OBJECT_TYPE IN ('PACKAGE', 'PACKAGE BODY')
    AND STATUS = 'VALID';

  chk('Package y Package Body compilados',
      vn_total = 2,
      'Objetos VALID encontrados: ' || vn_total);

  SELECT COUNT(*)
  INTO vn_total
  FROM USER_TRIGGERS
  WHERE TRIGGER_NAME = 'TRG_HISTORIA_VALIDAR_CITA'
    AND STATUS = 'ENABLED';

  chk('Trigger HU04 habilitado',
      vn_total = 1,
      'Trigger habilitado encontrado: ' || vn_total);

  ---------------------------------------------------------------------
  -- 2. Buscar dos medicos con usuarios activos
  ---------------------------------------------------------------------
  SELECT
    MAX(CASE WHEN rn = 1 THEN ID_MEDICO END),
    MAX(CASE WHEN rn = 1 THEN ID_USUARIO END),
    MAX(CASE WHEN rn = 2 THEN ID_MEDICO END),
    MAX(CASE WHEN rn = 2 THEN ID_USUARIO END)
  INTO
    vn_medico_a,
    vn_usuario_a,
    vn_medico_b,
    vn_usuario_b
  FROM (
    SELECT
      m.ID_MEDICO,
      u.ID_USUARIO,
      ROW_NUMBER() OVER (ORDER BY m.ID_MEDICO) rn
    FROM TBL_MEDICOS m
    JOIN TBL_USUARIOS u
      ON u.ID_ENTIDAD = m.ID_MEDICO
    JOIN TBL_ROLES r
      ON r.ID_ROL = u.ID_ROL
    WHERE UPPER(r.NOMBRE_ROL) = 'MEDICO'
      AND u.ESTADO = 'A'
  );

  chk('Dos medicos activos disponibles',
      vn_medico_a IS NOT NULL AND vn_medico_b IS NOT NULL,
      'Se requieren dos medicos con usuarios activos');

  ---------------------------------------------------------------------
  -- 3. Crear paciente y agenda temporales
  ---------------------------------------------------------------------
  INSERT INTO TBL_PACIENTES (
    DOCUMENTO,
    NOMBRE,
    APELLIDO,
    FECHA_NACIMIENTO,
    EMAIL,
    TELEFONO
  )
  VALUES (
    vc_documento,
    'PACIENTE',
    'PRUEBAS HU03',
    DATE '2000-01-01',
    'hu03test@prueba.local',
    '0000000000'
  )
  RETURNING ID_PACIENTE INTO vn_paciente;

  INSERT INTO TBL_AGENDA_MEDICO (
    ID_MEDICO,
    FECHA_HORA_INICIO,
    FECHA_HORA_FIN,
    ID_ESTADO
  )
  VALUES (
    vn_medico_a,
    vd_inicio,
    vd_inicio + (30 / 1440),
    PKG_CONSTANTES.agenda_libre
  )
  RETURNING ID_AGENDA INTO vn_agenda;

  ---------------------------------------------------------------------
  -- 4. Crear citas de prueba
  ---------------------------------------------------------------------
  crear_cita(PKG_CONSTANTES.cita_pendiente, vn_cita_ok);
  crear_cita(PKG_CONSTANTES.cita_pendiente, vn_cita_notas_null);
  crear_cita(PKG_CONSTANTES.cita_pendiente, vn_cita_otro_medico);
  crear_cita(PKG_CONSTANTES.cita_pendiente, vn_cita_otro_rol);
  crear_cita(PKG_CONSTANTES.cita_cancelada, vn_cita_cancelada);

  -- Confirmar datos de prueba antes de invocar el package,
  -- ya que el package tiene COMMIT / ROLLBACK interno.
  COMMIT;

  ---------------------------------------------------------------------
  -- 5. Registrar consulta correctamente
  ---------------------------------------------------------------------
  ctx(vn_usuario_a, 'MEDICO', vn_medico_a);

  PKG_HISTORIA.registrar_consulta(
    p_id_cita       => vn_cita_ok,
    p_diagnostico   => 'Diagnostico de prueba HU03',
    p_notas_medicas => 'Notas clinicas de prueba HU03',
    p_id_historia   => vn_historia
  );

  SELECT COUNT(*)
  INTO vn_total
  FROM TBL_HISTORIA_CLINICA
  WHERE ID_HISTORIA = vn_historia
    AND ID_CITA = vn_cita_ok
    AND DIAGNOSTICO = 'Diagnostico de prueba HU03'
    AND NOTAS_MEDICAS = 'Notas clinicas de prueba HU03';

  chk('Registro exitoso de historia clinica',
      vn_historia IS NOT NULL AND vn_total = 1,
      'ID_HISTORIA generado: ' || vn_historia);

  SELECT ID_ESTADO
  INTO vn_estado
  FROM TBL_CITAS_MEDICAS
  WHERE ID_CITA = vn_cita_ok;

  chk('La cita queda Finalizada (C3)',
      vn_estado = PKG_CONSTANTES.cita_finalizada,
      'ID_ESTADO obtenido: ' || vn_estado);

  ---------------------------------------------------------------------
  -- 6. Registrar consulta sin notas (NOTAS_MEDICAS es nullable)
  ---------------------------------------------------------------------
  PKG_HISTORIA.registrar_consulta(
    p_id_cita       => vn_cita_notas_null,
    p_diagnostico   => 'Diagnostico sin notas HU03',
    p_notas_medicas => NULL,
    p_id_historia   => vn_historia_null
  );

  SELECT COUNT(*)
  INTO vn_total
  FROM TBL_HISTORIA_CLINICA
  WHERE ID_HISTORIA = vn_historia_null
    AND ID_CITA = vn_cita_notas_null
    AND NOTAS_MEDICAS IS NULL;

  chk('Registro exitoso con notas medicas nulas',
      vn_historia_null IS NOT NULL AND vn_total = 1,
      'Se esperaba NOTAS_MEDICAS NULL');

  ---------------------------------------------------------------------
  -- 7. Validaciones de datos
  ---------------------------------------------------------------------
  esperar_error(
    'ID_CITA nulo',
    NULL,
    'Diagnostico valido',
    NULL,
    -20040
  );

  -- Obtener un ID positivo que no exista en la tabla.
    SELECT NVL(MAX(ID_CITA), 0) + 1
    INTO vn_cita_inexistente
    FROM TBL_CITAS_MEDICAS;

    esperar_error(
    'Cita inexistente',
    vn_cita_inexistente,
    'Diagnostico valido',
    NULL,
    -20041
    );

  esperar_error(
    'Diagnostico nulo',
    vn_cita_otro_rol,
    NULL,
    NULL,
    -20040
  );

  vn_diagnostico_largo := RPAD('X', 1001, 'X');

  esperar_error(
    'Diagnostico supera 1000 caracteres',
    vn_cita_otro_rol,
    vn_diagnostico_largo,
    NULL,
    -20040
  );

  vn_notas_largas := RPAD('X', 4001, 'X');

  esperar_error(
    'Notas medicas superan 4000 caracteres',
    vn_cita_otro_rol,
    'Diagnostico valido',
    vn_notas_largas,
    -20040
  );

  ---------------------------------------------------------------------
  -- 8. Validar rol no autorizado
  ---------------------------------------------------------------------
  ctx(vn_usuario_a, 'PACIENTE', vn_paciente);

  esperar_error(
    'Usuario con rol diferente a MEDICO',
    vn_cita_otro_rol,
    'Diagnostico valido',
    NULL,
    -20042
  );

  ---------------------------------------------------------------------
  -- 9. Validar medico que no es propietario de la cita
  ---------------------------------------------------------------------
  ctx(vn_usuario_b, 'MEDICO', vn_medico_b);

  esperar_error(
    'Medico diferente al propietario de la cita',
    vn_cita_otro_medico,
    'Diagnostico valido',
    NULL,
    -20042
  );

  ---------------------------------------------------------------------
  -- 10. Validar cita cancelada: trigger HU04
  ---------------------------------------------------------------------
  ctx(vn_usuario_a, 'MEDICO', vn_medico_a);

  esperar_error(
    'Cita cancelada rechazada por trigger HU04',
    vn_cita_cancelada,
    'Diagnostico valido',
    NULL,
    -20060
  );

  ---------------------------------------------------------------------
  -- 11. Validar historia duplicada
  --     El trigger HU04 requiere que la cita esté pendiente.
  --     Se cambia temporalmente la cita ya atendida a pendiente,
  --     se confirma ese cambio y se intenta insertar otra historia.
  --     La restriccion UNIQUE debe impedirlo.
  ---------------------------------------------------------------------
  UPDATE TBL_CITAS_MEDICAS
  SET ID_ESTADO = PKG_CONSTANTES.cita_pendiente
  WHERE ID_CITA = vn_cita_ok;

  COMMIT;

  esperar_error(
    'Historia duplicada rechazada por restriccion UNIQUE',
    vn_cita_ok,
    'Diagnostico duplicado HU03',
    NULL,
    -1
  );

  -- Restaurar estado final de la cita temporal.
  UPDATE TBL_CITAS_MEDICAS
  SET ID_ESTADO = PKG_CONSTANTES.cita_finalizada
  WHERE ID_CITA = vn_cita_ok;

  COMMIT;

  ---------------------------------------------------------------------
  -- 12. Verificar que los casos fallidos no dejaron historias
  ---------------------------------------------------------------------
  SELECT COUNT(*)
  INTO vn_total
  FROM TBL_HISTORIA_CLINICA
  WHERE ID_CITA IN (
    vn_cita_otro_medico,
    vn_cita_otro_rol,
    vn_cita_cancelada
  );

  chk('Los casos fallidos no generaron historias',
      vn_total = 0,
      'Historias encontradas: ' || vn_total);

  SELECT ID_ESTADO
  INTO vn_estado
  FROM TBL_CITAS_MEDICAS
  WHERE ID_CITA = vn_cita_cancelada;

  chk('La cita cancelada conserva su estado',
      vn_estado = PKG_CONSTANTES.cita_cancelada,
      'ID_ESTADO obtenido: ' || vn_estado);

  ---------------------------------------------------------------------
  -- 13. Limpiar contexto y datos temporales
  ---------------------------------------------------------------------
  PKG_CONTEXTO.LIMPIAR;

  limpiar_datos;

  ---------------------------------------------------------------------
  -- 14. Resumen
  ---------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('==================== RESUMEN HU03 ====================');
  DBMS_OUTPUT.PUT_LINE('  Pruebas OK    : ' || vn_ok);
  DBMS_OUTPUT.PUT_LINE('  Pruebas FALLO : ' || vn_fallos);

  IF vn_fallos = 0 THEN
    DBMS_OUTPUT.PUT_LINE('  RESULTADO: TODO CORRECTO');
  ELSE
    DBMS_OUTPUT.PUT_LINE('  RESULTADO: HAY FALLOS');
    DBMS_OUTPUT.PUT_LINE('  Revise las lineas FALLO anteriores.');
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    PKG_CONTEXTO.LIMPIAR;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('ERROR DURANTE LAS PRUEBAS: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('Ejecute sql/HU03/limpieza_hu03.sql si quedaron datos.');

    ROLLBACK;
    RAISE;
END;
/

SET FEEDBACK ON

/* ======================= FIN DE PRUEBAS HU03 ======================== */
