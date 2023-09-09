package CGenerator;
use v5.36;
use Carp;

sub new($class, %attrs) {
   $attrs{out} //= {};
   bless \%attrs, $class;
}

sub override($self, %attrs) {
   bless { %$self, %attrs }, ref $self
}

sub public_decl  { $_[0]{out}{public_decl} //= [] }
sub public_type  { $_[0]{out}{public_type} //= [] }
sub public_impl  { $_[0]{out}{public_impl} //= [] }
sub private_decl { $_[0]{out}{private_decl} //= [] }
sub private_type { $_[0]{out}{private_type} //= [] }
sub private_impl { $_[0]{out}{private_impl} //= [] }

sub generate_once($self, $list, $name, $source) {
   if (!$self->{out}{defined}{$name}++) {
      push $list->@*, ref $source eq 'CODE'? $source->($self, $name) : $source;
   }
   $name;
}

sub namespace($self) {
   $self->{namespace} // 'hashtree'
}

sub prefix_with_ns($self, $value) {
   # apply namespace only if it doesn't already exist
   return $value if index($value, $self->namespace) == 0;
   return $self->namespace . '_' . $value;
}

sub patch_header($self, $fname, $patch_markers=undef) {
   $patch_markers //= "GENERATED ".uc($self->namespace)." HEADERS";
   $self->_patch_file($fname, $patch_markers,
      join "\n", $self->public_decl->@*, $self->public_type->@*, $self->public_impl->@*);
}

sub patch_source($self, $fname, $patch_markers=undef) {
   $patch_markers //= "GENERATED ".uc($self->namespace)." IMPLEMENTATION";
   $self->_patch_file($fname, $patch_markers,
      join "\n", $self->private_decl->@*, $self->private_type->@*, $self->private_impl->@*);
}

sub _patch_file($self, $fname, $patch_markers, $new_content) {
   open my $fh, '+<', $fname or die "open($fname): $!";
   my $content= do { local $/= undef; <$fh> };
   $content =~ s{(BEGIN \Q$patch_markers\E[^\n]*\n).*?(\n[^\n]+?END \Q$patch_markers\E)}
      {$1$new_content$2}s
      or croak "Can't find $patch_markers in $fname";
   $fh->seek(0,0) or die "seek: $!";
   $fh->print($content) or die "write: $!";
   $fh->truncate($fh->tell) or die "truncate: $!";
   $fh->close or die "close: $!";
}

1;
