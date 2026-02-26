-- 1. Crear tabla de notificaciones
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'collaborator_alert',
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- 2. Habilitar RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 3. Políticas de RLS (Para este caso, permitimos que administradores vean y editen)
CREATE POLICY "Admins can view all notifications" 
ON public.notifications FOR SELECT 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.role = 'admin'
  )
);

CREATE POLICY "Admins can update notifications" 
ON public.notifications FOR UPDATE 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.role = 'admin'
  )
);

-- 4. Función del disparador para detectar cambios en status_sys
CREATE OR REPLACE FUNCTION public.handle_status_sys_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Solo notificar si cambia a CAMBIO o ELIMINAR
    IF (NEW.status_sys IN ('CAMBIO', 'ELIMINAR') AND (OLD.status_sys IS NULL OR OLD.status_sys != NEW.status_sys)) THEN
        INSERT INTO public.notifications (title, message, type, metadata)
        VALUES (
            'Alerta de Estado: ' || NEW.status_sys,
            'El colaborador ' || COALESCE(NEW.nombre, '') || ' ' || COALESCE(NEW.paterno, '') || ' ha sido marcado como ' || NEW.status_sys || '.',
            'collaborator_alert',
            jsonb_build_object(
                'contributor_id', NEW.id,
                'status_sys', NEW.status_sys,
                'numero_empleado', NEW.numero_empleado
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Crear el disparador en la tabla cssi_contributors
DROP TRIGGER IF EXISTS on_status_sys_change ON public.cssi_contributors;
CREATE TRIGGER on_status_sys_change
    AFTER UPDATE ON public.cssi_contributors
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_status_sys_change();

-- 6. Habilitar Realtime para la tabla notifications
-- Nota: Esto se suele hacer desde el dashboard de Supabase, 
-- pero se puede intentar vía SQL si los permisos lo permiten:
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
