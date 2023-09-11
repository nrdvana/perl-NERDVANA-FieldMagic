package XSEnum;
use v5.36;
use Carp;
use parent 'CGenerator';
use List::Util 'uniqstr';

=head1 DESCRIPTION

This module generates parser and wrapper functions for an enum declared in C code so that
typemaps can easily convert back and forth to a perl-view of that enum.

=cut

sub enum_int_type($self) { $self->{enum_int_type} // 'int' }
sub enum_srcfile($self) { $self->{enum_srcfile} // croak "enum_srcfile or enum_hash are required" }
sub enum_c_prefix($self) { $self->{enum_c_prefix} // croak "enum_c_prefix required" }
sub enum_pl_prefix($self) { $self->{enum_pl_prefix} // $self->{enum_c_prefix} }
sub enum_options($self) {
   $self->{enum_options} //= do {
      my $c_prefix= $self->enum_c_prefix;
      my $src= $self->_slurp_file($self->enum_srcfile);
      my %seen;
      my @values= sort grep !$seen{$_}++, $src =~ /(?:^|#define)\s*\Q$c_prefix\E(\w+)\b/g;
      croak "No values found for $c_prefix(\\w+) in ".$self->enum_srcfile unless @values;
      \@values;
   };
}

sub parse_fn($self) {
   my $name= $self->namespace . '_parse';
   $self->generate_once($self->private_impl, $name, sub {
      my $int_t= $self->enum_int_type;
      my $c_prefix= $self->enum_c_prefix;
      my $pl_prefix= $self->enum_pl_prefix;
      my $enum_options= $self->enum_options;
      push $self->public_decl->@* , <<~C;
         bool $name(pTHX_ SV *sv, $int_t *dest);
         C
      my $code= <<~C;
         bool $name(pTHX_ SV *sv, $int_t *dest) {
            if (looks_like_number(sv)) {
               $int_t val= SvIV(sv);
               if (val != SvIV(sv)) // check whether type narrowing lost some of the value
                  return false;
               switch (val) {
               @{[ join "\n      ", map "case $c_prefix$_:", @$enum_options ]}
                  *dest= val;
                  return true;
               default:
                  return false;
               }
            } else {
               STRLEN len;
               const char *str= SvPV(sv, len);
               const char *test_str= NULL;
               $int_t test_val= 0;
               switch(len) {
         C
      my %name_map;
      my %len_map;
      for (@$enum_options) {
         my $short= $_;
         my $long= $pl_prefix . $short;
         $name_map{$short}= $c_prefix.$_;
         $name_map{$long}= $c_prefix.$_;
         push $len_map{length $short}->@*, $short;
         push $len_map{length $long}->@*, $long;
      }
      sub _binary_split($name_map, $vals) {
         # Stop at length 1
         return qq{test_str= "$vals->[0]"; test_val= $name_map->{$vals->[0]};}
            if @$vals == 1;
         # Find a character comparison that splits the list roughly in half.
         my ($best_i, $best_ch, $best_less);
         my $goal= .5 * scalar @$vals;
         for (my $i= length $vals->[0]; $i >= 0; --$i) {
            for my $ch (uniqstr map substr($_, $i, 1), @$vals) {
               my @less= grep substr($_, $i, 1) lt $ch, @$vals;
               ($best_i, $best_ch, $best_less)= ($i, $ch, \@less)
                  if !defined $best_i || abs($goal - @less) < abs($goal - @$best_less);
            }
         }
         my %less= map +($_ => 1), @$best_less;
         my @less_src= _binary_split($name_map, $best_less);
         my @ge_src= _binary_split($name_map, [ grep !$less{$_}, @$vals ]);
         if (@ge_src > 1) {
            # combine "else { if"
            $ge_src[0]= '} else '.$ge_src[0];
         }
         return (
            "if (str[$best_i] < '$best_ch') {",
            (map "   $_", @less_src),
            (@ge_src > 1
               ? @ge_src
               : ( '} else {', (map "   $_", @ge_src), '}' )
            )
         );
      }
      for (sort { $a <=> $b } keys %len_map) {
         my @split_expr= _binary_split(\%name_map, $len_map{$_});
         local $"= "\n         ";
         $code .= <<~C;
               case $_:
                  @split_expr
                  break;
         C
      }
      $code .= <<~C;
               }
               if (strcmp(str, test_str) == 0) {
                  *dest= test_val;
                  return true;
               }
            }
            return false;
         }
         C
   });
}

sub get_sv_fn($self) {
   my $name= $self->namespace . '_get_sv';
   $self->generate_once($self->private_impl, $name, sub {
      my $int_t= $self->enum_int_type;
      my $enum_options= $self->enum_options;
      my $c_prefix= $self->enum_c_prefix;
      my $pl_prefix= $self->enum_pl_prefix;
      push $self->public_decl->@* , <<~C;
         SV* $name(pTHX_ $int_t val);
         C
      my $code= <<~C;
         SV* $name(pTHX_ $int_t val) {
            const char *pv= NULL;
            switch (val) {
         C
      $code .= <<~C for @$enum_options;
            case $c_prefix$_: pv= "$pl_prefix$_"; break;
         C
      $code .= <<~C
            default:
               return sv_2mortal(newSViv(val));
            }
            return sv_2mortal(nf_newSVivpv(val, pv));
         }
         C
   });
}

1;
