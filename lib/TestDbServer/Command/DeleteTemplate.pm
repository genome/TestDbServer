package TestDbServer::Command::DeleteTemplate;

use TestDbServer::Command::DeleteTemplateOrDatabase;

use Moose;
use namespace::autoclean;

extends 'TestDbServer::Command::DeleteTemplateOrDatabase';
has template_id => ( isa => 'Str', is => 'ro', required => 1 );

sub _entity_find_method { 'find_template' }
sub _entity_id_method { 'template_id' }
sub _not_found_exception { 'Exception::TemplateNotFound' }

__PACKAGE__->meta->make_immutable;

1;
