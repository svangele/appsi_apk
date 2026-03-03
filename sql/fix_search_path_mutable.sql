-- =============================================================================
-- FIX SUPABASE WARNING: Function Search Path Mutable for sync_profile_names
-- =============================================================================
-- Esta función no tenía la etiqueta "SECURITY DEFINER", por lo que el script
-- automático de limpieza anterior se la saltó. Sin embargo, Supabase aún
-- recomienda asegurarla. 

ALTER FUNCTION public.sync_profile_names() SET search_path = '';

NOTIFY pgrst, 'reload schema';
