-- Add status fields to contributors
ALTER TABLE public.cssi_contributors 
ADD COLUMN IF NOT EXISTS status_sys TEXT CHECK (status_sys IN ('ACTIVO', 'BAJA', 'CAMBIO')),
ADD COLUMN IF NOT EXISTS status_rh TEXT CHECK (status_rh IN ('ACTIVO', 'BAJA', 'CAMBIO', 'REINGRESO'));

-- Default values (optional but recommended)
UPDATE public.cssi_contributors SET status_sys = 'ACTIVO' WHERE status_sys IS NULL;
UPDATE public.cssi_contributors SET status_rh = 'ACTIVO' WHERE status_rh IS NULL;
