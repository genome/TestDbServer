package TestDbServer::Command::CreateDatabaseFromTemplate;

use TestDbServer::PostgresInstance;
use TestDbServer::Exceptions;

use Moose;
use namespace::autoclean;

has owner => ( isa => 'Maybe[Str]', is => 'ro', required => 1 );
has host => ( isa => 'Str', is => 'ro', required => 1 );
has port => ( isa => 'Int', is => 'ro', required => 1 );
has template_id => ( isa => 'Str', is => 'ro', required => 1 );
has schema => ( isa => 'TestDbServer::Schema', is => 'ro', required => 1 );
has superuser => ( isa => 'Str', is => 'ro', required => 1 );

sub execute {
    my $self = shift;

    my $template = $self->schema->find_template($self->template_id);
    unless ($template) {
        Exception::TemplateNotFound->throw(template_id => $self->template_id);
    }

    my $owner = $self->owner || $template->owner;
    my $pg = TestDbServer::PostgresInstance->new(
                        host => $self->host,
                        port => $self->port,
                        owner => $owner,
                        superuser => $self->superuser,
                    );

    if ($owner ne $self->superuser) {
        my $dbh = $self->schema->storage->dbh();
        grant_role($dbh, $owner, $self->superuser);
    }

    $pg->createdb_from_template($template->name);

    my $database = $self->schema->create_database(
                        name => $pg->name,
                        host => $self->host,
                        port => $self->port,
                        owner => $pg->owner,
                        template_id => $template->template_id,
                    );

    my $update_last_used_sql = $self->schema->sql_to_update_last_used_column();
    $template->update({ last_used_time => \$update_last_used_sql });

    return $database;
}

sub grant_role {
    my ($dbh, $source, $target) = @_;
    $dbh->do(sprintf('GRANT %s to %s', $source, $target));
}

__PACKAGE__->meta->make_immutable;

1;
