/* =====================================================================
   PROYECTO PL/SQL - SISTEMA DE GESTION DE CITAS MEDICAS
   RESETEO DE DATOS DE PRUEBA (HU01 a HU05)
   ---------------------------------------------------------------------
   Ejecucion : conectado como PROYECTOPLSQL, con F5 (Ejecutar script).
   Requisito : haber ejecutado PKG_CONSTANTES.
   ---------------------------------------------------------------------
   PARTE 1: devuelve las 7 citas pendientes de la carga inicial
            (441, 442, 443, 446, 447, 448, 450) a su estado original:
              - cita Pendiente, OBSERVACION nula
              - agenda Ocupado
              - se borran la historia, receta y detalle que se hayan
                creado sobre ellas (HU03 / HU05)
   PARTE 2: borra lo creado DESPUES de la carga (citas con ID > 450,
            hechas con HU01) y libera sus bloques de agenda.
            Los bloques en cirugia (A3) no se tocan.
   ---------------------------------------------------------------------
   OJO: si varios comparten la misma base de datos, avisen antes de
   ejecutarlo: borra las pruebas de todos. Si un trigger de auditoria
   (HU08) esta activo, los DELETE tambien quedaran en TBL_LOG_AUDITORIA.
   NO restaura TBL_STOCK_FARMACIA (HU05): el stock inicial es aleatorio.
   Para poder devolverlo, cada quien debe guardar una copia antes de
   probar (ver el final de este archivo).
   ===================================================================== */

SET DEFINE OFF;

/* ---------------------------------------------------------------------
   PARTE 1. Las 7 citas pendientes originales
   --------------------------------------------------------------------- */
DELETE FROM TBL_DETALLE_RECETA
WHERE  ID_RECETA IN (SELECT ID_RECETA FROM TBL_RECETAS_MEDICAS
                     WHERE  ID_HISTORIA IN (SELECT ID_HISTORIA FROM TBL_HISTORIA_CLINICA
                                            WHERE  ID_CITA IN (441,442,443,446,447,448,450)));

DELETE FROM TBL_RECETAS_MEDICAS
WHERE  ID_HISTORIA IN (SELECT ID_HISTORIA FROM TBL_HISTORIA_CLINICA
                       WHERE  ID_CITA IN (441,442,443,446,447,448,450));

DELETE FROM TBL_HISTORIA_CLINICA
WHERE  ID_CITA IN (441,442,443,446,447,448,450);

UPDATE TBL_CITAS_MEDICAS
SET    ID_ESTADO  = PKG_CONSTANTES.cita_pendiente,
       OBSERVACION = NULL
WHERE  ID_CITA IN (441,442,443,446,447,448,450);

UPDATE TBL_AGENDA_MEDICO
SET    ID_ESTADO = PKG_CONSTANTES.agenda_ocupada
WHERE  ID_AGENDA IN (441,442,443,446,447,448,450);

/* ---------------------------------------------------------------------
   PARTE 2. Citas creadas despues de la carga (ID_CITA > 450)
   Si no quieres borrar las pruebas de HU01, no ejecutes este bloque.
   --------------------------------------------------------------------- */
DELETE FROM TBL_DETALLE_RECETA
WHERE  ID_RECETA IN (SELECT ID_RECETA FROM TBL_RECETAS_MEDICAS
                     WHERE  ID_HISTORIA IN (SELECT ID_HISTORIA FROM TBL_HISTORIA_CLINICA
                                            WHERE  ID_CITA > 450));

DELETE FROM TBL_RECETAS_MEDICAS
WHERE  ID_HISTORIA IN (SELECT ID_HISTORIA FROM TBL_HISTORIA_CLINICA
                       WHERE  ID_CITA > 450);

DELETE FROM TBL_HISTORIA_CLINICA WHERE ID_CITA > 450;

DELETE FROM TBL_CITAS_MEDICAS    WHERE ID_CITA > 450;

-- Los bloques futuros (ID_AGENDA > 450) que quedaron Ocupado vuelven a Libre
UPDATE TBL_AGENDA_MEDICO
SET    ID_ESTADO = PKG_CONSTANTES.agenda_libre
WHERE  ID_AGENDA > 450
AND    ID_ESTADO = PKG_CONSTANTES.agenda_ocupada;

COMMIT;

/* ---------------------------------------------------------------------
   VERIFICACION
   --------------------------------------------------------------------- */
-- R1. Citas por estado (esperado con los datos originales: 353 / 90 / 7)
SELECT P.VALOR AS ESTADO, COUNT(*) AS TOTAL
FROM   TBL_CITAS_MEDICAS C JOIN TBL_PARAMETROS P ON P.ID_PARAM = C.ID_ESTADO
GROUP  BY P.VALOR;

-- R2. Coherencia cita / agenda (esperado: 0 filas)
SELECT C.ID_CITA, PC.ID_TIPO ESTADO_CITA, PA.ID_TIPO ESTADO_AGENDA
FROM   TBL_CITAS_MEDICAS C
JOIN   TBL_AGENDA_MEDICO A  ON A.ID_AGENDA = C.ID_AGENDA
JOIN   TBL_PARAMETROS    PC ON PC.ID_PARAM = C.ID_ESTADO
JOIN   TBL_PARAMETROS    PA ON PA.ID_PARAM = A.ID_ESTADO
WHERE (PC.ID_TIPO = 'C2' AND PA.ID_TIPO <> 'A1')
   OR (PC.ID_TIPO IN ('C1','C3') AND PA.ID_TIPO <> 'A2');

-- R3. Observacion solo en canceladas (esperado: 0 filas)
SELECT C.ID_CITA, P.ID_TIPO, C.OBSERVACION
FROM   TBL_CITAS_MEDICAS C JOIN TBL_PARAMETROS P ON P.ID_PARAM = C.ID_ESTADO
WHERE (P.ID_TIPO = 'C2' AND C.OBSERVACION IS NULL)
   OR (P.ID_TIPO <> 'C2' AND C.OBSERVACION IS NOT NULL);

-- R4. Historias solo para citas finalizadas (esperado: 0 filas)
SELECT H.ID_HISTORIA, P.ID_TIPO
FROM   TBL_HISTORIA_CLINICA H
JOIN   TBL_CITAS_MEDICAS C ON C.ID_CITA  = H.ID_CITA
JOIN   TBL_PARAMETROS    P ON P.ID_PARAM = C.ID_ESTADO
WHERE  P.ID_TIPO <> 'C3';

/* ---------------------------------------------------------------------
   OPCIONAL (HU05): copia y restauracion del stock
   Antes de probar el descuento de stock, ejecutar UNA vez:

     CREATE TABLE TBL_STOCK_RESPALDO AS SELECT * FROM TBL_STOCK_FARMACIA;

   Para devolver el stock a como estaba:

     UPDATE TBL_STOCK_FARMACIA S
     SET    CANTIDAD_DISPONIBLE = (SELECT R.CANTIDAD_DISPONIBLE
                                   FROM   TBL_STOCK_RESPALDO R
                                   WHERE  R.ID_STOCK = S.ID_STOCK);
     COMMIT;
   --------------------------------------------------------------------- */

/* ======================= FIN DEL RESETEO ======================= */
