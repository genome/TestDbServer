-- Verify live_database-drop_host_and_port

BEGIN;

INSERT INTO live_database (name, owner) VALUES ('xxxx', 'xxxx');

ROLLBACK;
