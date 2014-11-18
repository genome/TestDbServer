use App::Info::RDBMS::PostgreSQL;
use Data::UUID;

use TestDbServer::Exceptions;
use DBI;

package TestDbServer::PostgresInstance;

use TestDbServer::Types;

use Moose;
use namespace::autoclean;

use Try::Tiny;

use strict;
use warnings;

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
    isa => 'pg_identifier',
    required => 1,
);
has 'superuser' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);
has 'superuser_passwd' => (
    is => 'ro',
    isa => 'Maybe[Str]',
);
has 'name' => (
    is => 'ro',
    isa => 'pg_identifier',
    builder => 'unique_db_name',
);
has '_admin_dbh' => (
    is => 'ro',
    isa => 'DBI::db',
    builder => '_build_admin_dbh',
    lazy => 1,
);

{
    my $app_pg = App::Info::RDBMS::PostgreSQL->new();
    sub app_pg { return $app_pg }
}

sub _build_admin_dbh {
    my $self = shift;
    my($host, $port, $user, $pass) = map { $self->$_ } ( 'host', 'port', 'superuser', 'superuser_passwd' );
    return DBI->connect_cached("dbi:Pg:dbname=template1;port=$port;host=$host",
                               $user, $pass,
                               { RaiseError => 1, PrintError => 0 });
}

sub createdb_from_template {
    my($self, $template_name) = @_;

    unless ($self->is_valid_database($template_name)) {
        Exception::InvalidParam->throw(name => 'template name', value => $template_name);
    }

    my $dbh = $self->_admin_dbh;
    my($name, $owner) = map { $self->$_ } qw(name owner);
    try {
        my $rv = $dbh->do(qq(CREATE DATABASE "$name" WITH OWNER "$owner" TEMPLATE "$template_name"));

    } catch {
        Exception::CannotCreateDatabase->throw(error => $_);
    };

    return 1;
}

my $uuid_gen = Data::UUID->new();
sub unique_db_name {
    my $class = shift;
    my $hex = $uuid_gen->create_hex();
    $hex =~ s/^0x//;
    return $hex;
}

sub dropdb {
    my $self = shift;

    my $dbh = $self->_admin_dbh;
    my $name = $self->name;
    try {
        $dbh->do(qq(DROP DATABASE "$name"));

    } catch {
        Exception::CannotDropDatabase->throw(error => $_);
    };

    return 1;
}

sub is_valid_role {
    my($self, $role_name) = @_;

    my $dbh = $self->_admin_dbh;
    my $row = $dbh->selectrow_arrayref(q(SELECT 1 FROM pg_roles WHERE rolname=?), undef, $role_name);
    return $row->[0];
}

sub grant_role_to_role {
    my($self, $source, $target) = @_;

    my $dbh = $self->_admin_dbh;
    $dbh->do(sprintf('GRANT %s to %s', $source, $target));
}

sub is_valid_database {
    my($self, $db_name) = @_;

    my $dbh = $self->_admin_dbh;
    my $row = $dbh->selectrow_arrayref('SELECT 1 FROM pg_catalog.pg_database WHERE datname = ?', undef, $db_name);
    return $row->[0];
}

__PACKAGE__->meta->make_immutable;

1;
