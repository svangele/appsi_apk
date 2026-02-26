-- =============================================================================
-- FIX: Limpieza de Objetos Huérfanos tras Unificación Profiles 360
-- =============================================================================

-- 1. Eliminar Triggers que referencian a cssi_contributors
DROP TRIGGER IF EXISTS tr_auto_link_on_profile ON public.profiles;
DROP TRIGGER IF EXISTS tr_auto_link_on_contributor ON public.cssi_contributors;
DROP TRIGGER IF EXISTS on_status_sys_change ON public.cssi_contributors;

-- 2. Eliminar Funciones que referencian a cssi_contributors
DROP FUNCTION IF EXISTS public.fn_auto_link_cssi_profile();
DROP FUNCTION IF EXISTS public.handle_status_sys_change();

-- 3. Limpiar columnas obsoletas en profiles
-- cssi_id ya no es necesario porque profiles es ahora la tabla maestra única.
ALTER TABLE public.profiles DROP COLUMN IF EXISTS cssi_id;

-- 4. Corregir RPC delete_user_admin (tenia referencias a cssi_contributors)
CREATE OR REPLACE FUNCTION public.delete_user_admin(user_id_param uuid)
RETURNS void AS $$
BEGIN
  -- Eliminar de perfiles (esta tabla tiene la FK que bloquea si no se borra primero)
  DELETE FROM public.profiles WHERE id = user_id_param;
  
  -- Finalmente eliminar de auth.users (Supabase se encarga de identidades)
  DELETE FROM auth.users WHERE id = user_id_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Notificar recarga de esquema
NOTIFY pgrst, 'reload schema';
