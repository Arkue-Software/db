-- RedVital · databases/identidad/00_roles.sql — T-304.1 (roles)
-- Lo ejecuta UNA vez el SUPERUSUARIO (guion de inicialización). Ningún
-- servicio usa el superusuario. Idempotente: se puede volver a correr.
--   propietario → dueño del esquema; solo lo usan las migraciones (Flyway)
--   servicio    → con el que corre identity-service; sin definición de esquema
\set ON_ERROR_STOP on

SELECT format('CREATE ROLE identidad_propietario LOGIN PASSWORD %L', :'password_propietario')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'identidad_propietario') \gexec

SELECT format('CREATE ROLE identidad_servicio LOGIN PASSWORD %L NOCREATEDB NOCREATEROLE', :'password_servicio')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'identidad_servicio') \gexec

ALTER DATABASE db_identidad OWNER TO identidad_propietario;
ALTER SCHEMA public OWNER TO identidad_propietario;

REVOKE ALL ON DATABASE db_identidad FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT CONNECT ON DATABASE db_identidad TO identidad_servicio;
GRANT USAGE ON SCHEMA public TO identidad_servicio;   -- usar, nunca crear
