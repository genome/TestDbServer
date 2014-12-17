# TestDbServer

TestDbServer is a RESTful service to manage ephemeral PostgreSQL databases.

```
test-db has these available sub-commands:
 database create   create a test database
 database list     list databases
 delete            delete a template or database
 template create   create a new database template from an existing database
 template list     list templates
```

## Running TestDbServer on a Development VM

Initial VM setup should be done with:

```
# assuming you want to start fresh
$ vagrant destroy

# set `revision` as needed, e.g. `origin/master`, `origin` will be your local repo
$ edit manifests/dev.pp

# initial provisioning will take awhile due to compiling Perl, etc.
$ vagrant up
```

If you want to "update" the server on the VM run another `provision`:

```
$ vagrant provision
```

Run the client:

```
$ DIR="$(git rev-parse --show-toplevel)"
$ export PATH="$DIR/bin:$PATH"
$ export PERL5LIB="$DIR/lib:$DIR/local/lib/perl5:$PERL5LIB"
$ export TESTDBSERVER_URL=http://192.168.33.10
$ test-db database list
```

## Running Tests (or the client)

There are several ways to setup an environment to run tests.

### Carton

```
$ carton install
$ carton exec -- prove -lvr t/
```

### Development VM

First, follow direction to run TestDbServer on a development VM.

```
$ vagrant ssh
$ sudo -u test_db -i
$ cd ~/TestDbServer
$ export TEST_DB_CONF=test_db_server.vagrant.conf
$ perlbrew exec --with 5.20.1 carton exec -- prove -lvr t/
```

At the moment, `commands.t` fails on the development VM:

```
    # Subtest: create database with owner
    1..6
    # original template named CF37ED22863611E49031A9573AB6E997
NOTICE:  CREATE TABLE / PRIMARY KEY will create implicit index "test_table_25027_pkey" for table "test_table_25027"
    ok 1 - Create table in base template
    ok 2 - new
    ok 3 - execute
    ok 4 - table exists in template database
    not ok 5 - new_owner is not the same as template owner

    #   Failed test 'new_owner is not the same as template owner'
    #   at t/commands.t line 113.
    #          got: 'test_db'
    #     expected: anything else
    ok 6 - database has new_owner not template owner
    # Looks like you failed 1 test of 6.
not ok 2 - create database with owner
```
