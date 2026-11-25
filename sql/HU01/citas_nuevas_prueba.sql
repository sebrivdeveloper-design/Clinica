/* =====================================================================
   CITAS NUEVAS DE PRUEBA (via PKG_CITAS.PRC_RESERVAR_CITA)
   Ejecutar como PROYECTOPLSQL con F5. Requiere PKG_CITAS y
   PKG_CONSTANTES.fecha_sistema = 30/04/2026.

   Crea 15 citas Pendientes en los turnos libres del 04 al 08/05/2026,
   cada una con un paciente distinto y una franja de 1 hora. Pasa por el
   mismo procedimiento que usa la app, asi que la agenda queda coherente
   (turno Libre/Ocupado recalculado, sin solapamientos).
   ===================================================================== */
SET SERVEROUTPUT ON
ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY HH24:MI';

DECLARE
  v_i      NUMBER := 0;
  v_pac    NUMBER;
  v_hora   DATE;
  v_cita   NUMBER;
BEGIN
  FOR a IN (SELECT id_agenda, id_medico, fecha_hora_inicio
              FROM tbl_agenda_medico
             WHERE fecha_hora_inicio >= DATE '2026-05-04'
               AND fecha_hora_inicio <  DATE '2026-05-09'
               AND id_estado = PKG_CONSTANTES.agenda_libre
             ORDER BY fecha_hora_inicio, id_agenda
             FETCH FIRST 15 ROWS ONLY) LOOP
    BEGIN
      -- paciente distinto por cita
      SELECT id_paciente INTO v_pac
        FROM tbl_pacientes
       ORDER BY id_paciente
      OFFSET v_i ROWS FETCH NEXT 1 ROWS ONLY;

      -- franja: rota entre las 6 horas del turno de la manana
      v_hora := a.fecha_hora_inicio + MOD(v_i, 6) / 24;

      PKG_CITAS.PRC_RESERVAR_CITA(v_pac, a.id_agenda, v_hora, v_cita);
      DBMS_OUTPUT.PUT_LINE('Cita ' || v_cita || ' | medico ' || a.id_medico ||
                           ' | paciente ' || v_pac || ' | ' || TO_CHAR(v_hora));
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Omitida agenda ' || a.id_agenda || ': ' || SQLERRM);
    END;
    v_i := v_i + 1;
  END LOOP;
END;
/

-- Verificacion
SELECT c.id_cita, c.id_paciente, a.id_medico, c.hora_inicio, c.hora_fin, p.valor estado
  FROM tbl_citas_medicas c
  JOIN tbl_agenda_medico a ON a.id_agenda = c.id_agenda
  JOIN tbl_parametros    p ON p.id_param  = c.id_estado
 WHERE c.id_cita > 492
 ORDER BY c.hora_inicio, a.id_medico;

/*---------------------------------------------------------------------
   DESHACER (si quieres volver al estado original): descomenta y ejecuta.

   -- 1) guardar los turnos afectados, 2) borrar las citas, 3) recalcular:
   CREATE TABLE tmp_agendas_prueba AS
     SELECT DISTINCT id_agenda FROM tbl_citas_medicas WHERE id_cita > 492;
   DELETE FROM tbl_citas_medicas WHERE id_cita > 492;
   BEGIN
     FOR r IN (SELECT id_agenda FROM tmp_agendas_prueba) LOOP
       PKG_CITAS.PRC_SINCRONIZAR_ESTADO_AGENDA(r.id_agenda);
     END LOOP;
     COMMIT;
   END;
   /
   DROP TABLE tmp_agendas_prueba;
   --------------------------------------------------------------------- */
