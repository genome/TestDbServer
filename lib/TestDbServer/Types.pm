package TestDbServer::Types;

use Moose::Util::TypeConstraints;
use TestDbServer::Exceptions;

subtype 'pg_identifier',
    as 'Str',
    where { m/^\w+/ },
    message { Exception::InvalidParam->throw(error => 'String has non-alphanumeric characters', value => $_) };

1;
