requires 'perl', 'v5.10';

requires 'App::Sqitch';
requires 'Carp';
requires 'Data::UUID';
requires 'DBD::Pg';
requires 'DBI', '1.63';
requires 'DBIx::Class';
requires 'Exception::Class';
requires 'Mojolicious', '5';
requires 'Moose', '2.1';
requires 'MooseX::NonMoose';
requires 'namespace::autoclean';

on develop => sub {
    requires 'Test::Exception';
    requires 'Test::More';
    requires 'Test::Deep';
};

feature 'cli', 'command-line interface' => sub {
    requires 'LWP';
    requires 'LWP::Protocol::https';
};
