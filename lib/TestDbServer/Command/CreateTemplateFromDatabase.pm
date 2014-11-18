package TestDbServer::Command::CreateTemplateFromDatabase;

use TestDbServer::PostgresInstance;

use Moose;
use namespace::autoclean;

has name => ( isa => 'Str', is => 'ro', required => 1 );
has note => ( isa => 'Maybe[Str]', is => 'ro', required => 1 );
has database_id => ( isa => 'Str', is => 'ro', required => 1 );
has schema => ( isa => 'TestDbServer::Schema', is => 'ro', required => 1 );
has superuser => ( isa => 'Str', is => 'ro', required => 1 );
has host => ( isa => 'Str', is => 'ro', required => 1 );
has port => ( isa => 'Str', is => 'ro', required => 1 );

sub execute {
    my $self = shift;

    my $database = $self->schema->find_database($self->database_id);
    unless ($database) {
        Exception::DatabaseNotFound->throw(database_id => $self->database_id);
    }

    my $pg = TestDbServer::PostgresInstance->new(
                    host => $self->host,
                    port => $self->port,
                    owner => $database->owner,
                    name => $self->name,
                    superuser => $self->superuser,
                );

    my $template = $self->schema->create_template(
                                name => $self->name,
                                note => $self->note,
                                owner => $database->owner,
                            );

    $pg->createdb_from_template( $database->name );

    return $template->template_id;
}

__PACKAGE__->meta->make_immutable;

1;
