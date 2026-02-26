-- =============================================================================
-- FIX FINAL: Restauración de Columnas, RPC y RLS (Profiles 360)
-- =============================================================================

-- 1. ASEGURAR COLUMNAS FALTANTES EN PROFILES
-- Añadimos status_rh que faltaba tras la unificación
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS status_rh TEXT DEFAULT 'ACTIVO';

-- 2. FUNCIÓN UNIFICADA DE ACTUALIZACIÓN DE USUARIO (Sincronizada con Flutter)
-- Soporta email, rol, bloqueo, permisos y estados (sys/rh)
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

-- 3. POLÍTICAS RLS ROBUSTAS (Evitan recursión usando el JWT)
-- Aseguramos que RLS esté habilitado
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Ver perfiles: Admin, Yo mismo, o con permiso show_users/show_cssi
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

-- Modificar perfiles: Solo Admins
DROP POLICY IF EXISTS "Modificar perfiles: solo admins" ON public.profiles;
CREATE POLICY "Modificar perfiles: solo admins"
  ON public.profiles
  FOR ALL
  USING ( (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' );

-- Eliminar funciones obsoletas para limpiar el esquema
DROP FUNCTION IF EXISTS public.check_viewer_permission(text);

-- 4. RECARGA DE ESQUEMA Y SINCRONIZACIÓN INICIAL
-- Forzamos que todos los usuarios tengan el rol en el JWT
UPDATE auth.users u
SET raw_user_meta_data = raw_user_meta_data || jsonb_build_object('role', p.role, 'permissions', p.permissions)
FROM public.profiles p
WHERE u.id = p.id;

NOTIFY pgrst, 'reload schema';
