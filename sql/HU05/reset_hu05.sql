/* =====================================================================
   PROYECTO PL/SQL - SISTEMA DE GESTION DE CITAS MEDICAS
   RESET DE HU05: devuelve recetas y stock a como estaban al cargar los datos
   ---------------------------------------------------------------------
   Ejecucion : conectado como PROYECTOPLSQL, con F5 (Ejecutar script).
   Requisito : haber creado ANTES de probar la copia del stock
                 CREATE TABLE TBL_STOCK_RESPALDO AS SELECT * FROM TBL_STOCK_FARMACIA;
   ---------------------------------------------------------------------
   Que hace (despues de probar HU05 desde la pantalla o con Postman):
     1. Borra las recetas y detalles creados despues de la carga
        (ID_RECETA > 245 e ID_DETALLE > 475) y los medicamentos que se
        agregaron despues a recetas originales.
     2. Restaura TBL_STOCK_FARMACIA desde TBL_STOCK_RESPALDO.
   Que NO puede hacer:
     - Deshacer entregas hechas sobre medicamentos de las recetas ORIGINALES
       (ID_DETALLE <= 475): su pendiente, estado, farmaceutico y fecha
       cambiaron y la carga inicial no se guarda en otra tabla. Para evitarlo,
       pruebe las entregas solo con recetas que usted cree. Para volver a
       cargar todo, repita script_carga_datos_proyectoplsql.sql.
   Cuidado: si el respaldo se hizo DESPUES de entregar algo, el stock
   "restaurado" quedara con esas entregas. La consulta R1 ayuda a ver si
   los numeros son razonables.
   Si varios comparten la base, avisen antes: borra las pruebas de todos.
   El script de equipo reseteo_datos_prueba.sql (citas/historias) se ejecuta
   aparte; no restaura el stock.
   ===================================================================== */

SET DEFINE OFF;
SET SERVEROUTPUT ON SIZE UNLIMITED

/* ---------------------------------------------------------------------
   VISTA PREVIA: lo que se va a borrar (revisela antes de seguir; el script
   ejecuta todo con F5, asi que si algo no le cuadra, cancele)
   --------------------------------------------------------------------- */
SELECT 'recetas nuevas (ID > 245)' AS QUE, COUNT(*) AS CANTIDAD
FROM   TBL_RECETAS_MEDICAS WHERE ID_RECETA > 245
UNION ALL
SELECT 'detalles nuevos (ID > 475)', COUNT(*)
FROM   TBL_DETALLE_RECETA WHERE ID_DETALLE > 475;

/* ---------------------------------------------------------------------
   PARTE 1. Borrar lo creado despues de la carga
   --------------------------------------------------------------------- */
DELETE FROM TBL_DETALLE_RECETA WHERE ID_RECETA > 245;
DELETE FROM TBL_DETALLE_RECETA WHERE ID_DETALLE > 475;
DELETE FROM TBL_RECETAS_MEDICAS WHERE ID_RECETA > 245;

/* Si alguna receta ORIGINAL quedo con un medicamento nuevo ya borrado y
   su estado no cuadra, la verificacion R3 lo mostrara. */

/* ---------------------------------------------------------------------
   PARTE 2. Restaurar el stock desde el respaldo
   --------------------------------------------------------------------- */
UPDATE TBL_STOCK_FARMACIA S
SET    CANTIDAD_DISPONIBLE = (SELECT R.CANTIDAD_DISPONIBLE
                              FROM   TBL_STOCK_RESPALDO R
                              WHERE  R.ID_STOCK = S.ID_STOCK)
WHERE  EXISTS (SELECT 1 FROM TBL_STOCK_RESPALDO R WHERE R.ID_STOCK = S.ID_STOCK);

COMMIT;

/* ---------------------------------------------------------------------
   VERIFICACION
   --------------------------------------------------------------------- */
-- R1. Totales (esperado con la carga original: 245 recetas y 475 detalles)
SELECT (SELECT COUNT(*) FROM TBL_RECETAS_MEDICAS) AS RECETAS,
       (SELECT COUNT(*) FROM TBL_DETALLE_RECETA)  AS DETALLES
FROM   DUAL;

-- R2. Stock distinto al respaldo (esperado: 0 filas)
SELECT S.ID_MEDICAMENTO, S.CANTIDAD_DISPONIBLE AS ACTUAL, R.CANTIDAD_DISPONIBLE AS RESPALDO
FROM   TBL_STOCK_FARMACIA S
JOIN   TBL_STOCK_RESPALDO R ON R.ID_STOCK = S.ID_STOCK
WHERE  S.CANTIDAD_DISPONIBLE <> R.CANTIDAD_DISPONIBLE;

-- R3. Estado de recetas que no cuadra con sus detalles (esperado: 0 filas)
SELECT r.ID_RECETA, p.ID_TIPO AS ESTADO_RECETA
FROM   TBL_RECETAS_MEDICAS r
JOIN   TBL_PARAMETROS p ON p.ID_PARAM = r.ID_ESTADO
WHERE  EXISTS (SELECT 1 FROM TBL_DETALLE_RECETA d WHERE d.ID_RECETA = r.ID_RECETA)
AND    p.ID_TIPO <> (SELECT CASE
                              WHEN SUM(CASE WHEN d.CANTIDAD_PENDIENTE = d.CANTIDAD THEN 0 ELSE 1 END) = 0 THEN 'R1'
                              WHEN SUM(d.CANTIDAD_PENDIENTE) = 0 THEN 'R2'
                              ELSE 'R3'
                            END
                     FROM   TBL_DETALLE_RECETA d
                     WHERE  d.ID_RECETA = r.ID_RECETA);

/* ---------------------------------------------------------------------
   AL TERMINAR TODAS LAS PRUEBAS (cuando ya no necesite el respaldo):
     DROP TABLE TBL_STOCK_RESPALDO;
   La validacion del proyecto espera 14 tablas TBL_ y esta seria la 15.
   --------------------------------------------------------------------- */

/* ======================= FIN DEL RESET DE HU05 ======================= */
