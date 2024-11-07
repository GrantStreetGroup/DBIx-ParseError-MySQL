package DBIx::ParseError::MySQL;

use utf8;
use strict;
use warnings;

use Moo;

use Scalar::Util    qw( blessed    );
use Types::Standard qw( Str Bool Object );

# ABSTRACT: Error parser for MySQL
# VERSION

=head1 SYNOPSIS

    use DBIx::ParseError::MySQL;

    eval {
        my $result = $dbh->do('SELECT 1');
    };
    if ($@) {
        if (DBIx::ParseError::MySQL->new($@)->is_transient) { $dbh->reconnect }
        else                                                { die; }
    }

=head1 DESCRIPTION

This module is a database error categorizer, specifically for MySQL. This module is also
compatible with Galera's WSREP errors.

=head1 ATTRIBUTES

=head2 orig_error

Returns the original, untouched error object or string.

=cut

has orig_error => (
    is       => 'ro',
    isa      => Str|Object,
    required => 1,
);

=head2 error_string

Returns the stringified version of the error.

=cut

has error_string => (
    is       => 'lazy',
    isa      => Str,
    init_arg => undef,
);

sub _build_error_string {
    my $self = shift;

    # All of the exception objects should support this, too.
    return $self->orig_error."";
}

=head2 error_type

Returns a string that describes the type of error.  These can be one of the following:

    lock             Lock errors, like a lock wait timeout or deadlock
    connection       Connection/packet failures, disconnections
    shutdown         Errors that happen when a server is shutting down
    duplicate_value  Duplicate entry errors
    unknown          Any other error

=cut

has error_type => (
    is       => 'lazy',
    isa      => Str,
    init_arg => undef,
);

sub _build_error_type {
    my $self = shift;

    my $error = $self->error_string;

    # We have to capture just the first error, not other errors that may be buried in the
    # stack trace.
    $error =~ s/ at [^\n]+ line \d+\.?(?s:\n.*)?//;

    # Disable /x flag to allow for whitespace within string, but turn it on for newlines
    # and comments.
    #
    # These error messages are purposely long and case-sensitive, because we're looking
    # for these errors -anywhere- in the string.  Best to get as exact of a match as
    # possible.

    # Locks
    return 'lock' if $error =~ m<
        (?-x:Deadlock found when trying to get (?:user-level |locking service )?lock; try )(?:
            (?-x:restarting transaction)|
            (?-x:rolling back transaction/releasing locks and restarting lock acquisition)|
            (?-x:releasing locks and restarting lock acquisition)
        )|
        (?-x:Lock wait timeout exceeded; try restarting transaction)|
        (?-x:Service lock wait timeout exceeded)|
        (?-x:WSREP detected deadlock/conflict and aborted the transaction.\s+Try restarting the transaction)
    >x;

    # Various connection/packet problems
    return 'connection' if $error =~ m<
        # Connection dropped/interrupted
        (?-x:MySQL server has gone away)|
        (?-x:Lost connection to MySQL server)|
        # NOTE: Exclude max_execution_time interruptions, since these are not connection
        # failures, and retrying them would just produce the same results
        (?-x:Query execution was interrupted(?!, maximum statement execution time exceeded))|

        # Initial connection failure
        (?-x:Bad handshake)|
        (?-x:Too many connections)|
        (?-x:Host '\S+' is blocked because of many connection errors)|
        (?-x:Can't get hostname for your address)|
        (?-x:Can't connect to (?:local )?MySQL server)|

        # Packet corruption
        (?-x:Got a read error from the connection pipe)|
        (?-x:Got (?:an error|timeout) (?:reading|writing) communication packets)|
        (?-x:Malformed communication packet)|

        # XXX: This _might be_ a connection failure, but the DBD::mysql error message
        # does not expose the direct failure cause.  See DBD::mysql/dbdimp.c#L2551.
        (?-x:Turning (?:off|on) AutoCommit failed)
    >x;

    # Failover/shutdown of node/server
    return 'shutdown' if $error =~ m<
        (?-x:WSREP has not yet prepared node for application use)|
        (?-x:Server shutdown in progress)|
        (?-x:Normal shutdown)|
        (?-x:Shutdown complete)
    >x;

    # Duplicate entry error
    return 'duplicate_value' if $error =~ m<
        # Any value can be in the first piece here...
        (?-x:Duplicate entry '.+?' for key '\S+')
    >xs;  # include \n in .+

    return 'unknown';
}


=head2 is_transient

Returns a true value if the error is the type that is likely transient.  For example,
errors that recommend retrying transactions or connection failures.  This check can be
used to figure out if it's worth retrying a transaction.

This is merely a check for the following L<error types|/error_type>:
C<< lock connection shutdown >>.

=cut

has is_transient => (
    is       => 'lazy',
    isa      => Bool,
    init_arg => undef,
);

sub _build_is_transient {
    my $self = shift;

    my $type = $self->error_type;

    return 1 if $type =~ /^(lock|connection|shutdown)$/;
    return 0;
}

=head1 CONSTRUCTORS

=head2 new

    my $parsed_error = DBIx::ParseError::MySQL->new($@);

Returns a C<DBIx::ParseError::MySQL> object.  Since the error is the only parameter, it
can be passed by itself.

=for Pod::Coverage BUILDARGS

=cut

around BUILDARGS => sub {
    my ($orig, $class, @args) = @_;

    if (@args == 1 && defined $args[0] && (!ref $args[0] || blessed $args[0])) {
        my $error = shift @args;
        push @args, ( orig_error => $error );
    }

    return $class->$orig(@args);
};

=head1 SEE ALSO

L<DBIx::Class::ParseError> - A similar parser, but specifically tailored to L<DBIx::Class>.

=cut

1;
