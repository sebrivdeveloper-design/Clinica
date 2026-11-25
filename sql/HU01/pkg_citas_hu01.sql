/* =====================================================================
   PKG_CITAS (HU01 + base de HU03) - version unificada
   ---------------------------------------------------------------------
   Ejecutar conectado como PROYECTOPLSQL (F5 en SQL Developer).

   Por que existe esta version:
   El paquete con PRC_RESERVAR_CITA / PRC_FINALIZAR_CITA / FN_FRANJAS_LIBRES
   se creo con CREATE OR REPLACE sobre el MISMO nombre PKG_CITAS y borro los
   procedimientos que el backend (Java) llama. Aqui se conserva toda la
   logica nueva y se agregan los nombres que el backend espera:

     Backend llama                 Implementacion
     ---------------------------   ------------------------------------
     PRO_AGENDA_DISPONIBLE         franjas de 1 h libres de un medico
     PRO_RESERVAR_CITA             valida permisos y delega en PRC_RESERVAR_CITA
     PRO_MIS_CITAS                 citas del paciente (usa HORA_INICIO/FIN reales)
     PRO_LISTAR_MEDICOS            catalogo (GET /api/medicos)
     PRO_LISTAR_PACIENTES          catalogo (GET /api/pacientes)

   Codigos de error: alineados con GlobalExceptionHandler del backend
     -20001 conflicto/ocupado (409)   -20002 no encontrado (404)
     -20005 sin permiso (403)         -20007 estado invalido (409)
     -20008 horario/hora invalida (422)  -20009 paciente con otra cita (422)
   (-20006 se reservaba para credenciales invalidas -> HTTP 401, por eso
    "cita no existe" ya no usa -20006.)
   ===================================================================== */

CREATE OR REPLACE PACKAGE PROYECTOPLSQL.PKG_CITAS AS

  c_duracion_cita CONSTANT NUMBER := 1/24;   -- la cita dura 1 hora

  EXC_MEDICO_OCUPADO      EXCEPTION; PRAGMA EXCEPTION_INIT(EXC_MEDICO_OCUPADO,      -20001);
  EXC_AGENDA_EN_CIRUGIA   EXCEPTION; PRAGMA EXCEPTION_INIT(EXC_AGENDA_EN_CIRUGIA,   -20001);
  EXC_AGENDA_NO_EXISTE    EXCEPTION; PRAGMA EXCEPTION_INIT(EXC_AGENDA_NO_EXISTE,    -20002);
  EXC_PACIENTE_NO_EXISTE  EXCEPTION; PRAGMA EXCEPTION_INIT(EXC_PACIENTE_NO_EXISTE,  -20002);
  EXC_CITA_NO_EXISTE      EXCEPTION; PRAGMA EXCEPTION_INIT(EXC_CITA_NO_EXISTE,      -20002);
  EXC_SIN_PERMISO         EXCEPTION; PRAGMA EXCEPTION_INIT(EXC_SIN_PERMISO,         -20005);
  EXC_CITA_NO_PENDIENTE   EXCEPTION; PRAGMA EXCEPTION_INIT(EXC_CITA_NO_PENDIENTE,   -20007);
  EXC_HORARIO_INVALIDO    EXCEPTION; PRAGMA EXCEPTION_INIT(EXC_HORARIO_INVALIDO,    -20008);
  EXC_FIN_INVALIDO        EXCEPTION; PRAGMA EXCEPTION_INIT(EXC_FIN_INVALIDO,        -20008);
  EXC_PACIENTE_OCUPADO    EXCEPTION; PRAGMA EXCEPTION_INIT(EXC_PACIENTE_OCUPADO,    -20009);

  FUNCTION FN_AHORA RETURN DATE;
  FUNCTION FN_ID_PARAM(p_id_tipo IN VARCHAR2) RETURN NUMBER;

  -- Franjas de 1 hora aun libres de un turno (uso interno / otras HU)
  FUNCTION FN_FRANJAS_LIBRES(p_id_agenda IN NUMBER) RETURN SYS_REFCURSOR;

  -- Reserva sin solapamiento (bloqueo pesimista sobre la agenda)
  PROCEDURE PRC_RESERVAR_CITA(
    p_id_paciente IN  NUMBER,
    p_id_agenda   IN  NUMBER,
    p_hora_inicio IN  DATE,
    p_id_cita     OUT NUMBER);

  -- Finaliza la cita guardando la hora REAL de fin (HU03 la llama con commit 0)
  PROCEDURE PRC_FINALIZAR_CITA(
    p_id_cita  IN NUMBER,
    p_hora_fin IN DATE   DEFAULT NULL,
    p_commit   IN NUMBER DEFAULT 1);

  -- Recalcula Libre/Ocupado del turno (la reutilizara la HU02)
  PROCEDURE PRC_SINCRONIZAR_ESTADO_AGENDA(p_id_agenda IN NUMBER);

  ---------------------------------------------------------------------
  -- API que consume el backend (nombres PRO_*)
  ---------------------------------------------------------------------

  /* GET /api/agenda/disponible?idMedico=
     Una fila por FRANJA libre de 1 h.
     Columnas: ID_AGENDA, ID_MEDICO, FECHA_HORA_INICIO, FECHA_HORA_FIN, ESTADO */
  PROCEDURE PRO_AGENDA_DISPONIBLE(vn_id_medico IN  NUMBER,
                                  vc_agenda    OUT SYS_REFCURSOR);

  /* POST /api/citas
     vd_hora_inicio = inicio de la franja elegida (viene de PRO_AGENDA_DISPONIBLE).
     Si es NULL se reserva la primera franja libre del turno.
     La observacion no se guarda al reservar (acuerdo del equipo: solo al cancelar). */
  PROCEDURE PRO_RESERVAR_CITA(vn_id_paciente  IN  NUMBER,
                              vn_id_agenda    IN  NUMBER,
                              vd_hora_inicio  IN  DATE,
                              vn_id_cita      OUT NUMBER);

  /* GET /api/medicos. Columnas: ID_MEDICO, DOCUMENTO, NOMBRE, ESPECIALIDAD */
  PROCEDURE PRO_LISTAR_MEDICOS(vc_medicos OUT SYS_REFCURSOR);

  /* GET /api/pacientes. Columnas: ID_PACIENTE, DOCUMENTO, NOMBRE */
  PROCEDURE PRO_LISTAR_PACIENTES(vc_pacientes OUT SYS_REFCURSOR);

  /* GET /api/citas/mias. Columnas: ID_CITA, ID_AGENDA, FECHA_HORA_INICIO,
     FECHA_HORA_FIN, ID_MEDICO, MEDICO, ESPECIALIDAD, ESTADO, PUEDE_CANCELAR */
  PROCEDURE PRO_MIS_CITAS(vn_id_paciente IN  NUMBER,
                          vc_citas       OUT SYS_REFCURSOR);

END PKG_CITAS;
/

CREATE OR REPLACE PACKAGE BODY PROYECTOPLSQL.PKG_CITAS AS

  ---------------------------------------------------------------------
  -- "Ahora" del escenario: fecha de referencia + hora real del reloj.
  -- (PKG_CONSTANTES expone la funcion como fecha_sistema, sin prefijo FN_)
  ---------------------------------------------------------------------
  FUNCTION FN_AHORA RETURN DATE IS
  BEGIN
    RETURN TRUNC(PKG_CONSTANTES.fecha_sistema) + (SYSDATE - TRUNC(SYSDATE));
  END FN_AHORA;

  FUNCTION FN_ID_PARAM(p_id_tipo IN VARCHAR2) RETURN NUMBER IS
    v_id NUMBER;
  BEGIN
    SELECT id_param INTO v_id FROM tbl_parametros WHERE id_tipo = p_id_tipo;
    RETURN v_id;
  END FN_ID_PARAM;

  ---------------------------------------------------------------------
  PROCEDURE PRC_SINCRONIZAR_ESTADO_AGENDA(p_id_agenda IN NUMBER) IS
    v_ini      DATE;
    v_fin      DATE;
    v_estado   VARCHAR2(10);
    v_activas  NUMBER;
    v_franjas  NUMBER;
    v_nuevo    NUMBER;
  BEGIN
    SELECT a.fecha_hora_inicio, a.fecha_hora_fin, pe.id_tipo
      INTO v_ini, v_fin, v_estado
      FROM tbl_agenda_medico a
      JOIN tbl_parametros pe ON pe.id_param = a.id_estado
     WHERE a.id_agenda = p_id_agenda;

    IF v_estado = 'A3' THEN      -- En cirugia: no se toca
      RETURN;
    END IF;

    SELECT COUNT(*) INTO v_activas
      FROM tbl_citas_medicas c
      JOIN tbl_parametros pc ON pc.id_param = c.id_estado
     WHERE c.id_agenda = p_id_agenda AND pc.id_tipo <> 'C2';

    v_franjas := ROUND((v_fin - v_ini) * 24);
    v_nuevo   := FN_ID_PARAM(CASE WHEN v_activas >= v_franjas THEN 'A2' ELSE 'A1' END);

    UPDATE tbl_agenda_medico SET id_estado = v_nuevo WHERE id_agenda = p_id_agenda;
  END PRC_SINCRONIZAR_ESTADO_AGENDA;

  ---------------------------------------------------------------------
  FUNCTION FN_FRANJAS_LIBRES(p_id_agenda IN NUMBER) RETURN SYS_REFCURSOR IS
    v_rc    SYS_REFCURSOR;
    v_ahora DATE := FN_AHORA;
  BEGIN
    OPEN v_rc FOR
      SELECT s.id_agenda, s.id_medico, s.hora_inicio, s.hora_fin
        FROM (SELECT a.id_agenda, a.id_medico,
                     a.fecha_hora_inicio + (LEVEL - 1) / 24 AS hora_inicio,
                     a.fecha_hora_inicio +  LEVEL      / 24 AS hora_fin
                FROM tbl_agenda_medico a
                JOIN tbl_parametros pe ON pe.id_param = a.id_estado
               WHERE a.id_agenda = p_id_agenda
                 AND pe.id_tipo <> 'A3'
             CONNECT BY LEVEL <= ROUND((a.fecha_hora_fin - a.fecha_hora_inicio) * 24)) s
       WHERE s.hora_inicio >= v_ahora
         AND NOT EXISTS (
               SELECT 1
                 FROM tbl_citas_medicas c
                 JOIN tbl_agenda_medico ca ON ca.id_agenda = c.id_agenda
                 JOIN tbl_parametros pc    ON pc.id_param  = c.id_estado
                WHERE ca.id_medico = s.id_medico
                  AND pc.id_tipo  <> 'C2'
                  AND c.hora_inicio < s.hora_fin
                  AND s.hora_inicio < c.hora_fin)
       ORDER BY s.hora_inicio;
    RETURN v_rc;
  END FN_FRANJAS_LIBRES;

  ---------------------------------------------------------------------
  PROCEDURE PRC_RESERVAR_CITA(
    p_id_paciente IN  NUMBER,
    p_id_agenda   IN  NUMBER,
    p_hora_inicio IN  DATE,
    p_id_cita     OUT NUMBER) IS

    v_dummy     NUMBER;
    v_medico    NUMBER;
    v_ag_ini    DATE;
    v_ag_fin    DATE;
    v_ag_estado VARCHAR2(10);
    v_ini       DATE := TRUNC(p_hora_inicio, 'MI');
    v_fin       DATE;
    v_n         NUMBER;
    e_bloqueado EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_bloqueado, -30006);   -- recurso ocupado (WAIT vencido)
  BEGIN
    v_fin := v_ini + c_duracion_cita;

    -- 1. Paciente: se bloquea su fila para que no tenga dos reservas simultaneas
    BEGIN
      SELECT id_paciente INTO v_dummy
        FROM tbl_pacientes WHERE id_paciente = p_id_paciente FOR UPDATE;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'El paciente ' || p_id_paciente || ' no existe');
    END;

    -- 2. Bloqueo pesimista del turno del medico (HU01)
    BEGIN
      SELECT a.id_medico, a.fecha_hora_inicio, a.fecha_hora_fin, pe.id_tipo
        INTO v_medico, v_ag_ini, v_ag_fin, v_ag_estado
        FROM tbl_agenda_medico a
        JOIN tbl_parametros pe ON pe.id_param = a.id_estado
       WHERE a.id_agenda = p_id_agenda
         FOR UPDATE OF a.id_agenda WAIT 10;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'La agenda ' || p_id_agenda || ' no existe');
      WHEN e_bloqueado THEN
        RAISE_APPLICATION_ERROR(-20001, 'El bloque del medico esta siendo reservado por otro usuario');
    END;

    -- 3. Estado del turno
    IF v_ag_estado = 'A3' THEN
      RAISE_APPLICATION_ERROR(-20001, 'El medico esta en cirugia en este turno');
    ELSIF v_ag_estado = 'A2' THEN
      RAISE_APPLICATION_ERROR(-20001, 'El turno del medico ya esta completamente ocupado');
    END IF;

    -- 4. La cita debe quedar dentro del turno, en la grilla de 1 hora y a futuro
    IF v_ini < v_ag_ini OR v_fin > v_ag_fin THEN
      RAISE_APPLICATION_ERROR(-20008, 'La hora esta fuera del turno del medico');
    END IF;
    IF MOD(ROUND((v_ini - v_ag_ini) * 1440), 60) <> 0 THEN
      RAISE_APPLICATION_ERROR(-20008, 'La cita debe iniciar en punto dentro del turno (bloques de 1 hora)');
    END IF;
    IF v_ini < FN_AHORA THEN
      RAISE_APPLICATION_ERROR(-20008, 'No se puede reservar en el pasado');
    END IF;

    -- 5. Cruce con otra cita activa del MEDICO
    SELECT COUNT(*) INTO v_n
      FROM tbl_citas_medicas c
      JOIN tbl_agenda_medico a ON a.id_agenda = c.id_agenda
      JOIN tbl_parametros pc   ON pc.id_param = c.id_estado
     WHERE a.id_medico = v_medico
       AND pc.id_tipo <> 'C2'
       AND c.hora_inicio < v_fin
       AND v_ini < c.hora_fin;
    IF v_n > 0 THEN
      RAISE_APPLICATION_ERROR(-20001, 'El medico ya tiene una cita en ese horario');
    END IF;

    -- 6. Cruce con otra cita activa del PACIENTE
    SELECT COUNT(*) INTO v_n
      FROM tbl_citas_medicas c
      JOIN tbl_parametros pc ON pc.id_param = c.id_estado
     WHERE c.id_paciente = p_id_paciente
       AND pc.id_tipo <> 'C2'
       AND c.hora_inicio < v_fin
       AND v_ini < c.hora_fin;
    IF v_n > 0 THEN
      RAISE_APPLICATION_ERROR(-20009, 'El paciente ya tiene una cita en ese horario');
    END IF;

    -- 7. Registrar la cita (Pendiente) y actualizar el turno
    INSERT INTO tbl_citas_medicas
           (id_paciente, id_agenda, fecha_registro, hora_inicio, hora_fin, id_estado)
    VALUES (p_id_paciente, p_id_agenda, FN_AHORA, v_ini, v_fin, FN_ID_PARAM('C1'))
    RETURNING id_cita INTO p_id_cita;

    PRC_SINCRONIZAR_ESTADO_AGENDA(p_id_agenda);

    COMMIT;   -- libera los bloqueos
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END PRC_RESERVAR_CITA;

  ---------------------------------------------------------------------
  PROCEDURE PRC_FINALIZAR_CITA(
    p_id_cita  IN NUMBER,
    p_hora_fin IN DATE   DEFAULT NULL,
    p_commit   IN NUMBER DEFAULT 1) IS

    v_ini     DATE;
    v_ag_fin  DATE;
    v_estado  VARCHAR2(10);
    v_fin     DATE;
  BEGIN
    BEGIN
      SELECT c.hora_inicio, a.fecha_hora_fin, pe.id_tipo
        INTO v_ini, v_ag_fin, v_estado
        FROM tbl_citas_medicas c
        JOIN tbl_agenda_medico a ON a.id_agenda = c.id_agenda
        JOIN tbl_parametros pe   ON pe.id_param = c.id_estado
       WHERE c.id_cita = p_id_cita
         FOR UPDATE OF c.id_cita;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'La cita ' || p_id_cita || ' no existe');
    END;

    IF v_estado <> 'C1' THEN
      RAISE_APPLICATION_ERROR(-20007, 'Solo se puede finalizar una cita Pendiente');
    END IF;

    -- hora real de fin (sin segundos), sin pasar del fin del turno
    v_fin := LEAST(TRUNC(NVL(p_hora_fin, FN_AHORA), 'MI'), v_ag_fin);

    IF v_fin <= v_ini THEN
      RAISE_APPLICATION_ERROR(-20008, 'La hora de fin debe ser posterior al inicio de la cita');
    END IF;

    UPDATE tbl_citas_medicas
       SET hora_fin  = v_fin,
           id_estado = FN_ID_PARAM('C3')
     WHERE id_cita = p_id_cita;

    IF p_commit = 1 THEN
      COMMIT;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      IF p_commit = 1 THEN ROLLBACK; END IF;
      RAISE;
  END PRC_FINALIZAR_CITA;

  ---------------------------------------------------------------------
  -- PRO_AGENDA_DISPONIBLE  (GET /api/agenda/disponible)
  ---------------------------------------------------------------------
  PROCEDURE PRO_AGENDA_DISPONIBLE(vn_id_medico IN  NUMBER,
                                  vc_agenda    OUT SYS_REFCURSOR) IS
    va_rol     VARCHAR2(50) := PKG_CONTEXTO.FN_rol;
    vn_existe  NUMBER;
    vd_ahora   DATE         := FN_AHORA;
  BEGIN
    IF PKG_CONTEXTO.FN_id_usuario IS NULL
       OR NVL(va_rol, '?') NOT IN ('ADMINISTRADOR', 'MEDICO',
                                   'RECEPCIONISTA', 'PACIENTE') THEN
      RAISE_APPLICATION_ERROR(-20005, 'No tiene permiso para consultar la agenda');
    END IF;

    IF va_rol = 'MEDICO'
       AND NVL(PKG_CONTEXTO.FN_id_entidad, -1) <> NVL(vn_id_medico, -2) THEN
      RAISE_APPLICATION_ERROR(-20005, 'Un medico solo puede consultar su propia agenda');
    END IF;

    SELECT COUNT(*) INTO vn_existe FROM TBL_MEDICOS WHERE ID_MEDICO = vn_id_medico;
    IF vn_existe = 0 THEN
      RAISE_APPLICATION_ERROR(-20002, 'No se encontro el medico solicitado');
    END IF;

    OPEN vc_agenda FOR
      SELECT s.id_agenda,
             s.id_medico,
             s.hora_inicio AS fecha_hora_inicio,
             s.hora_fin    AS fecha_hora_fin,
             'Libre'       AS estado
        FROM (SELECT a.id_agenda, a.id_medico,
                     a.fecha_hora_inicio + (n.lvl - 1) / 24 AS hora_inicio,
                     a.fecha_hora_inicio +  n.lvl      / 24 AS hora_fin
                FROM tbl_agenda_medico a
                JOIN tbl_parametros pe ON pe.id_param = a.id_estado
                JOIN (SELECT LEVEL AS lvl FROM dual CONNECT BY LEVEL <= 48) n
                  ON n.lvl <= ROUND((a.fecha_hora_fin - a.fecha_hora_inicio) * 24)
               WHERE a.id_medico = vn_id_medico
                 AND pe.id_tipo <> 'A3') s
       WHERE s.hora_inicio >= vd_ahora
         AND NOT EXISTS (
               SELECT 1
                 FROM tbl_citas_medicas c
                 JOIN tbl_agenda_medico ca ON ca.id_agenda = c.id_agenda
                 JOIN tbl_parametros pc    ON pc.id_param  = c.id_estado
                WHERE ca.id_medico = s.id_medico
                  AND pc.id_tipo  <> 'C2'
                  AND c.hora_inicio < s.hora_fin
                  AND s.hora_inicio < c.hora_fin)
       ORDER BY s.hora_inicio;
  END PRO_AGENDA_DISPONIBLE;

  ---------------------------------------------------------------------
  -- PRO_RESERVAR_CITA  (POST /api/citas)
  ---------------------------------------------------------------------
  PROCEDURE PRO_RESERVAR_CITA(vn_id_paciente  IN  NUMBER,
                              vn_id_agenda    IN  NUMBER,
                              vd_hora_inicio  IN  DATE,
                              vn_id_cita      OUT NUMBER) IS
    va_rol    VARCHAR2(50) := PKG_CONTEXTO.FN_rol;
    vd_hora   DATE         := vd_hora_inicio;
    vc_franjas SYS_REFCURSOR;
    vn_a      NUMBER;
    vn_m      NUMBER;
    vd_fin    DATE;
  BEGIN
    -- Reservan ADMINISTRADOR, RECEPCIONISTA y PACIENTE (este solo a su nombre)
    IF PKG_CONTEXTO.FN_id_usuario IS NULL
       OR NVL(va_rol, '?') NOT IN ('ADMINISTRADOR', 'RECEPCIONISTA', 'PACIENTE') THEN
      RAISE_APPLICATION_ERROR(-20005, 'No tiene permiso para reservar citas');
    END IF;

    IF va_rol = 'PACIENTE'
       AND NVL(PKG_CONTEXTO.FN_id_entidad, -1) <> NVL(vn_id_paciente, -2) THEN
      RAISE_APPLICATION_ERROR(-20005, 'Un paciente solo puede reservar citas a su nombre');
    END IF;

    -- Sin hora: se toma la primera franja libre del turno
    IF vd_hora IS NULL THEN
      vc_franjas := FN_FRANJAS_LIBRES(vn_id_agenda);
      FETCH vc_franjas INTO vn_a, vn_m, vd_hora, vd_fin;
      IF vc_franjas%NOTFOUND THEN
        CLOSE vc_franjas;
        RAISE_APPLICATION_ERROR(-20001, 'El turno del medico no tiene franjas libres');
      END IF;
      CLOSE vc_franjas;
    END IF;

    PRC_RESERVAR_CITA(vn_id_paciente, vn_id_agenda, vd_hora, vn_id_cita);
  END PRO_RESERVAR_CITA;

  ---------------------------------------------------------------------
  -- PRO_LISTAR_MEDICOS  (GET /api/medicos)
  ---------------------------------------------------------------------
  PROCEDURE PRO_LISTAR_MEDICOS(vc_medicos OUT SYS_REFCURSOR) IS
  BEGIN
    IF PKG_CONTEXTO.FN_id_usuario IS NULL
       OR NVL(PKG_CONTEXTO.FN_rol, '?') NOT IN ('ADMINISTRADOR', 'MEDICO',
                                                'RECEPCIONISTA', 'PACIENTE') THEN
      RAISE_APPLICATION_ERROR(-20005, 'No tiene permiso para consultar los medicos');
    END IF;

    OPEN vc_medicos FOR
      SELECT m.ID_MEDICO,
             m.DOCUMENTO,
             m.NOMBRE || ' ' || m.APELLIDO AS NOMBRE,
             p.VALOR                       AS ESPECIALIDAD
      FROM   TBL_MEDICOS    m
      JOIN   TBL_PARAMETROS p ON p.ID_PARAM = m.ID_ESPECIALIDAD
      ORDER  BY m.NOMBRE, m.APELLIDO;
  END PRO_LISTAR_MEDICOS;

  ---------------------------------------------------------------------
  -- PRO_LISTAR_PACIENTES  (GET /api/pacientes)
  ---------------------------------------------------------------------
  PROCEDURE PRO_LISTAR_PACIENTES(vc_pacientes OUT SYS_REFCURSOR) IS
  BEGIN
    IF PKG_CONTEXTO.FN_id_usuario IS NULL
       OR NVL(PKG_CONTEXTO.FN_rol, '?') NOT IN ('ADMINISTRADOR', 'RECEPCIONISTA') THEN
      RAISE_APPLICATION_ERROR(-20005, 'No tiene permiso para consultar los pacientes');
    END IF;

    OPEN vc_pacientes FOR
      SELECT ID_PACIENTE,
             DOCUMENTO,
             NOMBRE || ' ' || APELLIDO AS NOMBRE
      FROM   TBL_PACIENTES
      ORDER  BY NOMBRE, APELLIDO;
  END PRO_LISTAR_PACIENTES;

  ---------------------------------------------------------------------
  -- PRO_MIS_CITAS  (GET /api/citas/mias)
  ---------------------------------------------------------------------
  PROCEDURE PRO_MIS_CITAS(vn_id_paciente IN  NUMBER,
                          vc_citas       OUT SYS_REFCURSOR) IS
    va_rol        VARCHAR2(50) := PKG_CONTEXTO.FN_rol;
    vn_paciente   NUMBER;
    vn_pendiente  NUMBER       := PKG_CONSTANTES.cita_pendiente;
    vd_ahora      DATE         := FN_AHORA;
  BEGIN
    IF PKG_CONTEXTO.FN_id_usuario IS NULL
       OR NVL(va_rol, '?') NOT IN ('ADMINISTRADOR', 'RECEPCIONISTA', 'PACIENTE') THEN
      RAISE_APPLICATION_ERROR(-20005, 'No tiene permiso para consultar citas de pacientes');
    END IF;

    IF va_rol = 'PACIENTE' THEN
      vn_paciente := PKG_CONTEXTO.FN_id_entidad;
    ELSE
      vn_paciente := vn_id_paciente;
    END IF;

    IF vn_paciente IS NULL THEN
      RAISE_APPLICATION_ERROR(-20002, 'Indique el paciente cuyas citas desea consultar');
    END IF;

    OPEN vc_citas FOR
      SELECT c.ID_CITA,
             a.ID_AGENDA,
             c.HORA_INICIO                 AS FECHA_HORA_INICIO,
             c.HORA_FIN                    AS FECHA_HORA_FIN,
             m.ID_MEDICO,
             m.NOMBRE || ' ' || m.APELLIDO AS MEDICO,
             e.VALOR                       AS ESPECIALIDAD,
             s.VALOR                       AS ESTADO,
             CASE WHEN c.ID_ESTADO = vn_pendiente
                   AND c.HORA_INICIO >= vd_ahora
                  THEN 'S' ELSE 'N' END    AS PUEDE_CANCELAR
      FROM   TBL_CITAS_MEDICAS c
      JOIN   TBL_AGENDA_MEDICO a ON a.ID_AGENDA = c.ID_AGENDA
      JOIN   TBL_MEDICOS       m ON m.ID_MEDICO = a.ID_MEDICO
      JOIN   TBL_PARAMETROS    e ON e.ID_PARAM  = m.ID_ESPECIALIDAD
      JOIN   TBL_PARAMETROS    s ON s.ID_PARAM  = c.ID_ESTADO
      WHERE  c.ID_PACIENTE = vn_paciente
      ORDER  BY c.HORA_INICIO DESC;
  END PRO_MIS_CITAS;

END PKG_CITAS;
/
SHOW ERRORS PACKAGE PROYECTOPLSQL.PKG_CITAS
SHOW ERRORS PACKAGE BODY PROYECTOPLSQL.PKG_CITAS