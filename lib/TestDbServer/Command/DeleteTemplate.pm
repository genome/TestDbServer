package TestDbServer::Command::DeleteTemplate;

use TestDbServer::Exceptions;

use Moose;
use namespace::autoclean;

has template_id => ( isa => 'Str', is => 'ro', required => 1 );
has schema => (isa => 'TestDbServer::Schema', is => 'ro', required => 1 );
has superuser => ( isa => 'Str', is => 'ro', required => 1 );
has host => ( isa => 'Str', is => 'ro', required => 1 );
has port => ( isa => 'Str', is => 'ro', required => 1 );

sub execute {
    my $self = shift;

    my $template = $self->schema->find_template($self->template_id);
    unless ($template) {
        Exception::TemplateNotFound->throw(name => $self->template_id);
    }

    my $pg = TestDbServer::PostgresInstance->new(name => $template->name,
                                                 host => $self->host,
                                                 port => $self->port,
                                                 owner => $template->owner,
                                                 superuser => $self->superuser,
                                          );

    $pg->dropdb();

    $template->delete();
}

__PACKAGE__->meta->make_immutable;

1;
