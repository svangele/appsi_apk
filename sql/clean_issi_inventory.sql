-- Script para limpiar todos los registros de la tabla issi_inventory
-- ATENCIÓN: Esta acción eliminará todos los datos de forma permanente.

TRUNCATE TABLE public.issi_inventory RESTART IDENTITY;

-- Alternativamente, si TRUNCATE tiene problemas por llaves foráneas:
-- DELETE FROM public.issi_inventory;
