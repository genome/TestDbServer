use TestDbServer::Schema;

use Test::More;
use Test::Exception;
use Test::Deep qw(cmp_deeply supersetof);
use File::Temp;
use Data::UUID;

use lib 't/lib';
use FakeApp;

use strict;
use warnings;

use TestDbServer::Configuration;

plan tests => 9;

my $config = TestDbServer::Configuration->new_from_path();
my $uuid_gen = Data::UUID->new;

my $schema;
subtest initialize => sub {
    plan tests => 3;

    my $connect_string = $config->db_connect_string;
    throws_ok { TestDbServer::Schema->connect($connect_string, $config->db_user, $config->db_password) }
        'Exception::NotInitialized',
        'Cannot call connect without initialize() first';

    my $fake_app = FakeApp->new();

    ok( TestDbServer::Schema->initialize($fake_app), 'Initialize schema');

    $schema = TestDbServer::Schema->connect($connect_string, $config->db_user, $config->db_password);
    ok($schema, 'Connect schema');
};

my @templates;
subtest save_template => sub {
    plan tests => 5;

    my $template_1 = $schema->create_template(name => $uuid_gen->create_str, owner => 'bubba', note => 'hi there');
    ok($template_1,'Save template with a note');
    push @templates, $template_1;

    my $template_2 = $schema->create_template(name => $uuid_gen->create_str, owner => 'bubba');
    ok($template_2, 'Save template without a note');
    push @templates, $template_2;

    throws_ok { $schema->create_template(name => $template_1->name, owner => 'bubba', note => 'garbage') }
        'DBIx::Class::Exception',
        'Cannot save_template() with duplicate name';

    check_required_attributes_for_save(
        sub { $schema->create_template(@_) },
        { name => "template name $$", owner => 'bubba'},
    );
};

my @databases;
subtest save_database => sub {
    plan tests => 11;

    my @database_info = (
        { host => 'localhost', port => 123, name => $uuid_gen->create_str, owner => 'bubba', template_id => $templates[0]->template_id },
        { host => 'localhost', port => 123, name => $uuid_gen->create_str, owner => 'bubba', template_id => $templates[0]->template_id },
        { host => 'other', port => 123, name => $uuid_gen->create_str, owner => 'bubba', template_id => $templates[0]->template_id },
        { host => 'localhost', port => 456, name => $uuid_gen->create_str, owner => 'bubba', template_id => $templates[0]->template_id },
        { host => 'other', port => 999, name => $uuid_gen->create_str, owner => 'bubba', template_id => $templates[1]->template_id },
    );

    for (my $i = 0; $i < @database_info; $i++) {
        my $db = $schema->create_database(%{ $database_info[$i] });
        ok($db, "Save database $i");
        push @databases, $db;
    }

    check_required_attributes_for_save(
        sub { $schema->create_database(@_) },
        { host => 'localhost', port => 123, name => 'joe', owner => 'bubba' }
    );

    throws_ok { $schema->create_database(template_id => 'garbage', host => 'h', port => 1, name => 'n', owner => 'o') }
        'DBIx::Class::Exception',
        'Cannot insert database that is not linked to a template';

    my %duplicate_host_port_name = %{$database_info[0]};
    $duplicate_host_port_name{template_id} = $templates[1]->template_id;
    throws_ok { $schema->create_database(%duplicate_host_port_name) }
        'DBIx::Class::Exception',
        'Cannot insert database with duplicate host port and name';
};

sub check_required_attributes_for_save {
    my $create_sub = shift;
    my $all_params_hash = shift;

    foreach my $missing ( keys %$all_params_hash ) {
        my %params = %$all_params_hash;
        delete $params{$missing};
        throws_ok { $create_sub->(%params) }
            'DBIx::Class::Exception',
            "$missing is a requried to save";
    }
}

subtest get_template => sub {
    plan tests => scalar(@templates) * 2;

    foreach my $template ( @templates ) {
        my $template_id = $template->template_id;
        my $tmpl = $schema->find_template($template_id);
        ok($tmpl, "Get template $template_id");
        is($tmpl->template_id, $template_id, 'template_id is correct');
    }
};

subtest get_database => sub {
    plan tests => scalar(@databases) * 2;

    foreach my $database ( @databases ) {
        my $database_id = $database->database_id;
        my $db = $schema->find_database($database_id);
        ok($db, "Get template $database_id");
        is($db->database_id, $database_id, 'database_id is correct');
    }
};

subtest all_get_templates => sub {
    plan tests => 1;

    my @got_templates = $schema->search_template();
    cmp_deeply([ map { $_->template_id } @got_templates ],
                supersetof(map { $_->template_id } @templates),
                'found expected templates');
};

subtest get_all_databases => sub {
    plan tests => 1;

    my @got_databases = $schema->search_database();
    cmp_deeply([ map { $_->database_id } @got_databases ],
                supersetof(map { $_->database_id } @databases),
                'found expected databases');
};

# $databases[2] is linked to $templates[1]
subtest delete_database => sub {
    plan tests => 3;

    dies_ok { $schema->delete_database('garbage') }
        'Deleting unknown database throws exception';

    delete_thing('database', $databases[-1]->database_id);
};

subtest delete_template => sub {
    plan tests => 5;

    dies_ok { $schema->delete_template('garbage') }
        'Deleting unknown template throws exception';

    throws_ok { $schema->delete_template($templates[0]->template_id) }
        'DBIx::Class::Exception',
        'Cannot remove template with linked databases';
    ok($schema->find_template($templates[0]->template_id), 'template still exists');

    delete_thing('template', $templates[1]->template_id);
};

sub delete_thing {
    my($thing_type, $id) = @_;

    my $delete_sub = "delete_${thing_type}";
    ok($schema->$delete_sub($id), "Delete $thing_type");

    my $find_sub = "find_${thing_type}";
    ok(! $schema->$find_sub($id), "$thing_type was deleted");
}
