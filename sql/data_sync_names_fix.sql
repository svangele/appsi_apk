-- =============================================================================
-- FIX DATA SYNC: Sincronización de Nombres y Visibilidad CSSI
-- =============================================================================

-- 1. SINCRONIZACIÓN DE DATOS EXISTENTES
-- A. Poblar full_name desde partes si está vacío
UPDATE public.profiles
SET full_name = TRIM(CONCAT(nombre, ' ', paterno, ' ', materno))
WHERE (full_name IS NULL OR full_name = '' OR full_name = 'Nuevo Usuario')
  AND nombre IS NOT NULL;

-- B. Poblar nombre/paterno desde full_name si están vacíos (para admins creados solo con full_name)
UPDATE public.profiles
SET 
    nombre = SPLIT_PART(full_name, ' ', 1),
    paterno = COALESCE(NULLIF(SPLIT_PART(full_name, ' ', 2), ''), 'PENDIENTE')
WHERE nombre IS NULL AND full_name IS NOT NULL AND full_name != '';

-- 2. DISPARADOR AUTOMÁTICO PARA MANTENER NOMBRES SINCRONIZADOS
-- Así, si se crea un colaborador desde CSSI (solo nombre/paterno), el full_name se genera solo.
CREATE OR REPLACE FUNCTION public.sync_profile_names()
RETURNS trigger AS $$
BEGIN
    -- Si el full_name viene vacío o no cambió pero el nombre/paterno sí, lo regeneramos
    IF (new.nombre IS NOT NULL OR new.paterno IS NOT NULL) AND 
       (new.full_name IS NULL OR new.full_name = '' OR new.full_name = 'Nuevo Usuario' OR 
        new.nombre != old.nombre OR new.paterno != old.paterno) THEN
        new.full_name := TRIM(CONCAT(new.nombre, ' ', new.paterno, ' ', new.materno));
    END IF;
    RETURN new;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_sync_profile_names ON public.profiles;
CREATE TRIGGER tr_sync_profile_names
    BEFORE INSERT OR UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.sync_profile_names();

-- 3. AJUSTE DE METADATOS (Asegurar que el JWT tenga el nombre correcto)
UPDATE auth.users u
SET raw_user_meta_data = raw_user_meta_data || 
    jsonb_build_object(
        'full_name', p.full_name
    )
FROM public.profiles p
WHERE u.id = p.id;

NOTIFY pgrst, 'reload schema';
