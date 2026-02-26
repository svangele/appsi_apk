-- Migración para añadir campos de fecha a CSSI (Área RH)
ALTER TABLE public.cssi_contributors 
ADD COLUMN IF NOT EXISTS fecha_ingreso DATE,
ADD COLUMN IF NOT EXISTS fecha_reingreso DATE,
ADD COLUMN IF NOT EXISTS fecha_cambio DATE;
