/* =====================================================================
   PROYECTO PL/SQL - SISTEMA DE GESTION DE CITAS MEDICAS
   HU02 - Cancelacion de citas: PRUEBAS
   ---------------------------------------------------------------------
   Ejecucion : conectado como PROYECTOPLSQL, con F5 (Ejecutar script).
   Requisitos: 01_esquema_y_datos.sql (datos del 24/11/2026),
               PKG_CONSTANTES (fecha_sistema = 30/04/2026),
               PKG_CONTEXTO y PKG_CITAS (sql/HU01/pkg_citas_hu01.sql,
               que ya incluye el bloque de la HU02).
   ---------------------------------------------------------------------
   Datos que usa (todos de la carga inicial):
     - Cita 483 (paciente 45) y cita 485 (paciente 93): Pendientes del
       30/04/2026, las dos en el turno 440 (Libre, quedan franjas).
     - Cita 1: Finalizada.
     - Turno 495: medico 10, 08/05/2026 07:00-13:00, Libre y sin citas.
       Se llena con la HU01 para probar el paso Ocupado -> Libre.
   Las pruebas hacen COMMIT. Para repetirlas: ejecutar reseteo_hu02.sql.
   Cada prueba imprime "OK" o "FALLO" en la salida (DBMS_OUTPUT).
   ===================================================================== */

SET SERVEROUTPUT ON
ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY HH24:MI';

-- ---------------------------------------------------------------------
-- 0. Precondiciones (si algo sale "AVISO", ejecutar reseteo_hu02.sql)
-- ---------------------------------------------------------------------
DECLARE
  vn_n NUMBER;
BEGIN
  SELECT COUNT(*) INTO vn_n
    FROM TBL_CITAS_MEDICAS
   WHERE ID_CITA IN (483, 485)
     AND ID_ESTADO = PKG_CONSTANTES.cita_pendiente;
  DBMS_OUTPUT.PUT_LINE(CASE WHEN vn_n = 2 THEN 'OK   ' ELSE 'AVISO' END ||
                       ' citas 483 y 485 Pendientes: ' || vn_n || ' de 2');

  SELECT COUNT(*) INTO vn_n FROM TBL_CITAS_MEDICAS WHERE ID_AGENDA = 495;
  DBMS_OUTPUT.PUT_LINE(CASE WHEN vn_n = 0 THEN 'OK   ' ELSE 'AVISO' END ||
                       ' turno 495 sin citas: tiene ' || vn_n);

  DBMS_OUTPUT.PUT_LINE('Fecha de referencia: ' ||
                       TO_CHAR(PKG_CONSTANTES.fecha_sistema, 'DD/MM/YYYY') ||
                       ' (esperado 30/04/2026)');
END;
/

/* =====================================================================
   PARTE A. PRC_CANCELAR_CITA (procedimiento interno)
   ===================================================================== */

-- P1. Cancelar la cita 483 como Paciente (esperado: OK)
BEGIN
  PKG_CITAS.PRC_CANCELAR_CITA(vn_id_cita => 483,
                              va_origen  => 'paciente',   -- se normaliza a 'Paciente'
                              va_motivo  => 'Prueba HU02 - viaje de trabajo');
  DBMS_OUTPUT.PUT_LINE('P1 OK: cita 483 cancelada');
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('P1 FALLO: ' || SQLERRM);
END;
/

-- P2. Cita inexistente (esperado: ORA-20002)
BEGIN
  PKG_CITAS.PRC_CANCELAR_CITA(vn_id_cita => 99999, va_origen => 'Paciente',
                              va_motivo  => 'Prueba HU02');
  DBMS_OUTPUT.PUT_LINE('P2 FALLO: no lanzo error');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20002 THEN 'P2 OK: ' ELSE 'P2 FALLO: ' END || SQLERRM);
END;
/

-- P3. Cancelar otra vez la 483, que ya esta Cancelada (esperado: ORA-20007)
BEGIN
  PKG_CITAS.PRC_CANCELAR_CITA(vn_id_cita => 483, va_origen => 'Paciente',
                              va_motivo  => 'Prueba HU02');
  DBMS_OUTPUT.PUT_LINE('P3 FALLO: no lanzo error');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20007 THEN 'P3 OK: ' ELSE 'P3 FALLO: ' END || SQLERRM);
END;
/

-- P4. Cita 1, que esta Finalizada (esperado: ORA-20007)
BEGIN
  PKG_CITAS.PRC_CANCELAR_CITA(vn_id_cita => 1, va_origen => 'Clinica',
                              va_motivo  => 'Prueba HU02');
  DBMS_OUTPUT.PUT_LINE('P4 FALLO: no lanzo error');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20007 THEN 'P4 OK: ' ELSE 'P4 FALLO: ' END || SQLERRM);
END;
/

-- P5. Origen invalido 'Doctor' (esperado: ORA-20020)
BEGIN
  PKG_CITAS.PRC_CANCELAR_CITA(vn_id_cita => 485, va_origen => 'Doctor',
                              va_motivo  => 'Prueba HU02');
  DBMS_OUTPUT.PUT_LINE('P5 FALLO: no lanzo error');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20020 THEN 'P5 OK: ' ELSE 'P5 FALLO: ' END || SQLERRM);
END;
/

-- P6. Motivo con solo espacios (esperado: ORA-20021)
BEGIN
  PKG_CITAS.PRC_CANCELAR_CITA(vn_id_cita => 485, va_origen => 'Clinica',
                              va_motivo  => '    ');
  DBMS_OUTPUT.PUT_LINE('P6 FALLO: no lanzo error');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20021 THEN 'P6 OK: ' ELSE 'P6 FALLO: ' END || SQLERRM);
END;
/

-- P7. Motivo de 600 caracteres (esperado: ORA-20022)
BEGIN
  PKG_CITAS.PRC_CANCELAR_CITA(vn_id_cita => 485, va_origen => 'Clinica',
                              va_motivo  => RPAD('x', 600, 'x'));
  DBMS_OUTPUT.PUT_LINE('P7 FALLO: no lanzo error');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20022 THEN 'P7 OK: ' ELSE 'P7 FALLO: ' END || SQLERRM);
END;
/

/* =====================================================================
   PARTE B. PRO_CANCELAR_CITA (lo que llama el backend)
   Se simula el usuario con PKG_CONTEXTO.SET_USUARIO, como hace Java.
   Usuarios de la carga: 7 = medico (jarango6), 12 = recepcion1,
   18 = paciente 33 (paciente570188942).
   ===================================================================== */

-- P8. Un MEDICO intenta cancelar (esperado: ORA-20005)
BEGIN
  PKG_CONTEXTO.SET_USUARIO(vn_id_usuario => 7, va_rol => 'MEDICO', vn_id_entidad => 6);
  PKG_CITAS.PRO_CANCELAR_CITA(vn_id_cita => 485, va_motivo => 'Prueba HU02');
  PKG_CONTEXTO.LIMPIAR;
  DBMS_OUTPUT.PUT_LINE('P8 FALLO: no lanzo error');
EXCEPTION
  WHEN OTHERS THEN
    PKG_CONTEXTO.LIMPIAR;
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20005 THEN 'P8 OK: ' ELSE 'P8 FALLO: ' END || SQLERRM);
END;
/

-- P9. El paciente 33 intenta cancelar la cita 485, que es del paciente 93
--     (esperado: ORA-20005)
BEGIN
  PKG_CONTEXTO.SET_USUARIO(vn_id_usuario => 18, va_rol => 'PACIENTE', vn_id_entidad => 33);
  PKG_CITAS.PRO_CANCELAR_CITA(vn_id_cita => 485, va_motivo => 'Prueba HU02');
  PKG_CONTEXTO.LIMPIAR;
  DBMS_OUTPUT.PUT_LINE('P9 FALLO: no lanzo error');
EXCEPTION
  WHEN OTHERS THEN
    PKG_CONTEXTO.LIMPIAR;
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20005 THEN 'P9 OK: ' ELSE 'P9 FALLO: ' END || SQLERRM);
END;
/

-- P10. Recepcion cancela la cita 485 (esperado: OK, OBSERVACION "Clinica: ...")
BEGIN
  PKG_CONTEXTO.SET_USUARIO(vn_id_usuario => 12, va_rol => 'RECEPCIONISTA', vn_id_entidad => NULL);
  PKG_CITAS.PRO_CANCELAR_CITA(vn_id_cita => 485,
                              va_motivo  => 'Prueba HU02 - el medico tiene una urgencia');
  PKG_CONTEXTO.LIMPIAR;
  DBMS_OUTPUT.PUT_LINE('P10 OK: cita 485 cancelada por la clinica');
EXCEPTION
  WHEN OTHERS THEN
    PKG_CONTEXTO.LIMPIAR;
    DBMS_OUTPUT.PUT_LINE('P10 FALLO: ' || SQLERRM);
END;
/

/* =====================================================================
   PARTE C. Turno Ocupado -> Libre (lo nuevo de la agenda por turnos)
   P11: se llenan las 6 franjas del turno 495 con la HU01 (queda Ocupado),
        se cancela la de las 09:00 (debe quedar Libre) y
   P12: se vuelve a reservar esa misma franja (debe dejarla reservar:
        la cancelacion de verdad libero el horario).
   ===================================================================== */
DECLARE
  TYPE t_numeros IS TABLE OF NUMBER;
  vt_pacientes   t_numeros := t_numeros(2, 12, 15, 62, 87, 2);  -- sin otras citas
  vn_cita        NUMBER;
  vn_cita_9am    NUMBER;
  vd_inicio      DATE;
  va_estado      VARCHAR2(10);

  FUNCTION FN_estado_turno RETURN VARCHAR2 IS
    va_tipo VARCHAR2(10);
  BEGIN
    SELECT P.ID_TIPO INTO va_tipo
      FROM TBL_AGENDA_MEDICO A JOIN TBL_PARAMETROS P ON P.ID_PARAM = A.ID_ESTADO
     WHERE A.ID_AGENDA = 495;
    RETURN va_tipo;
  END FN_estado_turno;
BEGIN
  SELECT FECHA_HORA_INICIO INTO vd_inicio FROM TBL_AGENDA_MEDICO WHERE ID_AGENDA = 495;

  -- Llenar el turno (07:00, 08:00, ... 12:00)
  FOR i IN 1 .. vt_pacientes.COUNT LOOP
    PKG_CITAS.PRC_RESERVAR_CITA(vt_pacientes(i), 495, vd_inicio + (i - 1) / 24, vn_cita);
    IF i = 3 THEN
      vn_cita_9am := vn_cita;   -- la de las 09:00 (paciente 15)
    END IF;
  END LOOP;

  va_estado := FN_estado_turno;
  DBMS_OUTPUT.PUT_LINE(CASE WHEN va_estado = 'A2' THEN 'P11a OK: ' ELSE 'P11a FALLO: ' END ||
                       'turno 495 lleno = ' || va_estado || ' (esperado A2 Ocupado)');

  -- Cancelar la cita de las 09:00
  PKG_CITAS.PRC_CANCELAR_CITA(vn_cita_9am, 'Clinica', 'Prueba HU02 - turno lleno');

  va_estado := FN_estado_turno;
  DBMS_OUTPUT.PUT_LINE(CASE WHEN va_estado = 'A1' THEN 'P11b OK: ' ELSE 'P11b FALLO: ' END ||
                       'turno 495 tras cancelar = ' || va_estado || ' (esperado A1 Libre)');

  -- P12. La franja de las 09:00 se puede volver a reservar
  PKG_CITAS.PRC_RESERVAR_CITA(15, 495, vd_inicio + 2 / 24, vn_cita);
  va_estado := FN_estado_turno;
  DBMS_OUTPUT.PUT_LINE(CASE WHEN va_estado = 'A2' THEN 'P12 OK: ' ELSE 'P12 FALLO: ' END ||
                       'franja 09:00 reservada otra vez (cita ' || vn_cita ||
                       '), turno = ' || va_estado || ' (esperado A2)');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('P11/P12 FALLO: ' || SQLERRM);
END;
/

/* =====================================================================
   VERIFICACION FINAL
   ===================================================================== */

-- V1. Citas de prueba de la cancelacion
--     Esperado: 483 Cancelada "Paciente: Prueba HU02 - viaje de trabajo"
--               485 Cancelada "Clinica: Prueba HU02 - el medico tiene una urgencia"
SELECT C.ID_CITA, C.ID_PACIENTE, C.ID_AGENDA, C.HORA_INICIO, P.VALOR AS ESTADO, C.OBSERVACION
  FROM TBL_CITAS_MEDICAS C JOIN TBL_PARAMETROS P ON P.ID_PARAM = C.ID_ESTADO
 WHERE C.ID_CITA IN (483, 485)
 ORDER BY C.ID_CITA;

-- V2. Turno 440 (el de 483 y 485). Esperado: Libre
SELECT A.ID_AGENDA, P.VALOR AS ESTADO_TURNO
  FROM TBL_AGENDA_MEDICO A JOIN TBL_PARAMETROS P ON P.ID_PARAM = A.ID_ESTADO
 WHERE A.ID_AGENDA = 440;

-- V3. Turno 495. Esperado: 7 citas (6 Pendientes + 1 Cancelada a las 09:00)
--     y el turno Ocupado
SELECT C.ID_CITA, C.ID_PACIENTE, C.HORA_INICIO, P.VALOR AS ESTADO, C.OBSERVACION
  FROM TBL_CITAS_MEDICAS C JOIN TBL_PARAMETROS P ON P.ID_PARAM = C.ID_ESTADO
 WHERE C.ID_AGENDA = 495
 ORDER BY C.HORA_INICIO, C.ID_CITA;

-- V4. Coherencia del estado de los turnos (D9 del script de datos). Esperado: 0 filas
SELECT A.ID_AGENDA, PA.ID_TIPO AS ESTADO_TURNO
  FROM TBL_AGENDA_MEDICO A JOIN TBL_PARAMETROS PA ON PA.ID_PARAM = A.ID_ESTADO
 WHERE (PA.ID_TIPO = 'A2' AND (SELECT COUNT(*) FROM TBL_CITAS_MEDICAS C JOIN TBL_PARAMETROS PC ON PC.ID_PARAM = C.ID_ESTADO
                               WHERE C.ID_AGENDA = A.ID_AGENDA AND PC.ID_TIPO <> 'C2')
                              <> ROUND((A.FECHA_HORA_FIN - A.FECHA_HORA_INICIO) * 24))
    OR (PA.ID_TIPO = 'A1' AND (SELECT COUNT(*) FROM TBL_CITAS_MEDICAS C JOIN TBL_PARAMETROS PC ON PC.ID_PARAM = C.ID_ESTADO
                               WHERE C.ID_AGENDA = A.ID_AGENDA AND PC.ID_TIPO <> 'C2')
                              >= ROUND((A.FECHA_HORA_FIN - A.FECHA_HORA_INICIO) * 24))
    OR (PA.ID_TIPO = 'A3' AND EXISTS (SELECT 1 FROM TBL_CITAS_MEDICAS C WHERE C.ID_AGENDA = A.ID_AGENDA));

-- V5. OBSERVACION solo y siempre en citas Canceladas (D10). Esperado: 0 filas
SELECT C.ID_CITA, P.ID_TIPO, C.OBSERVACION
  FROM TBL_CITAS_MEDICAS C JOIN TBL_PARAMETROS P ON P.ID_PARAM = C.ID_ESTADO
 WHERE (P.ID_TIPO = 'C2' AND C.OBSERVACION IS NULL)
    OR (P.ID_TIPO <> 'C2' AND C.OBSERVACION IS NOT NULL);

-- V6. Un medico con dos citas activas que se cruzan (D8c). Esperado: 0 filas
SELECT C1.ID_CITA, C2.ID_CITA, A1.ID_MEDICO
  FROM TBL_CITAS_MEDICAS C1
  JOIN TBL_AGENDA_MEDICO A1 ON A1.ID_AGENDA = C1.ID_AGENDA
  JOIN TBL_CITAS_MEDICAS C2 ON C2.ID_CITA > C1.ID_CITA
  JOIN TBL_AGENDA_MEDICO A2 ON A2.ID_AGENDA = C2.ID_AGENDA AND A2.ID_MEDICO = A1.ID_MEDICO
  JOIN TBL_PARAMETROS    P1 ON P1.ID_PARAM  = C1.ID_ESTADO
  JOIN TBL_PARAMETROS    P2 ON P2.ID_PARAM  = C2.ID_ESTADO
 WHERE P1.ID_TIPO <> 'C2' AND P2.ID_TIPO <> 'C2'
   AND C1.HORA_INICIO < C2.HORA_FIN
   AND C2.HORA_INICIO < C1.HORA_FIN;

/* ======================= FIN DE PRUEBAS HU02 ======================= */
