/* =====================================================================
   PROYECTO PL/SQL - SISTEMA DE GESTION DE CITAS MEDICAS
   PKG_CITAS - HU01: Reserva de citas sin solapamiento
   ---------------------------------------------------------------------
   Ejecucion : conectado como PROYECTOPLSQL, con F5 (Ejecutar script).
   Requisito : tablas con datos, PKG_CONSTANTES y PKG_CONTEXTO creados.
   Contenido :
     - EXC_MEDICO_OCUPADO (ORA-20001), pedida por la HU01
     - PRO_AGENDA_DISPONIBLE : bloques libres de un medico (SYS_REFCURSOR)
         -> GET /api/agenda/disponible?idMedico=
     - PRO_RESERVAR_CITA     : reserva con bloqueo pesimista
         -> POST /api/citas  { idPaciente, idAgenda, observacion? }
     - PRO_CITAS_MEDICO      : citas pendientes del medico en sesion para un
         dia (pantalla "Registrar consulta", sin digitar el numero de cita)
         -> GET /api/citas/medico?fecha=yyyy-MM-dd
     - PRO_LISTAR_MEDICOS    : medicos con su especialidad (para elegir en
         la agenda sin digitar ids)           -> GET /api/medicos
     - PRO_LISTAR_PACIENTES  : pacientes (solo ADMIN y RECEPCIONISTA)
                                              -> GET /api/pacientes
     - PRO_MIS_CITAS         : citas del paciente en sesion (o de un paciente
         si es ADMIN/RECEPCIONISTA)           -> GET /api/citas/mias
   ---------------------------------------------------------------------
   Codigos de error (los mismos del README del proyecto):
     -20001 medico ocupado         -20002 registro no encontrado
     -20005 sin permiso            -20008 horario que ya paso
     -20009 paciente con otra cita en ese horario
   Regla de oro: cada procedimiento de escritura termina con COMMIT
   (Java no confirma; con auto-commit=false el pool revierte si falta).
   ---------------------------------------------------------------------
   Fuera de alcance por ahora: HU02 (PRO_CANCELAR_CITA) y siguientes.
   ===================================================================== */

CREATE OR REPLACE PACKAGE PKG_CITAS AS

  /* HU01: se lanza cuando el bloque de agenda ya no esta libre.
     Se enlaza al codigo -20001 para que el backend la traduzca a HTTP 409. */
  EXC_MEDICO_OCUPADO EXCEPTION;
  PRAGMA EXCEPTION_INIT(EXC_MEDICO_OCUPADO, -20001);

  /* Bloques LIBRES de un medico desde la fecha de referencia del sistema.
     Columnas del cursor: ID_AGENDA, ID_MEDICO, FECHA_HORA_INICIO,
     FECHA_HORA_FIN, ESTADO (el backend las pasa a camelCase). */
  PROCEDURE PRO_AGENDA_DISPONIBLE(vn_id_medico IN  NUMBER,
                                  vc_agenda    OUT SYS_REFCURSOR);

  /* Reserva una cita. Bloquea la fila de la agenda con FOR UPDATE, valida,
     marca el bloque como OCUPADO, crea la cita PENDIENTE y hace COMMIT.
     Devuelve el id de la cita creada. */
  PROCEDURE PRO_RESERVAR_CITA(vn_id_paciente IN  NUMBER,
                              vn_id_agenda   IN  NUMBER,
                              va_observacion IN  VARCHAR2,
                              vn_id_cita     OUT NUMBER);

  /* Citas PENDIENTES del medico en sesion para un dia (si vd_fecha es NULL
     usa la fecha de referencia del sistema). Siempre filtra por el id del
     medico del contexto, asi nunca ve citas de otro medico.
     Columnas: ID_CITA, ID_AGENDA, FECHA_HORA_INICIO, FECHA_HORA_FIN,
     ID_PACIENTE, DOCUMENTO, PACIENTE, TIENE_HISTORIA ('S'/'N'). */
  PROCEDURE PRO_CITAS_MEDICO(vd_fecha IN  DATE,
                             vc_citas OUT SYS_REFCURSOR);

  /* Medicos con su especialidad. Columnas: ID_MEDICO, DOCUMENTO, NOMBRE,
     ESPECIALIDAD. Lo ven ADMIN, RECEPCIONISTA, PACIENTE y MEDICO. */
  PROCEDURE PRO_LISTAR_MEDICOS(vc_medicos OUT SYS_REFCURSOR);

  /* Pacientes. Columnas: ID_PACIENTE, DOCUMENTO, NOMBRE. Solo ADMIN y
     RECEPCIONISTA (el paciente no puede ver a los demas). */
  PROCEDURE PRO_LISTAR_PACIENTES(vc_pacientes OUT SYS_REFCURSOR);

  /* Citas de un paciente. El PACIENTE solo ve las suyas (ignora el
     parametro); ADMIN y RECEPCIONISTA envian el id del paciente.
     Columnas: ID_CITA, ID_AGENDA, FECHA_HORA_INICIO, FECHA_HORA_FIN,
     ID_MEDICO, MEDICO, ESPECIALIDAD, ESTADO, PUEDE_CANCELAR ('S'/'N'). */
  PROCEDURE PRO_MIS_CITAS(vn_id_paciente IN  NUMBER,
                          vc_citas       OUT SYS_REFCURSOR);

END PKG_CITAS;
/

CREATE OR REPLACE PACKAGE BODY PKG_CITAS AS

  -- ORA-30006: se agoto la espera del FOR UPDATE WAIT. Para el usuario
  -- significa lo mismo: otra reserva esta tomando ese bloque.
  EXC_BLOQUEO_TIMEOUT EXCEPTION;
  PRAGMA EXCEPTION_INIT(EXC_BLOQUEO_TIMEOUT, -30006);

  ---------------------------------------------------------------------
  -- PRO_AGENDA_DISPONIBLE
  ---------------------------------------------------------------------
  PROCEDURE PRO_AGENDA_DISPONIBLE(vn_id_medico IN  NUMBER,
                                  vc_agenda    OUT SYS_REFCURSOR) IS

    va_rol     VARCHAR2(50) := PKG_CONTEXTO.FN_rol;
    vn_existe  NUMBER;
    vn_libre   NUMBER       := PKG_CONSTANTES.agenda_libre;
    vd_hoy     DATE         := PKG_CONSTANTES.fecha_sistema;

  BEGIN
    -- Solo roles que ven la agenda (el farmaceutico no)
    IF PKG_CONTEXTO.FN_id_usuario IS NULL
       OR NVL(va_rol, '?') NOT IN ('ADMINISTRADOR', 'MEDICO',
                                   'RECEPCIONISTA', 'PACIENTE') THEN
      RAISE_APPLICATION_ERROR(-20005, 'No tiene permiso para consultar la agenda');
    END IF;

    -- Un medico solo consulta su propia agenda
    IF va_rol = 'MEDICO'
       AND NVL(PKG_CONTEXTO.FN_id_entidad, -1) <> NVL(vn_id_medico, -2) THEN
      RAISE_APPLICATION_ERROR(-20005, 'Un medico solo puede consultar su propia agenda');
    END IF;

    SELECT COUNT(*) INTO vn_existe
    FROM   TBL_MEDICOS
    WHERE  ID_MEDICO = vn_id_medico;

    IF vn_existe = 0 THEN
      RAISE_APPLICATION_ERROR(-20002, 'No se encontro el medico solicitado');
    END IF;

    OPEN vc_agenda FOR
      SELECT a.ID_AGENDA,
             a.ID_MEDICO,
             a.FECHA_HORA_INICIO,
             a.FECHA_HORA_FIN,
             p.VALOR AS ESTADO
      FROM   TBL_AGENDA_MEDICO a
      JOIN   TBL_PARAMETROS    p ON p.ID_PARAM = a.ID_ESTADO
      WHERE  a.ID_MEDICO         = vn_id_medico
      AND    a.ID_ESTADO         = vn_libre
      AND    a.FECHA_HORA_INICIO >= vd_hoy
      ORDER  BY a.FECHA_HORA_INICIO;

    -- Solo lectura: no hay COMMIT.
  END PRO_AGENDA_DISPONIBLE;

  ---------------------------------------------------------------------
  -- PRO_RESERVAR_CITA
  ---------------------------------------------------------------------
  PROCEDURE PRO_RESERVAR_CITA(vn_id_paciente IN  NUMBER,
                              vn_id_agenda   IN  NUMBER,
                              va_observacion IN  VARCHAR2,
                              vn_id_cita     OUT NUMBER) IS

    va_rol            VARCHAR2(50) := PKG_CONTEXTO.FN_rol;
    vn_libre          NUMBER       := PKG_CONSTANTES.agenda_libre;
    vn_ocupada        NUMBER       := PKG_CONSTANTES.agenda_ocupada;
    vn_pendiente      NUMBER       := PKG_CONSTANTES.cita_pendiente;
    vd_hoy            DATE         := PKG_CONSTANTES.fecha_sistema;

    vn_existe         NUMBER;
    vd_inicio         DATE;
    vd_fin            DATE;
    vn_estado_agenda  NUMBER;
    vn_cruces         NUMBER;

  BEGIN
    ----------------------------------------------------------------
    -- 1. Permisos: reservan ADMINISTRADOR, RECEPCIONISTA, MEDICO y PACIENTE.
    --    Solo el paciente esta limitado a reservar a su propio nombre.
    --    El FARMACEUTICO no agenda citas.
    ----------------------------------------------------------------
    IF PKG_CONTEXTO.FN_id_usuario IS NULL
       OR NVL(va_rol, '?') NOT IN ('ADMINISTRADOR', 'RECEPCIONISTA', 'MEDICO', 'PACIENTE') THEN
      RAISE_APPLICATION_ERROR(-20005, 'No tiene permiso para reservar citas');
    END IF;

    IF va_rol = 'PACIENTE'
       AND NVL(PKG_CONTEXTO.FN_id_entidad, -1) <> NVL(vn_id_paciente, -2) THEN
      RAISE_APPLICATION_ERROR(-20005, 'Un paciente solo puede reservar citas a su nombre');
    END IF;

    ----------------------------------------------------------------
    -- 2. El paciente debe existir
    ----------------------------------------------------------------
    SELECT COUNT(*) INTO vn_existe
    FROM   TBL_PACIENTES
    WHERE  ID_PACIENTE = vn_id_paciente;

    IF vn_existe = 0 THEN
      RAISE_APPLICATION_ERROR(-20002, 'No se encontro el paciente solicitado');
    END IF;

    ----------------------------------------------------------------
    -- 3. BLOQUEO PESIMISTA: se bloquea la fila del bloque de agenda.
    --    Si otra sesion la tiene bloqueada, esta espera hasta 5 s;
    --    cuando la otra confirma, aqui se lee el estado ya actualizado
    --    y el bloque aparece ocupado.
    ----------------------------------------------------------------
    BEGIN
      SELECT a.FECHA_HORA_INICIO, a.FECHA_HORA_FIN, a.ID_ESTADO
      INTO   vd_inicio, vd_fin, vn_estado_agenda
      FROM   TBL_AGENDA_MEDICO a
      WHERE  a.ID_AGENDA = vn_id_agenda
      FOR UPDATE WAIT 5;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'No se encontro el bloque de agenda solicitado');
    END;

    ----------------------------------------------------------------
    -- 4. El bloque debe estar libre (ocupado o en cirugia = no)
    ----------------------------------------------------------------
    IF vn_estado_agenda <> vn_libre THEN
      RAISE EXC_MEDICO_OCUPADO;
    END IF;

    ----------------------------------------------------------------
    -- 5. No se reserva un horario anterior a la fecha de referencia
    ----------------------------------------------------------------
    IF vd_inicio < vd_hoy THEN
      RAISE_APPLICATION_ERROR(-20008, 'No se puede reservar un horario que ya paso');
    END IF;

    ----------------------------------------------------------------
    -- 6. El paciente no puede tener otra cita pendiente que se cruce
    ----------------------------------------------------------------
    SELECT COUNT(*) INTO vn_cruces
    FROM   TBL_CITAS_MEDICAS c
    JOIN   TBL_AGENDA_MEDICO ag ON ag.ID_AGENDA = c.ID_AGENDA
    WHERE  c.ID_PACIENTE = vn_id_paciente
    AND    c.ID_ESTADO   = vn_pendiente
    AND    ag.FECHA_HORA_INICIO < vd_fin
    AND    ag.FECHA_HORA_FIN    > vd_inicio;

    IF vn_cruces > 0 THEN
      RAISE_APPLICATION_ERROR(-20009, 'El paciente ya tiene una cita pendiente en ese horario');
    END IF;

    ----------------------------------------------------------------
    -- 7. Misma unidad de trabajo: ocupar el bloque y crear la cita
    ----------------------------------------------------------------
    UPDATE TBL_AGENDA_MEDICO
    SET    ID_ESTADO = vn_ocupada
    WHERE  ID_AGENDA = vn_id_agenda;

    INSERT INTO TBL_CITAS_MEDICAS (ID_PACIENTE, ID_AGENDA, ID_ESTADO)
    VALUES (vn_id_paciente, vn_id_agenda, vn_pendiente)
    RETURNING ID_CITA INTO vn_id_cita;

    ----------------------------------------------------------------
    -- 8. Trazabilidad (la tabla de citas no tiene columna de observacion,
    --    por eso va al log junto con el usuario de la aplicacion)
    ----------------------------------------------------------------
    INSERT INTO TBL_LOG_AUDITORIA
           (USUARIO_APLICACION, ACCION, TABLA_AFECTADA, ID_REGISTRO,
            VALORES_NUEVOS, OBSERVACIONES)
    VALUES (NVL((SELECT USERNAME FROM TBL_USUARIOS
                 WHERE  ID_USUARIO = PKG_CONTEXTO.FN_id_usuario), USER),
            'INSERT', 'TBL_CITAS_MEDICAS', vn_id_cita,
            'ID_PACIENTE=' || vn_id_paciente || '; ID_AGENDA=' || vn_id_agenda
              || '; ESTADO=PENDIENTE',
            SUBSTR(va_observacion, 1, 4000));

    COMMIT;

  EXCEPTION
    WHEN EXC_MEDICO_OCUPADO OR EXC_BLOQUEO_TIMEOUT THEN
      ROLLBACK;
      RAISE_APPLICATION_ERROR(-20001, 'El medico ya tiene ocupado ese horario');
    WHEN OTHERS THEN
      ROLLBACK;   -- libera el bloqueo y deja la conexion limpia
      RAISE;      -- conserva el codigo -200xx original
  END PRO_RESERVAR_CITA;

  ---------------------------------------------------------------------
  -- PRO_CITAS_MEDICO
  ---------------------------------------------------------------------
  PROCEDURE PRO_CITAS_MEDICO(vd_fecha IN  DATE,
                             vc_citas OUT SYS_REFCURSOR) IS

    vn_pendiente  NUMBER := PKG_CONSTANTES.cita_pendiente;
    vd_dia        DATE   := TRUNC(NVL(vd_fecha, PKG_CONSTANTES.fecha_sistema));

  BEGIN
    -- Solo el medico; y debe tener su id de medico en el contexto
    IF PKG_CONTEXTO.FN_id_usuario IS NULL
       OR NVL(PKG_CONTEXTO.FN_rol, '?') <> 'MEDICO'
       OR PKG_CONTEXTO.FN_id_entidad IS NULL THEN
      RAISE_APPLICATION_ERROR(-20005, 'Solo un medico puede consultar sus citas del dia');
    END IF;

    OPEN vc_citas FOR
      SELECT c.ID_CITA,
             a.ID_AGENDA,
             a.FECHA_HORA_INICIO,
             a.FECHA_HORA_FIN,
             p.ID_PACIENTE,
             p.DOCUMENTO,
             p.NOMBRE || ' ' || p.APELLIDO AS PACIENTE,
             CASE WHEN EXISTS (SELECT 1 FROM TBL_HISTORIA_CLINICA h
                               WHERE  h.ID_CITA = c.ID_CITA)
                  THEN 'S' ELSE 'N' END AS TIENE_HISTORIA
      FROM   TBL_CITAS_MEDICAS c
      JOIN   TBL_AGENDA_MEDICO a ON a.ID_AGENDA   = c.ID_AGENDA
      JOIN   TBL_PACIENTES     p ON p.ID_PACIENTE = c.ID_PACIENTE
      WHERE  a.ID_MEDICO          = PKG_CONTEXTO.FN_id_entidad
      AND    c.ID_ESTADO          = vn_pendiente
      AND    a.FECHA_HORA_INICIO >= vd_dia
      AND    a.FECHA_HORA_INICIO <  vd_dia + 1
      ORDER  BY a.FECHA_HORA_INICIO;

    -- Solo lectura: no hay COMMIT.
  END PRO_CITAS_MEDICO;

  ---------------------------------------------------------------------
  -- PRO_LISTAR_MEDICOS
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
  -- PRO_LISTAR_PACIENTES
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
  -- PRO_MIS_CITAS
  ---------------------------------------------------------------------
  PROCEDURE PRO_MIS_CITAS(vn_id_paciente IN  NUMBER,
                          vc_citas       OUT SYS_REFCURSOR) IS

    va_rol        VARCHAR2(50) := PKG_CONTEXTO.FN_rol;
    vn_paciente   NUMBER;
    vn_pendiente  NUMBER       := PKG_CONSTANTES.cita_pendiente;
    vd_hoy        DATE         := PKG_CONSTANTES.fecha_sistema;

  BEGIN
    IF PKG_CONTEXTO.FN_id_usuario IS NULL
       OR NVL(va_rol, '?') NOT IN ('ADMINISTRADOR', 'RECEPCIONISTA', 'PACIENTE') THEN
      RAISE_APPLICATION_ERROR(-20005, 'No tiene permiso para consultar citas de pacientes');
    END IF;

    -- El paciente solo ve las suyas; los demas roles indican de quien
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
             a.FECHA_HORA_INICIO,
             a.FECHA_HORA_FIN,
             m.ID_MEDICO,
             m.NOMBRE || ' ' || m.APELLIDO AS MEDICO,
             e.VALOR                       AS ESPECIALIDAD,
             s.VALOR                       AS ESTADO,
             CASE WHEN c.ID_ESTADO = vn_pendiente
                   AND a.FECHA_HORA_INICIO >= vd_hoy
                  THEN 'S' ELSE 'N' END    AS PUEDE_CANCELAR
      FROM   TBL_CITAS_MEDICAS c
      JOIN   TBL_AGENDA_MEDICO a ON a.ID_AGENDA = c.ID_AGENDA
      JOIN   TBL_MEDICOS       m ON m.ID_MEDICO = a.ID_MEDICO
      JOIN   TBL_PARAMETROS    e ON e.ID_PARAM  = m.ID_ESPECIALIDAD
      JOIN   TBL_PARAMETROS    s ON s.ID_PARAM  = c.ID_ESTADO
      WHERE  c.ID_PACIENTE = vn_paciente
      ORDER  BY a.FECHA_HORA_INICIO DESC;
  END PRO_MIS_CITAS;

END PKG_CITAS;
/

/* ---------------------------------------------------------------------
   Si hay errores de compilacion:
     SHOW ERRORS PACKAGE BODY PKG_CITAS
   --------------------------------------------------------------------- */

---------------------------------------------------------------------
-- VERIFICACIONES
---------------------------------------------------------------------
-- V1. Los 2 objetos deben salir VALID
SELECT OBJECT_NAME, OBJECT_TYPE, STATUS
FROM   USER_OBJECTS
WHERE  OBJECT_NAME = 'PKG_CITAS'
ORDER  BY OBJECT_TYPE;

-- V2. Prueba funcional (deja los datos como estaban al terminar).
--     Esperado: OK cita N / ORA-20001 / ORA-20005 / OK limpieza
SET SERVEROUTPUT ON
DECLARE
  vn_agenda    NUMBER;
  vn_paciente  NUMBER;
  vn_otro_pac  NUMBER;
  vn_cita      NUMBER;
  vn_cita2     NUMBER;
  vc_cursor    SYS_REFCURSOR;
BEGIN
  SELECT MIN(ID_AGENDA) INTO vn_agenda
  FROM   TBL_AGENDA_MEDICO
  WHERE  ID_ESTADO = PKG_CONSTANTES.agenda_libre
  AND    FECHA_HORA_INICIO >= PKG_CONSTANTES.fecha_sistema;

  SELECT MIN(ID_PACIENTE), MAX(ID_PACIENTE) INTO vn_paciente, vn_otro_pac
  FROM   TBL_PACIENTES;

  IF vn_agenda IS NULL THEN
    DBMS_OUTPUT.PUT_LINE('No hay bloques libres desde ' ||
      TO_CHAR(PKG_CONSTANTES.fecha_sistema, 'DD/MM/YYYY') || ': revisar los datos');
    RETURN;
  END IF;

  -- 1. Recepcionista reserva: debe funcionar
  PKG_CONTEXTO.SET_USUARIO(1, 'RECEPCIONISTA', NULL);
  PKG_CITAS.PRO_RESERVAR_CITA(vn_paciente, vn_agenda, 'Prueba HU01', vn_cita);
  DBMS_OUTPUT.PUT_LINE('OK cita ' || vn_cita || ' sobre agenda ' || vn_agenda);

  -- 2. Mismo bloque otra vez: debe fallar con -20001
  BEGIN
    PKG_CITAS.PRO_RESERVAR_CITA(vn_otro_pac, vn_agenda, NULL, vn_cita2);
    DBMS_OUTPUT.PUT_LINE('ERROR: debio fallar');
  EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Esperado -> ' || SQLERRM);
  END;

  -- 3. Paciente intentando reservar a nombre de otro: debe fallar con -20005
  PKG_CONTEXTO.SET_USUARIO(2, 'PACIENTE', vn_paciente);
  BEGIN
    PKG_CITAS.PRO_RESERVAR_CITA(vn_paciente + 1000000, vn_agenda, NULL, vn_cita2);
    DBMS_OUTPUT.PUT_LINE('ERROR: debio fallar');
  EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Esperado -> ' || SQLERRM);
  END;
  PKG_CONTEXTO.LIMPIAR;

  -- Limpieza: deshacer la reserva de prueba
  DELETE FROM TBL_LOG_AUDITORIA
  WHERE  TABLA_AFECTADA = 'TBL_CITAS_MEDICAS' AND ID_REGISTRO = vn_cita;
  DELETE FROM TBL_CITAS_MEDICAS WHERE ID_CITA = vn_cita;
  UPDATE TBL_AGENDA_MEDICO
  SET    ID_ESTADO = PKG_CONSTANTES.agenda_libre
  WHERE  ID_AGENDA = vn_agenda;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('OK limpieza');
END;
/

/* ---------------------------------------------------------------------
   V3. PRUEBA DE CONCURRENCIA (dos pestanas de SQL Developer)
   Reemplazar 123 por un ID_AGENDA libre real.

   Pestana A:  SELECT * FROM TBL_AGENDA_MEDICO WHERE ID_AGENDA = 123 FOR UPDATE;
               (no confirmar todavia: A "esta reservando")
   Pestana B:  BEGIN
                 PKG_CONTEXTO.SET_USUARIO(1, 'RECEPCIONISTA', NULL);
                 PKG_CITAS.PRO_RESERVAR_CITA(1, 123, NULL, :id);
               END;
               -> se queda esperando (hasta 5 s)
   Pestana A:  UPDATE TBL_AGENDA_MEDICO
               SET ID_ESTADO = PKG_CONSTANTES.agenda_ocupada
               WHERE ID_AGENDA = 123;   COMMIT;
   Resultado:  B termina con ORA-20001 (medico ocupado). Si en A se hace
               ROLLBACK en vez de COMMIT, B logra reservar.
   --------------------------------------------------------------------- */

/* ---------------------------------------------------------------------
   V4. Citas del dia de un medico. Cambiar 1 por un ID_MEDICO real.
   Esperado: filas con paciente y hora (o ninguna si ese dia no hay citas).
   --------------------------------------------------------------------- */
VAR c REFCURSOR
BEGIN
  PKG_CONTEXTO.SET_USUARIO(1, 'MEDICO', 1);
  PKG_CITAS.PRO_CITAS_MEDICO(NULL, :c);
END;
/
PRINT c

/* ---------------------------------------------------------------------
   V5. Listados de apoyo (esperado: filas en cada uno)
   --------------------------------------------------------------------- */
VAR cm REFCURSOR
VAR cp REFCURSOR
VAR cc REFCURSOR
BEGIN
  PKG_CONTEXTO.SET_USUARIO(1, 'RECEPCIONISTA', NULL);
  PKG_CITAS.PRO_LISTAR_MEDICOS(:cm);
  PKG_CITAS.PRO_LISTAR_PACIENTES(:cp);
  PKG_CITAS.PRO_MIS_CITAS(1, :cc);   -- 1 = ID_PACIENTE de prueba
END;
/
PRINT cm
PRINT cp
PRINT cc

/* ======================= FIN DE PKG_CITAS (HU01) ======================= */