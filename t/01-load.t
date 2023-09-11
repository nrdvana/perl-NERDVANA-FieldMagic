#! /usr/bin/env perl
use Test2::V0;

ok( require NERDVANA::Field )
&& ok( require NERDVANA::Field::FieldSet )
&& ok( require NERDVANA::Field::FieldInfo )
   or bail_out("Module load error");

done_testing;

