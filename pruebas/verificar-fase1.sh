#!/usr/bin/env bash
# RedVital · databases · Verificación de T-304.1, T-312.1, T-330.4 (y T-312.5)
# Corre en un contenedor unido a la red de la base indicada por DB_SCOPE.
# Usa DB_*_HOST, DB_*_PORT y las contraseñas PASS_* descritas en README.md.
set -u
fallos=0
SQL_ERROR=
SCOPE=${DB_SCOPE:-}

case "$SCOPE" in
  identidad|campana|donacion|institucional) ;;
  *) echo "Alcance desconocido: $SCOPE" >&2; exit 2 ;;
esac

puerto_de() {
  case "$1" in
    db_identidad) echo "${DB_IDENTIDAD_PORT:-5432}" ;;
    db_campana) echo "${DB_CAMPANA_PORT:-5432}" ;;
    db_donacion) echo "${DB_DONACION_PORT:-5432}" ;;
    db_institucional) echo "${DB_INSTITUCIONAL_PORT:-5432}" ;;
    *) echo "Base desconocida: $1" >&2; return 2 ;;
  esac
}
host_de() {
  case "$1" in
    db_identidad) echo "${DB_IDENTIDAD_HOST:-${PGHOST:-127.0.0.1}}" ;;
    db_campana) echo "${DB_CAMPANA_HOST:-${PGHOST:-127.0.0.1}}" ;;
    db_donacion) echo "${DB_DONACION_HOST:-${PGHOST:-127.0.0.1}}" ;;
    db_institucional) echo "${DB_INSTITUCIONAL_HOST:-${PGHOST:-127.0.0.1}}" ;;
    *) echo "Base desconocida: $1" >&2; return 2 ;;
  esac
}
scope_includes() { [ "$SCOPE" = "$1" ]; }
sql() { # usuario base clave consulta
  local salida
  if salida=$(PGHOST="$(host_de "$2")" PGPORT="$(puerto_de "$2")" PGPASSWORD="$3" \
    psql -X -q -At -v ON_ERROR_STOP=1 -U "$1" -d "$2" -c "$4" 2>&1); then
    SQL_ERROR=
    return 0
  fi
  SQL_ERROR=$salida
  return 1
}
debe_funcionar() {
  if sql "$2" "$3" "$4" "$5"; then
    echo "  OK    $1"
  else
    echo "  FALLA $1 (debía funcionar)"
    [ -z "$SQL_ERROR" ] || printf '        %s\n' "$SQL_ERROR"
    fallos=$((fallos+1))
  fi
}
debe_fallar()    { if sql "$2" "$3" "$4" "$5"; then echo "  FALLA $1 (debía ser rechazado)"; fallos=$((fallos+1)); else echo "  OK    $1"; fi; }
valor()          { PGHOST="$(host_de "$2")" PGPORT="$(puerto_de "$2")" PGPASSWORD="$3" \
  psql -X -q -At -U "$1" -d "$2" -c "$4" 2>/dev/null; }

IP=identidad_propietario; IS=identidad_servicio; CP=campana_propietario; CS=campana_servicio
pIP="${PASS_IDENT_PROP:-}"; pIS="${PASS_IDENT_SERV:-}"; pCP="${PASS_CAMP_PROP:-}"; pCS="${PASS_CAMP_SERV:-}"
pD="${PASS_DONACION_ADMIN:-}"; pN="${PASS_INSTITUCIONAL_ADMIN:-}"
U=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)

if scope_includes identidad; then
  echo "T-304.1 — db_identidad: esquema y roles"
  [ "$(valor $IS db_identidad "$pIS" "SELECT count(*) FROM rol")" = "6" ] && echo "  OK    catálogo de roles con exactamente 6 valores" || { echo "  FALLA catálogo de roles"; fallos=$((fallos+1)); }
  debe_funcionar "servicio inserta un usuario"      $IS db_identidad "$pIS" "INSERT INTO usuario (id, correo, credencial_hash, rol_id) VALUES ('$U','verif-$U@banco-ficticio.test','x','operador')"
  debe_funcionar "servicio actualiza un usuario"    $IS db_identidad "$pIS" "UPDATE usuario SET activo=false WHERE id='$U'"
  debe_fallar    "servicio NO borra usuarios"       $IS db_identidad "$pIS" "DELETE FROM usuario WHERE id='$U'"
  debe_fallar    "servicio NO crea tablas"          $IS db_identidad "$pIS" "CREATE TABLE intrusa (x int)"
  debe_fallar    "servicio NO modifica el catálogo de roles" $IS db_identidad "$pIS" "INSERT INTO rol VALUES ('extra','x','x')"
  debe_fallar    "sesión de más de 8 horas"         $IS db_identidad "$pIS" "INSERT INTO sesion (usuario_id, secreto_hash, emitida_en, expira_en) VALUES ('$U','x', now(), now() + interval '9 hours')"
  debe_fallar    "jurisdicción institucional sin institución" $IS db_identidad "$pIS" "INSERT INTO usuario_jurisdiccion (usuario_id, ambito, asignada_por) VALUES ('$U','institucion','$U')"
  debe_fallar    "cliente de servicio no reconocido" $IS db_identidad "$pIS" "INSERT INTO credencial_servicio (cliente, secreto_hash) VALUES ('institucional','x')"

  echo "T-330.4 — serie de auditoría de Identidad (solo anexado)"
  debe_funcionar "servicio registra una denegación anónima" $IS db_identidad "$pIS" "INSERT INTO registro_auditoria_ident (actor_tipo, operacion, recurso_tipo, resultado, correlacion_id) VALUES ('anonimo','campanias:GET','campania','denegado','$U')"
  debe_fallar    "correlación de más de 36 caracteres (tamaño de un UUID)" $IS db_identidad "$pIS" "INSERT INTO registro_auditoria_ident (actor_tipo, operacion, recurso_tipo, resultado, correlacion_id) VALUES ('anonimo','x','x','denegado', repeat('a', 37))"
  debe_fallar    "anónimo con actor_id es rechazado" $IS db_identidad "$pIS" "INSERT INTO registro_auditoria_ident (actor_tipo, actor_id, operacion, recurso_tipo, resultado, correlacion_id) VALUES ('anonimo','alguien','x','x','denegado','x')"
  debe_fallar    "servicio NO actualiza la auditoría"  $IS db_identidad "$pIS" "UPDATE registro_auditoria_ident SET resultado='permitido' WHERE correlacion_id='$U'"
  debe_fallar    "servicio NO borra la auditoría"      $IS db_identidad "$pIS" "DELETE FROM registro_auditoria_ident WHERE correlacion_id='$U'"
  debe_fallar    "servicio NO vacía la auditoría"      $IS db_identidad "$pIS" "TRUNCATE registro_auditoria_ident"
  debe_fallar    "trigger bloquea UPDATE directo del PROPIETARIO" $IP db_identidad "$pIP" "UPDATE registro_auditoria_ident SET resultado='permitido' WHERE correlacion_id='$U'"
  debe_fallar    "trigger bloquea TRUNCATE directo del PROPIETARIO" $IP db_identidad "$pIP" "TRUNCATE registro_auditoria_ident"

  debe_fallar "campana_servicio no existe en db_identidad" $CS db_identidad "$pCS" "SELECT 1"
fi

if scope_includes campana; then
  echo "T-312.1 — db_campana: esquema y roles"
  C=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
  debe_funcionar "servicio crea una campaña"  $CS db_campana "$pCS" "INSERT INTO campania (id, institucion_id, territorio_codigo, territorio_ruta, nombre, sede, inicia_en, termina_en, cupo_total, creada_por) VALUES ('$C','$U','11001','/00/11/11001','Campaña ficticia','Sede ficticia', now()+interval '1 day', now()+interval '2 days', 10, '$U')"
  debe_fallar    "cupo reservado mayor que el total" $CS db_campana "$pCS" "UPDATE campania SET cupo_reservado = 11 WHERE id='$C'"
  debe_fallar    "campaña que termina antes de empezar" $CS db_campana "$pCS" "UPDATE campania SET termina_en = inicia_en - interval '1 hour' WHERE id='$C'"
  debe_fallar    "publicada sin fecha de publicación" $CS db_campana "$pCS" "UPDATE campania SET estado='publicada' WHERE id='$C'"
  debe_funcionar "reserva de cupo"            $CS db_campana "$pCS" "INSERT INTO reserva_cupo (campania_id, usuario_id, expira_en) VALUES ('$C','$U', now()+interval '23 hours')"
  debe_fallar    "reserva de más de 24 horas" $CS db_campana "$pCS" "INSERT INTO reserva_cupo (campania_id, usuario_id, expira_en) VALUES ('$C','$U', now()+interval '25 hours')"
  debe_fallar    "servicio NO borra campañas" $CS db_campana "$pCS" "DELETE FROM campania WHERE id='$C'"
  debe_fallar    "servicio NO crea tablas"    $CS db_campana "$pCS" "CREATE TABLE intrusa (x int)"
  debe_fallar    "servicio de Campañas NO entra a db_identidad" $CS db_identidad "$pCS" "SELECT 1"

  echo "T-312.5 — serie de auditoría de Campañas (solo anexado)"
  debe_funcionar "servicio registra un hecho" $CS db_campana "$pCS" "INSERT INTO registro_auditoria_camp (actor_tipo, actor_id, operacion, recurso_tipo, resultado, correlacion_id) VALUES ('usuario','$U','publicar_campania','campania','permitido','$C')"
  debe_fallar    "servicio NO borra la auditoría"         $CS db_campana "$pCS" "DELETE FROM registro_auditoria_camp"
  debe_fallar    "trigger bloquea UPDATE directo del PROPIETARIO" $CP db_campana "$pCP" "UPDATE registro_auditoria_camp SET resultado='denegado'"
  debe_fallar    "trigger bloquea TRUNCATE directo del PROPIETARIO" $CP db_campana "$pCP" "TRUNCATE registro_auditoria_camp"

  debe_fallar "identidad_servicio no existe en db_campana" $IS db_campana "$pIS" "SELECT 1"
fi

if scope_includes donacion; then
  echo "T-DB — db_donacion vacía"
  debe_funcionar "db_donacion está provisionada y vacía" postgres db_donacion "$pD" "SELECT 1 WHERE current_database()='db_donacion' AND NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname='public')"
fi

if scope_includes institucional; then
  echo "T-DB — db_institucional vacía"
  debe_funcionar "db_institucional está provisionada y vacía" postgres db_institucional "$pN" "SELECT 1 WHERE current_database()='db_institucional' AND NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname='public')"
fi

echo; [ $fallos -eq 0 ] && echo "Fase 1: todas las verificaciones pasaron" || echo "Fase 1: $fallos verificación(es) fallaron"
exit $fallos
