use Mojo::Base -strict;

use Test::More;
use Test::Exception;
use Mojo::Upload;
use Mojo::Asset::Memory;

use File::Temp qw();

use TestDbServer::Schema;
use TestDbServer::Configuration;
use TestDbServer::PostgresInstance;
use lib 't/lib';
use FakeApp;
use DBI;
use Data::UUID;

use TestDbServer::Command::SaveTemplateFile;
use TestDbServer::Command::CreateTemplateFromDatabase;
use TestDbServer::Command::CreateDatabase;
use TestDbServer::Command::CreateDatabaseFromTemplate;
use TestDbServer::Command::DeleteTemplate;
use TestDbServer::Command::DeleteDatabase;

my $config = TestDbServer::Configuration->new_from_path();
my $schema = create_new_schema($config);
my $uuid_gen = Data::UUID->new();

plan tests => 6;

subtest 'create template from database' => sub {
    plan tests => 5;

    my $pg = new_pg_instance();

    note('original database named '.$pg->name);
    my $database = $schema->create_database( map { $_ => $pg->$_ } qw( host port name owner ) );
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

    my $new_template_name = $uuid_gen->create_str;

    my $cmd = TestDbServer::Command::CreateTemplateFromDatabase->new(
                    name => $new_template_name,
                    note => 'new template from database',
                    database_id => $database->database_id,
                    schema => $schema,
                    superuser => $config->db_user,
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

subtest 'create database' => sub {
    plan tests => 6;

    # blank database
    my $create_blank_db_cmd = TestDbServer::Command::CreateDatabase->new(
                                host => $config->db_host,
                                port => $config->db_port,
                                owner => $config->test_db_owner,
                                superuser => $config->db_user,
                                template_id => undef,
                                schema => $schema,
                            );
    ok($create_blank_db_cmd, 'new - blank db');
    my $blank_db = $create_blank_db_cmd->execute();
    ok($blank_db->database_id, 'execute - blank db');

    my $blank_pg = TestDbServer::PostgresInstance->new(
                                host => $blank_db->host,
                                port => $blank_db->port,
                                name => $blank_db->name,
                                owner => $blank_db->owner,
                                superuser => $config->db_user,
                        );
    ok($blank_pg->dropdb, 'drop blank db');


    # with a template ID
    my $template = $schema->create_template(
                                name => $uuid_gen->create_str,
                                owner => $config->test_db_owner,
                            );
    my $create_db_cmd = TestDbServer::Command::CreateDatabase->new(
                                host => $config->db_host,
                                port => $config->db_port,
                                owner => $config->test_db_owner,
                                superuser => $config->db_user,
                                template_id => $template->template_id,
                                schema => $schema,
                            );
    ok($create_db_cmd, 'new - create with template');
    my $db = $create_db_cmd->execute();
    ok($db, 'execute - with template');

    my $db_pg =  TestDbServer::PostgresInstance->new(
                                host => $db->host,
                                port => $db->port,
                                name => $db->name,
                                owner => $db->owner,
                                superuser => $config->db_user,
                        );
    ok($db_pg->dropdb, 'drop db');
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
                    host => $config->db_host,
                    port => $config->db_port,
                    template_id => $template->template_id,
                    schema => $schema,
                    superuser => $config->db_user,
                );
    ok($cmd, 'new');
    my $database = $cmd->execute();
    ok($database, 'execute');

    # connect to the template database
    my $dbi = DBI->connect(sprintf('dbi:Pg:dbname=%s;host=%s;port=%s',
                                    $database->name, $database->host, $database->port),
                            $database->owner, '');
    ok($dbi->do("SELECT foo FROM $table_name WHERE FALSE"), 'table exists in template database');
    $dbi->disconnect;

    # remove the original template
    $pg->dropdb;

    # remove the created database
    TestDbServer::PostgresInstance->new(
                        host => $database->host,
                        port => $database->port,
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

    my $database = TestDbServer::Command::CreateDatabase->new(
                            host => $config->db_host,
                            port => $config->db_port,
                            owner => $config->test_db_owner,
                            superuser => $config->db_user,
                            template_id => undef,
                            schema => $schema,
                    )->execute();
    ok($database, 'Created database to delete');

    my $cmd = TestDbServer::Command::DeleteDatabase->new(
                            database_id => $database->database_id,
                            schema => $schema,
                            superuser => $config->db_user,
                        );
    ok($cmd, 'new delete database');
    ok($cmd->execute(), 'execute delete database');


    my $not_found_cmd = TestDbServer::Command::DeleteDatabase->new(
                            database_id => 'bogus',
                            schema => $schema,
                            superuser => $config->db_user,
                        );
    ok($cmd, 'new delete not existant');
    throws_ok { $cmd->execute() }
        'Exception::DatabaseNotFound',
        'Cannot delete unknown database';
};

subtest 'delete with connections' => sub {
    plan tests => 5;

    my $database = TestDbServer::Command::CreateDatabase->new(
                            host => $config->db_host,
                            port => $config->db_port,
                            owner => $config->test_db_owner,
                            superuser => $config->db_user,
                            template_id => undef,
                            schema => $schema,
                    )->execute();
    ok($database, 'Create database');
    my $dbh = DBI->connect(sprintf('dbi:Pg:dbname=%s;host=%s;port=%s',
                                    $database->name, $database->host, $database->port),
                            $database->owner,
                            '');
    ok($dbh, 'connect to created database');
    my $cmd = TestDbServer::Command::DeleteDatabase->new(
                                    database_id => $database->id,
                                    schema => $schema,
                                    superuser => $config->db_user,
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
    $pg->createdb();
    return $pg;
}


sub create_new_schema {
    my $config = shift;

    my $app = FakeApp->new();
    TestDbServer::Schema->initialize($app);

    return TestDbServer::Schema->connect($config->db_connect_string, $config->db_user, $config->db_password);
}

