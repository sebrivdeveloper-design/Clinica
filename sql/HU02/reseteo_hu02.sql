/* =====================================================================
   PROYECTO PL/SQL - SISTEMA DE GESTION DE CITAS MEDICAS
   HU02 - Cancelacion de citas: RESETEO DE LAS PRUEBAS
   ---------------------------------------------------------------------
   Ejecucion : conectado como PROYECTOPLSQL, con F5 (Ejecutar script).
   Deja los datos como estaban antes de pruebas_hu02.sql:
     1. Borra las citas que las pruebas crearon en el turno 495
        (solo las de los pacientes de prueba 2, 12, 15, 62 y 87).
     2. Devuelve a Pendiente las citas 483 y 485, SOLO si las cancelaron
        las pruebas (OBSERVACION con "Prueba HU02") y su hora sigue libre.
     3. Recalcula el estado de los turnos 440 y 495 con el procedimiento
        de la HU01 (PRC_SINCRONIZAR_ESTADO_AGENDA).
   No toca nada mas. No hace falta volver a ejecutar 01_esquema_y_datos.sql.
   ===================================================================== */

SET SERVEROUTPUT ON

DECLARE
  vn_filas NUMBER;
BEGIN
  -- 1. Citas creadas por la Parte C de las pruebas
  DELETE FROM TBL_CITAS_MEDICAS
   WHERE ID_AGENDA = 495
     AND ID_PACIENTE IN (2, 12, 15, 62, 87);
  DBMS_OUTPUT.PUT_LINE('Citas de prueba borradas del turno 495: ' || SQL%ROWCOUNT);

  -- 2. Volver a Pendiente 483 y 485 (si nadie ocupo su hora mientras tanto)
  UPDATE TBL_CITAS_MEDICAS C
     SET C.ID_ESTADO   = PKG_CONSTANTES.cita_pendiente,
         C.OBSERVACION = NULL
   WHERE C.ID_CITA IN (483, 485)
     AND C.ID_ESTADO = PKG_CONSTANTES.cita_cancelada
     AND C.OBSERVACION LIKE '%Prueba HU02%'
     AND NOT EXISTS (SELECT 1
                       FROM TBL_CITAS_MEDICAS O
                       JOIN TBL_AGENDA_MEDICO AO ON AO.ID_AGENDA = O.ID_AGENDA
                       JOIN TBL_AGENDA_MEDICO AC ON AC.ID_AGENDA = C.ID_AGENDA
                      WHERE AO.ID_MEDICO = AC.ID_MEDICO
                        AND O.ID_CITA  <> C.ID_CITA
                        AND O.ID_ESTADO <> PKG_CONSTANTES.cita_cancelada
                        AND O.HORA_INICIO < C.HORA_FIN
                        AND C.HORA_INICIO < O.HORA_FIN);
  vn_filas := SQL%ROWCOUNT;
  DBMS_OUTPUT.PUT_LINE('Citas devueltas a Pendiente (483/485): ' || vn_filas);

  -- 3. Recalcular el estado de los turnos afectados
  PKG_CITAS.PRC_SINCRONIZAR_ESTADO_AGENDA(440);
  PKG_CITAS.PRC_SINCRONIZAR_ESTADO_AGENDA(495);

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Reseteo de HU02 terminado');
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
    RAISE;
END;
/

-- Verificacion. Esperado: 483 y 485 Pendientes sin observacion,
-- turno 440 Libre y turno 495 Libre sin citas.
SELECT C.ID_CITA, P.VALOR AS ESTADO, C.OBSERVACION
  FROM TBL_CITAS_MEDICAS C JOIN TBL_PARAMETROS P ON P.ID_PARAM = C.ID_ESTADO
 WHERE C.ID_CITA IN (483, 485)
 ORDER BY C.ID_CITA;

SELECT A.ID_AGENDA, P.VALOR AS ESTADO_TURNO,
       (SELECT COUNT(*) FROM TBL_CITAS_MEDICAS C WHERE C.ID_AGENDA = A.ID_AGENDA) AS CITAS
  FROM TBL_AGENDA_MEDICO A JOIN TBL_PARAMETROS P ON P.ID_PARAM = A.ID_ESTADO
 WHERE A.ID_AGENDA IN (440, 495)
 ORDER BY A.ID_AGENDA;

/* ======================= FIN DE RESETEO HU02 ======================= */
