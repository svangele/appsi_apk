-- Tabla para Colaboradores SSI
CREATE TABLE IF NOT EXISTS cssi_contributors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Sección: SI Colaborador
    nombre TEXT NOT NULL,
    paterno TEXT NOT NULL,
    materno TEXT,
    curp TEXT UNIQUE,
    rfc TEXT UNIQUE,
    imss TEXT,
    credito TEXT, -- FOVISTE, INFONAVIT, OTRO
    fecha_nacimiento DATE,
    genero TEXT, -- FEMENINO, MASCULINO
    talla TEXT,
    estado_civil TEXT, -- CASADO, SOLTERO, UNION LIBRE
    escolaridad TEXT, -- PRIMARIA, SECUNDARIA, etc.
    detalle_escolaridad TEXT,
    
    -- Sección: Domicilio
    calle TEXT,
    no_calle TEXT,
    colonia TEXT,
    municipio_alcaldia TEXT,
    estado_federal TEXT,
    codigo_postal TEXT,
    
    -- Sección: Contacto Personal
    telefono TEXT,
    celular TEXT,
    correo_personal TEXT,
    
    -- Sección: Datos Bancarios
    banco TEXT,
    cuenta TEXT,
    clabe TEXT,
    
    -- Sección: Datos Empresa
    empresa_tipo TEXT, -- Era 'Tipo' en la solicitud
    area TEXT,
    puesto TEXT,
    ubicacion TEXT,
    empresa TEXT,
    jefe_inmediato TEXT,
    lider TEXT,
    gerente_regional TEXT,
    director TEXT,
    
    -- Sección: Area RH
    recluta TEXT,
    reclutador TEXT,
    fuente_reclutamiento TEXT,
    fuente_reclutamiento_espec TEXT,
    observaciones TEXT,
    
    -- Sección: Referencias (Integradas en la misma tabla)
    referencia_nombre TEXT,
    referencia_telefono TEXT,
    referencia_relacion TEXT,
    
    -- Auditoría
    usuario_id UUID REFERENCES auth.users(id),
    usuario_nombre TEXT
);

-- Habilitar RLS
ALTER TABLE cssi_contributors ENABLE ROW LEVEL SECURITY;

-- Políticas para cssi_contributors
CREATE POLICY "Admins have full access to cssi_contributors"
ON cssi_contributors FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
);
