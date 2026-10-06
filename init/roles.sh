#!/bin/sh
# Lo ejecuta la imagen oficial de PostgreSQL SOLO al crear la base por primera
# vez (docker-entrypoint-initdb.d). Es el "guion de inicialización" del
# superusuario: crea los roles propietario y servicio con contraseñas leídas
# de /run/secrets, nunca escritas en un archivo versionado.
set -e
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -v password_propietario="$(cat /run/secrets/${ROLES_PREFIJO}_propietario)" \
  -v password_servicio="$(cat /run/secrets/${ROLES_PREFIJO}_servicio)" \
  -f /roles/00_roles.sql
