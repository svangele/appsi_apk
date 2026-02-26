-- =============================================================================
-- MIGRACIÓN MAESTRA: FUSIÓN DE CSSI_CONTRIBUTORS HACIA PROFILES (PROFILES 360)
-- =============================================================================

-- 1. PREPARACIÓN DE LA TABLA PROFILES
-- Eliminamos el constraint que obliga a que todo ID sea un usuario de Auth,
-- permitiendo que Profiles sea nuestra tabla maestra de Colaboradores.
ALTER TABLE public.profiles 
DROP CONSTRAINT IF EXISTS profiles_id_fkey;

-- Agregar todas las columnas de la sección Colaborador si no existen
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS nombre TEXT,
ADD COLUMN IF NOT EXISTS paterno TEXT,
ADD COLUMN IF NOT EXISTS materno TEXT,
ADD COLUMN IF NOT EXISTS curp TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS rfc TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS imss TEXT,
ADD COLUMN IF NOT EXISTS credito TEXT,
ADD COLUMN IF NOT EXISTS fecha_nacimiento DATE,
ADD COLUMN IF NOT EXISTS genero TEXT,
ADD COLUMN IF NOT EXISTS talla TEXT,
ADD COLUMN IF NOT EXISTS estado_civil TEXT,
ADD COLUMN IF NOT EXISTS escolaridad TEXT,
ADD COLUMN IF NOT EXISTS detalle_escolaridad TEXT;

-- Sección Domicilio
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS calle TEXT,
ADD COLUMN IF NOT EXISTS no_calle TEXT,
ADD COLUMN IF NOT EXISTS colonia TEXT,
ADD COLUMN IF NOT EXISTS municipio_alcaldia TEXT,
ADD COLUMN IF NOT EXISTS estado_federal TEXT,
ADD COLUMN IF NOT EXISTS codigo_postal TEXT;

-- Sección Contacto
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS telefono TEXT,
ADD COLUMN IF NOT EXISTS celular TEXT,
ADD COLUMN IF NOT EXISTS correo_personal TEXT;

-- Sección Bancaria
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS banco TEXT,
ADD COLUMN IF NOT EXISTS cuenta TEXT,
ADD COLUMN IF NOT EXISTS clabe TEXT;

-- Sección Empresa
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS empresa_tipo TEXT,
ADD COLUMN IF NOT EXISTS area TEXT,
ADD COLUMN IF NOT EXISTS puesto TEXT,
ADD COLUMN IF NOT EXISTS ubicacion TEXT,
ADD COLUMN IF NOT EXISTS empresa TEXT,
ADD COLUMN IF NOT EXISTS jefe_inmediato TEXT,
ADD COLUMN IF NOT EXISTS lider TEXT,
ADD COLUMN IF NOT EXISTS gerente_regional TEXT,
ADD COLUMN IF NOT EXISTS director TEXT;

-- Sección RH
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS recluta TEXT,
ADD COLUMN IF NOT EXISTS reclutador TEXT,
ADD COLUMN IF NOT EXISTS fuente_reclutamiento TEXT,
ADD COLUMN IF NOT EXISTS fuente_reclutamiento_espec TEXT,
ADD COLUMN IF NOT EXISTS observaciones TEXT,
ADD COLUMN IF NOT EXISTS fecha_ingreso DATE,
ADD COLUMN IF NOT EXISTS fecha_reingreso DATE,
ADD COLUMN IF NOT EXISTS fecha_cambio DATE;

-- Sección Referencias
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS referencia_nombre TEXT,
ADD COLUMN IF NOT EXISTS referencia_telefono TEXT,
ADD COLUMN IF NOT EXISTS referencia_relacion TEXT;

-- Auditoría y Otros
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS foto_url TEXT,
ADD COLUMN IF NOT EXISTS numero_empleado TEXT;

-- 2. MIGRACIÓN DE DATOS
-- Migrar registros de cssi_contributors a profiles
-- Paso A: Actualizar perfiles de usuarios existentes que están vinculados
UPDATE public.profiles p
SET
    nombre = c.nombre,
    paterno = c.paterno,
    materno = c.materno,
    curp = c.curp,
    rfc = c.rfc,
    imss = c.imss,
    credito = c.credito,
    fecha_nacimiento = c.fecha_nacimiento,
    genero = c.genero,
    talla = c.talla,
    estado_civil = c.estado_civil,
    escolaridad = c.escolaridad,
    detalle_escolaridad = c.detalle_escolaridad,
    calle = c.calle,
    no_calle = c.no_calle,
    colonia = c.colonia,
    municipio_alcaldia = c.municipio_alcaldia,
    estado_federal = c.estado_federal,
    codigo_postal = c.codigo_postal,
    telefono = c.telefono,
    celular = c.celular,
    correo_personal = c.correo_personal,
    banco = c.banco,
    cuenta = c.cuenta,
    clabe = c.clabe,
    empresa_tipo = c.empresa_tipo,
    area = c.area,
    puesto = c.puesto,
    ubicacion = c.ubicacion,
    empresa = c.empresa,
    jefe_inmediato = c.jefe_inmediato,
    lider = c.lider,
    gerente_regional = c.gerente_regional,
    director = c.director,
    recluta = c.recluta,
    reclutador = c.reclutador,
    fuente_reclutamiento = c.fuente_reclutamiento,
    fuente_reclutamiento_espec = c.fuente_reclutamiento_espec,
    observaciones = c.observaciones,
    fecha_ingreso = c.fecha_ingreso,
    fecha_reingreso = c.fecha_reingreso,
    fecha_cambio = c.fecha_cambio,
    referencia_nombre = c.referencia_nombre,
    referencia_telefono = c.referencia_telefono,
    referencia_relacion = c.referencia_relacion,
    foto_url = c.foto_url,
    numero_empleado = c.numero_empleado
FROM public.cssi_contributors c
WHERE p.id = c.usuario_id OR p.email = LOWER(c.correo_personal);

-- Paso B: Insertar colaboradores que NO tienen un perfil de usuario aún
INSERT INTO public.profiles (
    id, full_name, role, is_blocked, permissions, status_sys,
    nombre, paterno, materno, curp, rfc, imss, credito, fecha_nacimiento, 
    genero, talla, estado_civil, escolaridad, detalle_escolaridad,
    calle, no_calle, colonia, municipio_alcaldia, estado_federal, codigo_postal,
    telefono, celular, correo_personal, email, banco, cuenta, clabe,
    empresa_tipo, area, puesto, ubicacion, empresa, jefe_inmediato, lider, 
    gerente_regional, director, recluta, reclutador, fuente_reclutamiento, 
    fuente_reclutamiento_espec, observaciones, fecha_ingreso, fecha_reingreso, 
    fecha_cambio, referencia_nombre, referencia_telefono, referencia_relacion, 
    foto_url, numero_empleado
)
SELECT 
    c.id, (c.nombre || ' ' || c.paterno), 'usuario'::user_role, false, 
    '{"show_users": false, "show_issi": false, "show_cssi": false, "show_logs": false}'::jsonb,
    'ACTIVO',
    c.nombre, c.paterno, c.materno, c.curp, c.rfc, c.imss, c.credito, c.fecha_nacimiento,
    c.genero, c.talla, c.estado_civil, c.escolaridad, c.detalle_escolaridad,
    c.calle, c.no_calle, c.colonia, c.municipio_alcaldia, c.estado_federal, c.codigo_postal,
    c.telefono, c.celular, c.correo_personal, LOWER(c.correo_personal), c.banco, c.cuenta, c.clabe,
    c.empresa_tipo, c.area, c.puesto, c.ubicacion, c.empresa, c.jefe_inmediato, c.lider,
    c.gerente_regional, c.director, c.recluta, c.reclutador, c.fuente_reclutamiento,
    c.fuente_reclutamiento_espec, c.observaciones, c.fecha_ingreso, c.fecha_reingreso,
    c.fecha_cambio, c.referencia_nombre, c.referencia_telefono, c.referencia_relacion,
    c.foto_url, c.numero_empleado
FROM public.cssi_contributors c
WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = c.usuario_id OR p.email = LOWER(c.correo_personal));

-- 3. LIMPIEZA
DROP TABLE public.cssi_contributors CASCADE;

-- 4. RELOAD SCHEMA
NOTIFY pgrst, 'reload schema';
