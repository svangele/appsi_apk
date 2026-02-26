-- =============================================================================
-- FINAL FIX: Convert generated "email" to regular column and restore sync
-- =============================================================================

-- 1. Remove the generated column and recreate it as a normal one
-- This is necessary because GENERATED columns cannot be manually updated.
-- We use a transaction-like approach (though in SQL Editor it's implicit)
ALTER TABLE public.profiles DROP COLUMN IF EXISTS email;
ALTER TABLE public.profiles ADD COLUMN email TEXT;

-- 2. Restore the sync in the handle_new_user trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  is_admin_user boolean;
BEGIN
  is_admin_user := (COALESCE(new.raw_user_meta_data->>'role', 'usuario') = 'admin');

  INSERT INTO public.profiles (id, full_name, role, email, is_blocked, permissions)
  VALUES (
    new.id, 
    COALESCE(new.raw_user_meta_data->>'full_name', 'Nuevo Usuario'), 
    (COALESCE(new.raw_user_meta_data->>'role', 'usuario'))::user_role,
    LOWER(new.email), -- Now we CAN save the email
    (new.banned_until IS NOT NULL AND new.banned_until > now()),
    CASE 
      WHEN is_admin_user THEN '{"show_users": true, "show_issi": true, "show_cssi": true, "show_logs": true}'::jsonb
      ELSE '{"show_users": false, "show_issi": false, "show_cssi": false, "show_logs": false}'::jsonb
    END
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role,
    email = EXCLUDED.email, -- Now we CAN update the email
    is_blocked = EXCLUDED.is_blocked;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Restore the sync in the update_user_admin RPC
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
  new_otro_pass text DEFAULT NULL
)
RETURNS void AS $$
BEGIN
  -- A. Update auth.users
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

  -- B. Update public.profiles (Now including email!)
  UPDATE public.profiles
  SET
    full_name = new_full_name,
    role = new_role::user_role,
    email = LOWER(new_email), -- Manual sync restored
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
    otro_pass = COALESCE(new_otro_pass, otro_pass)
  WHERE id = user_id_param;

  -- C. Update identities
  UPDATE auth.identities
  SET identity_data = identity_data || jsonb_build_object('email', LOWER(new_email))
  WHERE user_id = user_id_param AND provider = 'email';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Initial sync of all emails
UPDATE public.profiles p
SET email = u.email
FROM auth.users u
WHERE p.id = u.id;

NOTIFY pgrst, 'reload schema';
