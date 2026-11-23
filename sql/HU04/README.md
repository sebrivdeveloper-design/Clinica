# HU04 – Verificación de estado de la cita (trigger)

Responsable: Álvaro

Scripts .sql de esta HU. Después de hacer pull, ejecutar con F5 en SQL Developer (conectado como PROYECTOPLSQL) los archivos nuevos o modificados.

## Instalación

Con las tablas y `sql/pkg_constantes.sql` disponibles, ejecutar únicamente
`trg_historia_validar_cita.sql`. Crea el trigger independiente
`TRG_HISTORIA_VALIDAR_CITA`, `BEFORE INSERT FOR EACH ROW` sobre
`TBL_HISTORIA_CLINICA`. Revisar `SHOW ERRORS` y el estado `VALID` y `ENABLED`.

`PROGRAMADA` se representa por `PKG_CONSTANTES.cita_pendiente` (catálogo C1,
valor Pendiente). No se fijan IDs numéricos. Los demás estados producen
`ORA-20060`; Spring devuelve HTTP 409 con `{error, codigo: 20060}` y React
muestra el detalle usando `useEnvio` y `Toast`. No se cambió el formulario:
solo limpia campos y anuncia éxito cuando la petición termina correctamente.

El identificador nulo y la cita inexistente se dejan a NOT NULL (ORA-01400)
y `FK_HISTORIA_CITAS` (ORA-02291). La unicidad sigue a cargo de
`UQ_HISTORIA_CITA` (ORA-00001). No son nuevos errores de aplicación.
La traducción HTTP de esos errores nativos mantiene el comportamiento previo.
Los errores inesperados, incluidos los del catálogo, se propagan.

No hay COMMIT ni ROLLBACK en el trigger. HU03 debe insertar la historia antes
de cambiar la cita al estado final y confirmar su unidad de trabajo. La base
inspeccionada representa ese estado como Finalizada (C3), aunque la HU diga
ATENDIDA. La lectura del trigger valida el estado visible durante el INSERT;
no añade un bloqueo de la cita ni nuevas reglas de concurrencia.

## Verificación y límites

`pruebas_hu04.sql` prepara los casos de estado, FK, NOT NULL, unicidad y
rollback para una **copia aislada autorizada**, nunca para la base compartida.
Necesita datos base de paciente y agenda. Revierte sus filas, pero puede
consumir valores de secuencias. Revisar otros triggers antes de ejecutarlo.

El test Java `GlobalExceptionHandlerTest` verifica código 20060, HTTP 409 y
mensaje sin traza Oracle. Para probar React con HU03 disponible: intentar
registrar una cita cancelada, comprobar el aviso con el detalle, que no haya
aviso nuevo de éxito y que diagnóstico y notas permanezcan; repetir con una
cita pendiente y confirmar el éxito solo tras la respuesta del servidor.

La integración real desde `POST /api/historias` sigue pendiente de HU03:
`HistoriasRepository.registrar` responde 501. HU04 no implementa ese procedimiento
ni su llamada JDBC. El trigger y las pruebas SQL no se despliegan automáticamente.
