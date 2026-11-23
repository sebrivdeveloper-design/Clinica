/* =====================================================================
   PROYECTO PL/SQL - SISTEMA DE GESTION DE CITAS MEDICAS
   LIMPIEZA DE LAS PRUEBAS DE HU05
   ---------------------------------------------------------------------
   Ejecucion : conectado como PROYECTOPLSQL, con F5 (Ejecutar script).
   Cuando usarlo:
     - pruebas_hu05.sql se interrumpio y dejo datos a medias, o
     - termino la prueba de concurrencia (concurrencia_hu05.sql).
   Que hace:
     Busca las recetas que tienen algun medicamento con dosis
     'PRUEBA_HU05...' (la marca que ponen las pruebas), devuelve al stock
     lo que esas recetas hubieran entregado y borra los detalles y las
     recetas. No toca nada que no lleve esa marca.
   Antes: si dejo una pestana con un bloqueo (SELECT ... FOR UPDATE) de la
          prueba de concurrencia, ejecute ROLLBACK en esa pestana; si no,
          este script se queda esperando.
   Las recetas creadas desde la pantalla NO llevan marca: para
   deshacerlas use reset_hu05.sql.
   ===================================================================== */

SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
  TYPE t_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
  vt_recetas t_ids;
  vn_stock_devuelto NUMBER := 0;
BEGIN
  SELECT DISTINCT ID_RECETA
  BULK COLLECT INTO vt_recetas
  FROM   TBL_DETALLE_RECETA
  WHERE  DOSIS LIKE 'PRUEBA_HU05%';

  FOR i IN 1 .. vt_recetas.COUNT LOOP
    FOR d IN (SELECT ID_MEDICAMENTO, CANTIDAD - CANTIDAD_PENDIENTE AS ENTREGADO
              FROM   TBL_DETALLE_RECETA
              WHERE  ID_RECETA = vt_recetas(i)) LOOP
      UPDATE TBL_STOCK_FARMACIA
      SET    CANTIDAD_DISPONIBLE = CANTIDAD_DISPONIBLE + d.ENTREGADO
      WHERE  ID_MEDICAMENTO = d.ID_MEDICAMENTO;
      vn_stock_devuelto := vn_stock_devuelto + d.ENTREGADO;
    END LOOP;
    DELETE FROM TBL_DETALLE_RECETA  WHERE ID_RECETA = vt_recetas(i);
    DELETE FROM TBL_RECETAS_MEDICAS WHERE ID_RECETA = vt_recetas(i);
  END LOOP;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Recetas de prueba borradas : ' || vt_recetas.COUNT);
  DBMS_OUTPUT.PUT_LINE('Unidades devueltas al stock: ' || vn_stock_devuelto);
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END;
/

/* ---------------------------------------------------------------------
   VERIFICACION
   --------------------------------------------------------------------- */
-- L1. Restos con la marca (esperado: 0)
SELECT COUNT(*) AS RESTOS_DE_PRUEBA
FROM   TBL_DETALLE_RECETA
WHERE  DOSIS LIKE 'PRUEBA_HU05%';

-- L2. Totales (con los datos originales de la carga: 245 recetas y 475 detalles;
--     pueden ser mas si hay recetas creadas desde la pantalla)
SELECT (SELECT COUNT(*) FROM TBL_RECETAS_MEDICAS) AS RECETAS,
       (SELECT COUNT(*) FROM TBL_DETALLE_RECETA)  AS DETALLES
FROM   DUAL;

/* ======================= FIN DE LA LIMPIEZA ======================= */
