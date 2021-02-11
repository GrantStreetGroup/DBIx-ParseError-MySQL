# NAME

DBIx::ParseError::MySQL - Error parser for MySQL

# VERSION

version v1.0.0

# SYNOPSIS

    use DBIx::ParseError::MySQL;

    eval {
        my $result = $dbh->do('SELECT 1');
    };
    if ($@) {
        if (DBIx::ParseError::MySQL->new($@)->is_transient) { $dbh->reconnect }
        else                                                { die; }
    }

# DESCRIPTION

This module is a database error categorizer, specifically for MySQL. This module is also
compatible with Galera's WSREP errors.

# ATTRIBUTES

# orig\_error

Returns the original, untouched error object or string.

# error\_string

Returns the stringified version of the error.

# error\_type

Returns a string that describes the type of error.  These can be one of the following:

    lock             Lock errors, like a lock wait timeout or deadlock
    connection       Connection/packet failures, disconnections
    shutdown         Errors that happen when a server is shutting down
    duplicate_value  Duplicate entry errors
    unknown          Any other error

## is\_transient

Returns a true value if the error is the type that is likely transient.  For example,
errors that recommend retrying transactions or connection failures.  This check can be
used to figure out if it's worth retrying a transaction.

This is merely a check for the following [error types](#error_type):
`lock connection shutdown`.

# CONSTRUCTORS

# new

    my $parsed_error = DBIx::ParseError::MySQL->new($@);

Returns a `DBIx::ParseError::MySQL` object.  Since the error is the only parameter, it
can be passed by itself.

# SEE ALSO

[DBIx::Class::ParseError](https://metacpan.org/pod/DBIx%3A%3AClass%3A%3AParseError) - A similar parser, but specifically tailored to [DBIx::Class](https://metacpan.org/pod/DBIx%3A%3AClass).

# AUTHOR

Grant Street Group <developers@grantstreet.com>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2020 - 2021 by Grant Street Group.

This is free software, licensed under:

    The Artistic License 2.0 (GPL Compatible)
