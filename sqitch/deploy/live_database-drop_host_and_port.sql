-- Deploy live_database-drop_host_and_port
-- requires: live_database_table

BEGIN;

ALTER TABLE live_database DROP COLUMN host CASCADE;
ALTER TABLE live_database DROP COLUMN port;
ALTER TABLE live_database ADD CONSTRAINT live_database_unique_name UNIQUE (name);

COMMIT;
