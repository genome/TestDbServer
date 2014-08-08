use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::JSON;
use File::Temp;
use DBI;

use TestDbServer::Configuration;

plan tests => 7;

my $file_storage_path = File::Temp::tempdir( CLEANUP => 1);
my $db = File::Temp->new(TEMPLATE => 'testdbserver_testdb_XXXXX', SUFFIX => 'sqlite3');
my $connect_string = 'dbi:SQLite:' . $db->filename;
my $config = TestDbServer::Configuration->new(
                    file_storage_path => $file_storage_path,
                    db_connect_string => $connect_string,
                    db_host => 'localhost',
                    db_port => 5434,
                    db_user => 'postgres',
                );

my $t = Test::Mojo->new('TestDbServer');
my $app = $t->app;
$app->configuration($config);

my @databases;
subtest 'list' => sub {
    plan tests => 6;

    my $r = $t->get_ok('/databases')
        ->status_is(200)
        ->json_is([]);

    my $db = $app->db_storage;
    @databases = ( $db->create_database( host => 'foo', port => '123', name => 'qwerty', owner => 'me' ),
                   $db->create_database( host => 'bar', port => '456', name => 'uiop', owner => 'you' ),
                );
    my $expected_data = [ map { $_->database_id } @databases ];
    $t->get_ok('/databases')
      ->status_is(200)
      ->json_is($expected_data);
};

subtest 'get' => sub {
    plan tests => 12;

    $t->get_ok('/databases/'.$databases[0]->database_id)
        ->status_is(200)
        ->json_is('/id' => $databases[0]->database_id)
        ->json_is('/host' => 'foo')
        ->json_is('/port' => '123' )
        ->json_is('/name' => 'qwerty')
        ->json_is('/owner' => 'me')
        ->json_is('/template_id' => undef)
        ->json_has('/created')
        ->json_has('/expires');

    $t->get_ok('/databases/garbage')
        ->status_is(404);
};

subtest 'create from template' => sub {
    plan tests => 12;

    my $template_file = File::Temp->new();
    $template_file->print('CREATE TABLE foo (foo_id integer NOT NULL PRIMARY KEY)');
    $template_file->close();
    my $template_file_path = $app->file_storage->save($template_file->filename);

    my $db = $app->db_storage();
    my $template_owner = 'genome';
    my $template = $db->create_template(name => 'test template',
                                        file_path => $template_file_path,
                                        owner => $template_owner,
                                    );
    my $test =
        $t->post_ok('/databases?based_on=' . $template->template_id)
            ->status_is(201)
            ->json_is('/owner' => $template_owner)
            ->json_has('/id')
            ->json_has('/host')
            ->json_has('/port')
            ->json_has('/name')
            ->json_has('/expires');

    _validate_location_header($test);

    my $created_db_info = $test->tx->res->json;
    ok(_connect_to_created_database($created_db_info), 'connect to created database');

    $t->post_ok('/databases?based_on=bogus')
        ->status_is(404, 'Cannot create DB based on bogus template_id');
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

subtest 'create new' => sub {
    plan tests => 9;

    my $template_owner = 'genome';

    my $test =
        $t->post_ok("/databases?owner=$template_owner")
            ->status_is(201)
            ->json_has('/id')
            ->json_has('/host')
            ->json_has('/port')
            ->json_has('/name')
            ->json_has('/expires');

    _validate_location_header($test);

    my $created_db_info = $test->tx->res->json;
    ok(_connect_to_created_database($created_db_info), 'connect to created database');
};

subtest 'delete' => sub {
    plan tests => 6;

    my $template_owner = 'genome';
    my $test = $t->post_ok("/databases?owner=$template_owner")
            ->status_is(201);

    my $id = $test->tx->res->json->{id};
    $t->delete_ok("/databases/${id}")
        ->status_is(204);


    $t->delete_ok('/databases/bogus')
        ->status_is(404);
};

subtest 'delete while connected' => sub {
    plan tests => 7;

    my $template_owner = 'genome';
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

    my $template_owner = 'genome';

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
            ->json_has('/host')
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

    my $dbh = DBI->connect(sprintf('dbi:Pg:dbname=%s;host=%s;port=%s',
                                    @$created_db_info{'name','host','port'}),
                            $created_db_info->{owner},
                            '');
    return $dbh;
}

