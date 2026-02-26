-- =============================================================================
-- FIX: Restricciones de Clave Foránea para Eliminación de Usuarios
-- =============================================================================

-- 1. NOTIFICACIONES
-- Cambiamos la FK para que se eliminen automáticamente las notificaciones del usuario
ALTER TABLE public.notifications
DROP CONSTRAINT IF EXISTS notifications_user_id_fkey;

ALTER TABLE public.notifications
ADD CONSTRAINT notifications_user_id_fkey 
FOREIGN KEY (user_id) 
REFERENCES auth.users(id) 
ON DELETE CASCADE;

-- 2. INCIDENCIAS
-- Aseguramos que las incidencias también se eliminen en cascada
ALTER TABLE public.incidencias
DROP CONSTRAINT IF EXISTS incidencias_usuario_id_fkey;

ALTER TABLE public.incidencias
ADD CONSTRAINT incidencias_usuario_id_fkey 
FOREIGN KEY (usuario_id) 
REFERENCES auth.users(id) 
ON DELETE CASCADE;

-- 3. ACTUALIZAR RPC delete_user_admin (Limpieza extra por seguridad)
CREATE OR REPLACE FUNCTION public.delete_user_admin(user_id_param uuid)
RETURNS void AS $$
BEGIN
  -- Borrar notificaciones e incidencias es automático por CASCADE ahora,
  -- pero el perfil y el usuario de Auth deben borrarse en este orden:
  
  -- Eliminar perfil
  DELETE FROM public.profiles WHERE id = user_id_param;
  
  -- Eliminar usuario de Auth
  DELETE FROM auth.users WHERE id = user_id_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Notificar recarga de esquema
NOTIFY pgrst, 'reload schema';
