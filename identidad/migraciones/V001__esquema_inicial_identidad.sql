-- RedVital · db_identidad · V001 — T-304.1
-- Lo aplica Flyway como identidad_propietario. Una migración aplicada NUNCA
-- se edita: Flyway compara su suma de verificación y se niega a continuar.
-- Los cambios van en una versión nueva (V004, V005…).
-- gen_random_uuid() es nativa desde PostgreSQL 13: no requiere extensiones.

CREATE TABLE rol (
    codigo           VARCHAR(20) PRIMARY KEY,
    perfil           VARCHAR(80) NOT NULL,
    ambito_admitido  VARCHAR(80) NOT NULL
);

-- Los seis roles con sesión (DD, Tabla 13). El rol "servicio" de los tokens
-- de servicio no es una cuenta: vive en credencial_servicio.
INSERT INTO rol (codigo, perfil, ambito_admitido) VALUES
    ('donante',        'U2 — Donante registrado',     'ninguno'),
    ('operador',       'U3 — Operador de banco',       'institucion (exactamente una)'),
    ('admin_banco',    'U4 — Administrador de banco',  'institucion (exactamente una)'),
    ('coordinador',    'U5 — Coordinador territorial', 'territorio departamental o municipal'),
    ('admin_nacional', 'U6 — Administrador nacional',  'territorio nacional'),
    ('auditor',        'U7 — Auditor',                 'territorio nacional, lectura limitada');

CREATE TABLE usuario (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    correo            VARCHAR(160) NOT NULL UNIQUE,
    nombre            VARCHAR(120),
    credencial_hash   VARCHAR(200) NOT NULL,     -- resumen con sal; nunca la credencial en claro
    rol_id            VARCHAR(20)  NOT NULL REFERENCES rol(codigo),
    activo            BOOLEAN      NOT NULL DEFAULT TRUE,
    ultimo_acceso_en  TIMESTAMPTZ,
    creado_en         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actualizado_en    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE usuario_jurisdiccion (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id        UUID NOT NULL REFERENCES usuario(id),
    ambito            VARCHAR(20) NOT NULL CHECK (ambito IN ('territorio', 'institucion')),
    territorio_codigo VARCHAR(5),
    territorio_ruta   VARCHAR(32),
    institucion_id    UUID,                      -- referencia lógica: la institución vive en otra base
    asignada_por      UUID NOT NULL,
    vigente_desde     TIMESTAMPTZ NOT NULL DEFAULT now(),
    vigente_hasta     TIMESTAMPTZ,
    -- El diccionario de datos dice "presente si el ámbito es…": se impone aquí.
    CONSTRAINT ck_jurisdiccion_coherente CHECK (
        (ambito = 'territorio'  AND territorio_codigo IS NOT NULL AND territorio_ruta IS NOT NULL AND institucion_id IS NULL) OR
        (ambito = 'institucion' AND institucion_id IS NOT NULL AND territorio_codigo IS NULL AND territorio_ruta IS NULL)),
    CONSTRAINT ck_jurisdiccion_vigencia CHECK (vigente_hasta IS NULL OR vigente_hasta > vigente_desde)
);
CREATE INDEX ix_usuario_jurisdiccion_usuario ON usuario_jurisdiccion(usuario_id);

CREATE TABLE sesion (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id        UUID NOT NULL REFERENCES usuario(id),
    secreto_hash      VARCHAR(200) NOT NULL,
    emitida_en        TIMESTAMPTZ NOT NULL DEFAULT now(),
    expira_en         TIMESTAMPTZ NOT NULL,
    renovada_en       TIMESTAMPTZ,
    revocada_en       TIMESTAMPTZ,
    motivo_revocacion VARCHAR(30) CHECK (motivo_revocacion IS NULL OR motivo_revocacion IN
        ('cierre', 'desactivacion', 'cambio_rol', 'cambio_jurisdiccion', 'reutilizacion', 'rotacion_emergencia')),
    origen            VARCHAR(45),
    -- Vigencia absoluta de 8 horas (ADR-008): la base no admite una sesión más larga.
    CONSTRAINT ck_sesion_ocho_horas CHECK (expira_en <= emitida_en + INTERVAL '8 hours')
);
CREATE INDEX ix_sesion_usuario ON sesion(usuario_id);

CREATE TABLE credencial_servicio (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente       VARCHAR(40) NOT NULL UNIQUE CHECK (cliente IN ('gateway', 'donacion', 'notificaciones')),
    secreto_hash  VARCHAR(200) NOT NULL,
    activa        BOOLEAN NOT NULL DEFAULT TRUE,
    creada_en     TIMESTAMPTZ NOT NULL DEFAULT now(),
    rotada_en     TIMESTAMPTZ
);

-- Permisos del rol de servicio: leer, insertar y actualizar. Ningún DELETE:
-- en el dominio nada se borra físicamente, se marca.
GRANT SELECT ON rol TO identidad_servicio;
GRANT SELECT, INSERT, UPDATE ON usuario, usuario_jurisdiccion, sesion, credencial_servicio TO identidad_servicio;
