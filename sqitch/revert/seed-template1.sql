-- Revert seed-template1

BEGIN;

DELETE FROM database_template WHERE name = 'template1';

COMMIT;
