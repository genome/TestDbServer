-- Revert db_template_table

BEGIN;

CREATE TABLE IF NOT EXISTS db_template (
    template_id SERIAL NOT NULL PRIMARY KEY,
    name VARCHAR NOT NULL UNIQUE,
    owner VARCHAR NOT NULL,
    note VARCHAR,
    sql_script TEXT NOT NULL,
    create_time TIMESTAMP NOT NULL DEFAULT(now()),
    last_used_time TIMESTAMP NOT NULL DEFAULT(now())
);

COMMIT;
