use Mojo::Base -strict;

use Test::More;
use Test::Exception;

use File::Temp qw();

use TestDbServer::Schema;
use TestDbServer::Configuration;
use TestDbServer::PostgresInstance;
use lib 't/lib';
use FakeApp;
use DBI;
use Data::UUID;

use TestDbServer::Command::CreateTemplateFromDatabase;
use TestDbServer::Command::CreateDatabaseFromTemplate;
use TestDbServer::Command::DeleteTemplate;
use TestDbServer::Command::DeleteDatabase;

my $config = TestDbServer::Configuration->new_from_path();
my $schema = create_new_schema($config);
my $uuid_gen = Data::UUID->new();

plan tests => 7;

subtest 'create template from database' => sub {
    plan tests => 5;

    my $pg = new_pg_instance();

    note('original database named '.$pg->name);
    my $database = $schema->create_database( map { $_ => $pg->$_ } qw( name owner ) );
    # Make a table in the database
    my $table_name = "test_table_$$";
    {
        my $dbi = DBI->connect(sprintf('dbi:Pg:dbname=%s;host=%s;port=%s',
                                        $pg->name, $pg->host, $pg->port),
                                $pg->owner,
                                '');
        ok($dbi->do("CREATE TABLE $table_name (foo integer NOT NULL PRIMARY KEY)"),
            'Create table in base database');
        $dbi->disconnect;
    }

    my $new_template_name = TestDbServer::PostgresInstance::unique_db_name();

    my $cmd = TestDbServer::Command::CreateTemplateFromDatabase->new(
                    name => $new_template_name,
                    note => 'new template from database',
                    database_name => $database->name,
                    schema => $schema,
                    superuser => $config->db_user,
                    host => $pg->host,
                    port => $pg->port,
                );
    ok($cmd, 'new');
    my $template_id = $cmd->execute();
    ok($template_id, 'execute');

    my $template = $schema->find_template($template_id);
    ok($template, 'get created template');

    # connect to the template database
    my $dbi = DBI->connect(sprintf('dbi:Pg:dbname=%s;host=%s;port=%s',
                                    $template->name, $pg->host, $pg->port),
                            $pg->owner, '');
    ok($dbi->do("SELECT foo FROM $table_name WHERE FALSE"), 'table exists in template database');
    $dbi->disconnect;

    # remove the original database
    $pg->dropdb;

    # remove the template database
    TestDbServer::PostgresInstance->new(
                        host => $pg->host,
                        port => $pg->port,
                        owner => $template->owner,
                        superuser => $config->db_user,
                        name => $template->name
            )->dropdb;
};

subtest 'create database with owner' => sub {
    plan tests => 6;

    my $pg = new_pg_instance();

    note('original template named '.$pg->name);
    my $template = $schema->create_template( map { $_ => $pg->$_ } qw( name owner ) );
    # Make a table in the template
    my $table_name = "test_table_$$";
    {
        my $dbi = DBI->connect(sprintf('dbi:Pg:dbname=%s;host=%s;port=%s',
                                        $pg->name, $pg->host, $pg->port),
                                $pg->owner,
                                '');
        ok($dbi->do("CREATE TABLE $table_name (foo integer NOT NULL PRIMARY KEY)"),
            'Create table in base template');
        $dbi->disconnect;
    }

    my $new_owner = $config->db_user;
    my $cmd = TestDbServer::Command::CreateDatabaseFromTemplate->new(
                    owner => $new_owner,
                    host => $config->db_host,
                    port => $config->db_port,
                    template_name => $template->name,
                    schema => $schema,
                    superuser => $config->db_user,
                );
    ok($cmd, 'new');
    my $database = $cmd->execute();
    ok($database, 'execute');

    # connect to the newly created database
    my $dbi = DBI->connect(sprintf('dbi:Pg:dbname=%s;host=%s;port=%s',
                                    $database->name, $config->db_host, $config->db_port),
                            $pg->owner, '');
    ok($dbi->do("SELECT foo FROM $table_name WHERE FALSE"), 'table exists in template database');
    $dbi->disconnect;

    isnt($new_owner, $template->owner, 'new_owner is not the same as template owner');
    is($database->real_owner, $new_owner, 'database has new_owner not template owner');

    # remove the original template
    $pg->dropdb;

    # remove the created database
    TestDbServer::PostgresInstance->new(
                        host => $config->db_host,
                        port => $config->db_port,
                        owner => $database->owner,
                        superuser => $config->db_user,
                        name => $database->name
            )->dropdb;
};

subtest 'create database with invalid owner' => sub {
    plan tests => 3;

    my $pg = new_pg_instance();

    note('original template named '.$pg->name);
    my $template = $schema->create_template( map { $_ => $pg->$_ } qw( name owner ) );
    # Make a table in the template
    my $table_name = "test_table_$$";
    {
        my $dbi = DBI->connect(sprintf('dbi:Pg:dbname=%s;host=%s;port=%s',
                                        $pg->name, $pg->host, $pg->port),
                                $pg->owner,
                                '');
        ok($dbi->do("CREATE TABLE $table_name (foo integer NOT NULL PRIMARY KEY)"),
            'Create table in base template');
        $dbi->disconnect;
    }

    my $invalid_owner = 'xxx';
    my $cmd = TestDbServer::Command::CreateDatabaseFromTemplate->new(
                    owner => $invalid_owner,
                    host => $config->db_host,
                    port => $config->db_port,
                    template_name => $template->name,
                    schema => $schema,
                    superuser => $config->db_user,
                );
    ok($cmd, 'new');
    throws_ok { $cmd->execute() }
        'Exception::RoleNotFound',
        'Cannot create database with unknown owner';

    # remove the original template
    $pg->dropdb;
};

subtest 'create database from template' => sub {
    plan tests => 4;

    my $pg = new_pg_instance();

    note('original template named '.$pg->name);
    my $template = $schema->create_template( map { $_ => $pg->$_ } qw( name owner ) );
    # Make a table in the template
    my $table_name = "test_table_$$";
    {
        my $dbi = DBI->connect(sprintf('dbi:Pg:dbname=%s;host=%s;port=%s',
                                        $pg->name, $pg->host, $pg->port),
                                $pg->owner,
                                '');
        ok($dbi->do("CREATE TABLE $table_name (foo integer NOT NULL PRIMARY KEY)"),
            'Create table in base template');
        $dbi->disconnect;
    }

    my $cmd = TestDbServer::Command::CreateDatabaseFromTemplate->new(
                    owner => undef,
                    host => $config->db_host,
                    port => $config->db_port,
                    template_name => $template->name,
                    schema => $schema,
                    superuser => $config->db_user,
                );
    ok($cmd, 'new');
    my $database = $cmd->execute();
    ok($database, 'execute');

    # connect to the newly created database
    my $dbi = DBI->connect(sprintf('dbi:Pg:dbname=%s;host=%s;port=%s',
                                    $database->name, $config->db_host, $config->db_port),
                            $database->owner, '');
    ok($dbi->do("SELECT foo FROM $table_name WHERE FALSE"), 'table exists in template database');
    $dbi->disconnect;

    # remove the original template
    $pg->dropdb;

    # remove the created database
    TestDbServer::PostgresInstance->new(
                        host => $config->db_host,
                        port => $config->db_port,
                        owner => $database->owner,
                        superuser => $config->db_user,
                        name => $database->name
            )->dropdb;
};

subtest 'delete template' => sub {
    plan tests => 3;

    my $pg = new_pg_instance();

    my $template = $schema->create_template(
                                name => $pg->name,
                                owner => $pg->owner,
                            );

    my $cmd = TestDbServer::Command::DeleteTemplate->new(
                template_id => $template->template_id,
                schema => $schema);
    ok($cmd, 'new');
    ok($cmd->execute(), 'execute');

    ok(! $schema->find_template($template->template_id),
        'template is deleted');
};

subtest 'delete database' => sub {
    plan tests => 5;

    my $database = TestDbServer::Command::CreateDatabaseFromTemplate->new(
                            host => $config->db_host,
                            port => $config->db_port,
                            owner => $config->test_db_owner,
                            superuser => $config->db_user,
                            template_name => $config->default_template_name,
                            schema => $schema,
                    )->execute();
    ok($database, 'Created database to delete');

    my $cmd = TestDbServer::Command::DeleteDatabase->new(
                            database_id => $database->database_id,
                            schema => $schema,
                            superuser => $config->db_user,
                            host => $config->db_host,
                            port => $config->db_port,
                        );
    ok($cmd, 'new delete database');
    ok($cmd->execute(), 'execute delete database');


    my $not_found_cmd = TestDbServer::Command::DeleteDatabase->new(
                            database_id => 'bogus',
                            schema => $schema,
                            superuser => $config->db_user,
                            host => $config->db_host,
                            port => $config->db_port,
                        );
    ok($cmd, 'new delete not existant');
    throws_ok { $cmd->execute() }
        'Exception::DatabaseNotFound',
        'Cannot delete unknown database';
};

subtest 'delete with connections' => sub {
    plan tests => 5;

    my $database = TestDbServer::Command::CreateDatabaseFromTemplate->new(
                            host => $config->db_host,
                            port => $config->db_port,
                            owner => $config->test_db_owner,
                            superuser => $config->db_user,
                            template_name => $config->default_template_name,
                            schema => $schema,
                    )->execute();
    ok($database, 'Create database');
    my $dbh = DBI->connect(sprintf('dbi:Pg:dbname=%s;host=%s;port=%s',
                                    $database->name, $config->db_host, $config->db_port),
                            $database->owner,
                            '');
    ok($dbh, 'connect to created database');
    my $cmd = TestDbServer::Command::DeleteDatabase->new(
                                    database_id => $database->id,
                                    schema => $schema,
                                    superuser => $config->db_user,
                                    host => $config->db_host,
                                    port => $config->db_port,
                                );
    ok($cmd, 'new');
    throws_ok { $cmd->execute() }
        'Exception::CannotDropDatabase',
        'cannot execute - has connections';

    $dbh->disconnect();
    ok($cmd->execute(), 'delete after disconnecting');
};

sub new_pg_instance {
    my $pg = TestDbServer::PostgresInstance->new(
            host => $config->db_host,
            port => $config->db_port,
            owner => $config->test_db_owner,
            superuser => $config->db_user,
        );
    $pg->createdb_from_template('template1');
    return $pg;
}


sub create_new_schema {
    my $config = shift;

    my $app = FakeApp->new();
    TestDbServer::Schema->initialize($app);

    return TestDbServer::Schema->connect($config->db_connect_string, $config->db_user, $config->db_password);
}

