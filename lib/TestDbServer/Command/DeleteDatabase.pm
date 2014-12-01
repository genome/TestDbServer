package TestDbServer::Command::DeleteDatabase;

use TestDbServer::Command::DeleteTemplateOrDatabase;

use Moose;
use namespace::autoclean;

extends 'TestDbServer::Command::DeleteTemplateOrDatabase';
has database_id => ( isa => 'Str', is => 'ro', required => 1 );

sub _entity_find_method { 'find_database' }
sub _entity_id_method { 'database_id' }
sub _not_found_exception { 'Exception::DatabaseNotFound' }

__PACKAGE__->meta->make_immutable;

1;
