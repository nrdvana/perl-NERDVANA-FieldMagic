#! /usr/bin/env perl
use Test2::V0;

ok( require NERDVANA::FieldMagic )
#&& ok( require NERDVANA::FieldMagic::FieldSet )
#&& ok( require NERDVANA::FieldMagic::FieldInfo )
   or bail_out("Module load error");

NERDVANA::FieldMagic::hashtree_test()
   if $ENV{HASHTREE_TEST};

done_testing;

