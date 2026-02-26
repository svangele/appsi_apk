-- 0. Drop existing to avoid parameter name conflicts (42P13)
DROP FUNCTION IF EXISTS public.delete_user_admin(uuid);

CREATE OR REPLACE FUNCTION public.delete_user_admin(user_id_param uuid)
RETURNS void AS $$
BEGIN
  -- 1. Limpiar referencias de auditoría en cssi_contributors si existen
  UPDATE public.cssi_contributors 
  SET usuario_id = NULL 
  WHERE usuario_id = user_id_param;

  -- 2. Eliminar de perfiles (esta tabla tiene la FK que bloquea si no se borra primero)
  DELETE FROM public.profiles WHERE id = user_id_param;
  
  -- 3. Finalmente eliminar de auth.users (Supabase se encarga de identidades)
  DELETE FROM auth.users WHERE id = user_id_param;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-sync permissions for safety
NOTIFY pgrst, 'reload schema';
