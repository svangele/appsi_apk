-- =============================================================================
-- SCRIPT DEFINITIVO: Creación de Usuarios y Sincronización de Perfiles
-- =============================================================================

-- 1. FUNCIÓN DE ADMINISTRACIÓN (Alta Fidelidad con GoTrue)
-- Esta función crea usuarios directamente en auth.users cumpliendo con todos
-- los requisitos de escaneo (no-nulls) y vinculación de identidad.
CREATE OR REPLACE FUNCTION public.create_user_admin(
  email text,
  password text,
  full_name text,
  user_role text
)
RETURNS uuid AS $$
DECLARE
  new_user_id uuid;
BEGIN
  new_user_id := gen_random_uuid();

  -- A. Insertar en auth.users (Rellenando campos técnicos para evitar Scan Errors)
  INSERT INTO auth.users (
    id, instance_id, email, encrypted_password, email_confirmed_at, 
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at, 
    role, aud, is_sso_user, is_anonymous,
    confirmation_token, recovery_token, email_change_token_new, 
    email_change_token_current, email_change, phone_change, 
    phone_change_token, reauthentication_token,
    email_change_confirm_status
  )
  VALUES (
    new_user_id, '00000000-0000-0000-0000-000000000000', LOWER(email),
    extensions.crypt(password, extensions.gen_salt('bf', 10)),
    now(),
    '{"provider": "email", "providers": ["email"]}',
    jsonb_build_object(
      'sub', new_user_id,
      'email', LOWER(email),
      'full_name', full_name,
      'role', user_role,
      'email_verified', true,
      'phone_verified', false
    ),
    now(), now(), 'authenticated', 'authenticated', false, false,
    '', '', '', '', '', '', '', '', 0
  );

  -- B. Vincular identidad (Obligatorio para visibilidad en UI y Login)
  INSERT INTO auth.identities (
    id,               -- Identidad ID = User ID para máxima compatibilidad
    user_id, 
    identity_data, 
    provider, 
    provider_id,      -- Provider ID = User ID
    last_sign_in_at, 
    created_at, 
    updated_at
  )
  VALUES (
    new_user_id, 
    new_user_id,
    jsonb_build_object('sub', new_user_id, 'email', LOWER(email), 'email_verified', true),
    'email',
    new_user_id::text, 
    null, now(), now()
  );

  RETURN new_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. DISPARADOR DE PERFILES (Seguro y Sincronizado)
-- Crea o actualiza el perfil público cuando nace un usuario en auth.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS permissions JSONB DEFAULT '{
  "show_users": false, 
  "show_issi": false, 
  "show_cssi": false, 
  "show_logs": false
}'::jsonb;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  is_admin_user boolean;
BEGIN
  is_admin_user := (COALESCE(new.raw_user_meta_data->>'role', 'usuario') = 'admin');

  INSERT INTO public.profiles (id, full_name, role, is_blocked, permissions)
  VALUES (
    new.id, 
    COALESCE(new.raw_user_meta_data->>'full_name', 'Nuevo Usuario'), 
    (COALESCE(new.raw_user_meta_data->>'role', 'usuario'))::user_role,
    (new.banned_until IS NOT NULL AND new.banned_until > now()),
    -- Si es admin, le damos todos los permisos por defecto
    CASE 
      WHEN is_admin_user THEN '{"show_users": true, "show_issi": true, "show_cssi": true, "show_logs": true}'::jsonb
      ELSE '{"show_users": false, "show_issi": false, "show_cssi": false, "show_logs": false}'::jsonb
    END
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role,
    is_blocked = EXCLUDED.is_blocked;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. FUNCIÓN DE SEGURIDAD (No Recursiva)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
  RETURN (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. FUNCIÓN DE ACTUALIZACIÓN DE USUARIO (Edición, Bloqueo y Permisos)
CREATE OR REPLACE FUNCTION public.update_user_admin(
  user_id_param uuid,
  new_email text,
  new_full_name text,
  new_role text,
  new_cssi_id uuid DEFAULT NULL,
  new_numero_empleado text DEFAULT NULL,
  is_blocked_param boolean DEFAULT false,
  new_permissions jsonb DEFAULT NULL
)
RETURNS void AS $$
BEGIN
  -- A. Actualizar auth.users
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

  -- B. Actualizar public.profiles
  UPDATE public.profiles
  SET
    full_name = new_full_name,
    role = new_role::user_role,
    cssi_id = new_cssi_id,
    numero_empleado = new_numero_empleado,
    is_blocked = is_blocked_param,
    permissions = COALESCE(new_permissions, permissions)
  WHERE id = user_id_param;

  -- C. Actualizar identidades
  UPDATE auth.identities
  SET identity_data = identity_data || jsonb_build_object('email', LOWER(new_email))
  WHERE user_id = user_id_param AND provider = 'email';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Sincronizar datos existentes y asignar permisos por defecto a admins
UPDATE public.profiles p
SET 
  is_blocked = (u.banned_until IS NOT NULL AND u.banned_until > now()),
  permissions = CASE 
    WHEN p.role = 'admin' THEN '{"show_users": true, "show_issi": true, "show_cssi": true, "show_logs": true}'::jsonb
    ELSE '{"show_users": false, "show_issi": false, "show_cssi": false, "show_logs": false}'::jsonb
  END
FROM auth.users u
WHERE p.id = u.id;

NOTIFY pgrst, 'reload schema';
