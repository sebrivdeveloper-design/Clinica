# HU02 – Cancelación de citas

Responsable: Sofía

**Depende de la HU01.** La cancelación vive dentro de `PKG_CITAS`, el mismo paquete de la HU01, y reutiliza su procedimiento `PRC_SINCRONIZAR_ESTADO_AGENDA` para recalcular el estado del turno. Por eso el código está en [`../HU01/pkg_citas_hu01.sql`](../HU01/pkg_citas_hu01.sql), entre las marcas `INICIO HU02 / FIN HU02`.

| Archivo | Para qué |
|---|---|
| `../HU01/pkg_citas_hu01.sql` | `PKG_CITAS` completo (HU01 + HU02): `PRC_CANCELAR_CITA` y `PRO_CANCELAR_CITA` |
| `pruebas_hu02.sql` | 12 pruebas (validaciones, permisos y turno Ocupado → Libre) |
| `reseteo_hu02.sql` | Deja los datos como antes de las pruebas, para repetirlas |

## Qué hace
- Solo cancela citas **Pendientes**. Guarda el motivo en `OBSERVACION` como `Paciente: ...` o `Clinica: ...`.
- El origen sale del rol del usuario: un `PACIENTE` cancela como *Paciente*; `ADMINISTRADOR` y `RECEPCIONISTA` como *Clinica*. Un paciente solo puede cancelar sus propias citas.
- Libera la franja: si el turno estaba **Ocupado** pasa a **Libre**; si está **En cirugía** no se toca.
- Bloqueo pesimista: primero el turno y después la cita (mismo orden que la HU01).

## Códigos de error
| Código | HTTP | Cuándo |
|---|---|---|
| -20001 | 409 | Otro usuario está modificando el turno o la cita (esperó 10 s) |
| -20002 | 404 | La cita no existe |
| -20005 | 403 | Sin permiso (rol no autorizado o cita de otro paciente) |
| -20007 | 409 | La cita no está Pendiente |
| -20020 | 422 | Origen distinto de Paciente o Clinica |
| -20021 | 422 | Motivo vacío |
| -20022 | 422 | Motivo de más de 500 caracteres (con el origen) |
| -20023 | 422 | La cita no se pudo actualizar |

## Orden de ejecución (F5, conectado como `PROYECTOPLSQL`)
1. `sql/pkg_constantes.sql` (fecha 30/04/2026) y `sql/pkg_seguridad_contexto.sql`.
2. `sql/HU01/pkg_citas_hu01.sql`.
3. `pruebas_hu02.sql`. Para repetir: `reseteo_hu02.sql` y otra vez las pruebas.
