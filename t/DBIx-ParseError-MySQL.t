use strict;
use warnings;

use Test::More;

BEGIN { use_ok('DBIx::ParseError::MySQL') };

diag(qq(DBIx::ParseError::MySQL Perl $], $^X));

done_testing;
