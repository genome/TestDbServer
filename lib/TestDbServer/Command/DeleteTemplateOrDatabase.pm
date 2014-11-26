package TestDbServer::Command::DeleteTemplateOrDatabase;

use TestDbServer::Exceptions;

use Moose;
use Sub::Install;
use namespace::autoclean;

has schema => (isa => 'TestDbServer::Schema', is => 'ro', required => 1 );
has superuser => ( isa => 'Str', is => 'ro', required => 1 );
has host => ( isa => 'Str', is => 'ro', required => 1 );
has port => ( isa => 'Str', is => 'ro', required => 1 );

foreach my $subname ( qw( _entity_find_method _entity_id_method _not_found_exception )) {
    no strict 'refs';
    *$subname = sub { die "$_[0] didn't implement $subname"; }
}

sub execute {
    my $self = shift;

    my($finder, $id_getter) = ($self->_entity_find_method, $self->_entity_id_method);

    my $entity = $self->schema->$finder( $self->$id_getter );
    unless ($entity) {
        my $not_found = $self->_not_found_exception;
        $not_found->throw(name => $self->$id_getter);
    }

    my $pg = TestDbServer::PostgresInstance->new(
                        name => $entity->name,
                        host => $self->host,
                        port => $self->port,
                        owner => $entity->owner,
                        superuser => $self->superuser,
                    );

    $pg->dropdb();

    $entity->delete();

    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
