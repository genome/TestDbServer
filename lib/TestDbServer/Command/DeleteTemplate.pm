package TestDbServer::Command::DeleteTemplate;

use TestDbServer::Command::DeleteTemplateOrDatabase;

use Moose;
use namespace::autoclean;

extends 'TestDbServer::Command::DeleteTemplateOrDatabase';
has template_id => ( isa => 'Str', is => 'ro', required => 1 );

sub _entity_find_method { 'find_template' }
sub _entity_id_method { 'template_id' }
sub _not_found_exception { 'Exception::TemplateNotFound' }

sub execute {
    my $self = shift;

    my $databases_with_this_template = $self->schema->search_database(template_id => $self->template_id);
    $databases_with_this_template->update({template_id => undef});

    $self->SUPER::execute();
}

__PACKAGE__->meta->make_immutable;

1;
