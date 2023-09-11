package NERDVANA::Field::FieldSet;

=head1 CONSTRUCTOR

=head2 new

  $fieldset = NRDVANA::FieldSet->new();

Create a new L<NERDVANA::Field::FieldSet> which is not associated with any package.
The fields of this fieldset will not be available as lexical variable names during an eval,
but can act as generic storage attached to arbitrary objects that are guaranteed not to
interfere with other attributes, and which are faster and lighter than using inside-out
techniques like using the object's address as a key to an external hash.

These fields cannot be serialized.

=cut
1;