/* HU04: PROGRAMADA se representa como Pendiente (C1). */
CREATE OR REPLACE TRIGGER TRG_HISTORIA_VALIDAR_CITA
  BEFORE INSERT ON TBL_HISTORIA_CLINICA
  FOR EACH ROW
DECLARE
  vt_estado TBL_CITAS_MEDICAS.ID_ESTADO%TYPE;
  vt_pendiente TBL_CITAS_MEDICAS.ID_ESTADO%TYPE;
BEGIN
  IF :NEW.ID_CITA IS NULL THEN
    RETURN;
  END IF;

  BEGIN
    SELECT ID_ESTADO INTO vt_estado
    FROM TBL_CITAS_MEDICAS
    WHERE ID_CITA = :NEW.ID_CITA;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN; 
  END;

  
  vt_pendiente := PKG_CONSTANTES.cita_pendiente;
  IF vt_estado IS NULL OR vt_pendiente IS NULL OR vt_estado <> vt_pendiente THEN
    RAISE_APPLICATION_ERROR(-20060,
      'No se puede registrar la historia clinica: la cita debe estar pendiente (programada).');
  END IF;
END;
/
SHOW ERRORS TRIGGER TRG_HISTORIA_VALIDAR_CITA;
