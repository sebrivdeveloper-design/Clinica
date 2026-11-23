# HU03 – Registro de consulta médica

Responsable: Juan David

Scripts .sql de esta HU. Después de hacer pull, ejecutar con F5 en SQL Developer (conectado como PROYECTOPLSQL) los archivos nuevos o modificados.

# Objetivo

Registrar el diagnóstico y las notas clínicas al finalizar una consulta médica, creando una entrada en `TBL_HISTORIA_CLINICA` y actualizando el estado de la cita a Finalizada, dentro de una misma transacción.

# Scripts

| Archivo | Descripción |
|---|---|
| `pkg_historia.sql` | Especificación y cuerpo del package `PKG_HISTORIA`. |
| `pruebas_hu03.sql` | Pruebas funcionales, validaciones, permisos y manejo de errores. |
| `limpieza_hu03.sql` | Elimina los registros temporales generados por las pruebas. |

# Procedimiento

`PKG_HISTORIA.registrar_consulta`

# Parámetros

| Parámetro | Tipo | Dirección | Descripción |
|---|---|---|---|
| `p_id_cita` | NUMBER | IN | Identificador de la cita. |
| `p_diagnostico` | VARCHAR2 | IN | Diagnóstico médico (obligatorio, máximo 1000 caracteres). |
| `p_notas_medicas` | VARCHAR2 | IN | Notas clínicas (opcional, máximo 4000 caracteres). |
| `p_id_historia` | NUMBER | OUT | Identificador de la historia clínica generada. |

# Funcionamiento

1. Valida el contexto de seguridad y el rol MEDICO.
2. Valida los parámetros recibidos.
3. Verifica la existencia de la cita y bloquea su fila.
4. Comprueba que el médico autenticado sea el asignado a la cita.
5. Inserta el registro en `TBL_HISTORIA_CLINICA`.
6. El trigger de HU04 valida que la cita se encuentre pendiente.
7. Actualiza el estado de la cita a Finalizada, utilizando `PKG_CONSTANTES.cita_finalizada`.
8. Recupera el `ID_HISTORIA` generado.
9. Confirma ambas operaciones mediante COMMIT.

Ante cualquier error, ejecuta ROLLBACK y propaga la excepción.

# Dependencias

- `TBL_CITAS_MEDICAS`
- `TBL_AGENDA_MEDICO`
- `TBL_HISTORIA_CLINICA`
- `TBL_MEDICOS`
- `TBL_USUARIOS`
- `PKG_CONSTANTES`
- `PKG_CONTEXTO`
- Trigger `TRG_HISTORIA_VALIDAR_CITA` (HU04)

# Códigos de error

| Código | Descripción |
|---|---|
| `-20040` | Datos inválidos. |
| `-20041` | Cita inexistente. |
| `-20042` | Usuario sin permisos o médico no propietario de la cita. |
| `-20060` | Cita no pendiente, validada por el trigger HU04. |
| `-1` | Historia duplicada, por restricción UNIQUE de Oracle. |

# Ejecución

Conectado como `PROYECTOPLSQL` en Oracle SQL Developer:

1. Ejecutar `pkg_historia.sql` con F5.
2. Verificar que el PACKAGE y PACKAGE BODY estén VALID.
3. Ejecutar `pruebas_hu03.sql` con F5.
4. Comprobar el resumen de pruebas.
5. Si la ejecución se interrumpe, ejecutar `limpieza_hu03.sql`.

Los scripts de pruebas crean datos temporales identificados con `HU03TEST0001` y los eliminan al finalizar.

# Resultado esperado

- Consulta registrada correctamente.
- ID de historia clínica generado.
- Cita actualizada a Finalizada (C3).
- No se permiten historias duplicadas.
- Las operaciones fallidas no generan historias clínicas.
- Los datos temporales de pruebas se eliminan al terminar.