/* =====================================================================
   PROYECTO PL/SQL - SISTEMA DE GESTION DE CITAS MEDICAS
   PKG_FARMACIA - HU05: Prescripcion y descuento de stock
   ---------------------------------------------------------------------
   Ejecucion : conectado como PROYECTOPLSQL, con F5 (Ejecutar script).
   Requisito : tablas con datos, PKG_CONSTANTES y PKG_CONTEXTO creados.
   Contenido :
     Escritura (hacen COMMIT al terminar):
     - PRO_CREAR_RECETA      : crea la receta de una historia clinica
         -> POST /api/recetas                     { idHistoria }
     - PRO_AGREGAR_DETALLE   : agrega un medicamento a la receta
         -> POST /api/recetas/{id}/detalle        { idMedicamento, cantidad, dosis }
     - PRO_REGISTRAR_ENTREGA : entrega (total o parcial) y descuenta stock
         -> POST /api/recetas/detalle/{id}/entrega { cantidad }
     Consulta (solo lectura, devuelven SYS_REFCURSOR):
     - PRO_LISTAR_MEDICAMENTOS -> GET /api/medicamentos
     - PRO_DETALLES_PENDIENTES -> GET /api/recetas/detalles-pendientes
     - PRO_DETALLE_RECETA      -> GET /api/recetas/{id}/detalle
   ---------------------------------------------------------------------
   Reglas acordadas con el equipo y el profesor:
     - El stock se descuenta AL ENTREGAR, no al emitir la receta.
     - Al prescribir NO se valida stock (se puede recetar mas de lo que hay).
     - Una entrega mayor que el stock se RECHAZA (-20004); no se ajusta sola.
     - El estado de detalle y receta se DEDUCE; nunca lo envia el cliente.
     - Fecha: fecha de referencia del sistema (PKG_CONSTANTES.fecha_sistema)
       mas la hora real. No se usa SYSDATE como fecha de la operacion.
     - Sin auditoria manual: la cubren los triggers de HU08.
   ---------------------------------------------------------------------
   Codigos de error
     Compartidos del contrato (el backend los traduce):
       -20002 registro no encontrado   -20004 stock insuficiente
       -20005 sin permiso
     Propios de HU05 (rango -20080 a -20099, el backend responde 422):
       -20080 la historia ya tiene receta
       -20081 el medicamento ya esta en la receta
       -20082 la receta ya tiene entregas
       -20083 el detalle ya fue entregado completo
       -20084 la cantidad supera lo pendiente
       -20085 datos invalidos
       -20086 el medicamento no tiene inventario
       -20087 operacion en curso, intente de nuevo (tiempo de bloqueo)
     Las excepciones nombradas de la especificacion sirven para capturar
     estos codigos por nombre desde otros bloques o pruebas.
   ---------------------------------------------------------------------
   Transacciones: cada procedimiento de escritura es una sola unidad de
   trabajo. Valida TODO antes de modificar, bloquea con FOR UPDATE en el
   orden receta -> detalle -> stock, hace COMMIT al final y ante cualquier
   error hace ROLLBACK y relanza el error original (nunca lo silencia).
   Los procedimientos de consulta no hacen COMMIT ni ROLLBACK.
   ===================================================================== */

CREATE OR REPLACE PACKAGE PKG_FARMACIA AS

  /* Excepciones nombradas, enlazadas a los codigos del rango */
  EXC_STOCK_INSUFICIENTE        EXCEPTION;
  PRAGMA EXCEPTION_INIT(EXC_STOCK_INSUFICIENTE,        -20004);
  EXC_RECETA_EXISTENTE          EXCEPTION;
  PRAGMA EXCEPTION_INIT(EXC_RECETA_EXISTENTE,          -20080);
  EXC_MEDICAMENTO_REPETIDO      EXCEPTION;
  PRAGMA EXCEPTION_INIT(EXC_MEDICAMENTO_REPETIDO,      -20081);
  EXC_RECETA_CON_ENTREGAS       EXCEPTION;
  PRAGMA EXCEPTION_INIT(EXC_RECETA_CON_ENTREGAS,       -20082);
  EXC_DETALLE_ENTREGADO         EXCEPTION;
  PRAGMA EXCEPTION_INIT(EXC_DETALLE_ENTREGADO,         -20083);
  EXC_CANTIDAD_EXCEDE_PENDIENTE EXCEPTION;
  PRAGMA EXCEPTION_INIT(EXC_CANTIDAD_EXCEDE_PENDIENTE, -20084);
  EXC_DATOS_INVALIDOS           EXCEPTION;
  PRAGMA EXCEPTION_INIT(EXC_DATOS_INVALIDOS,           -20085);
  EXC_SIN_INVENTARIO            EXCEPTION;
  PRAGMA EXCEPTION_INIT(EXC_SIN_INVENTARIO,            -20086);
  EXC_OPERACION_EN_CURSO        EXCEPTION;
  PRAGMA EXCEPTION_INIT(EXC_OPERACION_EN_CURSO,        -20087);

  /* Crea la receta de una historia clinica. Solo el MEDICO dueno de la
     historia (historia -> cita -> agenda -> medico). Estado inicial:
     No entregada. Devuelve el id de la receta. */
  PROCEDURE PRO_CREAR_RECETA(vn_id_historia IN  NUMBER,
                             vn_id_receta   OUT NUMBER);

  /* Agrega un medicamento a una receta que aun no tiene entregas. Solo el
     MEDICO dueno de la receta. No valida stock. Estado inicial: No
     entregado, con cantidad pendiente igual a la prescrita. */
  PROCEDURE PRO_AGREGAR_DETALLE(vn_id_receta      IN  NUMBER,
                                vn_id_medicamento IN  NUMBER,
                                vn_cantidad       IN  NUMBER,
                                va_dosis          IN  VARCHAR2,
                                vn_id_detalle     OUT NUMBER);

  /* Registra una entrega (total o parcial) y descuenta el stock. Solo el
     FARMACEUTICO; su id sale del contexto, nunca del cliente. Rechaza con
     -20004 si la cantidad supera el stock. Devuelve lo que queda pendiente
     y los estados resultantes (texto) del detalle y de la receta. */
  PROCEDURE PRO_REGISTRAR_ENTREGA(vn_id_detalle         IN  NUMBER,
                                  vn_cantidad           IN  NUMBER,
                                  vn_cantidad_pendiente OUT NUMBER,
                                  va_estado_detalle     OUT VARCHAR2,
                                  va_estado_receta      OUT VARCHAR2);

  /* Medicamentos con su stock. Roles: ADMINISTRADOR, MEDICO, FARMACEUTICO.
     Columnas: ID_MEDICAMENTO, NOMBRE, DESCRIPCION, PRESENTACION,
     CANTIDAD_DISPONIBLE, CANTIDAD_MINIMA. */
  PROCEDURE PRO_LISTAR_MEDICAMENTOS(crs_medicamentos OUT SYS_REFCURSOR);

  /* Detalles con cantidad pendiente de entregar. Solo FARMACEUTICO.
     Columnas: ID_DETALLE, ID_RECETA, FECHA_EMISION, PACIENTE, DOCUMENTO,
     MEDICAMENTO, CANTIDAD, CANTIDAD_PENDIENTE, DOSIS, STOCK_DISPONIBLE,
     ESTADO. */
  PROCEDURE PRO_DETALLES_PENDIENTES(crs_detalles OUT SYS_REFCURSOR);

  /* Detalles de una receta. MEDICO dueno de la receta o FARMACEUTICO.
     Columnas: ID_DETALLE, ID_MEDICAMENTO, MEDICAMENTO, DOSIS, CANTIDAD,
     CANTIDAD_ENTREGADA, CANTIDAD_PENDIENTE, ESTADO, FARMACEUTICO,
     FECHA_ENTREGA. */
  PROCEDURE PRO_DETALLE_RECETA(vn_id_receta IN  NUMBER,
                               crs_detalles OUT SYS_REFCURSOR);

END PKG_FARMACIA;
/

CREATE OR REPLACE PACKAGE BODY PKG_FARMACIA AS

  -- ORA-30006: se agoto la espera del FOR UPDATE WAIT. Para el usuario
  -- significa que otra operacion esta usando ese registro.
  EXC_BLOQUEO_TIMEOUT EXCEPTION;
  PRAGMA EXCEPTION_INIT(EXC_BLOQUEO_TIMEOUT, -30006);

  ---------------------------------------------------------------------
  -- Privada: fecha de referencia del sistema + hora real
  -- (PKG_CONSTANTES.fecha_sistema trae 00:00; aqui se le suma la hora).
  ---------------------------------------------------------------------
  FUNCTION FN_FECHA_HORA_REFERENCIA RETURN DATE IS
  BEGIN
    RETURN PKG_CONSTANTES.fecha_sistema + (SYSDATE - TRUNC(SYSDATE));
  END FN_FECHA_HORA_REFERENCIA;

  ---------------------------------------------------------------------
  -- PRO_CREAR_RECETA
  ---------------------------------------------------------------------
  PROCEDURE PRO_CREAR_RECETA(vn_id_historia IN  NUMBER,
                             vn_id_receta   OUT NUMBER) IS

    vn_medico_ctx      NUMBER       := PKG_CONTEXTO.FN_id_entidad;
    va_rol             VARCHAR2(50) := PKG_CONTEXTO.FN_rol;
    vn_estado_inicial  NUMBER       := PKG_CONSTANTES.receta_no_entregada;
    vn_medico_historia NUMBER;
    vn_existe          NUMBER;
    vd_ahora           DATE;

  BEGIN
    ----------------------------------------------------------------
    -- 1. Permisos: solo un medico con su id en el contexto
    ----------------------------------------------------------------
    IF PKG_CONTEXTO.FN_id_usuario IS NULL
       OR NVL(va_rol, '?') <> 'MEDICO'
       OR vn_medico_ctx IS NULL THEN
      RAISE_APPLICATION_ERROR(-20005, 'No tiene permiso para crear recetas');
    END IF;

    ----------------------------------------------------------------
    -- 2. Parametro
    ----------------------------------------------------------------
    IF vn_id_historia IS NULL OR vn_id_historia <= 0 THEN
      RAISE_APPLICATION_ERROR(-20085, 'Indique la historia clinica de la receta');
    END IF;

    ----------------------------------------------------------------
    -- 3. La historia existe y es de este medico
    ----------------------------------------------------------------
    BEGIN
      SELECT ag.ID_MEDICO
      INTO   vn_medico_historia
      FROM   TBL_HISTORIA_CLINICA h
      JOIN   TBL_CITAS_MEDICAS    c  ON c.ID_CITA   = h.ID_CITA
      JOIN   TBL_AGENDA_MEDICO    ag ON ag.ID_AGENDA = c.ID_AGENDA
      WHERE  h.ID_HISTORIA = vn_id_historia;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'No se encontro la historia clinica');
    END;

    IF vn_medico_historia <> vn_medico_ctx THEN
      RAISE_APPLICATION_ERROR(-20005, 'La historia clinica no corresponde a este medico');
    END IF;

    ----------------------------------------------------------------
    -- 4. Una historia solo puede tener una receta
    ----------------------------------------------------------------
    SELECT COUNT(*) INTO vn_existe
    FROM   TBL_RECETAS_MEDICAS
    WHERE  ID_HISTORIA = vn_id_historia;

    IF vn_existe > 0 THEN
      RAISE_APPLICATION_ERROR(-20080, 'La historia clinica ya tiene una receta');
    END IF;

    ----------------------------------------------------------------
    -- 5. Crear la receta. Si dos medicos coinciden, la restriccion
    --    UQ_RECETAS_HISTORIA cierra la ventana entre el paso 4 y el INSERT.
    ----------------------------------------------------------------
    vd_ahora := FN_FECHA_HORA_REFERENCIA;

    BEGIN
      INSERT INTO TBL_RECETAS_MEDICAS (ID_HISTORIA, FECHA_EMISION, ID_ESTADO)
      VALUES (vn_id_historia, vd_ahora, vn_estado_inicial)
      RETURNING ID_RECETA INTO vn_id_receta;
    EXCEPTION
      WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20080, 'La historia clinica ya tiene una receta');
    END;

    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;   -- deja la conexion limpia
      RAISE;      -- conserva el codigo -200xx original
  END PRO_CREAR_RECETA;

  ---------------------------------------------------------------------
  -- PRO_AGREGAR_DETALLE
  ---------------------------------------------------------------------
  PROCEDURE PRO_AGREGAR_DETALLE(vn_id_receta      IN  NUMBER,
                                vn_id_medicamento IN  NUMBER,
                                vn_cantidad       IN  NUMBER,
                                va_dosis          IN  VARCHAR2,
                                vn_id_detalle     OUT NUMBER) IS

    vn_medico_ctx        NUMBER       := PKG_CONTEXTO.FN_id_entidad;
    va_rol               VARCHAR2(50) := PKG_CONTEXTO.FN_rol;
    vn_receta_sin_entrega NUMBER      := PKG_CONSTANTES.receta_no_entregada;
    vn_detalle_inicial   NUMBER       := PKG_CONSTANTES.detalle_no_entregado;
    vn_estado_receta     NUMBER;
    vn_medico_receta     NUMBER;
    vn_existe            NUMBER;

  BEGIN
    ----------------------------------------------------------------
    -- 1. Permisos: solo un medico con su id en el contexto
    ----------------------------------------------------------------
    IF PKG_CONTEXTO.FN_id_usuario IS NULL
       OR NVL(va_rol, '?') <> 'MEDICO'
       OR vn_medico_ctx IS NULL THEN
      RAISE_APPLICATION_ERROR(-20005, 'No tiene permiso para agregar medicamentos a una receta');
    END IF;

    ----------------------------------------------------------------
    -- 2. Datos: cantidad entera positiva de maximo 6 digitos (la columna
    --    es NUMBER(6) y redondearia un decimal en silencio), dosis con
    --    texto y de maximo 200 caracteres.
    ----------------------------------------------------------------
    IF vn_id_receta      IS NULL OR vn_id_receta      <= 0
       OR vn_id_medicamento IS NULL OR vn_id_medicamento <= 0
       OR vn_cantidad       IS NULL OR vn_cantidad       <= 0
       OR vn_cantidad <> TRUNC(vn_cantidad)
       OR vn_cantidad > 999999
       OR TRIM(va_dosis) IS NULL
       OR LENGTH(TRIM(va_dosis)) > 200 THEN
      RAISE_APPLICATION_ERROR(-20085, 'Datos invalidos: revise receta, medicamento, cantidad y dosis');
    END IF;

    ----------------------------------------------------------------
    -- 3. Bloquear la receta (solo su fila) y verificar dueno. Dos
    --    medicos o dos llamadas sobre la misma receta se turnan aqui.
    ----------------------------------------------------------------
    BEGIN
      SELECT r.ID_ESTADO, ag.ID_MEDICO
      INTO   vn_estado_receta, vn_medico_receta
      FROM   TBL_RECETAS_MEDICAS  r
      JOIN   TBL_HISTORIA_CLINICA h  ON h.ID_HISTORIA = r.ID_HISTORIA
      JOIN   TBL_CITAS_MEDICAS    c  ON c.ID_CITA     = h.ID_CITA
      JOIN   TBL_AGENDA_MEDICO    ag ON ag.ID_AGENDA  = c.ID_AGENDA
      WHERE  r.ID_RECETA = vn_id_receta
      FOR UPDATE OF r.ID_ESTADO WAIT 5;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'No se encontro la receta');
    END;

    IF vn_medico_receta <> vn_medico_ctx THEN
      RAISE_APPLICATION_ERROR(-20005, 'La receta no corresponde a este medico');
    END IF;

    ----------------------------------------------------------------
    -- 4. Solo se agrega mientras no haya entregas
    ----------------------------------------------------------------
    IF vn_estado_receta <> vn_receta_sin_entrega THEN
      RAISE_APPLICATION_ERROR(-20082, 'La receta ya tiene entregas: no se pueden agregar medicamentos');
    END IF;

    ----------------------------------------------------------------
    -- 5. El medicamento existe y tiene registro de inventario
    ----------------------------------------------------------------
    SELECT COUNT(*) INTO vn_existe
    FROM   TBL_MEDICAMENTOS
    WHERE  ID_MEDICAMENTO = vn_id_medicamento;

    IF vn_existe = 0 THEN
      RAISE_APPLICATION_ERROR(-20002, 'No se encontro el medicamento');
    END IF;

    SELECT COUNT(*) INTO vn_existe
    FROM   TBL_STOCK_FARMACIA
    WHERE  ID_MEDICAMENTO = vn_id_medicamento;

    IF vn_existe = 0 THEN
      RAISE_APPLICATION_ERROR(-20086, 'El medicamento no tiene registro de inventario');
    END IF;

    ----------------------------------------------------------------
    -- 6. Un medicamento no se repite dentro de la receta
    ----------------------------------------------------------------
    SELECT COUNT(*) INTO vn_existe
    FROM   TBL_DETALLE_RECETA
    WHERE  ID_RECETA      = vn_id_receta
    AND    ID_MEDICAMENTO = vn_id_medicamento;

    IF vn_existe > 0 THEN
      RAISE_APPLICATION_ERROR(-20081, 'El medicamento ya esta en la receta');
    END IF;

    ----------------------------------------------------------------
    -- 7. Crear el detalle: sin farmaceutico ni fecha hasta la entrega,
    --    pendiente igual a lo prescrito. No se valida stock al prescribir.
    ----------------------------------------------------------------
    BEGIN
      INSERT INTO TBL_DETALLE_RECETA
             (ID_RECETA, ID_MEDICAMENTO, CANTIDAD, DOSIS,
              ID_FARMACEUTICO, FECHA_ENTREGA, CANTIDAD_PENDIENTE, ID_ESTADO)
      VALUES (vn_id_receta, vn_id_medicamento, vn_cantidad, TRIM(va_dosis),
              NULL, NULL, vn_cantidad, vn_detalle_inicial)
      RETURNING ID_DETALLE INTO vn_id_detalle;
    EXCEPTION
      WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20081, 'El medicamento ya esta en la receta');
    END;

    COMMIT;

  EXCEPTION
    WHEN EXC_BLOQUEO_TIMEOUT THEN
      ROLLBACK;
      RAISE_APPLICATION_ERROR(-20087, 'La receta esta siendo usada por otra operacion, intente de nuevo');
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END PRO_AGREGAR_DETALLE;

  ---------------------------------------------------------------------
  -- PRO_REGISTRAR_ENTREGA
  ---------------------------------------------------------------------
  PROCEDURE PRO_REGISTRAR_ENTREGA(vn_id_detalle         IN  NUMBER,
                                  vn_cantidad           IN  NUMBER,
                                  vn_cantidad_pendiente OUT NUMBER,
                                  va_estado_detalle     OUT VARCHAR2,
                                  va_estado_receta      OUT VARCHAR2) IS

    vn_farmaceutico_ctx NUMBER       := PKG_CONTEXTO.FN_id_entidad;
    va_rol              VARCHAR2(50) := PKG_CONTEXTO.FN_rol;
    vn_det_parcial      NUMBER       := PKG_CONSTANTES.detalle_parcial;
    vn_det_entregado    NUMBER       := PKG_CONSTANTES.detalle_entregado;
    vn_rec_parcial      NUMBER       := PKG_CONSTANTES.receta_parcial;
    vn_rec_entregada    NUMBER       := PKG_CONSTANTES.receta_entregada;

    vn_existe           NUMBER;
    vn_id_receta        NUMBER;
    vn_id_medicamento   NUMBER;
    vn_estado_actual    NUMBER;
    vn_pendiente        NUMBER;
    vn_pendiente_nuevo  NUMBER;
    vn_disponible       NUMBER;
    vn_con_pendiente    NUMBER;
    vn_estado_det_nuevo NUMBER;
    vn_estado_rec_nuevo NUMBER;
    vd_ahora            DATE;

  BEGIN
    ----------------------------------------------------------------
    -- 1. Permisos: solo un farmaceutico registrado. Su id sale del
    --    contexto (el cliente no lo envia).
    ----------------------------------------------------------------
    IF PKG_CONTEXTO.FN_id_usuario IS NULL
       OR NVL(va_rol, '?') <> 'FARMACEUTICO'
       OR vn_farmaceutico_ctx IS NULL THEN
      RAISE_APPLICATION_ERROR(-20005, 'No tiene permiso para registrar entregas');
    END IF;

    SELECT COUNT(*) INTO vn_existe
    FROM   TBL_FARMACEUTICOS
    WHERE  ID_FARMACEUTICO = vn_farmaceutico_ctx;

    IF vn_existe = 0 THEN
      RAISE_APPLICATION_ERROR(-20005, 'El usuario no corresponde a un farmaceutico registrado');
    END IF;

    ----------------------------------------------------------------
    -- 2. Datos: cantidad entera positiva
    ----------------------------------------------------------------
    IF vn_id_detalle IS NULL OR vn_id_detalle <= 0
       OR vn_cantidad IS NULL OR vn_cantidad <= 0
       OR vn_cantidad <> TRUNC(vn_cantidad)
       OR vn_cantidad > 999999 THEN
      RAISE_APPLICATION_ERROR(-20085, 'Datos invalidos: revise el detalle y la cantidad a entregar');
    END IF;

    ----------------------------------------------------------------
    -- 3. Lectura SIN bloqueo, solo para saber que receta y que
    --    medicamento hay que bloquear.
    ----------------------------------------------------------------
    BEGIN
      SELECT ID_RECETA, ID_MEDICAMENTO
      INTO   vn_id_receta, vn_id_medicamento
      FROM   TBL_DETALLE_RECETA
      WHERE  ID_DETALLE = vn_id_detalle;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'No se encontro el detalle de la receta');
    END;

    ----------------------------------------------------------------
    -- 4. BLOQUEOS en orden fijo: receta -> detalle -> stock.
    --    Dos entregas de una misma receta se turnan en la receta; dos
    --    recetas con el mismo medicamento se turnan en el stock; el
    --    orden unico evita interbloqueos. Cada valor se lee DESPUES de
    --    bloquear, asi se ve lo que dejo confirmado la otra operacion.
    ----------------------------------------------------------------
    BEGIN
      SELECT r.ID_ESTADO
      INTO   vn_estado_actual
      FROM   TBL_RECETAS_MEDICAS r
      WHERE  r.ID_RECETA = vn_id_receta
      FOR UPDATE WAIT 5;

      SELECT d.CANTIDAD_PENDIENTE
      INTO   vn_pendiente
      FROM   TBL_DETALLE_RECETA d
      WHERE  d.ID_DETALLE = vn_id_detalle
      FOR UPDATE WAIT 5;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'No se encontro el detalle de la receta');
    END;

    BEGIN
      SELECT s.CANTIDAD_DISPONIBLE
      INTO   vn_disponible
      FROM   TBL_STOCK_FARMACIA s
      WHERE  s.ID_MEDICAMENTO = vn_id_medicamento
      FOR UPDATE WAIT 5;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20086, 'El medicamento no tiene registro de inventario');
    END;

    ----------------------------------------------------------------
    -- 5. Validaciones de negocio (todavia no se ha modificado nada)
    ----------------------------------------------------------------
    IF vn_pendiente = 0 THEN
      RAISE_APPLICATION_ERROR(-20083, 'El medicamento ya fue entregado completo');
    END IF;

    IF vn_cantidad > vn_pendiente THEN
      RAISE_APPLICATION_ERROR(-20084, 'La cantidad a entregar supera lo pendiente (' || vn_pendiente || ')');
    END IF;

    IF vn_cantidad > vn_disponible THEN
      RAISE_APPLICATION_ERROR(-20004, 'No hay stock suficiente del medicamento. Disponible: ' || vn_disponible);
    END IF;

    ----------------------------------------------------------------
    -- 6. Modificaciones, todas en la misma transaccion
    ----------------------------------------------------------------
    vd_ahora           := FN_FECHA_HORA_REFERENCIA;
    vn_pendiente_nuevo := vn_pendiente - vn_cantidad;

    IF vn_pendiente_nuevo = 0 THEN
      vn_estado_det_nuevo := vn_det_entregado;
    ELSE
      vn_estado_det_nuevo := vn_det_parcial;
    END IF;

    -- 6.1 Descontar el inventario
    UPDATE TBL_STOCK_FARMACIA
    SET    CANTIDAD_DISPONIBLE = CANTIDAD_DISPONIBLE - vn_cantidad
    WHERE  ID_MEDICAMENTO = vn_id_medicamento;

    -- 6.2 Actualizar el detalle (queda el ultimo farmaceutico y la ultima fecha)
    UPDATE TBL_DETALLE_RECETA
    SET    CANTIDAD_PENDIENTE = vn_pendiente_nuevo,
           ID_FARMACEUTICO    = vn_farmaceutico_ctx,
           FECHA_ENTREGA      = vd_ahora,
           ID_ESTADO          = vn_estado_det_nuevo
    WHERE  ID_DETALLE = vn_id_detalle;

    -- 6.3 Deducir el estado de la receta a partir de sus detalles
    --     (la receta esta bloqueada, nadie mas la esta recalculando)
    SELECT COUNT(*) INTO vn_con_pendiente
    FROM   TBL_DETALLE_RECETA
    WHERE  ID_RECETA = vn_id_receta
    AND    CANTIDAD_PENDIENTE > 0;

    IF vn_con_pendiente = 0 THEN
      vn_estado_rec_nuevo := vn_rec_entregada;
    ELSE
      vn_estado_rec_nuevo := vn_rec_parcial;
    END IF;

    UPDATE TBL_RECETAS_MEDICAS
    SET    ID_ESTADO = vn_estado_rec_nuevo
    WHERE  ID_RECETA = vn_id_receta;

    ----------------------------------------------------------------
    -- 7. Salidas informativas
    ----------------------------------------------------------------
    vn_cantidad_pendiente := vn_pendiente_nuevo;

    SELECT VALOR INTO va_estado_detalle
    FROM   TBL_PARAMETROS
    WHERE  ID_PARAM = vn_estado_det_nuevo;

    SELECT VALOR INTO va_estado_receta
    FROM   TBL_PARAMETROS
    WHERE  ID_PARAM = vn_estado_rec_nuevo;

    COMMIT;

  EXCEPTION
    WHEN EXC_BLOQUEO_TIMEOUT THEN
      ROLLBACK;
      RAISE_APPLICATION_ERROR(-20087, 'El medicamento o la receta estan siendo usados por otra operacion, intente de nuevo');
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END PRO_REGISTRAR_ENTREGA;

  ---------------------------------------------------------------------
  -- PRO_LISTAR_MEDICAMENTOS
  ---------------------------------------------------------------------
  PROCEDURE PRO_LISTAR_MEDICAMENTOS(crs_medicamentos OUT SYS_REFCURSOR) IS
  BEGIN
    IF PKG_CONTEXTO.FN_id_usuario IS NULL
       OR NVL(PKG_CONTEXTO.FN_rol, '?') NOT IN ('ADMINISTRADOR', 'MEDICO', 'FARMACEUTICO') THEN
      RAISE_APPLICATION_ERROR(-20005, 'No tiene permiso para consultar los medicamentos');
    END IF;

    OPEN crs_medicamentos FOR
      SELECT m.ID_MEDICAMENTO,
             m.NOMBRE,
             m.DESCRIPCION,
             p.VALOR               AS PRESENTACION,
             s.CANTIDAD_DISPONIBLE,
             s.CANTIDAD_MINIMA
      FROM   TBL_MEDICAMENTOS    m
      JOIN   TBL_PARAMETROS      p ON p.ID_PARAM       = m.ID_PRESENTACION
      LEFT   JOIN TBL_STOCK_FARMACIA s ON s.ID_MEDICAMENTO = m.ID_MEDICAMENTO
      ORDER  BY m.NOMBRE;

    -- Solo lectura: no hay COMMIT.
  END PRO_LISTAR_MEDICAMENTOS;

  ---------------------------------------------------------------------
  -- PRO_DETALLES_PENDIENTES
  ---------------------------------------------------------------------
  PROCEDURE PRO_DETALLES_PENDIENTES(crs_detalles OUT SYS_REFCURSOR) IS
  BEGIN
    IF PKG_CONTEXTO.FN_id_usuario IS NULL
       OR NVL(PKG_CONTEXTO.FN_rol, '?') <> 'FARMACEUTICO' THEN
      RAISE_APPLICATION_ERROR(-20005, 'Solo un farmaceutico puede consultar las entregas pendientes');
    END IF;

    OPEN crs_detalles FOR
      SELECT d.ID_DETALLE,
             d.ID_RECETA,
             r.FECHA_EMISION,
             pa.NOMBRE || ' ' || pa.APELLIDO AS PACIENTE,
             pa.DOCUMENTO,
             m.NOMBRE                         AS MEDICAMENTO,
             d.CANTIDAD,
             d.CANTIDAD_PENDIENTE,
             d.DOSIS,
             s.CANTIDAD_DISPONIBLE            AS STOCK_DISPONIBLE,
             e.VALOR                          AS ESTADO
      FROM   TBL_DETALLE_RECETA   d
      JOIN   TBL_RECETAS_MEDICAS  r  ON r.ID_RECETA      = d.ID_RECETA
      JOIN   TBL_HISTORIA_CLINICA h  ON h.ID_HISTORIA    = r.ID_HISTORIA
      JOIN   TBL_CITAS_MEDICAS    c  ON c.ID_CITA        = h.ID_CITA
      JOIN   TBL_PACIENTES        pa ON pa.ID_PACIENTE   = c.ID_PACIENTE
      JOIN   TBL_MEDICAMENTOS     m  ON m.ID_MEDICAMENTO = d.ID_MEDICAMENTO
      JOIN   TBL_PARAMETROS       e  ON e.ID_PARAM       = d.ID_ESTADO
      LEFT   JOIN TBL_STOCK_FARMACIA s ON s.ID_MEDICAMENTO = d.ID_MEDICAMENTO
      WHERE  d.CANTIDAD_PENDIENTE > 0
      ORDER  BY r.FECHA_EMISION, d.ID_DETALLE;

    -- Solo lectura: no hay COMMIT.
  END PRO_DETALLES_PENDIENTES;

  ---------------------------------------------------------------------
  -- PRO_DETALLE_RECETA
  ---------------------------------------------------------------------
  PROCEDURE PRO_DETALLE_RECETA(vn_id_receta IN  NUMBER,
                               crs_detalles OUT SYS_REFCURSOR) IS

    va_rol           VARCHAR2(50) := PKG_CONTEXTO.FN_rol;
    vn_medico_ctx    NUMBER       := PKG_CONTEXTO.FN_id_entidad;
    vn_medico_receta NUMBER;

  BEGIN
    IF PKG_CONTEXTO.FN_id_usuario IS NULL
       OR NVL(va_rol, '?') NOT IN ('MEDICO', 'FARMACEUTICO') THEN
      RAISE_APPLICATION_ERROR(-20005, 'No tiene permiso para consultar recetas');
    END IF;

    IF vn_id_receta IS NULL OR vn_id_receta <= 0 THEN
      RAISE_APPLICATION_ERROR(-20085, 'Indique la receta que desea consultar');
    END IF;

    -- La receta existe; si quien consulta es medico, debe ser la suya
    BEGIN
      SELECT ag.ID_MEDICO
      INTO   vn_medico_receta
      FROM   TBL_RECETAS_MEDICAS  r
      JOIN   TBL_HISTORIA_CLINICA h  ON h.ID_HISTORIA = r.ID_HISTORIA
      JOIN   TBL_CITAS_MEDICAS    c  ON c.ID_CITA     = h.ID_CITA
      JOIN   TBL_AGENDA_MEDICO    ag ON ag.ID_AGENDA  = c.ID_AGENDA
      WHERE  r.ID_RECETA = vn_id_receta;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'No se encontro la receta');
    END;

    IF va_rol = 'MEDICO' AND NVL(vn_medico_ctx, -1) <> vn_medico_receta THEN
      RAISE_APPLICATION_ERROR(-20005, 'La receta no corresponde a este medico');
    END IF;

    OPEN crs_detalles FOR
      SELECT d.ID_DETALLE,
             d.ID_MEDICAMENTO,
             m.NOMBRE                      AS MEDICAMENTO,
             d.DOSIS,
             d.CANTIDAD,
             d.CANTIDAD - d.CANTIDAD_PENDIENTE AS CANTIDAD_ENTREGADA,
             d.CANTIDAD_PENDIENTE,
             e.VALOR                       AS ESTADO,
             f.NOMBRE || ' ' || f.APELLIDO AS FARMACEUTICO,
             d.FECHA_ENTREGA
      FROM   TBL_DETALLE_RECETA d
      JOIN   TBL_MEDICAMENTOS   m ON m.ID_MEDICAMENTO = d.ID_MEDICAMENTO
      JOIN   TBL_PARAMETROS     e ON e.ID_PARAM       = d.ID_ESTADO
      LEFT   JOIN TBL_FARMACEUTICOS f ON f.ID_FARMACEUTICO = d.ID_FARMACEUTICO
      WHERE  d.ID_RECETA = vn_id_receta
      ORDER  BY d.ID_DETALLE;

    -- Solo lectura: no hay COMMIT.
  END PRO_DETALLE_RECETA;

END PKG_FARMACIA;
/

/* ---------------------------------------------------------------------
   Si hay errores de compilacion:
     SHOW ERRORS PACKAGE PKG_FARMACIA
     SHOW ERRORS PACKAGE BODY PKG_FARMACIA
   --------------------------------------------------------------------- */

---------------------------------------------------------------------
-- VERIFICACIONES (solo lectura: no modifican datos)
---------------------------------------------------------------------
-- V1. Los 2 objetos deben salir VALID
SELECT OBJECT_NAME, OBJECT_TYPE, STATUS
FROM   USER_OBJECTS
WHERE  OBJECT_NAME = 'PKG_FARMACIA'
ORDER  BY OBJECT_TYPE;

-- V2. Errores de compilacion, si los hubiera (esperado: 0 filas)
SELECT NAME, TYPE, LINE, POSITION, TEXT
FROM   USER_ERRORS
WHERE  NAME = 'PKG_FARMACIA'
ORDER  BY TYPE, SEQUENCE;

-- V3. Lista de medicamentos con el contexto de un farmaceutico
--     (esperado: 20 filas; los medicamentos 4, 13 y 14 con stock bajo el minimo)
VAR c1 REFCURSOR
BEGIN
  PKG_CONTEXTO.SET_USUARIO(15, 'FARMACEUTICO', 1);
  PKG_FARMACIA.PRO_LISTAR_MEDICAMENTOS(:c1);
  PKG_CONTEXTO.LIMPIAR;
END;
/
PRINT c1

-- V4. Detalles pendientes de entrega (esperado: filas con paciente y stock)
VAR c2 REFCURSOR
BEGIN
  PKG_CONTEXTO.SET_USUARIO(15, 'FARMACEUTICO', 1);
  PKG_FARMACIA.PRO_DETALLES_PENDIENTES(:c2);
  PKG_CONTEXTO.LIMPIAR;
END;
/
PRINT c2

/* Las pruebas que escriben (crear receta, detalle, entrega, concurrencia)
   van en pruebas_hu05.sql, Fase 4. Antes de ejecutarlas, respaldar el
   stock: CREATE TABLE TBL_STOCK_RESPALDO AS SELECT * FROM TBL_STOCK_FARMACIA; */

/* ======================= FIN DE PKG_FARMACIA (HU05) ======================= */
