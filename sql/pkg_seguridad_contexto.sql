/* =====================================================================
   PROYECTO PL/SQL - SISTEMA DE GESTION DE CITAS MEDICAS
   Paquetes de apoyo para el backend: PKG_SEGURIDAD y PKG_CONTEXTO
   ---------------------------------------------------------------------
   Por que existe este archivo:
     El backend (Spring Boot) llama a estos dos paquetes y NO existian
     en la BD. Sin ellos sale el error:
       PLS-00201: el identificador 'PKG_SEGURIDAD.LOGIN' se debe declarar
     - PKG_SEGURIDAD.LOGIN        -> lo usa POST /api/auth/login
     - PKG_CONTEXTO.SET_USUARIO   -> lo usa TODA peticion despues del
       PKG_CONTEXTO.LIMPIAR          login (reservar, cancelar, etc.)
   ---------------------------------------------------------------------
   Ejecucion : conectado como PROYECTOPLSQL, con F5 (Ejecutar script).
   Requisito : tablas TBL_USUARIOS y TBL_ROLES con datos cargados.
               Oracle 12.2 o superior (usa STANDARD_HASH).
   ---------------------------------------------------------------------
   OJO con los nombres: el backend ya llama LOGIN, SET_USUARIO y LIMPIAR
   (sin prefijo PRO_). Se dejan asi para no tocar el Java. Si el grupo
   decide aplicar el prefijo PRO_, hay que cambiar tambien
   AuthRepository.java y ContextoOracle.java.
   Codigo de error: -20006 = usuario o contrasena incorrectos (el
   backend lo convierte en HTTP 401).
   ===================================================================== */

---------------------------------------------------------------------
-- 1. PKG_CONTEXTO: guarda quien es el usuario de la peticion actual
---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE PKG_CONTEXTO AS

  /* El backend la llama al inicio de cada peticion con los datos del
     token (JWT). Los procedimientos pueden consultarlos con las FN_. */
  PROCEDURE SET_USUARIO(vn_id_usuario IN NUMBER,
                        va_rol        IN VARCHAR2,
                        vn_id_entidad IN NUMBER);

  /* El backend la llama al final de cada peticion para que la conexion
     vuelva limpia al pool (otra peticion de otro usuario la reutiliza). */
  PROCEDURE LIMPIAR;

  FUNCTION FN_id_usuario RETURN NUMBER;
  FUNCTION FN_rol        RETURN VARCHAR2;
  FUNCTION FN_id_entidad RETURN NUMBER;

END PKG_CONTEXTO;
/

CREATE OR REPLACE PACKAGE BODY PKG_CONTEXTO AS

  -- Variables del paquete: viven mientras dure la sesion de Oracle
  vn_usuario_actual  NUMBER;
  va_rol_actual      VARCHAR2(50);
  vn_entidad_actual  NUMBER;

  PROCEDURE SET_USUARIO(vn_id_usuario IN NUMBER,
                        va_rol        IN VARCHAR2,
                        vn_id_entidad IN NUMBER) IS
  BEGIN
    vn_usuario_actual := vn_id_usuario;
    va_rol_actual     := UPPER(TRIM(va_rol));
    vn_entidad_actual := vn_id_entidad;
  END SET_USUARIO;

  PROCEDURE LIMPIAR IS
  BEGIN
    vn_usuario_actual := NULL;
    va_rol_actual     := NULL;
    vn_entidad_actual := NULL;
  END LIMPIAR;

  FUNCTION FN_id_usuario RETURN NUMBER IS
  BEGIN
    RETURN vn_usuario_actual;
  END FN_id_usuario;

  FUNCTION FN_rol RETURN VARCHAR2 IS
  BEGIN
    RETURN va_rol_actual;
  END FN_rol;

  FUNCTION FN_id_entidad RETURN NUMBER IS
  BEGIN
    RETURN vn_entidad_actual;
  END FN_id_entidad;

END PKG_CONTEXTO;
/

---------------------------------------------------------------------
-- 2. PKG_SEGURIDAD: valida usuario y contrasena (la logica en la BD)
---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE PKG_SEGURIDAD AS

  /* Valida las credenciales. Si son correctas devuelve el id del
     usuario, su rol (en MAYUSCULAS, p. ej. MEDICO) y el id de la
     entidad (medico, paciente o farmaceutico). Si no, lanza -20006.
     El orden de los parametros es el que espera AuthRepository.java. */
  PROCEDURE LOGIN(va_username    IN  VARCHAR2,
                  va_password    IN  VARCHAR2,
                  vn_id_usuario  OUT NUMBER,
                  va_rol         OUT VARCHAR2,
                  vn_id_entidad  OUT NUMBER);

END PKG_SEGURIDAD;
/

CREATE OR REPLACE PACKAGE BODY PKG_SEGURIDAD AS

  PROCEDURE LOGIN(va_username    IN  VARCHAR2,
                  va_password    IN  VARCHAR2,
                  vn_id_usuario  OUT NUMBER,
                  va_rol         OUT VARCHAR2,
                  vn_id_entidad  OUT NUMBER) IS

    va_hash_guardado   TBL_USUARIOS.PASSWORD_HASH%TYPE;
    va_estado          TBL_USUARIOS.ESTADO%TYPE;
    va_hash_recibido   VARCHAR2(64);

  BEGIN
    ----------------------------------------------------------------
    -- 1. Datos vacios -> mismo mensaje generico (no se dice cual fallo)
    ----------------------------------------------------------------
    IF TRIM(va_username) IS NULL OR va_password IS NULL THEN
      RAISE_APPLICATION_ERROR(-20006, 'Usuario o contrasena incorrectos');
    END IF;

    ----------------------------------------------------------------
    -- 2. Buscar el usuario y su rol
    ----------------------------------------------------------------
    BEGIN
      SELECT u.ID_USUARIO, UPPER(TRIM(r.NOMBRE_ROL)), u.ID_ENTIDAD,
             u.PASSWORD_HASH, u.ESTADO
      INTO   vn_id_usuario, va_rol, vn_id_entidad,
             va_hash_guardado, va_estado
      FROM   TBL_USUARIOS u
      JOIN   TBL_ROLES    r ON r.ID_ROL = u.ID_ROL
      WHERE  u.USERNAME = TRIM(va_username);
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20006, 'Usuario o contrasena incorrectos');
    END;

    ----------------------------------------------------------------
    -- 3. Calcular SHA-256 de la contrasena recibida y comparar.
    --    Se compara en MAYUSCULAS porque Python guarda el hex en
    --    minusculas y Oracle lo devuelve en mayusculas.
    ----------------------------------------------------------------
    SELECT RAWTOHEX(STANDARD_HASH(va_password, 'SHA256'))
    INTO   va_hash_recibido
    FROM   DUAL;

    IF UPPER(va_hash_guardado) <> va_hash_recibido OR va_estado <> 'A' THEN
      RAISE_APPLICATION_ERROR(-20006, 'Usuario o contrasena incorrectos');
    END IF;

    -- Solo lectura: no hay COMMIT.
  END LOGIN;

END PKG_SEGURIDAD;
/

/* ---------------------------------------------------------------------
   Si hay errores de compilacion:
     SHOW ERRORS PACKAGE BODY PKG_SEGURIDAD
     SHOW ERRORS PACKAGE BODY PKG_CONTEXTO
   --------------------------------------------------------------------- */

---------------------------------------------------------------------
-- 3. Verificaciones
---------------------------------------------------------------------
-- 3.1 Los 4 objetos deben salir VALID
SELECT OBJECT_NAME, OBJECT_TYPE, STATUS
FROM   USER_OBJECTS
WHERE  OBJECT_NAME IN ('PKG_SEGURIDAD', 'PKG_CONTEXTO')
ORDER  BY OBJECT_NAME, OBJECT_TYPE;

-- 3.2 Nombres de rol: el frontend espera ADMINISTRADOR, MEDICO,
--     RECEPCIONISTA, FARMACEUTICO o PACIENTE (en mayusculas, sin tildes)
SELECT ID_ROL, NOMBRE_ROL, UPPER(TRIM(NOMBRE_ROL)) AS ROL_QUE_VE_EL_FRONT
FROM   TBL_ROLES;

-- 3.3 El hash de la contrasena de prueba debe coincidir (COINCIDE = S)
SELECT USERNAME, ESTADO,
       CASE WHEN UPPER(PASSWORD_HASH) =
                 RAWTOHEX(STANDARD_HASH('Clinica2026*', 'SHA256'))
            THEN 'S' ELSE 'N' END AS COINCIDE
FROM   TBL_USUARIOS
WHERE  ROWNUM <= 5;

-- 3.4 Probar el login a mano (cambiar 'USUARIO_AQUI' por un USERNAME
--     real de la consulta anterior). Esperado: imprime id, rol y entidad.
SET SERVEROUTPUT ON
DECLARE
  vn_id_usuario  NUMBER;
  va_rol         VARCHAR2(50);
  vn_id_entidad  NUMBER;
BEGIN
  PKG_SEGURIDAD.LOGIN(va_username   => 'USUARIO_AQUI',
                      va_password   => 'Clinica2026*',
                      vn_id_usuario => vn_id_usuario,
                      va_rol        => va_rol,
                      vn_id_entidad => vn_id_entidad);
  DBMS_OUTPUT.PUT_LINE('OK -> usuario ' || vn_id_usuario ||
                       ', rol ' || va_rol || ', entidad ' || vn_id_entidad);
END;
/

/* ================ FIN DE PKG_SEGURIDAD y PKG_CONTEXTO ================ */
