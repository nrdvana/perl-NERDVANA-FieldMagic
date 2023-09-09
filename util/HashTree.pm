package HashTree;
use v5.36;
use Carp;
use Scalar::Util 'looks_like_number';
use parent "CGenerator";

=head1 DESCRIPTION

A HashTree is a data structure that provides fast lookup from a key to the numbers 1..N.
It is a combination of a hash table and red/black trees, where all hash collisions are
added to trees so that performance never drops below log2(N).

The numbers 1..N usually represent the elements of some array (but shifted by 1) where the
application is storing objects which it wants to look up.  

The data structure is specially optimized to exist in a single span of memory, so it can be
conveniently allocated on the end of a user's array each time the array is reallocated to
accommodate more elements.

This algorithm is a template that requires:
  * A function that returns a hashcode for an element
  * A function that returns a hashcode for a search key
  * A function that compares an element with a search key
  * A function that compares two elements

Additionally, the user can tune some of the parameters of the algorithm:
  * The number of hash buckets allocated for a given element count
  * The maximum range of elements handled
  * The declared types of keys and elements, for clearer type checking.
  * Whether the functions are implemented as inline functions, macros, or callbacks.
  * whether to include assertions and debugging code

=head1 ATTRIBUTES

=head2 macro_elem_hashcode

  $code= $hashtree->macro_elem_hashcode($elemdata_expr, $index_expr); # size_t
  
  # Example:
  $hashtree->override(
    macro_elem_hashcode =>
      sub($self, $data, $idx) { "(($data)[$i]).name_hashcode" },
  }

This receives C code describing "elemdata" (user-supplied pointer) and
"index" (integer 1..N), and returns a C expression that describes how to get a
hashcode from that.  The hashcode will be stored in a size_t variable.

=cut

sub macro_elem_hashcode($self, $elemdata_expr, $index_expr) {
   ($self->{macro_elem_hashcode} // croak "macro_elem_hashcode is required")
      ->($self, $elemdata_expr, $index_expr);
}

=head2 macro_key_hashcode

  $code= $hashtree->macro_key_hashcode($key_expr); # size_t
  
  # Example:
  $hashtree->override(
    macro_key_hashcode =>
      sub($self, $key) { "calc_hashcode($key)" }
  )

This receives C code describing a "key" (input to fund() function) and returns
a C expression that gets a hash code from the key.  The hash code is assigned
to a size_t variable.

=cut

sub macro_key_hashcode($self, $key_expr) {
   ($self->{macro_key_hashcode} // croak "macro_key_hashcode is required")
      ->($self, $key_expr);
}

=head2 macro_cmp_key_elem

  $code= $hashtree->macro_cmp_key_elem($key_expr, $elemdata_expr, $index_expr);
  
  # Example
  $hashtree->override(
    macro_cmp_key_elem =>
      sub($self, $key, $data, $idx) { "strcmp($key, ($data)[$idx].name)" }
  )

This receives an expression for a key (input to find()), elemdata (also an input
to find()) and an index 1..N of the element requested.  It returns a C expression
in the style of strcmp, which is an integer less than zero if the key sorts less
than the element, 0 if they sort equal, and greater than 0 if the key sorts greater
than the element.

=cut

sub macro_cmp_key_elem($self, $key_expr, $elemdata_expr, $index_expr) {
   ($self->{macro_cmp_key_elem} // croak "macro_cmp_key_elem is required")
      ->($self, $key_expr, $elemdata_expr, $index_expr);
}

=head2 macro_cmp_elem_elem

  $code= $hashtree->macro_cmp_elem_elem($elemdata_expr, $idx1_expr, $idx2_expr);
  
  # Example:
  $hashtree->override(
    macro_cmp_elem_elem =>
      sub($self, $data, $idx1, $idx2) {
        "strcmp(($data)[$idx1].name, ($data)[$idx2].name)"
      }
  )

This receives the user "elemdata" (passed to the find() function) and two integer
indices 1..N of the elements to be compared.  It should return an integer in the
style of strcmp, where the element of $idx1 comparing less than the element of
$idx2 should return an integer less than zero, and so on.

=cut

sub macro_cmp_elem_elem($self, $elemdata_expr, $idx1_expr, $idx2_expr) {
   ($self->{macro_cmp_elem_elem} // croak "macro_cmp_elem_elem is required")
      ->($self, $elemdata_expr, $idx1_expr, $idx2_expr);
}

=head2 common_namespace

This defaults to L</namespace>, but can be overridden to share generic hashtree functions
with several more specific implementations.

=head2 context_param

This defaults to 'pTHX_' which allows you to call Perl API functions from the macros.

=head2 elemdata_type

This is the type of the third argument to 'find'.  By default, it is C<void*> and you
need to cast it as needed during your macros.

=head2 key_type

This is the type of the fourth argument to 'find'.  By default, it is C<void*> and you
need to cast it as needed in your macros.

=head2 word_types

This specifies which C types should be used for 8-bit, 16-bit, 32-bit and so on.
The hashtree automatically chooses a word size based on the C<capacity>.

=head2 max_capacity

The upper limit of what the hashtree should support.  For example, on 32-bit systems
there is no reason to generate code for 64-bit capacities.

=cut

sub common_namespace($self) { $self->{common_namespace} // $self->namespace }
sub elemdata_type($self) { $self->{elemdata_type} // 'void*' }
sub key_type($self) { $self->{key_type} // 'void*' }
sub word_types($self) { $self->{word_types} // [ 'uint8_t', 'uint16_t', 'uint32_t', 'uint64_t' ] }
sub max_capacity($self) { $self->{max_capacity} // 0x7FFFFFFF }
#sub min_capacity($self) { $self->{min_capacity} // 8 }

sub word_max_capacity($self) { [ 0x7F, 0x7FFF, 0x7FFFFFFF, "0x7FFFFFFFFFFF" ] }
# max tree height is 2x the max black nodes, which are log2(N)
sub word_max_tree_height($self) { [ 16, 32, 64, 128 ] }
sub max_word_idx($self) {
   $self->max_capacity > 0x7FFFFFFF? 3
   : $self->max_capacity > 0x7FFF? 2
   : $self->max_capacity > 0x7F? 1
   : 0
}

=head2 macro_table_buckets

Returns the number of buckets to allocate for a given capacity.

=cut

sub macro_table_buckets($self, $capacity_expr) {
   my $name= uc($self->common_namespace .'_TABLE_BUCKETS');
   $self->generate_once($self->public_decl, $name, sub {
      <<~C
      // For a given capacity, this is how many hashtable buckets will be allocated
      #define $name(capacity) ((capacity) + ((capacity) >> 1))
      C
   });
   "$name($capacity_expr)"
}

sub macro_hashtree_size($self, $capacity_expr) {
   my $name= uc($self->common_namespace . '_SIZE');
   $self->generate_once($self->public_decl, $name, sub {
      <<~C
      // Size of hashtree structure, not including element array that it is appended to
      // This is a function of the max capacity of elements.
      #define $name(capacity) ( \\
         ((capacity) > 0x7FFFFFFF? 8 \\
          : (capacity) > 0x7FFF? 4 \\
          : (capacity) > 0x7F? 2 \\
          : 1 \\
         ) * ( \\
           ((capacity)+1)*2 \\
           + @{[ $self->macro_table_buckets('capacity') ]} \\
         ))
      C
   });
   "$name($capacity_expr)"
}

#sub node_type($self, $word_idx) {
#   my $bits= ((8 << $word_idx)-1);
#   my $struct= $self->namespace . '_rbnode_' . $bits;
#   $self->generate_once($self->private_type, "${struct}_t", sub { <<~C });
#      typedef struct $struct {
#         @{[ $self->word_types->[$word_idx] }
#            left  :$bits, is_red: 1,
#            right;
#      } ${struct}_t;
#      C
#   $struct.'_t'
#}

sub find_fn($self) {
   my $name= $self->namespace . '_find';
   $self->generate_once($self->private_impl, $name, sub {
      my $elemdata_t= $self->elemdata_type;
      my $key_t= $self->key_type;
      push $self->public_decl->@* , <<~C;
         size_t $name(void *hashtree, size_t capacity, $elemdata_t elemdata, $key_t search_key);
         C
      my $code= <<~C;
         // Look up the search_key in the hashtable, walk the tree of conflicts, and
         // return the element index which matched.
         size_t $name(void *hashtree, size_t capacity, $elemdata_t elemdata, $key_t search_key) {
            size_t n_buckets= @{[ $self->macro_table_buckets('capacity') ]}, node;
            size_t el_hashcode, key_hashcode= @{[ $self->macro_key_hashcode('search_key') ]};
            int cmp;
         C
      for (0..$self->max_word_idx) {
         my $word_t= $self->word_types->[$_];
         my $word_max= $self->word_max_capacity->[$_];
         $code .= <<~C
            if (capacity <= @{[ sprintf("0x%X", $word_max) ]}) {
               $word_t *bucket= (($word_t *)hashtree) + (1 + capacity + key_hashcode % n_buckets);
               if ((node= *bucket)) {
                  do {
                     el_hashcode= @{[ $self->macro_elem_hashcode('elemdata', 'node') ]};
                     cmp= (key_hashcode == el_hashcode)? (@{[ $self->macro_cmp_key_elem('search_key', 'elemdata', 'node') ]})
                        : key_hashcode < el_hashcode? -1 : 1;
                     if (!cmp) return node;
                     node= (($word_t *)hashtree)[ node*2 + (cmp < 0)? 0 : 1 ] >> 1;
                  } while (node);
               }
               return node;
            }
         C
      }
      $code .= <<~C
            return 0;
         }
         C
   });
}

sub reindex_fn($self) {
   my $name= $self->namespace . '_reindex';
   $self->generate_once($self->private_impl, $name, sub {
      my $elemdata_t= $self->elemdata_type;
      push $self->public_decl->@* , <<~C;
         bool $name(void *hashtree, size_t capacity, $elemdata_t elemdata, size_t el_i, size_t last_i);
         C
      my $code= <<~C;
         bool $name(void *hashtree, size_t capacity, $elemdata_t elemdata, size_t el_i, size_t last_i) {
            size_t n_buckets= @{[ $self->macro_table_buckets('capacity') ]}, node;
            size_t el_hashcode, new_hashcode, pos;
            IV cmp;
         C
      for (0..$self->max_word_idx) {
         my $word_t= $self->word_types->[$_];
         my $word_max= $self->word_max_capacity->[$_];
         my $max_tree_height= $self->word_max_tree_height->[$_];
         my $balance_fn= $self->balance_fn($_);
         $code .= <<~C
            if (capacity <= @{[ sprintf("0x%X", $word_max) ]}) {
               $word_t *bucket, *parent_ptr, parents[1+$max_tree_height];
               for (; el_i <= last_i; el_i++) {
                  new_hashcode= @{[ $self->macro_elem_hashcode('elemdata', 'el_i') ]};
                  bucket= (($word_t *)hashtree) + (1 + capacity + new_hashcode % n_buckets);
                  if (!(node= *bucket))
                     *bucket= el_i;
                  else {
                     // red/black insert
                     parents[0]= 0; // mark end of list
                     pos= 0;
                     assert(node < el_i);
                     do {
                        parents[++pos]= node;
                        el_hashcode= @{[ $self->macro_elem_hashcode('elemdata', 'node') ]};
                        cmp= new_hashcode == el_hashcode? (@{[ $self->macro_cmp_elem_elem('elemdata', 'el_i', 'node') ]})
                           : new_hashcode < el_hashcode? -1 : 1;
                        parent_ptr= &(($word_t *)hashtree)[ node*2 + (cmp < 0)? 0 : 1 ];
                        node= *parent_ptr >> 1;
                     } while (node && pos < $max_tree_height);
                     if (pos > $max_tree_height) {
                        assert(pos <= $max_tree_height);
                        return false; // fatal error, should never happen unless datastruct corrupt
                     }
                     // Set left or right pointer of node to new node
                     *parent_ptr |= el_i << 1;
                     // Set color of new node to red. other fields should be initialized to zero already
                     // Note that this is never the root of the tree because that happens automatically
                     // above when *bucket= el_i and node[el_i] is assumed to be zeroed (black) already.
                     (($word_t *)hashtree)[ el_i*2 ]= 1;
                     if (pos > 1) { // no need to balance unless more than 1 parent
                        $balance_fn(($word_t *)hashtree, parents+pos);
                        *bucket= parents[1]; // may have changed after tree balance
                        // tree root is always black
                        (($word_t *)hashtree)[ parents[1]*2 ]= (($word_t *)hashtree)[ parents[1]*2 ] >> 1 << 1; 
                     }
                  }
               }
               return true;
            }
         C
      }
      $code .= <<~C;
            return false; // happens if capacity is out of bounds
         }
         C
   });
}

sub balance_fn($self, $word_idx) {
   my $bits= ((8 << $word_idx)-1);
   my $word_t= $self->word_types->[$word_idx];
   my $name= $self->common_namespace . "_rb_balance_$bits";
   $self->generate_once($self->private_impl, $name, sub {
      $self->generate_once($self->private_impl, 'HASHTREE_LEFT', sub { <<~C });
         #define HASHTREE_LEFT(n)        (hashtree[(n)*2] >> 1)
         #define HASHTREE_RIGHT(n)       (hashtree[(n)*2+1] >> 1)
         #define HASHTREE_IS_RED(n)      (hashtree[(n)*2] & 1)
         #define HASHTREE_SET_LEFT(n,v)  (hashtree[(n)*2]= (hashtree[(n)*2] & 1) | ((v)<<1))
         #define HASHTREE_SET_RIGHT(n,v) (hashtree[(n)*2]= ((v)<<1))
         #define HASHTREE_SET_RED(n)     (hashtree[(n)*2] |= 1)
         #define HASHTREE_SET_BLACK(n)   (hashtree[(n)*2]= hashtree[(n)*2] >> 1 << 1)
         C
      push $self->private_decl->@* , <<~C;
         static void $name($word_t *hashtree, $word_t *parents);
         C
      
      <<~C
      // balance a tree from parents[0] upward.  (parents is terminated by a 0 value)
      // nodes is the full array of tree nodes.
      static void $name($word_t *hashtree, $word_t *parents) {
         $word_t pos= *parents--, newpos, parent;
         // if current is a black node, no rotations needed
         while (pos && HASHTREE_IS_RED(pos)) {
            if (!(parent= *parents))
               break;
            // current is red, the imbalanced child is red, and parent is black.
            // if the current is on the left of the parent, the parent is to the right
            if (HASHTREE_LEFT(parent) == pos) {
               // if the sibling is also red, we can pull down the color black from the parent
               if (HASHTREE_IS_RED(HASHTREE_RIGHT(parent))) {
                  HASHTREE_SET_BLACK(HASHTREE_RIGHT(parent));
                  HASHTREE_SET_BLACK(pos);
                  HASHTREE_SET_RED(parent);
               }
               else {
                  // if the imbalance (red node) is on the right, and the parent is on the right,
                  //  need to rotate those lower nodes over to the left.
                  if (HASHTREE_IS_RED(HASHTREE_RIGHT(pos))) {
                     // rotate pos left so parent's left now points to pos.right
                     newpos= HASHTREE_RIGHT(pos);
                     HASHTREE_SET_RIGHT(pos, HASHTREE_LEFT(newpos));
                     HASHTREE_SET_LEFT(newpos, pos);
                     pos= newpos;
                     // parent.left has not been updated here
                  }
                  // Now we can do our right rotation to balance the tree.
                  HASHTREE_SET_LEFT(parent, HASHTREE_RIGHT(pos));
                  HASHTREE_SET_RED(parent);
                  HASHTREE_SET_RIGHT(pos, parent);
                  HASHTREE_SET_BLACK(pos);
                  // if the parent was the root of the tree, update the stack
                  // else update the grandparent to point to new parent.
                  if (!parents[-1])
                     *parents= pos;
                  else if (HASHTREE_LEFT(parents[-1]) == parent)
                     HASHTREE_SET_LEFT(parents[-1], pos);
                  else
                     HASHTREE_SET_RIGHT(parents[-1], pos);
                  break;
               }
            }
            // else the parent is to the left.  Repeat mirror of code above
            else {
               // if the sibling is also red, we can pull down the color black from the parent
               if (HASHTREE_IS_RED(HASHTREE_LEFT(parent))) {
                  HASHTREE_SET_BLACK(HASHTREE_LEFT(parent));
                  HASHTREE_SET_BLACK(pos);
                  HASHTREE_SET_RED(parent);
               }
               else {
                  // if the imbalance (red node) is on the left, and the parent is on the left,
                  //  need to rotate those lower nodes over to the right.
                  if (HASHTREE_IS_RED(HASHTREE_LEFT(pos))) {
                     // rotate pos right so parent's right now points to pos.left
                     newpos= HASHTREE_LEFT(pos);
                     HASHTREE_SET_LEFT(pos, HASHTREE_RIGHT(newpos));
                     HASHTREE_SET_RIGHT(newpos, pos);
                     pos= newpos;
                     // parent.right has not been updated here
                  }
                  // Now we can do our left rotation to balance the tree.
                  HASHTREE_SET_RIGHT(parent, HASHTREE_LEFT(pos));
                  HASHTREE_SET_RED(parent);
                  HASHTREE_SET_LEFT(pos, parent);
                  HASHTREE_SET_BLACK(pos);
                  // if the parent was the root of the tree, update the stack
                  // else update the grandparent to point to new parent.
                  if (!parents[-1])
                     *parents= pos;
                  else if (HASHTREE_LEFT(parents[-1]) == parent)
                     HASHTREE_SET_LEFT(parents[-1], pos);
                  else
                     HASHTREE_SET_RIGHT(parents[-1], pos);
                  break;
               }
            }
            // jump twice up the tree. if current reaches the Sentinel (black node, id=0), we're done
            parents--;
            pos= *parents--;
         }
      }
      C
   });
}

sub structcheck_fn($self) {
   my $name= $self->namespace . "_structcheck";
   $self->generate_once($self->private_impl, $name, sub {
      my $elemdata_t= $self->elemdata_type;
      push $self->public_decl->@* , <<~C;
         bool $name(pTHX_ void* hashtree, size_t capacity, $elemdata_t elemdata, size_t max_el);
         C
      my $code= <<~C;
         // Verify that every filled bucket refers to a valid tree,
         // and that every element can be found.
         bool $name(pTHX_ void* hashtree, size_t capacity, $elemdata_t elemdata, size_t max_el) {
         C

      for (0..$self->max_word_idx) {
         my $bits= ((8 << $_)-1);
         my $word_t= $self->word_types->[$_];
         my $word_max= $self->word_max_capacity->[$_];
         my $max_tree_height= $self->word_max_tree_height->[$_];
         my $treecheck= $self->common_namespace.'_treecheck_'.$bits;
         $self->generate_once($self->private_impl, $treecheck, sub { <<~C });
         // Gets called recursively to verify the Red/Black properties of the subtree at 'idx'
         // Returns the number of black nodes in the current subtree, or -1 if there was an error.
         static int $treecheck($word_t *hashtree, size_t max_node, size_t node, int *blackcount_out) {
            $word_t subtree;
            int i, depth[2]= { 0, 0 }, blackcount[2]= { 0, 0 };
            for (i=0; i < 2; i++) {
               if ((subtree= (hashtree[node*2 + i]>>1))) {
                  if (subtree > max_node) // out of bounds?
                     return -1;
                  if (HASHTREE_IS_RED(node) && HASHTREE_IS_RED(subtree)) // two adjacent reds?
                     return -1;
                  depth[i]= $treecheck(hashtree, max_node, subtree, blackcount+i);
                  if (depth[i] < 0) return -1;
               }
            }
            if (blackcount[0] != blackcount[1])
               return -1;
            *blackcount_out= blackcount[0] + (HASHTREE_IS_RED(node) ^ 1);
            return 1 + (depth[0] > depth[1]? depth[0] : depth[1]);
         }
         C
         
         my $name_with_bitsuffix= $name.'_'.$bits;
         push $self->private_impl->@* , <<~C;
         // Verify that every filled bucket refers to a valid tree,
         // and that every node can be found.
         static bool $name_with_bitsuffix(pTHX_ $word_t *hashtree, size_t capacity, $elemdata_t elemdata, size_t max_el) {
            size_t n_buckets= @{[ $self->macro_table_buckets('capacity') ]}, node;
            size_t el_hashcode, i_hashcode;
            int cmp, i, depth, blackcount;
            $word_t *bucket, *table= hashtree + 1 + capacity;
            bool success= true;
            for (bucket= table + n_buckets - 1; bucket >= table; bucket--) {
               if (*bucket > max_el) {
                  warn("Bucket %ld refers to element %ld which is greater than max_el %ld", (long)(bucket-table), (long)*bucket, (long)max_el);
                  success= false;
               } else if (*bucket) {
                  if (HASHTREE_IS_RED(*bucket)) {
                     warn("Tree at node %ld has red root", (long) *bucket);
                     success= false;
                  }
                  depth= $treecheck(hashtree, max_el, *bucket, &blackcount);
                  if (depth < 0) {
                     warn("Tree at node %ld is corrupt", (long) *bucket);
                     success= false;
                  } else if (depth > $max_tree_height) {
                     warn("Tree at node %ld exceeds maximum height (%ld > %ld)", (long) *bucket, (long) depth, (long) $max_tree_height);
                     success= false;
                  }
               }
            }
            // Check properties of sentinel node
            if (HASHTREE_LEFT(0) || HASHTREE_RIGHT(0)) {
               warn("Sentinel node has sub-trees");
               success= false;
            }
            if (HASHTREE_IS_RED(0)) {
               warn("Sentinel node is red");
               success= false;
            }
            // Second pass, check that every element can be found in the table.
            // But don't try iterating a broken tree.
            if (success)
               for (i= 1; i <= max_el; i++) {
                  i_hashcode= @{[ $self->macro_elem_hashcode('elemdata', 'i') ]};
                  bucket= table + i_hashcode % n_buckets;
                  node= *bucket;
                  while (node && node != i) {
                     el_hashcode= @{[ $self->macro_elem_hashcode('elemdata','node') ]};
                     cmp= i_hashcode == el_hashcode? (@{[ $self->macro_cmp_elem_elem('elemdata', 'i', 'node') ]})
                        : i_hashcode < el_hashcode? -1 : 1;
                     if (!cmp) {
                        warn("Element %ld compares equal with element %ld", (long) i, (long) node);
                        success= false;
                        break;
                     }
                     else if (cmp < 0)
                        node= HASHTREE_LEFT(node);
                     else
                        node= HASHTREE_RIGHT(node);
                  }
                  if (!node) {
                     warn("Element %ld not found in hash table", (long)i);
                     success= false;
                  }
               }
            return success;
         }
         C
         $code .= <<~C
            if (capacity < @{[ sprintf("0x%X", $word_max) ]})
               return $name_with_bitsuffix(aTHX_ ($word_t*)hashtree, capacity, elemdata, max_el);
         C
      }
      $code .= <<~C
            return false;
         }
         C
   });
}

1;
