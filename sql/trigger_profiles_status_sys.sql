-- Función para detectar cambios en status_sys en la tabla profiles
-- Esta función reutiliza la lógica del trigger existente en cssi_contributors
CREATE OR REPLACE FUNCTION public.handle_profiles_status_sys_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Notificar cuando status_sys cambia a cualquier valor distinto de ACTIVO
    IF (NEW.status_sys IS DISTINCT FROM OLD.status_sys AND NEW.status_sys IS NOT NULL AND NEW.status_sys != 'ACTIVO') THEN
        INSERT INTO public.notifications (title, message, type, metadata)
        VALUES (
            'Estatus Sys: ' || COALESCE(NEW.nombre, '') || ' ' || COALESCE(NEW.paterno, ''),
            'El colaborador ' || COALESCE(NEW.nombre, '') || ' ' || COALESCE(NEW.paterno, '') || ' ha sido marcado como ' || NEW.status_sys || '.',
            'collaborator_alert',
            jsonb_build_object(
                'profile_id', NEW.id,
                'status_sys', NEW.status_sys,
                'numero_empleado', NEW.numero_empleado
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- También disparar cuando se INSERTA un perfil con status distinto a ACTIVO
CREATE OR REPLACE FUNCTION public.handle_profiles_status_sys_insert()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.status_sys IS NOT NULL AND NEW.status_sys != 'ACTIVO') THEN
        INSERT INTO public.notifications (title, message, type, metadata)
        VALUES (
            'Nuevo Colaborador: ' || COALESCE(NEW.nombre, '') || ' ' || COALESCE(NEW.paterno, ''),
            'Nuevo colaborador creado con estatus ' || NEW.status_sys || '.',
            'collaborator_alert',
            jsonb_build_object(
                'profile_id', NEW.id,
                'status_sys', NEW.status_sys,
                'numero_empleado', NEW.numero_empleado
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Crear/reemplazar el trigger de UPDATE en profiles
DROP TRIGGER IF EXISTS on_profiles_status_sys_change ON public.profiles;
CREATE TRIGGER on_profiles_status_sys_change
    AFTER UPDATE OF status_sys ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_profiles_status_sys_change();

-- Crear/reemplazar el trigger de INSERT en profiles
DROP TRIGGER IF EXISTS on_profiles_status_sys_insert ON public.profiles;
CREATE TRIGGER on_profiles_status_sys_insert
    AFTER INSERT ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_profiles_status_sys_insert();
