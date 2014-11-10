use Exception::Class (
    Exception::BaseException,

    Exception::RequiredParamMissing => {
        isa => 'Exception::BaseException',
        description => 'Required parameter is missing',
        fields => ['params'],
    },

    Exception::NotInitialized => {
        isa => 'Exception::BaseException',
    },

    Exception::CannotMakeDirectory => {
        isa => 'Exception::BaseException',
        fields => ['path'],
    },

    Exception::FileExists => {
        description => 'File exists',
        isa => 'Exception::BaseException',
        fields => ['path'],
    },

    Exception::CannotOpenFile => {
        isa => 'Exception::BaseException',
        fields => ['path'],
    },

    Exception::CannotUnlinkFile => {
        isa => 'Exception::BaseException',
        fields => ['path'],
    },

    Exception::ShellCommandFailed => {
        isa => 'Exception::BaseException',
        fields => [qw(exit_code signal core_dump output)],
    },

    Exception::CannotCreateDatabase => {
        isa => 'Exception::ShellCommandFailed',
    },

    Exception::CannotDropDatabase => {
        isa => 'Exception::ShellCommandFailed',
    },

    Exception::CannotImportDatabase => {
        isa => 'Exception::ShellCommandFailed',
    },

    Exception::DatabaseNotFound => {
        isa => 'Exception::BaseException',
        fields => [qw(database_id)],
    },

    Exception::TemplateNotFound => {
        isa => 'Exception::BaseException',
        fields => [qw(template_id)],
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

package Exception::ShellCommandFailed;

sub throw {
    my($class, %params) = @_;

    # extract info from the passed-in error code
    if (my $child_error = delete $params{child_error}) {
        $params{exit_code} = $child_error >> 8;
        $params{signal} = $child_error & 127;
        $params{core_dump} = $child_error & 128;
    }
    $class->SUPER::throw(%params);
}

1;
