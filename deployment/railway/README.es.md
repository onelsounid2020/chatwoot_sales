# Deploy de Chatwoot en Railway (Staging + Producción)

Esta guía te permite:
- subir tu versión personalizada,
- seguir desarrollando sin frenar,
- y no mezclar entornos.

## 1) Estrategia recomendada de ramas

- `main`: Producción (estable)
- `develop` (o `sales-dev`): Staging (trabajo continuo)

Flujo:
1. Haces cambios en feature branch.
2. Merge a `develop` -> despliega Staging.
3. Cuando esté estable, merge a `main` -> despliega Producción.

## 2) Servicios que debes crear en Railway

Para **cada entorno** (staging/prod), crea:
- 1 servicio `web` (Rails)
- 1 servicio `worker` (Sidekiq)
- 1 `Postgres`
- 1 `Redis`

Importante: no compartas la misma base entre staging y producción.

## 3) Configuración de comandos

Usa estos comandos en Railway:

- **Deploy Command (web y worker):**
  - `bin/railway-release`

- **Start Command (web):**
  - `bin/railway-web`

- **Start Command (worker):**
  - `bin/railway-worker`

## 4) Variables de entorno mínimas

Variables clave (por entorno):
- `RAILS_ENV=production`
- `NODE_ENV=production`
- `SECRET_KEY_BASE` (obligatoria)
- `FRONTEND_URL` (URL pública del entorno)
- `REDIS_URL` (desde plugin Redis)
- `DATABASE_URL` (desde plugin Postgres)
- `RAILS_LOG_TO_STDOUT=true`
- `RAILS_SERVE_STATIC_FILES=true`

Para correo/adjuntos/integraciones, replica tus variables actuales según necesidad.

## 5) Notas importantes para no perder datos

- Nunca elimines el servicio de Postgres en producción.
- Activa backups/snapshots en Railway para la base productiva.
- Si usas almacenamiento local de archivos, migra a S3-compatible para producción (Railway filesystem no es persistente para assets subidos por usuarios).

## 6) Primera puesta en marcha

1. Despliega `web` y `worker` con la rama de staging.
2. Verifica logs de `web` y que `bin/railway-release` ejecute migraciones.
3. Ingresa, valida login y conversaciones.
4. Repite para producción con `main`.

## 7) Operación diaria

- Desarrollo continuo: deploy automático en staging.
- Releases productivos: merges controlados a `main`.
- Hotfix: branch desde `main`, merge a `main` y luego back-merge a `develop`.
