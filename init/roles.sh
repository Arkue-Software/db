#!/bin/sh
# Lo ejecuta la imagen oficial de PostgreSQL SOLO al crear la base por primera
# vez (docker-entrypoint-initdb.d). Es el "guion de inicialización" del
# superusuario: toma las contraseñas de Docker secrets o, para el Compose local,
# de variables de entorno con valores de desarrollo.
set -eu
password_propietario_file="/run/secrets/${ROLES_PREFIJO}_propietario"
password_servicio_file="/run/secrets/${ROLES_PREFIJO}_servicio"

if [ -r "$password_propietario_file" ]; then
  password_propietario="$(cat "$password_propietario_file")"
else
  : "${ROLES_PASSWORD_PROPIETARIO:?Falta el secreto del rol propietario}"
  password_propietario="$ROLES_PASSWORD_PROPIETARIO"
fi

if [ -r "$password_servicio_file" ]; then
  password_servicio="$(cat "$password_servicio_file")"
else
  : "${ROLES_PASSWORD_SERVICIO:?Falta el secreto del rol de servicio}"
  password_servicio="$ROLES_PASSWORD_SERVICIO"
fi

psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -v password_propietario="$password_propietario" \
  -v password_servicio="$password_servicio" \
  -f /roles/00_roles.sql
