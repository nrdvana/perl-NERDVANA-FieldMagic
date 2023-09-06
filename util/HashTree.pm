package HashTree;
use v5.36;
use Carp;
use Scalar::Util 'looks_like_number';

sub new($class, %opts) {
   $opts{out} //= {};
   bless \%opts, $class;
}

sub public_decl  { $_[0]{out}{public_decl} //= [] }
sub public_type  { $_[0]{out}{public_type} //= [] }
sub public_impl  { $_[0]{out}{public_impl} //= [] }
sub private_decl { $_[0]{out}{private_decl} //= [] }
sub private_type { $_[0]{out}{private_type} //= [] }
sub private_impl { $_[0]{out}{private_impl} //= [] }

sub with($self, %opts) {
   bless { %$self, %opts }, ref $self
}

sub generate($self, $list, $name, $source) {
   if (!$self->{out}{defined}{$name}) {
      push $list->@*, $source;
   }
}

sub namespace($self) {
   $self->{namespace} // 'hashtree'
}
sub prefix_with_ns($self, $value) {
   # apply namespace only if it doesn't already exist
   return $value if index($value, $self->namespace) == 0;
   return $self->namespace . '_' . $value;
}

sub word_type($self)    { $self->{word_type} // die "word_type is required" }
sub word_suffix($self)  { $self->{word_suffix} // '_'.($self->{word_type} =~ s/\W+/_/gr) }
sub word_size($self)    { $self->{word_size} }

sub elem_type($self)    { $self->{elem_type} // die "elem_type is required" }
sub elem_namespace($self) {
   $self->{elem_namespace} // $self->prefix_with_ns($self->elem_type)
}
sub elem_key_type($self) {
   $self->{elem_key_type} // "IV"
}
sub elem_key($self, $elem_expr) {
   ref $self->{elem_key} eq 'CODE' or croak "elem_key coderef is required";
   $self->{elem_key}->($self, $elem_expr);
}
sub elem_key_cmp($self, $p0, $p1) {
   if ($self->{elem_key_cmp}) {
      return $self->{elem_key_cmp}->($self, $p0, $p1);
   } else {
      my $macro_name= uc($self->elem_namespace . '_KEY_CMP');
      $self->generate($self->private_decl, $macro_name, "#define $macro_name(a, b) ((IV)((b)-(a)))");
      return "$macro_name($p0, $p1)";
   }
}
sub elem_keyhash($self, $elem_expr) {
   ref $self->{elem_keyhash} eq 'CODE' or croak "elem_keyhash coderef is required";
   $self->{elem_keyhash}->($self, $elem_expr);
}

sub node_type($self)    { $self->{node_type} // "struct ".$self->namespace."__rbnode".$self->word_suffix }

sub find_fn($self)      { $self->{find_fn} // $self->elem_namespace.'_find'.$self->word_suffix }
sub reindex_fn($self)   { $self->{reindex_fn} // $self->elem_namespace.'_reindex'.$self->word_suffix }
sub balance_fn($self)   { $self->{balance_fn} // $self->namespace.'__rbbalance'.$self->word_suffix }

sub patch_header($self, $fname, $patch_markers= "GENERATED HashTree HEADERS") {
   $self->_patch_file($fname, $patch_markers,
      join "\n", $self->public_decl->@*, $self->public_type->@*, $self->public_impl->@*);
}
sub patch_source($self, $fname, $patch_markers= "GENERATED HashTree IMPLEMENTATION") {
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
   $fh->close or die "close: $!";
}

sub table_count($self, $capacity) {
   my $macro= uc($self->namespace).'_TABLE_COUNT';
   $self->generate($self->public_decl, $macro, <<~C);
      // For a given capacity, this is how many hashtable buckets will be allocated
      #define $macro(capacity) ((capacity) + ((capacity) >> 1))
      C
   return "$macro($capacity)";
}

sub max_capacity($self) {
   my $macro= uc($self->namespace.'_'.$self->word_type.'_MAX_CAPACITY');
   my $ws= $self->word_size;
   $self->generate($self->public_decl, $macro, <<~C);
      // Maximum number of elements that can be indexed using this word size
      #define $macro ((1 << ($ws * 8 - 1)) - 2)
      C
   return $macro
}

sub hashtree_size($self) {
   my $name= uc($self->namespace.'_'.$self->word_type.'_SIZE');
   my $ws= $self->word_size;
   $self->generate($self->public_decl, $name, <<~C);
      // size of hashtree structure, not including element array that it is appended to
      #define $name(capacity) ((((capacity)+1)*2 + @{[ $self->table_count('capacity') ]} * $ws)
      C
   return $name;
}

sub tree_height_limit($self) {
   my $name= uc($self->namespace).'_TREE_HEIGHT_LIMIT'.uc($self->word_suffix);
   my $ws= $self->word_size;
   $self->generate($self->private_decl, $name, <<~C);
      // Max tree height of N nodes is log2(N) * 2
      // Max array index range for this implementation is 0..(2^(n-1)-2)
      // because one bit is used for flags, and zero is used as NULL.
      #define $name (($ws * 8 - 1)*2)
      C
   return $name;
}

sub generate_rb_node_struct($self) {
   my $struct= $self->node_type;
   return $struct if $self->{out}{defined}{$struct}++;

   my $word= $self->word_type;
   my $sz= $self->word_size;
   push $self->private_decl->@*, $struct.';';
   my $h;
   if (looks_like_number($sz)) {
      $h= <<~H;
         $struct {
            $word
               left  :@{[ $sz*8 - 1 ]}, is_red: 1,
               right :@{[ $sz*8 - 1 ]}, is_righttree: 1;
         };
         H
   } else {
      $h= <<~H;
         $struct {
            $word
         H
      for (1,2,4,8) {
         $h .= <<~H;
            #if $sz == $_
               left  :@{[ $_*8 - 1 ]}, is_red: 1,
               right :@{[ $_*8 - 1 ]}, is_righttree: 1;
            #endif
            H
      }
      $h .= "};\n";
   }
   push $self->private_type->@*, $h;
   return $struct;
}

sub generate_find($self) {
   my $fn= $self->find_fn;
   return $fn if $self->{out}{defined}{$fn}++;
   
   my $node_struct= $self->generate_rb_node_struct;
   my $elem_type= $self->elem_type;
   my $word_type= $self->word_type;
   my $key_type= $self->elem_key_type;
   push $self->public_decl->@*, "IV $fn($elem_type *el_array, size_t capacity, $key_type search_key);";
   push $self->private_impl->@* , <<~C;
      // Look up the search_key in the hashtable, walk the tree of conflicts, and
      // return the el_array element which matched.
      IV $fn($elem_type *el_array, size_t capacity, $key_type search_key) {
         size_t table_count= @{[ $self->table_count('capacity') ]}, hash_code, node;
         $node_struct *nodes= ($node_struct*) (el_array + capacity);
         $word_type *table= ($word_type*) (nodes + 1 + capacity);
         hash_code= @{[ $self->elem_keyhash('el_array[i]') ]} % table_count;
         IV cmp;
         if ((node= table[hash_code])) {
            do {
               cmp= @{[ $self->elem_key_cmp($self->elem_key('el_array[node-1]'), 'search_key') ]};
               if (!cmp)
                  return node-1;
               node= (cmp < 0)? nodes[node].left : nodes[node].right;
            } while (node);
         }
         return -1;
      }
      C
   return $fn;
}

sub generate_reindex($self) {
   my $fn= $self->reindex_fn;
   return $fn if $self->{out}{defined}{$fn}++;
   
   my $node_struct= $self->generate_rb_node_struct;
   my $balance= $self->generate_rb_balance;
   my $elem_type= $self->elem_type;
   my $word_type= $self->word_type;
   my $tree_height_limit= $self->tree_height_limit;
   my $ws= $self->word_size;
   push $self->public_decl->@*, "bool $fn($elem_type *el_array, size_t capacity, size_t from_i, size_t until_i);";
   push $self->private_impl->@* , <<~C;
      // For an array of 'capacity' elements followed by 1+ that number of
      // tree nodes, followed by table_count hash buckets (which scales per capacity),
      // reindex the elements from first_i to last_i.
      // If this returns false, it means there is a fatal error in the data structure.
      bool $fn($elem_type *el_array, size_t capacity, size_t i, size_t until_i) {
         size_t table_count= @{[ $self->table_count('capacity') ]}, hash_code, pos, node;
         IV cmp;
         $node_struct *nodes= ($node_struct*) (el_array + capacity);
         $word_type *table= ($word_type*) (nodes + 1 + capacity);
         $word_type parents[1+$tree_height_limit];
         assert(((to_i + 1) >> ($ws*4) >> ($ws*4)) == 0); // to_i should never be more than 2^N - 2
         for (; i < until_i; i++) {
            hash_code= @{[ $self->elem_keyhash('el_array[i]') ]} % table_count;
            if (!table[hash_code])
               table[hash_code]= i+1; // element i uses node i+1, because 0 means NULL
            else {
               // red/black insert
               parents[0]= 0; // mark end of list
               pos= 0, node= table[hash_code];
               assert(node <= i);
               do {
                  parents[++pos]= node;
                  cmp= @{[ $self->elem_key_cmp($self->elem_key('el_array[i]'), $self->elem_key('el_array[node-1]')) ]};
                  node= cmp < 0? nodes[node].left : nodes[node].right;
               } while (node && pos < $tree_height_limit) {
               if (pos >= $tree_height_limit)
                  assert(pos < TREE_HEIGHT_LIMIT);
                  return false; // fatal error, should never happen unless datastruct corrupt
               }
               node= parents[pos];
               if (go_left) {
                  nodes[node].left= i+1;
               else
                  nodes[node].right= i+1;
               nodes[i+1].is_red= 1; // other fields should be initialized to zero already
               if (pos > 1) { // no need to balance unless more than 1 parent
                  $balance(nodes, parents+pos-1);
                  table[hash_code]= parents[1]; // may have changed after tree balance
                  nodes[parents[1]].is_red= 0; // tree root is always black
               }
            }
         }
         return true;
      }
      C
   return $fn;
}

sub generate_rb_balance($self) {
   my $fn= $self->balance_fn;
   return $fn if $self->{out}{defined}{$fn}++;

   $self->generate_rb_node_struct;
   my $word= $self->word_type;
   push $self->private_decl->@*, "static void $fn($word *tree, $word *parents);";
   push $self->private_impl->@* , <<~C;
      // balance a tree from parents[0] upward.  (parents is terminated by a 0 value)
      // nodes is the full array of tree nodes.
      static void $fn($word *nodes, $word *parents) {
         $word pos= *parents--, parent;
         // if current is a black node, no rotations needed
         while (pos && nodes[pos].is_red) {
            if (!(parent= *parents))
               break;
            // current is red, the imbalanced child is red, and parent is black.
            // if the current is on the left of the parent, the parent is to the right
            if (nodes[parent].left == pos) {
               // if the sibling is also red, we can pull down the color black from the parent
               if (nodes[nodes[parent].right].is_red) {
                  nodes[nodes[parent].right].is_red= 0;
                  nodes[pos].is_red= 0;
                  nodes[parent].is_red= 1;
               }
               else {
                  // if the imbalance (red node) is on the right, and the parent is on the right,
                  //  need to rotate those lower nodes over to the left.
                  if (nodes[nodes[pos].right].is_red) {
                     // rotate pos left so parent's left now points to pos.right
                     newpos= nodes[pos].right;
                     nodes[pos].right= nodes[newpos].left;
                     nodes[newpos].left= pos;
                     pos= newpos;
                     // parent.left has not been updated here
                  }
                  // Now we can do our right rotation to balance the tree.
                  nodes[parent].left= nodes[pos].right;
                  nodes[parent].is_red= 1;
                  nodes[pos].right= parent;
                  nodes[pos].is_red= 0;
                  // if the parent was the root of the tree, update the stack
                  // else update the grandparent to point to new parent.
                  if (!parents[-1])
                     *parents= pos;
                  else if (nodes[parents[-1]].left == parent)
                     nodes[parents[-1]].left= pos;
                  else
                     nodes[parents[-1]].right= pos;
                  break;
               }
            }
            // else the parent is to the left.  Repeat mirror of code above
            else {
               // if the sibling is also red, we can pull down the color black from the parent
               if (nodes[nodes[parent].left].is_red) {
                  nodes[nodes[parent].left].is_red= 0;
                  nodes[pos].is_red= 0;
                  nodes[parent].is_red= 1;
               }
               else {
                  // if the imbalance (red node) is on the left, and the parent is on the left,
                  //  need to rotate those lower nodes over to the right.
                  if (nodes[nodes[pos].right].is_red) {
                     // rotate pos right so parent's right now points to pos.left
                     newpos= nodes[pos].left;
                     nodes[pos].left= nodes[newpos].right;
                     nodes[newpos].right= pos;
                     pos= newpos;
                     // parent.right has not been updated here
                  }
                  // Now we can do our left rotation to balance the tree.
                  nodes[parent].right= nodes[pos].left;
                  nodes[parent].is_red= 1;
                  nodes[pos].left= parent;
                  nodes[pos].is_red= 0;
                  // if the parent was the root of the tree, update the stack
                  // else update the grandparent to point to new parent.
                  if (!parents[-1])
                     *parents= pos;
                  else if (nodes[parents[-1]].left == parent)
                     nodes[parents[-1]].left= pos;
                  else
                     nodes[parents[-1]].right= pos;
                  break;
               }
            }
            // jump twice up the tree. if current reaches the Sentinel (black node, id=0), we're done
            parents--;
            pos= *parents--;
         }
      }
      C
   return $fn;
}

1;
