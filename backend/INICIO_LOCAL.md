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

`INICIAR_JUEGO.cmd` usa la misma comprobación antes de abrir Godot.

Configuración actual: API `http://localhost:4001`; PostgreSQL `localhost:5432`;
base `videojuego_rpg`; usuario `postgres`. Las credenciales se leen de
`backend/.env`. No se usa el clúster alternativo del puerto 5433.

Verificación de API y conexión a PostgreSQL: `http://localhost:4001/health`.
Debe mostrar `status: ok` y `database: connected`.

## Consultar los datos

`VER_BASE_DATOS.cmd` abre la consola SQL conectada a la misma base del backend.

```sql
SELECT * FROM player_customization ORDER BY updated_at DESC;
SELECT * FROM player_place_progress ORDER BY updated_at DESC;
SELECT * FROM outfits;
SELECT * FROM hair_styles;
```

Cada consulta termina con `;`. Para listar tablas usa `\dt`; para salir, `\q`.
Después de guardar en el juego, vuelve a ejecutar la consulta para ver el cambio.

Si prefieres pgAdmin 4, usa Tools > Import/Export Servers > Import y selecciona
`backend/.local/pgadmin-servidor.json`. El archivo apunta al servidor del puerto
5432. Luego abre Databases > videojuego_rpg > Schemas > public > Tables;
clic derecho en una tabla > View/Edit Data > All Rows.

## Desarrollo con recarga automática

Si el backend está activo, detén primero su terminal con Ctrl+C. Para una instancia
en segundo plano, identifica su PID antes de detenerla:

```powershell
Get-NetTCPConnection -LocalPort 4001 -State Listen | Select-Object OwningProcess
Stop-Process -Id <PID>
cd backend
npm.cmd run dev
```

No ejecutes un segundo servidor en el mismo puerto. `npm.cmd` evita el bloqueo de
`npm.ps1` sin modificar la política de PowerShell. El puerto de `.env` debe coincidir
con `API_BASE_URL` en `scripts/services/api_service.gd`.

Las pruebas se ejecutan con `npm.cmd test` desde `backend` y usan exclusivamente
la base separada `videojuego_rpg_test`, configurada en `.env.test`.
