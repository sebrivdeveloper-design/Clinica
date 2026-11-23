
/* =====================================================================
   HU03 - LIMPIEZA DE DATOS DE PRUEBA
   ---------------------------------------------------------------------
   Ejecutar conectado como PROYECTOPLSQL con F5.

   Elimina exclusivamente:
     - Paciente con documento HU03TEST0001.
     - Agenda temporal del 31/12/2099 a las 00:00.
     - Citas asociadas a esos datos.
     - Historias clinicas asociadas.

   No modifica pacientes, citas ni historias clinicas reales.
   ===================================================================== */

SET SERVEROUTPUT ON

DECLARE
  vn_historias NUMBER;
  vn_citas     NUMBER;
  vn_agendas   NUMBER;
  vn_pacientes NUMBER;
BEGIN
  ---------------------------------------------------------------------
  -- 1. Historias de citas de prueba
  ---------------------------------------------------------------------
  DELETE FROM TBL_HISTORIA_CLINICA
  WHERE ID_CITA IN (
    SELECT c.ID_CITA
    FROM TBL_CITAS_MEDICAS c
    WHERE c.ID_PACIENTE IN (
      SELECT p.ID_PACIENTE
      FROM TBL_PACIENTES p
      WHERE p.DOCUMENTO = 'HU03TEST0001'
    )
    OR c.ID_AGENDA IN (
      SELECT a.ID_AGENDA
      FROM TBL_AGENDA_MEDICO a
      WHERE a.FECHA_HORA_INICIO = DATE '2099-12-31'
    )
  );

  vn_historias := SQL%ROWCOUNT;

  ---------------------------------------------------------------------
  -- 2. Citas de prueba
  ---------------------------------------------------------------------
  DELETE FROM TBL_CITAS_MEDICAS
  WHERE ID_PACIENTE IN (
    SELECT ID_PACIENTE
    FROM TBL_PACIENTES
    WHERE DOCUMENTO = 'HU03TEST0001'
  )
  OR ID_AGENDA IN (
    SELECT ID_AGENDA
    FROM TBL_AGENDA_MEDICO
    WHERE FECHA_HORA_INICIO = DATE '2099-12-31'
  );

  vn_citas := SQL%ROWCOUNT;

  ---------------------------------------------------------------------
  -- 3. Agenda temporal
  ---------------------------------------------------------------------
  DELETE FROM TBL_AGENDA_MEDICO
  WHERE FECHA_HORA_INICIO = DATE '2099-12-31';

  vn_agendas := SQL%ROWCOUNT;

  ---------------------------------------------------------------------
  -- 4. Paciente temporal
  ---------------------------------------------------------------------
  DELETE FROM TBL_PACIENTES
  WHERE DOCUMENTO = 'HU03TEST0001';

  vn_pacientes := SQL%ROWCOUNT;

  COMMIT;

  DBMS_OUTPUT.PUT_LINE('================ LIMPIEZA HU03 ================');
  DBMS_OUTPUT.PUT_LINE('Historias eliminadas : ' || vn_historias);
  DBMS_OUTPUT.PUT_LINE('Citas eliminadas     : ' || vn_citas);
  DBMS_OUTPUT.PUT_LINE('Agendas eliminadas   : ' || vn_agendas);
  DBMS_OUTPUT.PUT_LINE('Pacientes eliminados : ' || vn_pacientes);
  DBMS_OUTPUT.PUT_LINE('Limpieza completada.');

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('Error en limpieza HU03: ' || SQLERRM);
    RAISE;
END;
/

/* ---------------------------------------------------------------------
   VERIFICACION: todos los resultados deben ser 0
   --------------------------------------------------------------------- */

SELECT 'Paciente de prueba restante' AS VERIFICACION,
       COUNT(*) AS RESTANTES
FROM TBL_PACIENTES
WHERE DOCUMENTO = 'HU03TEST0001'

UNION ALL

SELECT 'Agenda temporal restante',
       COUNT(*)
FROM TBL_AGENDA_MEDICO
WHERE FECHA_HORA_INICIO = DATE '2099-12-31';

/* ======================= FIN LIMPIEZA HU03 =========================== */
