-- Revert database_template-drop_host_and_port

BEGIN;

ALTER TABLE database_template ADD COLUMN host VARCHAR NOT NULL;
ALTER TABLE database_template ADD COLUMN port VARCHAR NOT NULL;
ALTER TABLE database_template ADD CONSTRAINT database_template_unique_host_port_name UNIQUE (host, port, name);

COMMIT;
