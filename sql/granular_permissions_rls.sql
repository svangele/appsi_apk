-- =============================================================================
-- FIX: Funciones de Apoyo para RLS (Evitar Recursión y Errores de Lógica)
-- =============================================================================

-- Función para verificar permisos del visualizador de forma segura
CREATE OR REPLACE FUNCTION public.check_viewer_permission(perm_key TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND (
            role = 'admin' 
            OR (permissions->>perm_key)::boolean = true
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- =============================================================================
-- ACTUALIZACIÓN DE POLÍTICAS RLS (Profiles)
-- =============================================================================

-- 1. PERFILES (profiles)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Ver perfiles: Yo mismo, o si tengo permiso de ver usuarios/cssi, o soy admin
DROP POLICY IF EXISTS "Ver perfiles: permiso o admin" ON public.profiles;
CREATE POLICY "Ver perfiles: permiso o admin"
  ON public.profiles
  FOR SELECT
  USING (
    id = auth.uid() OR
    public.check_viewer_permission('show_users') OR
    public.check_viewer_permission('show_cssi')
  );

-- Modificar perfiles: Solo Admins (basado en el rol del QUE MODIFICA)
DROP POLICY IF EXISTS "Modificar perfiles: solo admins" ON public.profiles;
CREATE POLICY "Modificar perfiles: solo admins"
  ON public.profiles
  FOR UPDATE
  USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- =============================================================================
-- ACTUALIZACIÓN DE POLÍTICAS RLS (ISSI y Otros)
-- =====================

-- Ver ISSI: permiso o admin
DROP POLICY IF EXISTS "Ver ISSI: permiso o admin" ON public.issi_inventory;
CREATE POLICY "Ver ISSI: permiso o admin"
  ON public.issi_inventory
  FOR SELECT
  USING ( public.check_viewer_permission('show_issi') );

-- Modificar ISSI: permiso o admin
DROP POLICY IF EXISTS "Modificar ISSI: permiso o admin" ON public.issi_inventory;
CREATE POLICY "Modificar ISSI: permiso o admin"
  ON public.issi_inventory
  FOR ALL
  USING ( public.check_viewer_permission('show_issi') );

-- Ver logs: permiso o admin
DROP POLICY IF EXISTS "Ver logs: permiso o admin" ON public.system_logs;
CREATE POLICY "Ver logs: permiso o admin"
  ON public.system_logs
  FOR SELECT
  USING ( public.check_viewer_permission('show_logs') );

-- Notificar recarga de esquema
NOTIFY pgrst, 'reload schema';
