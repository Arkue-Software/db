-- T-304.4 — Metadatos públicos de las llaves de firma de Identidad.
-- La llave privada permanece fuera de la base y fuera del control de versiones.

CREATE TABLE llave_firma (
    kid                 VARCHAR(80) PRIMARY KEY,
    clave_publica_pem   TEXT NOT NULL,
    activa_desde        TIMESTAMPTZ NOT NULL,
    retirada_en         TIMESTAMPTZ,
    CONSTRAINT ck_llave_firma_retirada CHECK (
        retirada_en IS NULL OR retirada_en > activa_desde
    )
);

GRANT SELECT, INSERT, UPDATE ON llave_firma TO identidad_servicio;
