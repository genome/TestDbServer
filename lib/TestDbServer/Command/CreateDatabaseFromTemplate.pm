package TestDbServer::Command::CreateDatabaseFromTemplate;

use TestDbServer::PostgresInstance;
use TestDbServer::Exceptions;

use Moose;
use namespace::autoclean;

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

    my $pg = TestDbServer::PostgresInstance->new(
                        host => $self->host,
                        port => $self->port,
                        owner => $template->owner,
                        superuser => $self->superuser,
                    );

    $pg->createdb_from_template($template->name);

    my $database = $self->schema->create_database(
                        name => $pg->name,
                        owner => $pg->owner,
                        template_id => $template->template_id,
                    );

    my $update_last_used_sql = $self->schema->sql_to_update_last_used_column();
    $template->update({ last_used_time => \$update_last_used_sql });

    return $database;
}

__PACKAGE__->meta->make_immutable;

1;
