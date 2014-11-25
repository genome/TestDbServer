use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Test::Deep qw(cmp_deeply supersetof);
use Mojo::JSON;
use File::Temp qw();
use DBI;
use Data::UUID;

use TestDbServer::Configuration;

plan tests => 9;

my $config = TestDbServer::Configuration->new_from_path();

my $t = Test::Mojo->new('TestDbServer');
my $app = $t->app;
$app->configuration($config);

my $uuid_gen = Data::UUID->new();

$config->external_hostname( $uuid_gen->create_str );

my @databases;
subtest 'list' => sub {
    plan tests => 6;

    my $r = $t->get_ok('/databases')
        ->status_is(200);

    my $db_list = $r->tx->res->json;
    is(ref($db_list), 'ARRAY', '/databases is an arrayref');

    my $db = $app->db_storage;
    my $owner = $uuid_gen->create_str;
    @databases = ( $db->create_database( name => $uuid_gen->create_str, owner => $owner ),
                   $db->create_database( name => $uuid_gen->create_str, owner => $owner ),
                );
    $r = $t->get_ok('/databases')
      ->status_is(200);

    $db_list = $r->tx->res->json;
    cmp_deeply($db_list, supersetof(map { $_->database_id } @databases), 'Found created databases');
};

subtest 'search' => sub {
    plan tests => 11;

    $t->get_ok('/databases?name='.$databases[0]->name)
        ->status_is(200)
        ->json_is([$databases[0]->database_id]);

    my $r = $t->get_ok('/databases?owner='.$databases[0]->owner)
        ->status_is(200)
        ->json_is([ map { $_->database_id } @databases ]);

    $t->get_ok('/databases?name=garbage')
        ->status_is(200)
        ->json_is([]);

    $t->get_ok('/databases?garbage=foo')
        ->status_is(400);
};

subtest 'get' => sub {
    plan tests => 14;

    my $expected_host = $t->app->configuration->external_hostname;
    my $expected_port = $t->app->configuration->db_port;

    $t->get_ok('/databases/'.$databases[0]->database_id)
        ->status_is(200)
        ->json_is('/id' => $databases[0]->database_id)
        ->json_is('/host', $expected_host)
        ->json_is('/port', $expected_port)
        ->json_is('/name' => $databases[0]->name)
        ->json_is('/owner' => $databases[0]->owner)
        ->json_is('/template_id' => undef)
        ->json_has('/created')
        ->json_has('/expires');

    $t->get_ok('/databases/903482394')
        ->status_is(404);

    $t->get_ok('/databases/garbage')
        ->status_is(400);
};

subtest 'create from template' => sub {
    plan tests => 16;

    my $db = $app->db_storage();
    my $pg = TestDbServer::PostgresInstance->new(
                    host => $config->db_host,
                    port => $config->db_port,
                    owner => $config->test_db_owner,
                    superuser => $config->db_user,
                );
    ok( $pg->createdb_from_template('template1'), 'create database to use as a template');

    my $template = $db->create_template(
                                            name => $pg->name,
                                            owner => $pg->owner,
                                        );

    sleep(1);  # allow the last_used_time to change

    my $test =
        $t->post_ok("/databases?based_on=" . $template->template_id)
            ->status_is(201)
            ->json_is('/owner' => $template->owner)
            ->json_has('/id')
            ->json_is('/host', $config->external_hostname)
            ->json_has('/port')
            ->json_has('/name')
            ->json_has('/expires');

    _validate_location_header($test);

    my $created_db_info = $test->tx->res->json;
    ok(_connect_to_created_database($created_db_info), 'connect to created database');

    my $template_after_create = $db->find_template($template->template_id);
    isnt($template_after_create->last_used_time,
         $template->last_used_time,
         'Template last used time was updated');

    $t->post_ok('/databases?based_on=347394')
        ->status_is(404, 'Cannot create DB based on bogus template_id');

    $t->post_ok('/databases?based_on=bogus')
        ->status_is(400, 'Cannot create DB based on bogus template_id');
};

sub _validate_location_header {
    my $test = shift;
    subtest 'validate location header' => sub {
        plan tests => 3;
        my $db_id = $test->tx->res->json->{id};
        $test->header_like('Location' => qr(/databases/$db_id), 'Location header');
        my $location = $test->tx->res->headers->location;
        $t->get_ok($location)
            ->status_is(200, 'Get created database info');
    };
}

subtest 'create new with owner' => sub {
    plan tests => 11;

    my $template_owner = $config->test_db_owner;

    my $test =
        $t->post_ok("/databases?owner=$template_owner")
            ->status_is(201)
            ->json_has('/id')
            ->json_is('/host', $config->external_hostname)
            ->json_has('/port')
            ->json_has('/name')
            ->json_has('/expires');

    _validate_location_header($test);

    my $created_db_info = $test->tx->res->json;
    ok(_connect_to_created_database($created_db_info), 'connect to created database');

    my $created_id = $test->tx->res->json->{id};
    my $database = $app->db_storage()->find_database($created_id);
    ok($database, 'database record');
    is($database->owner, $template_owner, 'owner');
};

subtest 'create new without owner' => sub {
    plan tests => 9;

    my $test =
        $t->post_ok('/databases')
            ->status_is(201)
            ->json_has('/id')
            ->json_has('/host')
            ->json_has('/port')
            ->json_has('/name')
            ->json_has('/expires');

    my $created_id = $test->tx->res->json->{id};
    my $database = $app->db_storage()->find_database($created_id);
    ok($database, 'database record');
    is($database->owner, $config->db_user, 'owner');
};

subtest 'delete' => sub {
    plan tests => 8;

    my $template_owner = $config->test_db_owner;
    my $test = $t->post_ok("/databases?owner=$template_owner")
            ->status_is(201);

    my $id = $test->tx->res->json->{id};
    $t->delete_ok("/databases/${id}")
        ->status_is(204);


    $t->delete_ok('/databases/99999')
        ->status_is(404);

    $t->delete_ok('/databases/bogus')
        ->status_is(400);
};

subtest 'delete while connected' => sub {
    plan tests => 7;

    my $template_owner = $config->test_db_owner;
    my $test = $t->post_ok("/databases?owner=$template_owner")
            ->status_is(201);

    my $created_db_info = $test->tx->res->json;
    my $id = $created_db_info->{id};
    ok(my $dbh = _connect_to_created_database($created_db_info), 'connect to created database');

    $t->delete_ok("/databases/${id}")
        ->status_is(409);

    $dbh->disconnect;
    $t->delete_ok("/databases/${id}")
        ->status_is(204);
};

subtest 'update expire time' => sub {
   plan tests => 15;

    my $template_owner = $config->test_db_owner;

    my $test =
        $t->post_ok("/databases?owner=$template_owner")
            ->status_is(201)
            ->json_has('/expires');

    my $created_db_info = $test->tx->res->json;
    ok(_connect_to_created_database($created_db_info), 'connect to created database');


    my $db_url = $test->tx->res->headers->location;
    my $expire_ttl = 3;
    $test =
        $t->patch_ok("${db_url}?ttl=${expire_ttl}")
            ->status_is(200)
            ->json_has('/id')
            ->json_is('/host', $config->external_hostname)
            ->json_has('/port')
            ->json_has('/name')
            ->json_has('/expires');
    ok(_connect_to_created_database($created_db_info), 'connect immediately after patching ttl');

    note('waiting to expire...');
    sleep($expire_ttl * 2);

    $t->get_ok($db_url)
        ->status_is(404, 'database record has expired');
    ok(! _connect_to_created_database($created_db_info), 'Cannot connect to expired database');
};


sub _connect_to_created_database {
    my $created_db_info = shift;

    # The test configures a bogus external_hostname we can't really connect to
    my $real_host = $app->configuration->db_host;
    my $dbh = DBI->connect(sprintf('dbi:Pg:dbname=%s;port=%s;host=%s',
                                    @$created_db_info{'name','port'}, $real_host),
                            $created_db_info->{owner},
                            '');
    return $dbh;
}

