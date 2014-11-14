package TestDbServer::Schema::Result::Database;
use parent 'DBIx::Class::Core';

__PACKAGE__->table('live_database');
__PACKAGE__->add_columns(qw(database_id name owner create_time expire_time template_id));
__PACKAGE__->set_primary_key('database_id');
__PACKAGE__->belongs_to(template => 'TestDbServer::Schema::Result::Template', 'template_id');

1;
