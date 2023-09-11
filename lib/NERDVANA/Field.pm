package NERDVANA::Field;

# VERSION
# ABSTRACT: 3D Coordinate Space math

use strict;
use warnings;
use Carp;

require XSLoader;
XSLoader::load('NERDVANA::Field', $NERDVANA::Field::VERSION);

1;

__END__

=head1 SYNOPSIS

  package Color {
    use v5.36;
    use NERDVANA::Field qw/ -parent -twigil /;
    field $.r;
    field $.g;
    field $.b;
    sub html_notation($self) {
      sprintf("#%02x%02x%02x", $.r, $.g, $.b)
    }
  }
 
  my $c= Color->new(255,255,80);
  my $fields= NERDVANA::Field::fieldset_for_package('Color');
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
    use NERDVANA::Field;
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
  my $custom_fields= NERDVANA::Field::anonymous_fieldset();
  $custom_fields->add_field('test', 'SCALAR')->set($vec, "Example");

=head1 FUNCTIONS

=head2 fieldset_for_package

  $fieldset = fieldset_for_package("My::Package", $bool_create);
  $fieldset = fieldset_for_package(\%main::My::Package::, $bool_create);

Return a L<NERDVANA::Field::FieldSet> that describes the fields of a named package.
If create is false, the return value will be C<undef> unless fields have been initialized
for that package.

=head2 field_type

  $dualvar= NRDVANA::Field::field_type('SV');
  $dualvar= NRDVANA::Field::field_type(0x81);

Takes either a string or a number, and gives you a dualvar SV that tell you both answers.
If the name or number is not valid, this returns C<undef>.

=head2 anonymous_fieldset

Shortcut for L<NERDVANA::Field/new>.

=head2 get_object_fieldsets

  @fieldsets= get_object_fieldsets($object);

Returns a list of all fieldsets which have active storage associated with the object.

