-- Revert live_database-drop_host_and_port

BEGIN;

ALTER TABLE live_database ADD COLUMN host VARCHAR NOT NULL;
ALTER TABLE live_database ADD COLUMN port VARCHAR NOT NULL;
ALTER TABLE live_database ADD CONSTRAINT live_database_unique_host_port_name UNIQUE (host, port, name);


COMMIT;
