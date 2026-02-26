-- RPC para permitir que la aplicación registre eventos en system_logs
-- a pesar de las restricciones de RLS (Row Level Security).
-- Se ejecuta con SECURITY DEFINER para tener permisos de escritura.

CREATE OR REPLACE FUNCTION public.log_event(
    action_type_param TEXT,
    target_info_param TEXT
)
RETURNS void AS $$
BEGIN
    INSERT INTO public.system_logs (
        action_type,
        target_info,
        created_at
    )
    VALUES (
        action_type_param,
        target_info_param,
        NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Otorgar permiso de ejecución a usuarios autenticados
GRANT EXECUTE ON FUNCTION public.log_event(TEXT, TEXT) TO authenticated;
