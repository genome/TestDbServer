-- Verify database_template-drop_host_and_port

BEGIN;

INSERT INTO database_template (name, owner) VALUES ('xxxx', 'xxxx');

ROLLBACK;
