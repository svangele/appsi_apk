-- =============================================================================
-- SYSTEM REPAIR: Fix for Generated "email" Column Error in public.profiles and auth.identities
-- =============================================================================

-- 1. DROP ALL PREVIOUS VERSIONS OF update_user_admin
-- We need to drop them to ensure we don't have conflicting overloads.
DROP FUNCTION IF EXISTS public.update_user_admin(uuid, text, text, text, uuid, text, boolean, jsonb);
DROP FUNCTION IF EXISTS public.update_user_admin(uuid, text, text, text, uuid, text, boolean, jsonb, text, text, text, text, text, text, text, text, text, text);
DROP FUNCTION IF EXISTS public.update_user_admin(uuid, text, text, text, uuid, text, boolean, jsonb, text, text, text, text, text, text, text, text, text, text, text);

-- 2. CREATE THE DEFINITIVE VERSION
CREATE OR REPLACE FUNCTION public.update_user_admin(
  user_id_param uuid,
  new_email text,
  new_full_name text,
  new_role text,
  new_cssi_id uuid DEFAULT NULL,
  new_numero_empleado text DEFAULT NULL,
  is_blocked_param boolean DEFAULT false,
  new_permissions jsonb DEFAULT NULL,
  -- 10 parameters for credentials
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
  -- Parameter for system status
  new_status_sys text DEFAULT 'ACTIVO'
)
RETURNS void AS $$
BEGIN
  -- A. Update auth.users (email and blocking)
  UPDATE auth.users
  SET 
    email = LOWER(new_email),
    raw_user_meta_data = raw_user_meta_data || 
      jsonb_build_object(
        'full_name', new_full_name,
        'role', new_role,
        'email', LOWER(new_email)
      ),
    updated_at = now(),
    banned_until = CASE WHEN is_blocked_param THEN '3000-01-01 00:00:00+00'::timestamptz ELSE NULL END
  WHERE id = user_id_param;

  -- B. Update public.profiles (WITHOUT manual email update)
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
    status_sys = COALESCE(new_status_sys, status_sys)
  WHERE id = user_id_param;

  -- C. Update identities (Safe version using jsonb for identity_data)
  -- This avoids the "generated column" error on auth.identities.email
  UPDATE auth.identities
  SET identity_data = identity_data || jsonb_build_object('email', LOWER(new_email))
  WHERE user_id = user_id_param AND provider = 'email';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. RELOAD SCHEMA
NOTIFY pgrst, 'reload schema';
