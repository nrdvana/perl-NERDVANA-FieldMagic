#! /usr/bin/env perl
use Test2::V0;

ok( require NERDVANA::Field );

my $t= NERDVANA::Field::field_type('SV');
is( "$t", 'FIELD_TYPE_SV' );
is( 0+$t, 0x81 );

my $main_fields= NERDVANA::Field::fieldset_for_package('main');
is( $main_fields->field_count, 0, 'main has no fields' );

done_testing;

