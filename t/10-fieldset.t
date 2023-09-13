#! /usr/bin/env perl
use Test2::V0;
use NERDVANA::FieldMagic qw( new_fieldset fieldset_for_package FIELD_TYPE_SV );
use Scalar::Util 'weaken';

my $anon_fields= new_fieldset();
is( $anon_fields, object {
   call field_count => 0;
   call package_name => undef;
}, 'anon_fields' );
weaken($anon_fields);
is( $anon_fields, undef, 'correct garbage collection of anon fields' );

my $main_fields= fieldset_for_package('main');
is( $main_fields, object {
   call field_count => 0;
   call package_name => 'main';
}, 'main_fields' );

weaken($main_fields);
ok( $main_fields, 'main_fields not garbage collected' );

# should get the same fields for main's stash
ok( $main_fields == fieldset_for_package(\%main::), 'same fieldset object' );

# Add a SV field without default
$main_fields->add_field("test", FIELD_TYPE_SV);

# Lookup by name
is( $main_fields->field("test"), object {
   call fieldset => $main_fields;
   call field_idx => 0;
   call name => 'test';
   call type => FIELD_TYPE_SV;
}, "field 'test'" );

# Lookup by index
is( $main_fields->field(0), object {
   call field_idx => 0;
   call name => 'test';
   call type => FIELD_TYPE_SV;
}, "field 'test'" );

# Can't add a duplicate
ok( !eval { $main_fields->add_field("test", FIELD_TYPE_SV) }, "can't add duplicate" );
like( $@, qr/exists/, 'exception text' );

# Add another 8 fields
for (0..7) {
   $main_fields->add_field("x$_", FIELD_TYPE_SV);
}
# Find each of them
for (0..7) {
   is( $main_fields->field("x$_")->name, "x$_", "found field x$_" );
}

done_testing;
