use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use File::Temp qw();
use Data::UUID;

use TestDbServer::Configuration;

plan tests => 2;

my $uuid_gen = Data::UUID->new;
my $config = TestDbServer::Configuration->new_from_path();

my $t = Test::Mojo->new('TestDbServer');
my $app = $t->app;
$app->configuration($config);

my($orig_template_count, $orig_db_count);
subtest 'root with no db entities' => sub {
    plan tests => 4;

    my $r = $t->get_ok('/')
        ->status_is(200)
        ->json_has('/template_count')
        ->json_has('/database_count');

    my $got_data = $r->tx->res->json;
    ($orig_template_count, $orig_db_count) = @$got_data{'template_count','database_count'};
};

subtest 'root with one template and one database' => sub {
    plan tests => 4;

    my $storage = $app->db_storage();
    my $template = $storage->create_template(
                                            name => $uuid_gen->create_str,
                                            owner => 'bubba',
                                        );
    my $database = $storage->create_database(name => $uuid_gen->create_str,
                                             owner => 'bubba',
                                             template_id => $template->template_id);
    my $r = $t->get_ok('/')
        ->status_is(200)
        ->json_is('/template_count' => $orig_template_count + 1)
        ->json_is('/database_count' => $orig_db_count + 1);
};
