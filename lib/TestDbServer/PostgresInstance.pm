use App::Info::RDBMS::PostgreSQL;
use Data::UUID;

use TestDbServer::Exceptions;
use DBI;

package TestDbServer::PostgresInstance;

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
    isa => 'Str',
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
    isa => 'Str',
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
                               { RaiseError => 1, PrintError => 1 });
}

sub _validate_identifier {
    my $str = shift;

    return $str =~ m/^\w+$/;
}

sub createdb_from_template {
    my($self, $template_name) = @_;

    my $name = $self->name;
    my $owner = $self->owner;
    foreach ([ $name, 'database'], [ $owner, 'owner' ], [ $template_name, 'template name' ]) {
        my($value, $name) = @$_;
        unless (_validate_identifier($value)) {
            Exception::InvalidParam->throw(name => $name, value => $value);
        }
    }

    my $dbh = $self->_admin_dbh;
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

    unless (_validate_identifier($self->name)) {
        Exception::InvalidParam->throw(name => 'name', value => $self->name);
    }

    my $dbh = $self->_admin_dbh;
    my $name = $self->name;
    try {
        $dbh->do(qq(DROP DATABASE "$name"));

    } catch {
        Exception::CannotDropDatabase->throw(error => $_);
    };

    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
