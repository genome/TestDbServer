-- Verify db_template_table

BEGIN;

SELECT 1/(count(*)-1) FROM pg_class WHERE relname = 'db_template';

ROLLBACK;
