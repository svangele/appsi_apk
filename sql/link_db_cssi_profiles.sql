-- =============================================================================
-- UNIFICACIÓN ESTRUCTURAL: CSSI_CONTRIBUTORS x PROFILES
-- =============================================================================

-- 1. ASEGURAR COLUMNAS EN PROFILES
-- Añadimos cssi_id como FK y numero_empleado para redundancia de búsqueda.
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS cssi_id UUID REFERENCES public.cssi_contributors(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS numero_empleado TEXT;

-- 2. ASEGURAR COLUMNAS EN CSSI_CONTRIBUTORS (Si faltan)
ALTER TABLE public.cssi_contributors 
ADD COLUMN IF NOT EXISTS numero_empleado TEXT,
ADD COLUMN IF NOT EXISTS foto_url TEXT;

-- 3. FUNCIÓN DE AUTO-VINCULACIÓN (Lógica Dual)
-- Busca coincidencias por correo electrónico para unir la identidad del sistema 
-- con el expediente del colaborador.
CREATE OR REPLACE FUNCTION public.fn_auto_link_cssi_profile()
RETURNS TRIGGER AS $$
BEGIN
    -- Caso A: Se inserta/actualiza un Colaborador
    IF (TG_TABLE_NAME = 'cssi_contributors') THEN
        -- Intentar vincular perfiles que tengan el mismo correo personal
        UPDATE public.profiles
        SET 
            cssi_id = NEW.id,
            numero_empleado = NEW.numero_empleado
        WHERE email = LOWER(NEW.correo_personal)
           OR full_name = (NEW.nombre || ' ' || NEW.paterno)
        AND cssi_id IS NULL; -- Solo si no está ya vinculado
        
    -- Caso B: Se inserta/actualiza un Perfil
    ELSIF (TG_TABLE_NAME = 'profiles') THEN
        -- Intentar buscar colaborador por email
        UPDATE public.profiles p
        SET 
            cssi_id = c.id,
            numero_empleado = c.numero_empleado
        FROM public.cssi_contributors c
        WHERE p.id = NEW.id
          AND LOWER(c.correo_personal) = LOWER(p.email)
          AND p.cssi_id IS NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. TRIGGERS
DROP TRIGGER IF EXISTS tr_auto_link_on_contributor ON public.cssi_contributors;
CREATE TRIGGER tr_auto_link_on_contributor
AFTER INSERT OR UPDATE OF correo_personal ON public.cssi_contributors
FOR EACH ROW EXECUTE FUNCTION public.fn_auto_link_cssi_profile();

DROP TRIGGER IF EXISTS tr_auto_link_on_profile ON public.profiles;
CREATE TRIGGER tr_auto_link_on_profile
AFTER INSERT ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.fn_auto_link_cssi_profile();

-- 5. SINCRONIZACIÓN INICIAL
-- Vincula todos los registros actuales que coincidan por correo
UPDATE public.profiles p
SET 
    cssi_id = c.id,
    numero_empleado = c.numero_empleado
FROM public.cssi_contributors c
WHERE (LOWER(p.email) = LOWER(c.correo_personal) OR p.full_name = (c.nombre || ' ' || c.paterno))
  AND p.cssi_id IS NULL;

-- 6. RELOAD SCHEMA
NOTIFY pgrst, 'reload schema';
