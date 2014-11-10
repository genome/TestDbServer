-- Deploy database_template-drop_host_and_port
-- requires: database_template-table

BEGIN;

-- CASCADE for the unnamed unique constraint on host, port, and name
ALTER TABLE database_template DROP COLUMN host CASCADE;
ALTER TABLE database_template DROP COLUMN port;
ALTER TABLE database_template ADD CONSTRAINT database_template_unique_name UNIQUE (name);

COMMIT;
