/* SOLO en una copia aislada autorizada, despues de instalar el trigger.
   Necesita al menos un paciente y una agenda.
   Revierte sus filas; las secuencias identity pueden avanzar aun con rollback.
   No ejecutar junto con scripts que hagan COMMIT ni triggers autonomos. */
SET SERVEROUTPUT ON;
DECLARE
  v_paciente NUMBER;
  v_agenda NUMBER;
  v_cita NUMBER;
  v_historia NUMBER;
  v_inexistente NUMBER;
  v_total NUMBER;

  PROCEDURE comprobar(p_condicion BOOLEAN, p_caso VARCHAR2) IS
  BEGIN
    IF p_condicion IS NULL OR NOT p_condicion THEN
      DBMS_OUTPUT.PUT_LINE('FALLO: ' || p_caso);
      RAISE VALUE_ERROR;
    END IF;
    DBMS_OUTPUT.PUT_LINE('OK: ' || p_caso);
  END;

  PROCEDURE rechaza(p_cita NUMBER, p_codigo NUMBER, p_caso VARCHAR2) IS
    v_error NUMBER := 0;
    v_antes NUMBER;
    v_despues NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_antes FROM TBL_HISTORIA_CLINICA WHERE ID_CITA = p_cita;
    BEGIN
      INSERT INTO TBL_HISTORIA_CLINICA (ID_CITA, DIAGNOSTICO, NOTAS_MEDICAS)
      VALUES (p_cita, 'Prueba HU04', 'Debe rechazarse');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE <> p_codigo THEN RAISE; END IF;
        v_error := SQLCODE;
    END;
    SELECT COUNT(*) INTO v_despues FROM TBL_HISTORIA_CLINICA WHERE ID_CITA = p_cita;
    comprobar(v_error = p_codigo AND v_antes = v_despues, p_caso);
  END;
BEGIN
  SAVEPOINT hu04_pruebas;
  SELECT COUNT(*) INTO v_total FROM USER_OBJECTS
  WHERE OBJECT_NAME = 'TRG_HISTORIA_VALIDAR_CITA' AND OBJECT_TYPE = 'TRIGGER' AND STATUS = 'VALID';
  comprobar(v_total = 1, 'Trigger compilado');
  SELECT COUNT(*) INTO v_total FROM USER_TRIGGERS
  WHERE TRIGGER_NAME = 'TRG_HISTORIA_VALIDAR_CITA' AND STATUS = 'ENABLED';
  comprobar(v_total = 1, 'Trigger habilitado');
  SELECT MIN(ID_PACIENTE) INTO v_paciente FROM TBL_PACIENTES;
  SELECT MIN(ID_AGENDA) INTO v_agenda FROM TBL_AGENDA_MEDICO;
  comprobar(v_paciente IS NOT NULL AND v_agenda IS NOT NULL, 'Datos base disponibles');

  INSERT INTO TBL_CITAS_MEDICAS (ID_PACIENTE, ID_AGENDA, ID_ESTADO)
  VALUES (v_paciente, v_agenda, PKG_CONSTANTES.cita_pendiente)
  RETURNING ID_CITA INTO v_cita;
  INSERT INTO TBL_HISTORIA_CLINICA (ID_CITA, DIAGNOSTICO, NOTAS_MEDICAS)
  VALUES (v_cita, 'Prueba HU04', 'Pendiente aceptada')
  RETURNING ID_HISTORIA INTO v_historia;
  comprobar(v_historia IS NOT NULL, 'PENDIENTE permite insertar');
  rechaza(v_cita, -1, 'Unicidad de historia por cita');

  -- Orden compatible con HU03: primero historia, despues estado final.
  UPDATE TBL_CITAS_MEDICAS SET ID_ESTADO = PKG_CONSTANTES.cita_finalizada WHERE ID_CITA = v_cita;
  SELECT COUNT(*) INTO v_total FROM TBL_HISTORIA_CLINICA WHERE ID_CITA = v_cita;
  comprobar(v_total = 1, 'Transicion posterior de HU03 conserva historia');
  DELETE FROM TBL_HISTORIA_CLINICA WHERE ID_CITA = v_cita;
  rechaza(v_cita, -20060, 'ATENDIDA: representada como Finalizada C3');
  UPDATE TBL_CITAS_MEDICAS SET ID_ESTADO = PKG_CONSTANTES.cita_cancelada WHERE ID_CITA = v_cita;
  rechaza(v_cita, -20060, 'CANCELADA');
  -- Otro parametro existente tambien debe rechazarse como estado de cita.
  UPDATE TBL_CITAS_MEDICAS SET ID_ESTADO = PKG_CONSTANTES.agenda_libre WHERE ID_CITA = v_cita;
  rechaza(v_cita, -20060, 'Cualquier otro ID_ESTADO');
  SELECT NVL(MIN(ID_CITA), 0) - 1 INTO v_inexistente FROM TBL_CITAS_MEDICAS;
  rechaza(v_inexistente, -2291, 'Cita inexistente: FK');
  rechaza(NULL, -1400, 'Cita nula: NOT NULL');

  ROLLBACK TO hu04_pruebas;
  SELECT COUNT(*) INTO v_total FROM TBL_CITAS_MEDICAS WHERE ID_CITA = v_cita;
  comprobar(v_total = 0, 'Rollback elimina la cita de prueba');
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK TO hu04_pruebas;
    RAISE;
END;
/
