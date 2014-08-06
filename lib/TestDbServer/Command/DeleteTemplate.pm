package TestDbServer::Command::DeleteTemplate;

use TestDbServer::Exceptions;

use Moose;

has template_id => ( isa => 'Str', is => 'ro', required => 1 );
has schema => (isa => 'TestDbServer::Schema', is => 'ro', required => 1 );
has file_storage => ( isa => 'TestDbServer::FileStorage', is => 'ro', required => 1 );

no Moose;

sub execute {
    my $self = shift;

    my $template = $self->schema->find_template($self->template_id);
    unless ($template) {
        Exception::TemplateNotFound->throw(template_id => $self->template_id);
    }

    $self->file_storage->unlink($template->file_path);

    $template->delete();
}

1;
