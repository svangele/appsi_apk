-- =============================================================================
-- SCRIPT PARA LIMPIAR TABLA DE COLABORADORES (CSSI)
-- =============================================================================

-- Desactivar temporalmente los triggers si es necesario (opcional)
-- ALTER TABLE public.cssi_contributors DISABLE TRIGGER ALL;

-- Opción 1: Borrado total (Mantiene la estructura)
DELETE FROM public.cssi_contributors;

-- Opción 2: Reiniciar el contador de IDs si se prefiere (opcional si es SERIAL, 
-- pero usamos UUID por lo que no es necesario reiniciar secuencias de ID)

-- Si hay registros vinculados en profiles, se pondrán a NULL 
-- (asumiendo que se aplicó el script de unión con ON DELETE SET NULL)
UPDATE public.profiles SET cssi_id = NULL, numero_empleado = NULL;

-- Notificar recarga de esquema
NOTIFY pgrst, 'reload schema';

-- ALTER TABLE public.cssi_contributors ENABLE TRIGGER ALL;
