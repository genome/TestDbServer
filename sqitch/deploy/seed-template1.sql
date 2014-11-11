-- Deploy seed-template1
-- requires: database_template-drop_host_and_port

BEGIN;

INSERT INTO database_template (name, owner, note)
VALUES ('template1', 'postgres', 'built-in template1');

COMMIT;
