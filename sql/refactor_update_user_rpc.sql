-- =============================================================================
-- REFACTOR: update_user_admin para PROFILES 360
-- =============================================================================

-- Eliminamos versiones previas para evitar conflictos de firmas
DROP FUNCTION IF EXISTS public.update_user_admin(uuid, text, text, text, uuid, text, boolean, jsonb);
DROP FUNCTION IF EXISTS public.update_user_admin(uuid, text, text, text, uuid, text, boolean, jsonb, text, text, text, text, text, text, text, text, text, text);
DROP FUNCTION IF EXISTS public.update_user_admin(uuid, text, text, text, uuid, text, boolean, jsonb, text, text, text, text, text, text, text, text, text, text, text);

-- Nueva función unificada
CREATE OR REPLACE FUNCTION public.update_user_admin(
  user_id_param uuid,
  new_email text,
  new_full_name text,
  new_role text,
  new_status_sys text DEFAULT 'ACTIVO'
)
RETURNS void AS $$
BEGIN
  -- 1. Actualizar auth.users (Email y MetaData)
  UPDATE auth.users
  SET 
    email = LOWER(new_email),
    raw_user_meta_data = raw_user_meta_data || 
      jsonb_build_object(
        'full_name', new_full_name,
        'role', new_role
      ),
    updated_at = now()
  WHERE id = user_id_param;

  -- 2. Actualizar public.profiles
  -- Nota: Solo actualizamos los campos básicos del sistema aquí. 
  -- Los campos de Colaborador se editan directamente en la tabla profiles.
  UPDATE public.profiles
  SET 
    email = LOWER(new_email),
    full_name = new_full_name,
    role = new_role::user_role,
    status_sys = new_status_sys,
    updated_at = now()
  WHERE id = user_id_param;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
