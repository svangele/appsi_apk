-- 1. Eliminar las restricciones antiguas si existen
ALTER TABLE public.cssi_contributors DROP CONSTRAINT IF EXISTS cssi_contributors_status_sys_check;
ALTER TABLE public.cssi_contributors DROP CONSTRAINT IF EXISTS cssi_contributors_status_rh_check;

-- 2. Agregar las nuevas restricciones que incluyen 'ELIMINAR' y 'REINGRESO'
ALTER TABLE public.cssi_contributors 
ADD CONSTRAINT cssi_contributors_status_sys_check 
CHECK (status_sys IN ('ACTIVO', 'BAJA', 'CAMBIO', 'ELIMINAR', 'REINGRESO'));

ALTER TABLE public.cssi_contributors 
ADD CONSTRAINT cssi_contributors_status_rh_check 
CHECK (status_rh IN ('ACTIVO', 'BAJA', 'CAMBIO', 'ELIMINAR', 'REINGRESO'));

-- 3. Asegurar que las columnas existan (por si acaso) y tengan el tipo correcto
-- (Ya existen, pero esto refuerza la estructura)
ALTER TABLE public.cssi_contributors 
ALTER COLUMN status_sys SET DEFAULT 'ACTIVO',
ALTER COLUMN status_rh SET DEFAULT 'ACTIVO';

-- 4. Aplicar la misma restricción a la tabla profiles para consistencia
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_status_sys_check;
ALTER TABLE public.profiles 
ADD CONSTRAINT profiles_status_sys_check 
CHECK (status_sys IN ('ACTIVO', 'BAJA', 'CAMBIO', 'ELIMINAR', 'REINGRESO'));
