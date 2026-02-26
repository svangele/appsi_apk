-- Migración para habilitar notificaciones por usuario
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

-- Actualizar política de lectura (SELECT)
DROP POLICY IF EXISTS "Admins can view all notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users and Admins can view notifications" ON public.notifications;

CREATE POLICY "Users and Admins can view notifications" 
ON public.notifications FOR SELECT 
TO authenticated 
USING (
    (user_id = auth.uid()) OR 
    (EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role = 'admin'
    ))
);

-- Actualizar política de actualización (UPDATE)
DROP POLICY IF EXISTS "Admins can update notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users and Admins can update notifications" ON public.notifications;

CREATE POLICY "Users and Admins can update notifications" 
ON public.notifications FOR UPDATE 
TO authenticated 
USING (
    (user_id = auth.uid()) OR 
    (EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role = 'admin'
    ))
);

-- Habilitar inserción (INSERT) para usuarios autenticados
DROP POLICY IF EXISTS "Users can insert notifications" ON public.notifications;
CREATE POLICY "Users can insert notifications" 
ON public.notifications FOR INSERT 
TO authenticated 
WITH CHECK (true);
