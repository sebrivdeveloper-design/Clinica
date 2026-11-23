
/* =====================================================================
   HU03 - REGISTRO DE CONSULTA MEDICA
   PKG_HISTORIA: registra el diagnostico y las notas medicas,
                 y finaliza la cita en una misma transaccion.
   ---------------------------------------------------------------------
   Ejecucion: conectado como PROYECTOPLSQL, con F5 (Ejecutar script).
   Dependencias:
     - TBL_CITAS_MEDICAS
     - TBL_AGENDA_MEDICO
     - TBL_HISTORIA_CLINICA
     - PKG_CONSTANTES
     - PKG_CONTEXTO
     - TRG_HISTORIA_VALIDAR_CITA (HU04)
   ===================================================================== */

CREATE OR REPLACE PACKAGE PKG_HISTORIA AS

  /* Registra la consulta de una cita.
     Solo el medico propietario de la cita puede realizar la operacion.
     Inserta la historia clinica y cambia la cita a Finalizada.
     Devuelve el ID_HISTORIA generado por Oracle. */
  PROCEDURE registrar_consulta(
    p_id_cita       IN  NUMBER,
    p_diagnostico   IN  VARCHAR2,
    p_notas_medicas IN  VARCHAR2,
    p_id_historia   OUT NUMBER
  );

END PKG_HISTORIA;
/

/* =====================================================================
   CUERPO DEL PACKAGE
   ===================================================================== */

CREATE OR REPLACE PACKAGE BODY PKG_HISTORIA AS

  PROCEDURE registrar_consulta(
    p_id_cita       IN  NUMBER,
    p_diagnostico   IN  VARCHAR2,
    p_notas_medicas IN  VARCHAR2,
    p_id_historia   OUT NUMBER
  ) IS

    vn_medico_ctx    NUMBER       := PKG_CONTEXTO.FN_id_entidad;
    va_rol           VARCHAR2(50) := PKG_CONTEXTO.FN_rol;
    vn_medico_cita   NUMBER;
    vn_estado_final  NUMBER       := PKG_CONSTANTES.cita_finalizada;

  BEGIN
    p_id_historia := NULL;

    ------------------------------------------------------------------
    -- 1. Validacion del contexto y permisos
    ------------------------------------------------------------------
    IF PKG_CONTEXTO.FN_id_usuario IS NULL
       OR NVL(va_rol, '?') <> 'MEDICO'
       OR vn_medico_ctx IS NULL THEN
      RAISE_APPLICATION_ERROR(
        -20042,
        'No tiene permiso para registrar consultas medicas'
      );
    END IF;

    ------------------------------------------------------------------
    -- 2. Validacion de datos recibidos
    ------------------------------------------------------------------
    IF p_id_cita IS NULL
       OR p_id_cita <= 0
       OR TRIM(p_diagnostico) IS NULL
       OR LENGTH(TRIM(p_diagnostico)) > 1000
       OR LENGTH(TRIM(p_notas_medicas)) > 4000 THEN
      RAISE_APPLICATION_ERROR(
        -20040,
        'Datos invalidos: revise la cita, el diagnostico y las notas medicas'
      );
    END IF;

    ------------------------------------------------------------------
    -- 3. Verificar existencia de la cita y su medico.
    --    Se bloquea la fila de la cita durante la transaccion para
    --    evitar que otra operacion modifique su estado simultaneamente.
    ------------------------------------------------------------------
    BEGIN
      SELECT ag.ID_MEDICO
      INTO   vn_medico_cita
      FROM   TBL_CITAS_MEDICAS c
      JOIN   TBL_AGENDA_MEDICO ag
             ON ag.ID_AGENDA = c.ID_AGENDA
      WHERE  c.ID_CITA = p_id_cita
      FOR UPDATE OF c.ID_ESTADO;

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(
          -20041,
          'No se encontro la cita medica indicada'
        );
    END;

    ------------------------------------------------------------------
    -- 4. Verificar que el medico autenticado sea el propietario
    --    de la cita.
    ------------------------------------------------------------------
    IF vn_medico_cita <> vn_medico_ctx THEN
      RAISE_APPLICATION_ERROR(
        -20042,
        'La cita medica no corresponde al medico autenticado'
      );
    END IF;

    ------------------------------------------------------------------
    -- 5. Registrar la historia clinica.
    --    HU04 valida mediante su trigger que la cita este pendiente.
    --    ID_HISTORIA se genera automaticamente y se recupera.
    ------------------------------------------------------------------
    INSERT INTO TBL_HISTORIA_CLINICA (
      ID_CITA,
      DIAGNOSTICO,
      NOTAS_MEDICAS
    )
    VALUES (
      p_id_cita,
      TRIM(p_diagnostico),
      NULLIF(TRIM(p_notas_medicas), '')
    )
    RETURNING ID_HISTORIA INTO p_id_historia;

    ------------------------------------------------------------------
    -- 6. Finalizar la cita.
    --    ATENDIDA corresponde al estado Finalizada (C3).
    ------------------------------------------------------------------
    UPDATE TBL_CITAS_MEDICAS
    SET    ID_ESTADO = vn_estado_final
    WHERE  ID_CITA = p_id_cita;

    ------------------------------------------------------------------
    -- 7. Confirmar ambas operaciones
    ------------------------------------------------------------------
    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END registrar_consulta;

END PKG_HISTORIA;
/

/* =====================================================================
   VERIFICACION DE COMPILACION
   ===================================================================== */

SHOW ERRORS PACKAGE PKG_HISTORIA;
SHOW ERRORS PACKAGE BODY PKG_HISTORIA;

/* ======================= FIN PKG_HISTORIA ============================ */

SELECT OBJECT_NAME,
       OBJECT_TYPE,
       STATUS
FROM USER_OBJECTS
WHERE OBJECT_NAME = 'PKG_HISTORIA'
ORDER BY OBJECT_TYPE;