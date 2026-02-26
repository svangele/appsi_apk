-- =============================================================================
-- FIX SUPREMO: ID Auto-gen, Sincronización Forzada y RLS de Alta Disponibilidad
-- =============================================================================

-- 1. ARREGLAR SCHEMA: ID AUTO-GENERADO Y COLUMNAS
-- Esto soluciona el error "null value in column id" al insertar desde Flutter
ALTER TABLE public.profiles 
ALTER COLUMN id SET DEFAULT gen_random_uuid(),
ADD COLUMN IF NOT EXISTS status_rh TEXT DEFAULT 'ACTIVO';

-- 2. SINCRONIZACIÓN FORZADA DE METADATOS (Auth <-> Profiles)
-- Nos aseguramos de que TODO usuario en Auth tenga su rol y permisos de Profile
-- Esto es CRÍTICO para que el JWT funcione correctamente.
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT id, role, permissions, full_name, email FROM public.profiles LOOP
        UPDATE auth.users 
        SET raw_user_meta_data = jsonb_build_object(
            'role', r.role,
            'permissions', r.permissions,
            'full_name', r.full_name,
            'email', r.email,
            'email_verified', true
        )
        WHERE id = r.id;
    END LOOP;
END $$;

-- 3. POLÍTICAS RLS ROBUSTAS (SELECT, INSERT, UPDATE, DELETE)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Ver perfiles: Admin (JWT), Yo mismo, o con permisos
DROP POLICY IF EXISTS "Ver perfiles: permiso o admin" ON public.profiles;
CREATE POLICY "Ver perfiles: permiso o admin"
  ON public.profiles
  FOR SELECT
  USING (
    id = auth.uid() OR 
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' OR
    (auth.jwt() -> 'user_metadata' -> 'permissions' ->> 'show_users')::boolean = true OR
    (auth.jwt() -> 'user_metadata' -> 'permissions' ->> 'show_cssi')::boolean = true
  );

-- Modificar perfiles: Solo Admins o personal con permiso (CRUD Total)
DROP POLICY IF EXISTS "Modificar perfiles: solo admins" ON public.profiles;
CREATE POLICY "Modificar perfiles: solo admins"
  ON public.profiles
  FOR ALL
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
  )
  WITH CHECK (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
  );

-- 4. RPC DE ACTUALIZACIÓN ACTUALIZADO (Soporte total)
CREATE OR REPLACE FUNCTION public.update_user_admin(
  user_id_param uuid,
  new_email text,
  new_full_name text,
  new_role text,
  new_status_sys text DEFAULT 'ACTIVO',
  is_blocked_param boolean DEFAULT false,
  new_permissions jsonb DEFAULT NULL,
  new_status_rh text DEFAULT 'ACTIVO'
)
RETURNS void AS $$
BEGIN
  -- A. Actualizar auth.users (Metadata para el JWT)
  UPDATE auth.users
  SET 
    email = LOWER(new_email),
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. LIMPIEZA DE FUNCIONES QUE PODRÍAN CAUSAR RECURSIÓN
DROP FUNCTION IF EXISTS public.check_viewer_permission(text);

-- Recarga de esquema
NOTIFY pgrst, 'reload schema';
