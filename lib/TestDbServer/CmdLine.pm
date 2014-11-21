package TestDbServer::CmdLine;

# helpers for the command-line tools

use File::Spec;
use File::Basename;
use LWP;
use Carp;
use URI::Escape qw(uri_escape);
use JSON qw(decode_json);
use Getopt::Long qw();

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(get_user_agent url_for assert_success template_id_from_name database_id_from_name
                    get_template_name_from_id get_database_name_from_id foreach_database_or_template
                    parse_opts);

sub find_available_sub_command_paths {
    my($cmd) = shift;

    return  grep { -x }
            glob("${cmd}-*");
}

sub split_into_command_to_run_and_args {
    my($base_command_path, @argv) = @_;

    for( my $split_pos = $#argv; $split_pos >= 0; $split_pos-- ) {
        my $command_to_run = join('-', $base_command_path, @argv[0 .. $split_pos]);

        if (-x $command_to_run) {
            my @args_for_command = @argv[$split_pos+1 .. $#argv];
            return ($command_to_run, @args_for_command);
        }
    }
    return ($base_command_path, @argv);
}

my $ua;
sub get_user_agent {
    my $timeout = shift || 5;
    unless($ua) {
        $ua = LWP::UserAgent->new;
        $ua->agent("TestDbServer::CmdLine/0.1 ");
        $ua->timeout($timeout);
    }
    return $ua;
}

sub base_url {
    return $ENV{TESTDBSERVER_URL} || 'http://localhost';
}

sub url_for {
    my $query_string;
    if (ref($_[$#_])) {
        my $query_list = pop @_;
        my @query_list = map { uri_escape($_) } @$query_list;

        my @query_strings;
        for(my $i = 0; $i < @query_list; $i+=2) {
            push @query_strings, join('=', @query_list[$i, $i+1]);
        }
        $query_string = join('&', @query_strings);
    }

    my $url = join('/', base_url(), @_);
    if ($query_string) {
        $url .= '?' . $query_string;
    }
    return $url;
}

sub assert_success {
    my $rsp = shift;

    unless (ref($rsp) && $rsp->isa('HTTP::Response')) {
        Carp::croak("Expected an HTTP::Response instance, but got " . ref($rsp) || $rsp);
    }

    if ($rsp->is_redirect && $rsp->request->method eq 'POST') {
        Carp::croak('redirect received when trying to create, are you sure your server URL is correct?');
    }

    unless ($rsp->is_success) {
        Carp::croak('Got error response '.$rsp->code . ': '. $rsp->message);
    }

    return 1;
}

sub get_template_name_from_id {
    my($template_id) = @_;
    return _get_type_name_from_id('templates', $template_id);
}

sub get_database_name_from_id {
    my($database_id) = @_;
    return _get_type_name_from_id('databases', $database_id);
}

sub _get_type_name_from_id {
    my($type, $id) = @_;

    return undef unless defined $id;

    my $ua = get_user_agent();

    my $req = HTTP::Request->new(GET => url_for($type, $id));
    my $rsp = $ua->request($req);
    unless (eval { assert_success($rsp); 1 }) {
        return undef;
    }
    my $tmpl = decode_json($rsp->content);
    return $tmpl->{name};
}

sub foreach_database_or_template {
    my($type, $cb) = @_;

    my $ua = get_user_agent();

    my $req = HTTP::Request->new(GET => url_for($type));
    my $rsp = $ua->request($req);
    assert_success($rsp);

    my $id_list = decode_json($rsp->content);
    my $count = 0;
    foreach my $id ( @$id_list ) {
        my $req = HTTP::Request->new(GET => url_for($type, $id));
        my $rsp = $ua->request($req);
        next unless eval { assert_success $rsp };
        my $data = decode_json($rsp->content);
        $cb->($data);
        $count++;
    }
    return $count || '0 but true';
}

sub parse_opts {
    my @desc = @_;
    my $opts = {};
    my $opts_parser = Getopt::Long::Parser->new();
    my $ok = $opts_parser->getoptions($opts, @desc);
    unless ($ok) {
        exit 9;
    }
    return $opts;
}


1;
