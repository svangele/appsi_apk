-- =============================================================================
-- FIX DEFINITIVO: Sincronización de Metadatos y RLS sin Recursión
-- =============================================================================

-- 1. Sincronizar Permisos y Roles de Profiles -> Auth (Para que salgan en el JWT)
UPDATE auth.users u
SET raw_user_meta_data = raw_user_meta_data || 
    jsonb_build_object(
        'role', p.role,
        'permissions', p.permissions
    )
FROM public.profiles p
WHERE u.id = p.id;

-- 2. Función Unificada de Actualización de Usuario (Garantiza sincronía)
CREATE OR REPLACE FUNCTION public.update_user_admin(
  user_id_param uuid,
  new_email text,
  new_full_name text,
  new_role text,
  new_status_sys text DEFAULT 'ACTIVO',
  is_blocked_param boolean DEFAULT false,
  new_permissions jsonb DEFAULT NULL
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
    is_blocked = is_blocked_param,
    permissions = COALESCE(new_permissions, permissions),
    updated_at = now()
  WHERE id = user_id_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Eliminar políticas dependientes antes de limpiar la función
DROP POLICY IF EXISTS "Ver perfiles: permiso o admin" ON public.profiles;
DROP POLICY IF EXISTS "Modificar perfiles: solo admins" ON public.profiles;
DROP POLICY IF EXISTS "Ver ISSI: permiso o admin" ON public.issi_inventory;
DROP POLICY IF EXISTS "Modificar ISSI: permiso o admin" ON public.issi_inventory;
DROP POLICY IF EXISTS "Ver logs: permiso o admin" ON public.system_logs;

-- Ahora podemos borrar la función recursiva anterior
DROP FUNCTION IF EXISTS public.check_viewer_permission(text);

-- 4. Re-habilitar RLS con Políticas Basadas en JWT (No recursivas)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Ver perfiles: permiso o admin"
  ON public.profiles
  FOR SELECT
  USING (
    id = auth.uid() OR
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' OR
    (auth.jwt() -> 'user_metadata' -> 'permissions' ->> 'show_users')::boolean = true OR
    (auth.jwt() -> 'user_metadata' -> 'permissions' ->> 'show_cssi')::boolean = true
  );

-- Modificar perfiles: Solo Admins (directo via JWT)
DROP POLICY IF EXISTS "Modificar perfiles: solo admins" ON public.profiles;
CREATE POLICY "Modificar perfiles: solo admins"
  ON public.profiles
  FOR ALL
  USING ( (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' );

-- 5. Otras Tablas (ISSI, Logs)
DROP POLICY IF EXISTS "Ver ISSI: permiso o admin" ON public.issi_inventory;
CREATE POLICY "Ver ISSI: permiso o admin"
  ON public.issi_inventory FOR SELECT
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' OR
    (auth.jwt() -> 'user_metadata' -> 'permissions' ->> 'show_issi')::boolean = true
  );

DROP POLICY IF EXISTS "Modificar ISSI: permiso o admin" ON public.issi_inventory;
CREATE POLICY "Modificar ISSI: permiso o admin"
  ON public.issi_inventory FOR ALL
  USING ( (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' );

DROP POLICY IF EXISTS "Ver logs: permiso o admin" ON public.system_logs;
CREATE POLICY "Ver logs: permiso o admin"
  ON public.system_logs FOR SELECT
  USING ( (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' );

-- 6. Recarga de esquema
NOTIFY pgrst, 'reload schema';
