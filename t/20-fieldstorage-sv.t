#! /usr/bin/env perl
use Test2::V0;
use NERDVANA::FieldMagic qw( new_fieldset fieldset_for_package FIELD_TYPE_SV );
use Scalar::Util 'weaken';

my $main_fields= new_fieldset;#_for_package('main');
is( $main_fields, object {
   call field_count => 0;
   call package_name => undef;
}, 'main_fields' );

my $field= $main_fields->add_field(x => 'SV');
my $object= bless {}, 'main';
is( $field->get_value($object), undef, 'initially undef' );
ok( !$field->has_value($object), 'exists is false' );
is( $field->get_lvalue($object), undef, 'lvalue is also undef' );
ok( $field->has_value($object), 'exists is true' );
$_= 1 for $field->get_lvalue($object);
is( $field->get_value($object), 1, 'get = 1' );
 
done_testing;
