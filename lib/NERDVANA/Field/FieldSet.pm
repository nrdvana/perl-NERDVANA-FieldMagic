package NERDVANA::Field::FieldSet;

1;

__END__

=head1 CONSTRUCTOR

=head2 new

  $fieldset = NRDVANA::Field::FieldSet->new();

Create a new L<NERDVANA::Field::FieldSet> which is not associated with any package.
These variables essentially operate like the "inside-out object" pattern, but much faster.

=head1 ATTRIBUTES

=head2 field_count

Number of fields that have been created in this set.

=head2 package_name

If this FieldSet is bound to a package, this returns the name of the package.
If the FieldSet is anonymous, this returns C<undef>.

TODO: If the FieldSet is bound to a package and the package gets deleted (i.e. entire stash
removed) I think this becomes C<undef>.  Would be good to test and then document that
situation.

=head1 METHODS

=head2 field

  $fieldinfo= $fieldset->field($name);
  $fieldinfo= $fieldset->field($idx);

Return an object describing a field, either by name or by number.
(field names cannot be purely numeric, so there is no ambiguity here)

=head2 add_field

  $fieldinfo= $fieldset->add_field($name, $type, ...);
  $fieldinfo= $fieldset->add_field($name, FIELD_TYPE_SV, default => $default_value);
  $fieldinfo= $fieldset->add_field($name, 'SV', default => $default_value);

Create a new field for the fieldset.  Fields may not be modified or deleted after they are
created.  The C<$type> of field determines which additional options can be supplied.

