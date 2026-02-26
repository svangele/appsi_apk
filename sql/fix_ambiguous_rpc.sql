-- =============================================================================
-- LIMPIEZA DE COLISIONES: Eliminación de Overloads de RPC
-- =============================================================================

-- 0. ASEGURAR COLUMNAS DE AUDITORÍA
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- 1. ELIMINAR TODAS LAS VERSIONES ANTERIORES POR NOMBRE
-- Como PostgREST se confunde cuando hay múltiples funciones con el mismo nombre,
-- borramos todas las variaciones posibles antes de crear la definitiva.

DO $$ 
DECLARE 
    func_name text := 'update_user_admin';
    func_schema text := 'public';
    func_record record;
BEGIN
    FOR func_record IN 
        SELECT pg_proc.oid::regprocedure as signature
        FROM pg_proc 
        JOIN pg_namespace ON pg_proc.pronamespace = pg_namespace.oid
        WHERE proname = func_name 
          AND nspname = func_schema
    LOOP
        EXECUTE 'DROP FUNCTION ' || func_record.signature;
    END LOOP;
END $$;

-- 2. CREAR FUNCIONES DEFINITIVAS (Unificadas y Limpias)

-- A. Función para Crear Usuario (Auth) o Conceder Acceso a Perfil Existente
CREATE OR REPLACE FUNCTION public.create_user_admin(
  email text,
  password text,
  full_name text,
  user_role text,
  user_id_param uuid DEFAULT NULL  -- Si se pasa, usamos este ID para vincular a un perfil existente
)
RETURNS uuid AS $$
DECLARE
  new_user_id uuid;
BEGIN
  -- 0. Verificar permisos de administrador
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'No tienes permisos de administrador para crear usuarios.';
  END IF;

  -- Si no se pasa un ID, generamos uno nuevo
  new_user_id := COALESCE(user_id_param, gen_random_uuid());

  -- 1. Insertar en auth.users (Metadata para el JWT)
  -- Si ya existe el ID en auth.users, esto fallará por duplicado (comportamiento esperado)
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

  -- 2. Vincular identidad (Obligatorio para login)
  INSERT INTO auth.identities (
    id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
  )
  VALUES (
    new_user_id, new_user_id,
    jsonb_build_object('sub', new_user_id, 'email', LOWER(email), 'email_verified', true),
    'email', new_user_id::text, null, now(), now()
  );

  -- 3. Asegurar que el perfil público tenga los datos mínimos (si no existía se creará por el trigger)
  -- El trigger handle_new_user se encargará del resto.
  
  RETURN new_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- B. Función de Actualización Unificada
CREATE OR REPLACE FUNCTION public.update_user_admin(
  user_id_param uuid,
  new_email text,
  new_full_name text,
  new_role text,
  new_status_sys text DEFAULT 'ACTIVO',
  is_blocked_param boolean DEFAULT false,
  new_permissions jsonb DEFAULT NULL,
  new_status_rh text DEFAULT 'ACTIVO',
  new_password text DEFAULT NULL
)
RETURNS void AS $$
BEGIN
  -- 0. Verificar permisos de administrador
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'No tienes permisos de administrador para actualizar usuarios.';
  END IF;

  -- A. Actualizar auth.users (Metadata para el JWT)
  UPDATE auth.users
  SET 
    email = LOWER(new_email),
    encrypted_password = CASE 
      WHEN new_password IS NOT NULL AND new_password <> '' 
      THEN extensions.crypt(new_password, extensions.gen_salt('bf', 10)) 
      ELSE encrypted_password 
    END,
    raw_user_meta_data = raw_user_meta_data || 
      jsonb_build_object(
        'full_name', new_full_name,
        'role', new_role,
        'permissions', COALESCE(new_permissions, raw_user_meta_data->'permissions')
      ),
    updated_at = now(),
    banned_until = CASE WHEN is_blocked_param THEN '3000-01-01 00:00:00+00'::timestamptz ELSE NULL END
  WHERE id = user_id_param;

  -- B. Actualizar public.profiles
  UPDATE public.profiles
  SET
    email = LOWER(new_email),
    full_name = new_full_name,
    role = new_role::user_role,
    status_sys = new_status_sys,
    status_rh = new_status_rh,
    is_blocked = is_blocked_param,
    permissions = COALESCE(new_permissions, permissions),
    updated_at = now()
  WHERE id = user_id_param;

  -- C. Actualizar identidades (para login)
  UPDATE auth.identities
  SET identity_data = identity_data || jsonb_build_object('email', LOWER(new_email))
  WHERE user_id = user_id_param AND provider = 'email';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

NOTIFY pgrst, 'reload schema';
