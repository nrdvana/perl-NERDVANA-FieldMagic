package NERDVANA::FieldMagic::FieldInfo;

1;

__END__

=head1 ATTRIBUTES

=head2 fieldset

A reference to the L<NERDVANA::FieldMagic::FieldSet> that owns this field.
(FieldInfo objects hold a strong reference to FieldSet)

=head2 field_idx

Index of this field within the containing FieldSet.

=head2 name

Name of the field, not including sigil or twigil.

=head2 type

The type of the field, as declared.  Returns a dualvar that is both the name and integer
value of the symbolic constant.
