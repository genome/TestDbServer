package TestDbServer::Schema::Result::Template;
use parent 'DBIx::Class::Core';

__PACKAGE__->table('database_template');
__PACKAGE__->add_columns(qw(template_id name owner note create_time last_used_time));
__PACKAGE__->set_primary_key('template_id');

1;
