package TestDbServer::Command::CreateDatabaseFromTemplate;

use TestDbServer::PostgresInstance;
use TestDbServer::Exceptions;

use Moose;
use namespace::autoclean;

use constant DEFAULT_TEMPLATE_NAME => 'template1';

has owner => ( isa => 'Maybe[Str]', is => 'ro', required => 1 );
has host => ( isa => 'Str', is => 'ro', required => 1 );
has port => ( isa => 'Int', is => 'ro', required => 1 );
has template_id => ( isa => 'Maybe[Str]', is => 'ro', required => 1 );
has schema => ( isa => 'TestDbServer::Schema', is => 'ro', required => 1 );
has superuser => ( isa => 'Str', is => 'ro', required => 1 );

sub execute {
    my $self = shift;

    my $default_template_id = $self->schema
                                   ->search_template(name => DEFAULT_TEMPLATE_NAME)
                                   ->next->id;
    my $template_id = defined $self->template_id
                    ? $self->template_id
                    : $default_template_id;

    my $template = $self->schema->find_template($template_id);
    unless ($template) {
        Exception::TemplateNotFound->throw(template_id => $template_id);
    }

    my $owner = $self->owner || $template->owner;
    my $pg = TestDbServer::PostgresInstance->new(
                        host => $self->host,
                        port => $self->port,
                        owner => $owner,
                        superuser => $self->superuser,
                    );

    if ($owner ne $self->superuser) {
        $self->grant_role_to_superuser($pg, $owner);
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

sub grant_role_to_superuser {
    my ($self, $pg, $source) = @_;

    for my $role_name ($source, $self->superuser) {
        unless ($pg->is_valid_role($role_name)) {
            Exception::RoleNotFound->throw(role_name => $role_name);
        }
    }
    $pg->grant_role_to_role($source, $self->superuser);
}

__PACKAGE__->meta->make_immutable;

1;
