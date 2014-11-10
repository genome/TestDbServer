use App::Info::RDBMS::PostgreSQL;
use Data::UUID;

use TestDbServer::Exceptions;
use TestDbServer::CommandLineRunner;

package TestDbServer::PostgresInstance;

use Moose;
use namespace::autoclean;

has 'host' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);
has 'port' => (
    is => 'ro',
    isa => 'Int',
    required => 1,
);
has 'owner' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);
has 'superuser' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);
has 'name' => (
    is => 'ro',
    isa => 'Str',
    builder => '_build_name',
);
{
    my $app_pg = App::Info::RDBMS::PostgreSQL->new();
    sub app_pg { return $app_pg }
}

sub createdb {
    my $self = shift;

    return $self->_createdb_common();
}

sub _createdb_common {
    my $self = shift;

    my $createdb = $self->app_pg->createdb;

    my $runner = TestDbServer::CommandLineRunner->new(
                        $createdb,
                        '-h', $self->host,
                        '-p', $self->port,
                        '-U', $self->superuser,
                        '-O', $self->owner,
                        @_,
                        $self->name,
                    );
    unless ($runner->rv) {
        Exception::CannotCreateDatabase->throw(error => "$createdb failed",
                                               output => $runner->output,
                                               child_error => $runner->child_error);
    }
    return 1;
}


sub createdb_from_template {
    my($self, $template_name) = @_;

    return $self->_createdb_common(
                '-T', $template_name,
            );
}

my $uuid_gen = Data::UUID->new();
sub _build_name {
    my $class = shift;
    my $hex = $uuid_gen->create_hex();
    $hex =~ s/^0x//;
    return $hex;
}

sub dropdb {
    my $self = shift;
    my $dropdb = $self->app_pg->dropdb;

    my $host = $self->host;
    my $port = $self->port;
    my $superuser = $self->superuser;
    my $name = $self->name;

    my $runner = TestDbServer::CommandLineRunner->new(
                        $dropdb,
                        '-h', $host,
                        '-p', $port,
                        '-U', $superuser,
                        $name
                    );
    unless ($runner->rv) {
        Exception::CannotDropDatabase->throw(error => "$dropdb failed",
                                             output => $runner->output,
                                             child_error => $runner->child_error);
    }
    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
