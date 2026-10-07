# RedVital databases

Esquemas SQL separados del código de cada servicio y versionados con Flyway.
Cada servicio persistente tiene una instancia PostgreSQL independiente:

| Servicio | Base | Estado del esquema |
|---|---|---|
| Identidad | `db_identidad` | Migraciones versionadas V001–V003 |
| Campañas | `db_campana` | Migraciones versionadas V001–V002 |
| Donación | `db_donacion` | Base vacía; pendiente del esquema aprobado por sus responsables |
| Institucional | `db_institucional` | Base vacía; pendiente del esquema aprobado por sus responsables |
| Notificaciones | — | No requiere base de negocio |

Las cuatro bases tienen volúmenes y redes aislados con nombres estables
(`redvital_identidad_data`, `redvital_campana_data`,
`redvital_donacion_data`, `redvital_institucional_data`); el nombre de cada
red se puede sobrescribir con `DB_*_NETWORK`. No se reutilizan las credenciales
de superusuario entre servicios.

Las redes son internas y no publican puertos PostgreSQL en el host. Cada
servicio debe conectarse solo a su red de datos correspondiente y usar el
nombre del servicio PostgreSQL como host (`db-identidad` o `db-campana`) en el
puerto 5432. No conectes Gateway ni otros servicios a esas redes de datos.

Identidad y Campañas se construyen como imágenes independientes desde
`identidad/Dockerfile` y `campanas/Dockerfile`, ambas basadas en PostgreSQL 16.
Docker Compose las construye al levantarlas; las migraciones Flyway se ejecutan
en sus contenedores separados.

## Roles

Identidad y Campañas usan roles distintos por base:

| Rol | Uso | Privilegios |
|---|---|---|
| `postgres` | Inicialización local | Crea roles de la base |
| `*_propietario` | Migraciones Flyway | Administra el esquema |
| `*_servicio` | Ejecución del servicio | Solo los permisos explícitos de sus tablas |

Las tablas de auditoría permiten insertar al servicio, pero no actualizar,
eliminar ni vaciar registros. Los disparadores bloquean esas operaciones
directas también para el rol propietario; este es un control ante errores
operativos, no una garantía contra un administrador que pueda cambiar el
esquema o deshabilitar los disparadores. Una protección contra manipulación por
administradores requiere exportación a un destino externo e independiente.

## Levantar solo las bases de Identidad y Campañas

Desde la raíz del repositorio:

```powershell
docker compose up
```

Este Compose predeterminado construye y levanta los dos contenedores. Usa
credenciales predeterminadas solo para desarrollo local; puedes sobrescribirlas
con variables de entorno o en un archivo `.env`. No publica los puertos de las
bases en el host.

## Levantar la pila completa y migrar

PowerShell:

```powershell
# Ejecuta desde la raiz de este repositorio.
$secretDir = Join-Path (Get-Location).Path "secretos"
New-Item -ItemType Directory -Force -Path $secretDir | Out-Null
$nombres = @(
  "postgres_superusuario_identidad", "identidad_propietario", "identidad_servicio",
  "postgres_superusuario_campana", "campana_propietario", "campana_servicio",
  "postgres_superusuario_donacion", "postgres_superusuario_institucional"
)
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
foreach ($nombre in $nombres) {
  $bytes = New-Object byte[] 32
  $rng.GetBytes($bytes)
  $secreto = [BitConverter]::ToString($bytes).Replace("-", "").ToLowerInvariant()
  [IO.File]::WriteAllText((Join-Path $secretDir $nombre), $secreto)
}
docker compose -f docker-compose.migraciones.yml up -d
docker compose -f docker-compose.migraciones.yml logs migracion-identidad migracion-campana
```

Los archivos de `secretos/` están excluidos del control de versiones. En un
volumen ya inicializado, cambiar esos archivos no rota automáticamente las
contraseñas almacenadas por PostgreSQL.

## Despliegue con GitHub Actions

El workflow `.github/workflows/ci-cd-QA.yml` se ejecuta al hacer push a `main`
o manualmente desde GitHub Actions. El runner `self-hosted` debe ser Ubuntu
con Docker instalado y permisos para ejecutar `docker`.

El CI construye las imágenes de Identidad y Campañas y comprueba en contenedores
efímeros que la inicialización crea sus roles y permite autenticarlos. Si pasa,
el CD despliega `db-identidad` y `db-campana` en las redes Docker aisladas
`redvital_identidad_data` y `redvital_campana_data`, con volúmenes persistentes
del mismo nombre. No se publican puertos PostgreSQL en el host. Los servicios
que necesiten conectarse deben unirse únicamente a la red que les corresponde.

Configura estos GitHub Actions Secrets antes de ejecutar el despliegue:
`POSTGRES_IDENTIDAD_PASSWORD`, `IDENTIDAD_PROPIETARIO_PASSWORD`,
`IDENTIDAD_SERVICIO_PASSWORD`, `POSTGRES_CAMPANA_PASSWORD`,
`CAMPANA_PROPIETARIO_PASSWORD` y `CAMPANA_SERVICIO_PASSWORD`. Docker conserva las credenciales como variables
de entorno del contenedor para que pueda reiniciarse; por ello, limita el acceso
al daemon Docker a administradores de confianza. Cambiar un secret no rota las
credenciales dentro de una base ya inicializada; la rotación debe hacerse
explícitamente en PostgreSQL y en los secrets correspondientes.

Este workflow despliega únicamente las dos bases construidas en este repositorio;
no ejecuta migraciones Flyway ni despliega los servicios de aplicación.

## Reglas de cambio

1. No edites una migración que ya haya sido aplicada: Flyway valida su suma de
   comprobación.
2. Añade una nueva migración `V00N__descripcion.sql` en un Pull Request.
3. El responsable del servicio mantiene su modelo de persistencia y verifica
   que mapee el esquema publicado aquí.
4. No agregues tablas ni roles a Donación o Institucional hasta recibir sus
   definiciones aprobadas.
