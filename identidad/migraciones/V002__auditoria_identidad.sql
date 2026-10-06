-- RedVital · db_identidad · V002 — T-330.4
-- Serie de auditoría de Identidad. Recibe, además de sus propias acciones
-- sensibles, las denegaciones que entrega el gateway (ADR-016). Estructura
-- común de las cuatro series. No existe ningún campo para el contenido del
-- recurso: se registra que se intentó, nunca el dato al que se intentó acceder.

CREATE TABLE registro_auditoria_ident (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_tipo               VARCHAR(20) NOT NULL CHECK (actor_tipo IN ('usuario', 'sistema', 'anonimo')),
    actor_id                 VARCHAR(64),
    rol                      VARCHAR(40),
    jurisdiccion_solicitada  VARCHAR(80),
    operacion                VARCHAR(80) NOT NULL,
    recurso_tipo             VARCHAR(40) NOT NULL,
    recurso_id               UUID,
    resultado                VARCHAR(20) NOT NULL CHECK (resultado IN ('permitido', 'denegado')),
    correlacion_id           VARCHAR(36) NOT NULL,
    origen                   VARCHAR(45),
    ocurrido_en              TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_auditoria_anonimo_sin_actor CHECK (actor_tipo <> 'anonimo' OR actor_id IS NULL)
);
CREATE INDEX ix_auditoria_ident_correlacion ON registro_auditoria_ident(correlacion_id);
CREATE INDEX ix_auditoria_ident_ocurrido    ON registro_auditoria_ident(ocurrido_en);

-- Solo anexado en dos capas:
-- 1) Permisos: el servicio solo inserta y lee.
GRANT SELECT, INSERT ON registro_auditoria_ident TO identidad_servicio;

-- 2) Disparador: bloquea modificaciones directas, incluso las accidentales
--    del propietario de la tabla. Un administrador con privilegios DDL puede
--    deshabilitarlo; la inmutabilidad frente a administradores requiere un
--    destino externo e independiente.
CREATE FUNCTION impedir_modificacion_auditoria() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'La bitácora de auditoría es de solo anexado: % no permitido sobre %', TG_OP, TG_TABLE_NAME;
END;
$$;

CREATE TRIGGER tg_auditoria_ident_sin_modificacion
    BEFORE UPDATE OR DELETE ON registro_auditoria_ident
    FOR EACH ROW EXECUTE FUNCTION impedir_modificacion_auditoria();

CREATE TRIGGER tg_auditoria_ident_sin_vaciado
    BEFORE TRUNCATE ON registro_auditoria_ident
    FOR EACH STATEMENT EXECUTE FUNCTION impedir_modificacion_auditoria();
