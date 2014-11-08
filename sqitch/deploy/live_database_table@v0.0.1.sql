-- Deploy live_database

BEGIN;

CREATE TABLE IF NOT EXISTS live_database (
            database_id SERIAL NOT NULL PRIMARY KEY,
            host VARCHAR NOT NULL,
            port INTEGER NOT NULL,
            name VARCHAR NOT NULL,
            owner VARCHAR NOT NULL,
            create_time TIMESTAMP NOT NULL DEFAULT(now()),
            expire_time TIMESTAMP NOT NULL DEFAULT(now() + interval '7 days'),
            template_id INTEGER REFERENCES database_template(template_id),
            UNIQUE (host, port, name)
    );

COMMIT;
