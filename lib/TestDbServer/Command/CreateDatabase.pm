package TestDbServer::Command::CreateDatabase;

use TestDbServer::PostgresInstance;

use Moose;
use namespace::autoclean;

has host => ( isa => 'Str', is => 'ro', required => 1 );
has port => ( isa => 'Int', is => 'ro', required => 1 );
has owner => ( isa => 'Maybe[Str]', is => 'ro', required => 1 );
has template_id => ( isa => 'Maybe[Str]', is => 'ro', required => 1 );
has superuser => ( isa => 'Str', is => 'ro', required => 1 );
has schema => (isa => 'TestDbServer::Schema', is => 'ro', required => 1 );

sub execute {
    my $self = shift;

    my $pg = TestDbServer::PostgresInstance->new(
                        host => $self->host,
                        port => $self->port,
                        owner => $self->owner,
                        superuser => $self->superuser,
                    );

    my $database = $self->schema->create_database(
                        name => $pg->name,
                        owner => $self->owner,
                        template_id => $self->template_id,
                    );

    $pg->createdb();

    return $database;
}

__PACKAGE__->meta->make_immutable;

1;
