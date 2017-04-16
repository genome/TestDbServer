package TestDbServer::DatabaseRoutes;
use Mojo::Base 'Mojolicious::Controller';

use Try::Tiny;

use TestDbServer::Utils;
use TestDbServer::Command::CreateDatabaseFromTemplate;
use TestDbServer::Command::DeleteDatabase;

sub list {
    my $self = shift;

    $self->_remove_expired_databases();

    my $params = $self->req->params->to_hash;
    $self->app->log->info('list databases: '
                            . %$params
                                ? join(', ', map { join(' => ', $_, $params->{$_}) } keys %$params )
                                : 'no params');
    my $databases = %$params
                    ? $self->app->db_storage->search_database(%$params)
                    : $self->app->db_storage->search_database;

    my(@ids, %render_args);
    %render_args = ( json => \@ids );
    try {
        while (my $db = $databases->next) {
            push @ids, $db->database_id;
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
            $self->app->log->fatal("list databases exception: $_");
            die $_;
        }
    }
    finally {
        if (exists($render_args{status}) and $render_args{status} == 400) {
            $self->app->log->error("list databases failed: $render_args{text}");
        } else {
            $self->app->log->info('found ' . scalar($render_args{json}) . ' databases');
        }
        $self->render(%render_args);
    };
}

sub get {
    my $self = shift;
    my $id = $self->stash('id');

    $self->_remove_expired_databases();

    $self->app->log->info("get database $id");

    my $schema = $self->app->db_storage();
    my($database, $error);
    try {
        $database = $schema->find_database($id);
    } catch {
        $error = $_;
    };

    if ($database) {
        $self->app->log->info("found database $id");
        $self->render(json => $self->_hashref_for_database_obj($database));

    } elsif ($error) {
        $self->app->log->error("Cannot get database $id");
        $self->render(status => 400, text => $error);

    } else {
        $self->app->log->info("database $id not found");
        $self->render(status => 404, text => "database $id not found");
    }
}

sub _remove_expired_databases {
    my $self = shift;

    my $schema = $self->app->db_storage;

    my $database_set = $schema->search_expired_databases();
    my($host,$port) = $self->app->host_and_port_for_created_database();

    while (my $database = $database_set->next()) {
        try {
            $schema->txn_do(sub {
                $self->app->log->info('expiring database '.$database->database_id);
                my $cmd = TestDbServer::Command::DeleteDatabase->new(
                                schema => $schema,
                                database_id => $database->database_id,
                                superuser => $self->app->configuration->db_user,
                                host => $host,
                                port => $port,
                            );
                $cmd->execute();
            });
        }
        catch {
            $self->app->log->error("expire database ".$database->database_id." failed: $_");
            if (ref($_) && $_->isa('Exception::CannotDropDatabase')) {
                $self->app->log->info('  removing database record');
                $schema->txn_do(sub {
                    $database->delete();
                });
            }
        };
    }
}

sub _hashref_for_database_obj {
    my($self, $database) = @_;

    my %h;
    @h{'id','name','owner','created','expires','template_id'}
        = map { $database->$_ } qw( database_id name owner create_time expire_time template_id );

    $h{host} = $self->app->configuration->external_hostname;
    $h{port} = $self->app->configuration->db_port;

    return \%h;
}

sub _resolve_template_name_and_owner_for_creating_database {
    my $self = shift;

    my $template_name = $self->req->param('based_on');
    my $owner = $self->req->param('owner');
    unless ($template_name) {
        $template_name = $self->app->configuration->default_template_name;
        $self->app->log->info("create database from default template: $template_name");

        # The real owner of this template is likely the postgres superuser.
        # Instead, use this owner from the configuration
        $owner ||= $self->app->configuration->db_user;
    }

    return ($template_name, $owner);
}

sub create {
    my $self = shift;

    my($template_name, $owner) = $self->_resolve_template_name_and_owner_for_creating_database();
    $self->app->log->info("create database from template $template_name");

    my $schema = $self->app->db_storage;

    my($database, $return_code);
    try {
        $schema->txn_do(sub {
            my($host, $port) = $self->app->host_and_port_for_created_database();
            my $cmd = TestDbServer::Command::CreateDatabaseFromTemplate->new(
                            owner => $owner,
                            template_name => $template_name,
                            host => $host,
                            port => $port,
                            superuser => $self->app->configuration->db_user,
                            schema => $self->app->db_storage,
                    );
            $database = $cmd->execute();
        });
    }
    catch {
        if (ref($_) && $_->isa('Exception::TemplateNotFound')) {
            $self->app->log->error('template not found');
            $return_code = 404;

        } elsif (ref($_) && $_->isa('Exception::CannotCreateDatabase')) {
            $self->app->log->error("Cannot create database: $_");
            $return_code = 503;

        } else {
            $self->app->log->fatal("_create_database_from_template: $_");
            $return_code = 400;
        }
    };

    if ($database) {
        $self->app->log->info('created database '.$database->database_id);
        my $response_location = TestDbServer::Utils::id_url_for_request_and_entity_id($self->req, $database->database_id);
        $self->res->headers->location($response_location);

        $self->render(status => 201, json => $self->_hashref_for_database_obj($database));

    } else {
        $self->rendered($return_code);
    }
}

sub delete {
    my $self = shift;
    my $id = $self->stash('id');

    $self->app->log->info("delete database $id");

    my $schema = $self->app->db_storage;
    my $return_code;
    try {
        my($host, $port) = $self->app->host_and_port_for_created_database();
        my $cmd = TestDbServer::Command::DeleteDatabase->new(
                        database_id => $id,
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
        if (ref($_) && $_->isa('Exception::DatabaseNotFound')) {
            $self->app->log->error("database $id does not exist");
            $return_code = 404;
        } elsif (ref($_) && $_->isa('Exception::CannotDropDatabase')) {
            $self->app->log->error("Cannot drop database $id");
            $return_code = 409;
        } else {
            $self->app->log->fatal("delete database $id failed: $_");
            $return_code = 400;
        }
    };

    $self->rendered($return_code);
}

sub patch {
    my $self = shift;
    my $id = $self->stash('id');

    my $schema = $self->app->db_storage;

    my($return_code, $database);
    try {
        my $ttl = $self->req->param('ttl');

        $self->app->log->info("patch database $id ttl $ttl\n");

        if (! $ttl or $ttl < 1) {
            Exception::RequiredParamMissing->throw(params => ['ttl']);
        }
        my $update_expire_sql = $schema->sql_to_update_expire_column($ttl);

        $schema->txn_do(sub {
            $database = $schema->find_database($id);
            unless ($database) {
                Exception::DatabaseNotFound->throw(database_id => $id);
            }
            $database->update({ expire_time => \$update_expire_sql});

        });
        $return_code = 200;
    }
    catch {
        if (ref($_) && $_->isa('Exception::RequiredParamMissing')) {
            $self->app->log->error("required param missing: ".join(', ', @{ $_->params }));
            $return_code = 400;

        } elsif (ref($_) && $_->isa('Exception::DatabaseNotFound')) {
            $self->app->log->error("database $id not found");
            $return_code = 404;

        } else {
            $self->app->log->fatal("patch database failed: $_");
            die $_;
        }
    };

    if ($database) {
        my $response_location = TestDbServer::Utils::id_url_for_request_and_entity_id($self->req, $database->database_id);
        $self->res->headers->location($response_location);

        $self->render(status => 200, json => $self->_hashref_for_database_obj($database));

    } else {
        $self->rendered($return_code);
    }
}

1;
