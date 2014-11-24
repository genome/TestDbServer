package TestDbServer::Configuration;

use Memoize qw(memoize);
use Moose;
use namespace::autoclean;

has db_connect_string   => ( is => 'rw' );
has db_user             => ( is => 'rw' );
has db_password         => ( is => 'rw' );
has db_host             => ( is => 'rw' );
has db_port             => ( is => 'rw' );
has test_db_owner       => ( is => 'rw' );
has external_hostname   => ( is => 'rw' );

sub new_from_app_config {
    my($class, $config) = @_;

    my $meta = $class->meta;
    my %props;
    foreach my $attr ( $meta->get_all_attributes ) {
        $props{$attr->name} = $config->{$attr->name};
    }

    return $class->SUPER::new(%props);
}

memoize('new_from_path');
sub new_from_path {
    my ($class, $path) = @_;

    $path ||= $ENV{TEST_DB_CONF}
        or die 'TEST_DB_CONF must be set';

    unless (-f $path) {
        die "path is not a file: $path";
    }

    local $@;
    my $config = do $path;
    if (!$config && $@) {
        die "config threw exception: $@";
    }
    if (!$config && $!) {
        die "config load failed: $!";
    }
    if (!$config || ref($config) ne 'HASH') {
        die "invalid config";
    }
    return $class->SUPER::new(%$config);
}

__PACKAGE__->meta->make_immutable;

1;
