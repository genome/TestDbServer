package TestDbServer::TemplateRoutes;
use Mojo::Base 'Mojolicious::Controller';

use Try::Tiny;
use File::Basename;

use TestDbServer::Utils;
use TestDbServer::Command::DeleteTemplate;
use TestDbServer::Command::CreateTemplateFromDatabase;

sub list {
    my $self = shift;

    my $params = $self->req->params->to_hash;

    $self->app->log->info('list templates: '
                            . %$params
                                ? join(', ', map { join(' => ', $_, $params->{$_}) } keys %$params )
                                : 'no params');

    my $templates = %$params
                    ? $self->app->db_storage->search_template(%$params)
                    : $self->app->db_storage->search_template;

    my(@ids, %render_args);
    %render_args = ( json => \@ids );
    try {
        while(my $tmpl = $templates->next) {
            push @ids, $tmpl->template_id;
        }
    }
    catch {
        if (ref($_)
            and
            $_->isa('DBIx::Class::Exception')
            and
            $_ =~ m/(column "\w+" does not exist)/
        ) {
            %render_args = ( status => 400, text => $1 );
        } else {
            $self->app->log->fatal("list templates exception: $_");
            die $_;
        }
    }
    finally {
        if (exists($render_args{status}) and $render_args{status} == 400) {
            $self->app->log->error("list templates failed: $render_args{text}");
        } else {
            $self->app->log->info('found ' . scalar($render_args{json}) . ' templates');
        }

        $self->render(%render_args);
    }
}

sub get {
    my $self = shift;

    my $id = $self->stash('id');

    $self->app->log->info("get template $id");

    my $schema = $self->app->db_storage;

    my($template, $error);
    try {
        $template = $schema->find_template($id);
    }
    catch {
        $error = $_;
    };

    if ($template) {
        $self->app->log->info("found template $id");
        my %template = map { $_ => $template->$_ } qw(template_id name owner note create_time last_used_time);
        $self->render(json => \%template);

    } elsif ($error) {
        $self->app->log->error("Cannot get template $id");
        $self->render(status => 400, text => $error);

    } else {
        $self->app->log->info("template $id not found");
        $self->render_not_found;
    }
}

sub save {
    my $self = shift;

    my $schema = $self->app->db_storage;
    my ($template_id, $return_code);
    try {
        foreach my $req_param ( qw( name based_on ) ) {
            unless ($self->param($req_param)) {
                Exception::RequiredParamMissing->throw(params => [$req_param]);
            }
        }

        my($host, $port) = $self->app->host_and_port_for_created_database();

        my $cmd = TestDbServer::Command::CreateTemplateFromDatabase->new(
                        name => $self->param('name') || undef,
                        note => $self->param('note') || undef,
                        database_name => $self->param('based_on') || undef,
                        schema => $schema,
                        superuser => $self->app->configuration->db_user,
                        host => $host,
                        port => $port,
                    );
        $schema->txn_do(sub {
            $template_id = $cmd->execute();
            $return_code = 201;
        });
    }
    catch {
        if (ref($_) && $_->isa('Exception::RequiredParamMissing')) {
            $self->app->log->error('Missing required parameter: '.join(', ', @{ $_->params }));
            $return_code = 400;

        } elsif (ref($_) && $_->isa('Exception::DatabaseNotFound')) {
            $self->app->log->error("database not found: ".$self->param('based_on'));
            $return_code = 404;

        } elsif (ref($_) && $_->isa('DBIx::Class::Exception') && m/duplicate key value violates unique constraint/) {
            $self->app->log->error('there is already a template with that name');
            $return_code = 409;

        } else {
            $self->app->log->fatal("create template based on: $_");
            $return_code = 400;
        }

    };

    if ($template_id) {
        $self->app->log->info("Created template $template_id");
        my $response_location = TestDbServer::Utils::id_url_for_request_and_entity_id($self->req, $template_id);
        $self->res->headers->location($response_location);
    }
    $self->rendered($return_code);
}

sub delete {
    my $self = shift;

    my $id = $self->stash('id');
    $self->app->log->info("deleting template $id");

    my $schema = $self->app->db_storage;

    my $return_code;
    try {
        my($host, $port) = $self->app->host_and_port_for_created_database();
        my $cmd = TestDbServer::Command::DeleteTemplate->new(
                    template_id => $id,
                    schema => $schema,
                    superuser => $self->app->configuration->db_user,
                    host => $host,
                    port => $port,
                );
        $schema->txn_do(sub {
            $cmd->execute();
            $return_code = 204;
        });
    }
    catch {
        if (ref($_) && $_->isa('Exception::TemplateNotFound')) {
            $self->app->log->error("template $id does not exist");
            $return_code = 404;
        } else {
            $self->app->log->fatal("delete template failed: $_");
            $return_code = 400;
        }
    };

    $self->rendered($return_code);
}

1;
