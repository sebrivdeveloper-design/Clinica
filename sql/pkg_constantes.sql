/* =====================================================================
   PROYECTO PL/SQL - SISTEMA DE GESTION DE CITAS MEDICAS
   PKG_CONSTANTES: estados por codigo (ID_TIPO) y fecha de referencia
   ---------------------------------------------------------------------
   Ejecucion : conectado como PROYECTOPLSQL, con F5 (Ejecutar script).
   Requisito : haber ejecutado la creacion de tablas y la carga de datos
               (TBL_PARAMETROS debe tener los codigos C1..C3, A1..A3,
               R1..R3, D1..D3).
   Uso       : en vez de escribir ID_ESTADO = 2, escribir
               PKG_CONSTANTES.cita_cancelada
   Se ejecuta UNA vez por base de datos. No modificar sin avisar al grupo.
   ===================================================================== */

CREATE OR REPLACE PACKAGE PKG_CONSTANTES AS
  -- Estado de cita
  FUNCTION cita_pendiente       RETURN NUMBER;  -- C1
  FUNCTION cita_cancelada       RETURN NUMBER;  -- C2
  FUNCTION cita_finalizada      RETURN NUMBER;  -- C3
  -- Estado de agenda
  FUNCTION agenda_libre         RETURN NUMBER;  -- A1
  FUNCTION agenda_ocupada       RETURN NUMBER;  -- A2
  FUNCTION agenda_cirugia       RETURN NUMBER;  -- A3
  -- Estado de receta
  FUNCTION receta_no_entregada  RETURN NUMBER;  -- R1
  FUNCTION receta_entregada     RETURN NUMBER;  -- R2
  FUNCTION receta_parcial       RETURN NUMBER;  -- R3
  -- Estado de detalle de receta
  FUNCTION detalle_no_entregado RETURN NUMBER;  -- D1
  FUNCTION detalle_parcial      RETURN NUMBER;  -- D2
  FUNCTION detalle_entregado    RETURN NUMBER;  -- D3
  -- Fecha de referencia del sistema (condicion del profesor)
  FUNCTION fecha_sistema        RETURN DATE;    -- 30/04/2026
END PKG_CONSTANTES;
/

CREATE OR REPLACE PACKAGE BODY PKG_CONSTANTES AS

  -- Busca el ID_PARAM a partir del codigo estable (ID_TIPO)
  FUNCTION id_param(p_tipo IN VARCHAR2) RETURN NUMBER IS
    v_id NUMBER;
  BEGIN
    SELECT ID_PARAM INTO v_id FROM TBL_PARAMETROS WHERE ID_TIPO = p_tipo;
    RETURN v_id;
  END id_param;

  FUNCTION cita_pendiente       RETURN NUMBER IS BEGIN RETURN id_param('C1'); END;
  FUNCTION cita_cancelada       RETURN NUMBER IS BEGIN RETURN id_param('C2'); END;
  FUNCTION cita_finalizada      RETURN NUMBER IS BEGIN RETURN id_param('C3'); END;

  FUNCTION agenda_libre         RETURN NUMBER IS BEGIN RETURN id_param('A1'); END;
  FUNCTION agenda_ocupada       RETURN NUMBER IS BEGIN RETURN id_param('A2'); END;
  FUNCTION agenda_cirugia       RETURN NUMBER IS BEGIN RETURN id_param('A3'); END;

  FUNCTION receta_no_entregada  RETURN NUMBER IS BEGIN RETURN id_param('R1'); END;
  FUNCTION receta_entregada     RETURN NUMBER IS BEGIN RETURN id_param('R2'); END;
  FUNCTION receta_parcial       RETURN NUMBER IS BEGIN RETURN id_param('R3'); END;

  FUNCTION detalle_no_entregado RETURN NUMBER IS BEGIN RETURN id_param('D1'); END;
  FUNCTION detalle_parcial      RETURN NUMBER IS BEGIN RETURN id_param('D2'); END;
  FUNCTION detalle_entregado    RETURN NUMBER IS BEGIN RETURN id_param('D3'); END;

  FUNCTION fecha_sistema        RETURN DATE IS BEGIN RETURN DATE '2026-04-30'; END;

END PKG_CONSTANTES;
/

/* ---------------------------------------------------------------------
   VERIFICACION
   Esperado con los datos cargados: 1, 2, 3, 10, 11, 12 y fecha 30/04/2026
   (fecha de referencia del escenario desde el reseteo por turnos del 24/11/2026)
   Si el paquete queda con errores: SHOW ERRORS PACKAGE BODY PKG_CONSTANTES
   --------------------------------------------------------------------- */
SELECT PKG_CONSTANTES.cita_pendiente   AS C1,
       PKG_CONSTANTES.cita_cancelada   AS C2,
       PKG_CONSTANTES.cita_finalizada  AS C3,
       PKG_CONSTANTES.agenda_libre     AS A1,
       PKG_CONSTANTES.agenda_ocupada   AS A2,
       PKG_CONSTANTES.agenda_cirugia   AS A3,
       TO_CHAR(PKG_CONSTANTES.fecha_sistema, 'DD/MM/YYYY') AS FECHA
FROM   DUAL;

/* ======================= FIN DE PKG_CONSTANTES ======================= */
