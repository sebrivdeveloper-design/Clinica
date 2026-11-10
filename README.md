# Sistema de citas médicas — Bases de Datos I

Arquitectura: **Oracle (datos + lógica PL/SQL) → Spring Boot (intermediario JDBC) → React (presentación)**.

```
proyectoClinica/
├── backend/    Spring Boot 4.1.2 · Java 21 · JDBC · JWT HS256
└── frontend/   React 19 · Vite · TypeScript
```

## Ejecutar

Requisitos: Oracle XE en `localhost:1521/XE` con el esquema `PROYECTOPLSQL`, Java 21, Node 20+.

```bash
# 1) Backend (puerto 8080)
cd backend
./mvnw spring-boot:run          # Windows: mvnw.cmd spring-boot:run

# 2) Frontend (puerto 5180)
cd frontend
npm install
npm run dev                     # abrir http://localhost:5180
```

- URL del backend para el frontend: `frontend/.env` → `VITE_API_BASE_URL` (ver `.env.example`).
- Orígenes permitidos por CORS: `app.cors.allowed-origins` en `application.properties`.
- Duración del token: `app.jwt.expiration-minutes` (60 por defecto).
- Compilar para producción: `npm run build` (frontend) y `./mvnw package` (backend).

## Flujo de cada petición

1. El frontend envía `Authorization: Bearer <JWT>`.
2. Spring Security valida firma y expiración del JWT (no valida permisos por rol).
3. `ContextoOracle` llama `PKG_CONTEXTO.SET_USUARIO(idUsuario, rol, idEntidad)` en la misma conexión.
4. Se invoca el procedimiento PL/SQL. Oracle aplica reglas, permisos (-20005) y hace COMMIT.
5. `PKG_CONTEXTO.LIMPIAR` y respuesta JSON. Errores `-200xx` → `{"error": "...", "codigo": 200xx}`.

> Java **no** hace COMMIT. Con `hikari.auto-commit=false`, si un procedimiento no hace COMMIT,
> el pool revierte los cambios al devolver la conexión. Cada procedimiento de escritura debe confirmar su transacción.

## Estado de los endpoints

| Endpoint | Estado |
|---|---|
| `POST /api/auth/login` | **Disponible** (`PKG_SEGURIDAD.LOGIN`) |
| `GET /api/agenda/disponible?idMedico=` | Pendiente PL/SQL → 501 |
| `POST /api/citas` | Pendiente PL/SQL → 501 |
| `PUT /api/citas/{id}/cancelar` | Pendiente PL/SQL → 501 |
| `POST /api/citas/cancelacion-masiva` | Pendiente PL/SQL → 501 |
| `POST /api/historias` · `GET /api/historias` | Pendiente PL/SQL → 501 |
| `POST /api/recetas` · `POST /api/recetas/{id}/detalle` | Pendiente PL/SQL → 501 |
| `POST /api/recetas/detalle/{id}/entrega` | Pendiente PL/SQL → 501 |
| `GET /api/medicamentos` | Pendiente PL/SQL → 501 |
| `GET /api/reportes/resumen?desde=&hasta=` | Pendiente PL/SQL → 501 |

Los pendientes ya validan JWT y establecen el contexto Oracle; responden **501** con un mensaje claro y
la interfaz muestra "Pendiente de integración con Oracle" (nunca un éxito simulado).

## Cómo conectar un procedimiento cuando el equipo lo implemente

Solo se modifica el método del repositorio correspondiente (`citas/`, `historias/`, `farmacia/`, `reportes/`):

```java
public Map<String, Object> reservar(UsuarioSesion u, ReservaCitaRequest req) {
    return contexto.ejecutar(u, con -> {
        try (CallableStatement cs = con.prepareCall("{call PKG_XXX.RESERVAR_CITA(?, ?, ?, ?)}")) {
            cs.setLong(1, req.idPaciente());
            cs.setLong(2, req.idAgenda());
            cs.setString(3, req.observacion());
            cs.registerOutParameter(4, Types.NUMERIC);
            cs.execute();
            return Map.of("idCita", cs.getLong(4));
        }
    });
}
```

Para consultas que devuelven `SYS_REFCURSOR`:

```java
cs.registerOutParameter(n, oracle.jdbc.OracleTypes.CURSOR);
cs.execute();
try (ResultSet rs = (ResultSet) cs.getObject(n)) { return CursorMapper.aLista(rs); }
```

`CursorMapper` convierte columnas a camelCase (`FECHA_HORA_INICIO` → `fechaHoraInicio`), que es lo que
espera el frontend (`src/types/*.ts`). El frontend no necesita cambios.

**Cuerpos de petición propuestos** (derivados de las tablas; ajustar si el procedimiento requiere otros):

| Endpoint | Body |
|---|---|
| `POST /api/citas` | `{ idPaciente, idAgenda, observacion? }` |
| `PUT /api/citas/{id}/cancelar` | `{ observacion? }` (opcional) |
| `POST /api/citas/cancelacion-masiva` | `{ idMedico, desde: "yyyy-MM-dd", hasta: "yyyy-MM-dd", observacion? }` |
| `POST /api/historias` | `{ idCita, diagnostico, notasMedicas? }` |
| `POST /api/recetas` | `{ idHistoria }` |
| `POST /api/recetas/{id}/detalle` | `{ idMedicamento, cantidad, dosis }` |
| `POST /api/recetas/detalle/{id}/entrega` | `{ cantidad }` |

**Respuestas que el frontend sabe leer** (si existen): `idCita`, `idHistoria`, `idReceta`, `idDetalle`,
`citasCanceladas`. Para `reportes/resumen`, cualquier objeto: valores simples se muestran como indicadores y
listas como tablas.

## Códigos de error

| Código | HTTP | Mensaje en la interfaz |
|---|---|---|
| 20001 | 409 | El médico ya tiene ocupado ese horario |
| 20002 | 404 | No se encontró el registro solicitado |
| 20003 | 409 | La cita no está en un estado válido para esta operación |
| 20004 | 409 | No hay stock suficiente del medicamento |
| 20005 | 403 | No tiene permiso para realizar esta operación |
| 20006 | 401 | Usuario o contraseña incorrectos |
| 20007 | 409 | Aún faltan medicamentos por entregar |
| otro 200xx | 422 | Mensaje enviado por Oracle |

## Estructura del frontend

```
frontend/src/
├── config/env.ts           URL base desde VITE_API_BASE_URL
├── api/                    cliente HTTP (Bearer, 401 → cierre de sesión), ApiError, mensajes por código
├── auth/                   AuthContext (JWT, expiración), tokenStorage, rutas protegidas
├── services/               authService, citasService, historiaService, farmaciaService, reportesService
├── types/                  contratos de datos por módulo
├── hooks/                  useConsulta (GET con carga/error), useEnvio (operaciones + notificaciones)
├── components/ui/          Button, Card, DataTable, ConfirmDialog, Toast, Tabs, Form, estados
├── layout/AppLayout.tsx    barra lateral por rol + barra superior (responsive)
├── navigation/menu.ts      menú y roles por módulo (organización visual; Oracle valida permisos)
├── pages/                  pantallas
└── styles/global.css       sistema visual
```
