-- Permitir que todos los usuarios autenticados vean los datos de CSSI
-- Pero mantener que solo los admins puedan crear, editar o eliminar.

DROP POLICY IF EXISTS "Admins have full access to cssi_contributors" ON public.cssi_contributors;

-- 1. Todos pueden ver
CREATE POLICY "Usuarios autenticados pueden ver colaboradores"
ON public.cssi_contributors FOR SELECT
TO authenticated
USING (true);

-- 2. Solo admins pueden insertar
CREATE POLICY "Solo admins pueden insertar colaboradores"
ON public.cssi_contributors FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
);

-- 3. Solo admins pueden actualizar
CREATE POLICY "Solo admins pueden actualizar colaboradores"
ON public.cssi_contributors FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
);

-- 4. Solo admins pueden eliminar
CREATE POLICY "Solo admins pueden eliminar colaboradores"
ON public.cssi_contributors FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
);
