use TestDbServer::Schema;

use Test::More;
use Test::Exception;
use DBI;
use File::Temp;

use TestDbServer::Configuration;
use TestDbServer::PostgresInstance;

use strict;
use warnings;

plan tests => 5;

my $config = TestDbServer::Configuration->new_from_path();
my $host = $config->db_host;
my $port = $config->db_port;
my $superuser = $config->db_user;
my $owner = $config->test_db_owner;

subtest 'create from template param validation' => sub {
    plan tests => 3;

    my $invalid_sql = q{'Robert'); DROP TABLE students; --};
    my %valid_params = ( host => $host, port => $port, owner => $owner, superuser => $superuser );
    foreach my $check_param ( qw( name owner ) ) {
        throws_ok { TestDbServer::PostgresInstance->new(
                        %valid_params,
                        $check_param => $invalid_sql,
                  ) }
                qr(String has non-alphanumeric characters),
                "Invalid parameter for $check_param throws exception";
    }

    my $pg = TestDbServer::PostgresInstance->new( %valid_params );
    throws_ok { $pg->createdb_from_template($invalid_sql) }
            'Exception::InvalidParam',
            'Invalid parameter for template name throws exception';
};

subtest 'create connect delete' => sub {
    plan tests => 6;

    my $pg = TestDbServer::PostgresInstance->new(
                host => $host,
                port => $port,
                owner => $owner,
                superuser => $superuser,
            );
    ok($pg, 'Created new PostgresInstance');
    ok($pg->name, 'has a name: '. $pg->name);

    ok($pg->createdb_from_template('template1'), 'Create database');

    my $db_name = $pg->name;
    ok(connect_to_db($db_name), 'Connected');

    ok($pg->dropdb, 'Delete database');
    ok( ! connect_to_db($db_name), 'Cannot connect to deleted database');
};

subtest 'create db from template' => sub {
    plan tests => 5;

    my $original_pg = TestDbServer::PostgresInstance->new(
                host => $host,
                port => $port,
                owner => $owner,
                superuser => $superuser,
            );
    ok($original_pg->createdb_from_template('template1'), 'Create original DB');
    {
        my $dbi = DBI->connect(sprintf('dbi:Pg:dbname=%s;host=%s;port=%s',
                                        $original_pg->name, $original_pg->host, $original_pg->port),
                                $original_pg->owner,
                                '');
        $dbi->do('CREATE TABLE foo(foo_id integer NOT NULL PRIMARY KEY)');
    }


    my $copy_pg = TestDbServer::PostgresInstance->new(
                host => $host,
                port => $port,
                owner => $owner,
                superuser => $superuser,
            );
    ok($copy_pg->createdb_from_template($original_pg->name), 'Create database from template');

    my $dbh = connect_to_db($copy_pg->name);
    my $sth = $dbh->table_info('','','foo','TABLE');
    my $rows = $sth->fetchall_arrayref({TABLE_NAME => 1});
    is_deeply($rows,
        [ { TABLE_NAME => 'foo' } ],
        'Copied created table');

    $dbh->disconnect();
    ok($original_pg->dropdb(), 'drop original database');
    ok($copy_pg->dropdb(), 'drop copy database');
};

subtest 'create duplicate database' => sub {
    plan tests => 2;

    my $original_pg = TestDbServer::PostgresInstance->new(
                host => $host,
                port => $port,
                owner => $owner,
                superuser => $superuser,
            );
    ok($original_pg->createdb_from_template('template1'), 'Create original DB');

    my $copy_pg = TestDbServer::PostgresInstance->new(
                host => $host,
                port => $port,
                owner => $owner,
                superuser => $superuser,
                name => $original_pg->name,
            );
    throws_ok { $copy_pg->createdb_from_template('template1') }
            'Exception::CannotCreateDatabase',
            'Creating a database with duplicate name throws exception';
};

subtest 'is_valid_role' => sub {
    plan tests => 2;

    my $pg = create_pg_object_from_config();
    ok($pg->is_valid_role($config->db_user), 'valid role');
    ok(! $pg->is_valid_role('garbage'), 'invalid role');
};

sub connect_to_db {
    my $db_name = shift;
    DBI->connect("dbi:Pg:dbname=$db_name;host=$host;port=$port", $owner, '', { PrintError => 0 });
}
