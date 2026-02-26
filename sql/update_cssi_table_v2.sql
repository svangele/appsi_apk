-- Añadir campos para Número de Empleado y Foto
ALTER TABLE cssi_contributors 
ADD COLUMN IF NOT EXISTS numero_empleado TEXT,
ADD COLUMN IF NOT EXISTS foto_url TEXT;

-- Nota: Recordar crear un bucket llamado 'employee_photos' en Supabase Storage
-- con acceso público de lectura y acceso autenticado para inserción/borrado.
