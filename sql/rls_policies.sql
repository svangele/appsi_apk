-- =============================================================================
-- RLS Policies for system_logs and issi_inventory
-- Run this in Supabase SQL Editor
-- =============================================================================

-- =====================
-- 1. system_logs
-- =====================
ALTER TABLE public.system_logs ENABLE ROW LEVEL SECURITY;

-- Only admins can view logs
DROP POLICY IF EXISTS "Solo admins pueden ver logs" ON public.system_logs;
CREATE POLICY "Solo admins pueden ver logs"
  ON public.system_logs
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
  );

-- Only the system (via SECURITY DEFINER functions) can insert logs
DROP POLICY IF EXISTS "Solo sistema puede insertar logs" ON public.system_logs;
CREATE POLICY "Solo sistema puede insertar logs"
  ON public.system_logs
  FOR INSERT
  WITH CHECK (false);

-- No one can update or delete logs
DROP POLICY IF EXISTS "Nadie puede actualizar logs" ON public.system_logs;
CREATE POLICY "Nadie puede actualizar logs"
  ON public.system_logs
  FOR UPDATE
  USING (false);

DROP POLICY IF EXISTS "Nadie puede eliminar logs" ON public.system_logs;
CREATE POLICY "Nadie puede eliminar logs"
  ON public.system_logs
  FOR DELETE
  USING (false);

-- =====================
-- 2. issi_inventory
-- =====================
ALTER TABLE public.issi_inventory ENABLE ROW LEVEL SECURITY;

-- All authenticated users can view inventory
DROP POLICY IF EXISTS "Usuarios autenticados pueden ver inventario" ON public.issi_inventory;
CREATE POLICY "Usuarios autenticados pueden ver inventario"
  ON public.issi_inventory
  FOR SELECT
  USING (auth.role() = 'authenticated');

-- Only admins can insert inventory items
DROP POLICY IF EXISTS "Solo admins pueden crear items" ON public.issi_inventory;
CREATE POLICY "Solo admins pueden crear items"
  ON public.issi_inventory
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
  );

-- Only admins can update inventory items
DROP POLICY IF EXISTS "Solo admins pueden actualizar items" ON public.issi_inventory;
CREATE POLICY "Solo admins pueden actualizar items"
  ON public.issi_inventory
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
  );

-- Only admins can delete inventory items
DROP POLICY IF EXISTS "Solo admins pueden eliminar items" ON public.issi_inventory;
CREATE POLICY "Solo admins pueden eliminar items"
  ON public.issi_inventory
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
  );
