-- Migración para añadir campos a ISSI (Inventario)
ALTER TABLE public.issi_inventory 
ADD COLUMN IF NOT EXISTS fecha_actualizacion DATE,
ADD COLUMN IF NOT EXISTS gpu TEXT;
