-- Tabla para Registro de Incidencias
CREATE TABLE IF NOT EXISTS public.incidencias (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Los campos solicitados
    status TEXT NOT NULL DEFAULT 'PENDIENTE' CHECK (status IN ('APROBADA', 'CANCELADA', 'PENDIENTE')),
    nombre_usuario TEXT NOT NULL, -- Nombre del usuario que realiza la petición
    periodo TEXT NOT NULL CHECK (periodo IN ('2020 – 2021', '2021 – 2022', '2022 – 2023', '2024 – 2025', '2025 – 2026')),
    dias INTEGER NOT NULL, -- Máximo dos dígitos (validado en la app)
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    fecha_regreso DATE NOT NULL,
    
    -- Relación con el usuario
    usuario_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Habilitar RLS
ALTER TABLE public.incidencias ENABLE ROW LEVEL SECURITY;

-- Políticas de RLS
-- 1. Los usuarios pueden ver sus propias incidencias
DROP POLICY IF EXISTS "Usuarios ven sus propias incidencias" ON public.incidencias;
CREATE POLICY "Usuarios ven sus propias incidencias"
    ON public.incidencias
    FOR SELECT
    USING (auth.uid() = usuario_id);

-- 2. Los admins pueden ver todas las incidencias
DROP POLICY IF EXISTS "Admins ven todas las incidencias" ON public.incidencias;
CREATE POLICY "Admins ven todas las incidencias"
    ON public.incidencias
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'admin'
        )
    );

-- 3. Usuarios autenticados pueden crear incidencias para sí mismos
DROP POLICY IF EXISTS "Usuarios crean sus propias incidencias" ON public.incidencias;
CREATE POLICY "Usuarios crean sus propias incidencias"
    ON public.incidencias
    FOR INSERT
    WITH CHECK (auth.uid() = usuario_id);

-- 4. Usuarios pueden actualizar sus propias incidencias SOLO si están PENDIENTES
DROP POLICY IF EXISTS "Usuarios actualizan sus propias incidencias pendientes" ON public.incidencias;
CREATE POLICY "Usuarios actualizan sus propias incidencias pendientes"
    ON public.incidencias
    FOR UPDATE
    USING (
        auth.uid() = usuario_id 
        AND status = 'PENDIENTE'
    )
    WITH CHECK (
        auth.uid() = usuario_id 
        AND status = 'PENDIENTE' -- Evita que el usuario cambie el status él mismo
    );

-- 5. Admins pueden actualizar cualquier incidencia (incluyendo cambiar estatus)
DROP POLICY IF EXISTS "Admins actualizan todas las incidencias" ON public.incidencias;
CREATE POLICY "Admins actualizan todas las incidencias"
    ON public.incidencias
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'admin'
        )
    );
