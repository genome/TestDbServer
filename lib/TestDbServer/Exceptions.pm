use Exception::Class (
    Exception::BaseException,

    Exception::RequiredParamMissing => {
        isa => 'Exception::BaseException',
        description => 'Required parameter is missing',
        fields => ['params'],
    },

    Exception::InvalidParam => {
        isa => 'Exception::BaseException',
        description => 'Parameter value is invalid',
        fields => ['name', 'value'],
    },

    Exception::NotInitialized => {
        isa => 'Exception::BaseException',
    },

    Exception::ShellCommandFailed => {
        isa => 'Exception::BaseException',
        fields => [qw(exit_code signal core_dump output)],
    },

    Exception::CannotCreateDatabase => {
        isa => 'Exception::BaseException',
    },

    Exception::CannotDropDatabase => {
        isa => 'Exception::BaseException',
    },

    Exception::DatabaseNotFound => {
        isa => 'Exception::BaseException',
        fields => [qw(name)],
    },

    Exception::TemplateNotFound => {
        isa => 'Exception::BaseException',
        fields => [qw(name)],
    },

    Exception::RoleNotFound => {
        isa => 'Exception::BaseException',
        fields => [qw(role_name)],
    },
);

package Exception::BaseException;

sub full_message {
    my $self = shift;

    my $class = ref($self);
    my $message = "$class: " . $self->error . " at " . $self->_find_source_location();
    if (my $fields = $self->_fields_string) {
        $message .= "\n\t"  . $fields;
    }

    return $message . "\n";
}

sub _fields_string {
    my $self = shift;

    return join("\n\t", map { "$_: " . $self->$_ } $self->Fields);
}

sub _find_source_location {
    my $self = shift;

    my $frame = $self->trace->next_frame;

    return $frame->filename . ': ' . $frame->line;
}

1;
