-- Add status_sys to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS status_sys TEXT DEFAULT 'ACTIVO';

-- Update the update_user_admin RPC to handle status_sys
CREATE OR REPLACE FUNCTION public.update_user_admin(
  user_id_param uuid,
  new_email text,
  new_full_name text,
  new_role text,
  new_cssi_id uuid DEFAULT NULL,
  new_numero_empleado text DEFAULT NULL,
  is_blocked_param boolean DEFAULT false,
  new_permissions jsonb DEFAULT NULL,
  new_drp_user text DEFAULT NULL,
  new_drp_pass text DEFAULT NULL,
  new_gp_user text DEFAULT NULL,
  new_gp_pass text DEFAULT NULL,
  new_bitrix_user text DEFAULT NULL,
  new_bitrix_pass text DEFAULT NULL,
  new_ek_user text DEFAULT NULL,
  new_ek_pass text DEFAULT NULL,
  new_otro_user text DEFAULT NULL,
  new_otro_pass text DEFAULT NULL,
  -- NEW PARAMETER
  new_status_sys text DEFAULT 'ACTIVO'
)
RETURNS void AS $$
BEGIN
  -- A. Actualizar auth.users (email y bloqueo)
  UPDATE auth.users
  SET 
    email = LOWER(new_email),
    banned_until = CASE WHEN is_blocked_param THEN 'infinity'::timestamptz ELSE NULL END,
    updated_at = now()
  WHERE id = user_id_param;

  -- B. Actualizar public.profiles
  UPDATE public.profiles
  SET
    full_name = new_full_name,
    role = new_role::user_role,
    cssi_id = new_cssi_id,
    numero_empleado = new_numero_empleado,
    is_blocked = is_blocked_param,
    permissions = COALESCE(new_permissions, permissions),
    drp_user = COALESCE(new_drp_user, drp_user),
    drp_pass = COALESCE(new_drp_pass, drp_pass),
    gp_user = COALESCE(new_gp_user, gp_user),
    gp_pass = COALESCE(new_gp_pass, gp_pass),
    bitrix_user = COALESCE(new_bitrix_user, bitrix_user),
    bitrix_pass = COALESCE(new_bitrix_pass, bitrix_pass),
    ek_user = COALESCE(new_ek_user, ek_user),
    ek_pass = COALESCE(new_ek_pass, ek_pass),
    otro_user = COALESCE(new_otro_user, otro_user),
    otro_pass = COALESCE(new_otro_pass, otro_pass),
    -- Update status_sys
    status_sys = COALESCE(new_status_sys, status_sys)
  WHERE id = user_id_param;

  -- C. Asegurar que la identidad de auth también se actualice (para el login)
  UPDATE auth.identities
  SET email = LOWER(new_email)
  WHERE user_id = user_id_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
