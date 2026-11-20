# Backend y base de datos local

Desde la carpeta del proyecto:

```powershell
.\INICIAR_BACKEND.cmd
.\VER_BASE_DATOS.cmd
```

El primer acceso comprueba PostgreSQL, aplica las migraciones idempotentes y
reutiliza la API si ya está activa. Si debe iniciarla, compila el código actual
y deja el proceso en segundo plano. Los registros quedan en `backend/.local/api.log`
y `backend/.local/api-error.log`.

`INICIAR_JUEGO.cmd` usa la misma comprobación antes de abrir Godot. Busca el
ejecutable de Godot 4 en Descargas o en el `PATH`; si está en otra ubicación,
configura `GODOT_EXE` con su ruta. Utiliza el perfil normal del jugador y no
crea un progreso separado en `backend/.local`.

La API usa el `PORT` de `backend/.env` (por defecto, `4000`) y PostgreSQL usa
`DATABASE_URL` del mismo archivo. No se fija un puerto de PostgreSQL ni una
instalación particular de Windows en el código.

Verificación de API y conexión a PostgreSQL: `http://localhost:4000/health`
(o el puerto configurado en `.env`).
Debe mostrar `status: ok` y `database: connected`.

## Consultar los datos

`VER_BASE_DATOS.cmd` abre la consola SQL conectada a la misma base del backend.
Requiere `psql` en el `PATH` o la variable `PSQL_EXE` con su ruta.

```sql
SELECT * FROM player_customization ORDER BY updated_at DESC;
SELECT * FROM player_place_progress ORDER BY updated_at DESC;
SELECT * FROM player_quest_progress ORDER BY updated_at DESC;
SELECT * FROM outfits;
SELECT * FROM hair_styles;
```

Cada consulta termina con `;`. Para listar tablas usa `\dt`; para salir, `\q`.
Después de guardar en el juego, vuelve a ejecutar la consulta para ver el cambio.

Si prefieres pgAdmin 4, conecta el servidor indicado por `DATABASE_URL` en
`backend/.env` y abre la base indicada en esa URL. Luego entra en
Schemas > public > Tables para consultar las filas.

## Desarrollo con recarga automática

Si el backend está activo, detén primero su terminal con Ctrl+C. Para una instancia
en segundo plano, identifica su PID antes de detenerla:

```powershell
Get-NetTCPConnection -LocalPort 4000 -State Listen | Select-Object OwningProcess
Stop-Process -Id <PID>
cd backend
npm.cmd run dev
```

No ejecutes un segundo servidor en el mismo puerto. `npm.cmd` evita el bloqueo de
`npm.ps1` sin modificar la política de PowerShell. Si cambias `PORT` en `.env`,
configura también `VIDEOJUEGO_API_BASE_URL` para Godot con la nueva URL; el valor
por defecto de ambos es `4000`.

Las pruebas se ejecutan con `npm.cmd test` desde `backend` y usan exclusivamente
la base separada `videojuego_rpg_test`, configurada en `.env.test`.
