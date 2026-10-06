-- RedVital · db_campana · V001 — T-312.1
-- El cupo y sus reservas viven en la misma base: reservar nunca exige una
-- transacción distribuida.

CREATE TABLE campania (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institucion_id    UUID NOT NULL,              -- referencia lógica, sin FK (otra base)
    territorio_codigo VARCHAR(5)   NOT NULL,      -- DIVIPOLA de la sede
    territorio_ruta   VARCHAR(32)  NOT NULL,      -- filtra por jurisdicción sin llamar a otro servicio
    nombre            VARCHAR(160) NOT NULL,
    descripcion       VARCHAR(500),
    sede              VARCHAR(200) NOT NULL,
    inicia_en         TIMESTAMPTZ  NOT NULL,
    termina_en        TIMESTAMPTZ  NOT NULL,
    cupo_total        INTEGER,                    -- nulo = sin cupo limitado
    cupo_reservado    INTEGER      NOT NULL DEFAULT 0,
    estado            VARCHAR(20)  NOT NULL DEFAULT 'borrador'
                        CHECK (estado IN ('borrador', 'publicada', 'cerrada', 'cancelada')),
    publicada_en      TIMESTAMPTZ,
    creada_por        UUID NOT NULL,
    creada_en         TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizada_en    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_campania_fechas CHECK (termina_en > inicia_en),
    -- El cupo nunca se sobrevende: la base lo impide aunque el código falle.
    CONSTRAINT ck_campania_cupo CHECK (
        cupo_reservado >= 0 AND (cupo_total IS NULL OR (cupo_total >= 0 AND cupo_reservado <= cupo_total))),
    CONSTRAINT ck_campania_publicada CHECK (estado NOT IN ('publicada', 'cerrada') OR publicada_en IS NOT NULL)
);
CREATE INDEX ix_campania_estado_termina ON campania(estado, termina_en);
CREATE INDEX ix_campania_territorio     ON campania(territorio_ruta);
CREATE INDEX ix_campania_institucion    ON campania(institucion_id);

CREATE TABLE reserva_cupo (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campania_id   UUID NOT NULL REFERENCES campania(id),
    usuario_id    UUID NOT NULL,                  -- "sub" del donante; Campañas no conoce donantes
    estado        VARCHAR(20) NOT NULL DEFAULT 'pendiente'
                    CHECK (estado IN ('pendiente', 'confirmada', 'liberada', 'cancelada')),
    creada_en     TIMESTAMPTZ NOT NULL DEFAULT now(),
    expira_en     TIMESTAMPTZ NOT NULL,           -- el menor entre +24 h y el inicio de la campaña
    confirmada_en TIMESTAMPTZ,
    cerrada_en    TIMESTAMPTZ,
    CONSTRAINT ck_reserva_24_horas CHECK (expira_en <= creada_en + INTERVAL '24 hours')
);
-- Índice crítico: el proceso de expiración corre cada minuto con este filtro.
CREATE INDEX ix_reserva_estado_expira ON reserva_cupo(estado, expira_en);
CREATE INDEX ix_reserva_campania      ON reserva_cupo(campania_id);

GRANT SELECT, INSERT, UPDATE ON campania, reserva_cupo TO campana_servicio;
