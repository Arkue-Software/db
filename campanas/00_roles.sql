-- RedVital · databases/campanas/00_roles.sql — T-312.1 (roles)
-- Mismo patrón que identidad/00_roles.sql. Lo ejecuta una vez el superusuario.
\set ON_ERROR_STOP on

SELECT format('CREATE ROLE campana_propietario LOGIN PASSWORD %L', :'password_propietario')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'campana_propietario') \gexec

SELECT format('CREATE ROLE campana_servicio LOGIN PASSWORD %L NOCREATEDB NOCREATEROLE', :'password_servicio')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'campana_servicio') \gexec

ALTER DATABASE db_campana OWNER TO campana_propietario;
ALTER SCHEMA public OWNER TO campana_propietario;

REVOKE ALL ON DATABASE db_campana FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT CONNECT ON DATABASE db_campana TO campana_servicio;
GRANT USAGE ON SCHEMA public TO campana_servicio;
