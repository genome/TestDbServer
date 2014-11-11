-- Verify seed-template1

BEGIN;

SELECT 1/COUNT(*) FROM database_template WHERE name = 'template1';

ROLLBACK;
