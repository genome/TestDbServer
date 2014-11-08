-- Verify live_database

BEGIN;

select database_id, host, port, name, owner, create_time, expire_time, template_id
from live_database
where FALSE;

ROLLBACK;
