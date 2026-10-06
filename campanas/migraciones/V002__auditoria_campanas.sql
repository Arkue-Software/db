-- T-312.5 — Serie de auditoría de Campañas.
-- El registro evita almacenar el contenido del recurso y admite solo
-- inserciones del rol de servicio. El trigger previene cambios accidentales;
-- el propietario de migraciones y el superusuario siguen siendo roles de
-- confianza administrativa y no constituyen una garantía antimanipulación.

CREATE TABLE registro_auditoria_camp (
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
    CONSTRAINT ck_auditoria_camp_anonimo_sin_actor CHECK (
        actor_tipo <> 'anonimo' OR actor_id IS NULL
    )
);

CREATE INDEX ix_auditoria_camp_correlacion ON registro_auditoria_camp(correlacion_id);
CREATE INDEX ix_auditoria_camp_ocurrido ON registro_auditoria_camp(ocurrido_en);

GRANT SELECT, INSERT ON registro_auditoria_camp TO campana_servicio;

CREATE FUNCTION impedir_modificacion_auditoria_camp() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'La bitácora es append-only: % no permitido sobre %', TG_OP, TG_TABLE_NAME;
END;
$$;

CREATE TRIGGER tg_auditoria_camp_sin_modificacion
    BEFORE UPDATE OR DELETE ON registro_auditoria_camp
    FOR EACH ROW EXECUTE FUNCTION impedir_modificacion_auditoria_camp();

CREATE TRIGGER tg_auditoria_camp_sin_vaciado
    BEFORE TRUNCATE ON registro_auditoria_camp
    FOR EACH STATEMENT EXECUTE FUNCTION impedir_modificacion_auditoria_camp();
