package NERDVANA::FieldMagic;

# VERSION
# ABSTRACT: It's Fields All The Way Down

use strict;
use warnings;
use Carp;

require XSLoader;
XSLoader::load('NERDVANA::FieldMagic', $NERDVANA::FieldMagic::VERSION);

1;

__END__

=head1 SYNOPSIS

  package Color {
    use v5.36;
    use NERDVANA::FieldMagic qw/ -parent -twigil /;
    field $.r;
    field $.g;
    field $.b;
    sub html_notation($self) {
      sprintf("#%02x%02x%02x", $.r, $.g, $.b)
    }
  }
 
  my $c= Color->new(255,255,80);
  my $fields= NERDVANA::FieldMagic::fieldset_for_package('Color');
  $fields->get_field('r')->set($c, 2);

  $fields->add_field('a', 'SCALAR');
  eval {
    package Point;
    *html_notation= sub($self) {
      defined $.a? sprintf("#%02x%02x%02x%02x", $.r, $.g, $.b, $.a)
      : sprintf("#%02x%02x%02x%02x", $.r, $.g, $.b);
    }
  }
  
  package Vector {
    use v5.36;
    use NERDVANA::FieldMagic;
    field $x :virtual[0];
    field $y :virtual[1];
    field $z :virtual[2];
    sub new($class, $_x, $_y, $_z) {
      bless [ $_x, $_y, $_z ], $class;
    }
    sub x :lvalue { $x }
    sub y :lvalue { $y }
    sub z :lvalue { $z }
    sub magnitude($self) {
      $x*$x + $y*$y + $z*$z
    }
  }
  my $vec= Vector->new(1,1,1);
  my $custom_fields= NERDVANA::FieldMagic::anonymous_fieldset();
  $custom_fields->add_field('test', 'SCALAR')->set($vec, "Example");

=head1 FUNCTIONS

=head2 fieldset_for_package

  $fieldset = fieldset_for_package("My::Package", $bool_create);
  $fieldset = fieldset_for_package(\%main::My::Package::, $bool_create);

Return a L<NERDVANA::FieldMagic::FieldSet> that describes the fields of a named package.
If create is false, the return value will be C<undef> unless fields have been initialized
for that package.

=head2 field_type

  $dualvar= NRDVANA::Field::field_type('SV');
  $dualvar= NRDVANA::Field::field_type(0x81);

Takes either a string or a number, and gives you a dualvar SV that tell you both answers.
If the name or number is not valid, this returns C<undef>.

=head2 new_fieldset

Shortcut for L<NERDVANA::FieldMagic::FieldSet/new>.

=head2 get_object_fieldsets

  @fieldsets= get_object_fieldsets($object);

Returns a list of all fieldsets which have active storage associated with the object.

=head1 CONSTANTS

=head2 Field Types

=over

=item FIELD_TYPE_SV

=item FIELD_TYPE_AV

=item FIELD_TYPE_HV

=item FIELD_TYPE_VIRT_SV

=item FIELD_TYPE_VIRT_AV

=item FIELD_TYPE_VIRT_HV

=item FIELD_TYPE_BOOL

=item FIELD_TYPE_IV

=item FIELD_TYPE_UV

=item FIELD_TYPE_NV

=item FIELD_TYPE_PV

=item FIELD_TYPE_STRUCT

=back
