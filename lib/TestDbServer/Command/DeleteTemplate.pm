package TestDbServer::Command::DeleteTemplate;

use TestDbServer::Exceptions;

use Moose;
use namespace::autoclean;

has template_id => ( isa => 'Str', is => 'ro', required => 1 );
has schema => (isa => 'TestDbServer::Schema', is => 'ro', required => 1 );

sub execute {
    my $self = shift;

    my $template = $self->schema->find_template($self->template_id);
    unless ($template) {
        Exception::TemplateNotFound->throw(name => $self->template_id);
    }

    $template->delete();
}

__PACKAGE__->meta->make_immutable;

1;
