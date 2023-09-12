package RBHash;
use v5.36;
use Carp;
use Scalar::Util 'looks_like_number';
use parent "CGenerator";

=head1 DESCRIPTION

A RBHash is a data structure that provides fast lookup from a key to the numbers 1..N.
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

  $code= $rbhash->macro_elem_hashcode($elemdata_expr, $index_expr); # size_t
  
  # Example:
  $rbhash->override(
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

  $code= $rbhash->macro_key_hashcode($key_expr); # size_t
  
  # Example:
  $rbhash->override(
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

  $code= $rbhash->macro_cmp_key_elem($key_expr, $elemdata_expr, $index_expr);
  
  # Example
  $rbhash->override(
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

  $code= $rbhash->macro_cmp_elem_elem($elemdata_expr, $idx1_expr, $idx2_expr);
  
  # Example:
  $rbhash->override(
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

This defaults to L</namespace>, but can be overridden to share generic rbhash functions
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
The rbhash automatically chooses a word size based on the C<capacity>.

=head2 max_capacity

The upper limit of what the rbhash should support.  For example, on 32-bit systems
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

sub macro_rbhash_size($self, $capacity_expr) {
   my $name= uc($self->common_namespace . '_SIZE');
   $self->generate_once($self->public_decl, $name, sub {
      <<~C
      // Size of rbhash structure, not including element array that it is appended to
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
         size_t $name(void *rbhash, size_t capacity, $elemdata_t elemdata, $key_t search_key);
         C
      my $code= <<~C;
         // Look up the search_key in the hashtable, walk the tree of conflicts, and
         // return the element index which matched.
         size_t $name(void *rbhash, size_t capacity, $elemdata_t elemdata, $key_t search_key) {
            size_t n_buckets= @{[ $self->macro_table_buckets('capacity') ]};
            size_t el_hashcode, key_hashcode;
            int cmp;
            if (!n_buckets) return 0;
            key_hashcode= @{[ $self->macro_key_hashcode('search_key') ]};
         C
      for (0..$self->max_word_idx) {
         my $word_t= $self->word_types->[$_];
         my $word_max= $self->word_max_capacity->[$_];
         $code .= <<~C
            @{[ $_? 'else ':'' ]} if (capacity <= @{[ sprintf("0x%X", $word_max) ]}) {
               $word_t node, *bucket= (($word_t *)rbhash) + (1 + capacity)*2 + (key_hashcode % n_buckets);
               if ((node= *bucket)) {
                  do {
                     el_hashcode= @{[ $self->macro_elem_hashcode('elemdata', 'node') ]};
                     cmp= (key_hashcode == el_hashcode)? (@{[ $self->macro_cmp_key_elem('search_key', 'elemdata', 'node') ]})
                        : key_hashcode < el_hashcode? -1 : 1;
                     if (!cmp) return node;
                     node= (($word_t *)rbhash)[ node*2 + (cmp < 0? 0 : 1) ] >> 1;
                  } while (node);
               }
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
         bool $name(void *rbhash, size_t capacity, $elemdata_t elemdata, size_t el_i, size_t last_i);
         C
      my $code= <<~C;
         bool $name(void *rbhash, size_t capacity, $elemdata_t elemdata, size_t el_i, size_t last_i) {
            size_t n_buckets= @{[ $self->macro_table_buckets('capacity') ]};
            size_t el_hashcode, new_hashcode, pos;
            IV cmp;
            if (el_i < 1 || last_i > capacity || !n_buckets)
               return false;
         C
      for (0..$self->max_word_idx) {
         my $word_t= $self->word_types->[$_];
         my $word_max= $self->word_max_capacity->[$_];
         my $max_tree_height= $self->word_max_tree_height->[$_];
         my $balance_fn= $self->balance_fn($_);
         my $treecheck= $self->treecheck_fn($_);
         my $treeprint= $self->treeprint_fn($_);
         $code .= <<~C
            if (capacity <= @{[ sprintf("0x%X", $word_max) ]}) {
               $word_t *bucket, node, tree_ref, parents[1+$max_tree_height], err_node;
               const char *err_msg;
               for (; el_i <= last_i; el_i++) {
                  new_hashcode= @{[ $self->macro_elem_hashcode('elemdata', 'el_i') ]};
                  bucket= (($word_t *)rbhash) + (1 + capacity)*2 + new_hashcode % n_buckets;
                  if (!(node= *bucket))
                     *bucket= el_i;
                  else {
                     // red/black insert
                     pos= 0;
                     assert(node < el_i);
                     do {
                        parents[++pos]= node;
                        el_hashcode= @{[ $self->macro_elem_hashcode('elemdata', 'node') ]};
                        cmp= new_hashcode == el_hashcode? (@{[ $self->macro_cmp_elem_elem('elemdata', 'el_i', 'node') ]})
                           : new_hashcode < el_hashcode? -1 : 1;
                        tree_ref= node*2 + (cmp < 0? 0 : 1);
                        node= (($word_t *)rbhash)[tree_ref] >> 1;
                     } while (node && pos < $max_tree_height);
                     if (pos > $max_tree_height) {
                        assert(pos <= $max_tree_height);
                        return false; // fatal error, should never happen unless datastruct corrupt
                     }
                     // Set left or right pointer of node to new node
                     (($word_t *)rbhash)[tree_ref] |= el_i << 1;
                     // Set color of new node to red. other fields should be initialized to zero already
                     // Note that this is never the root of the tree because that happens automatically
                     // above when *bucket= el_i and node[el_i] is assumed to be zeroed (black) already.
                     (($word_t *)rbhash)[ el_i*2 ]= 1;
                     if (pos > 1) { // no need to balance unless more than 1 parent
                        parents[0]= 0; // mark end of list
                        $balance_fn(($word_t *)rbhash, parents+pos);
                        *bucket= parents[1]; // may have changed after tree balance
                        // tree root is always black
                        (($word_t *)rbhash)[ parents[1]*2 ]= (($word_t *)rbhash)[ parents[1]*2 ] >> 1 << 1; 
                     }
                  }
                  if (!$treecheck(rbhash, el_i, *bucket, 0,
                     NULL, NULL, &err_msg, &err_node
                  )) {
                     $treeprint(rbhash, capacity, *bucket, err_node, stderr);
                     warn("Tree rooted at %ld is corrupt, %s at node %d", (long) *bucket, err_msg, (long) err_node);
                     return false;
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
      $self->generate_once($self->private_impl, 'RBHASH_LEFT', sub { <<~C });
         #define RBHASH_LEFT(n)        (rbhash[(n)*2] >> 1)
         #define RBHASH_RIGHT(n)       (rbhash[(n)*2+1] >> 1)
         #define RBHASH_IS_RED(n)      (rbhash[(n)*2] & 1)
         #define RBHASH_SET_LEFT(n,v)  (rbhash[(n)*2]= (rbhash[(n)*2] & 1) | ((v)<<1))
         #define RBHASH_SET_RIGHT(n,v) (rbhash[(n)*2+1]= ((v)<<1))
         #define RBHASH_SET_RED(n)     (rbhash[(n)*2] |= 1)
         #define RBHASH_SET_BLACK(n)   (rbhash[(n)*2]= rbhash[(n)*2] >> 1 << 1)
         C
      push $self->private_decl->@* , <<~C;
         static void $name($word_t *rbhash, $word_t *parents);
         C
      
      <<~C
      // balance a tree from parents[0] upward.  (parents is terminated by a 0 value)
      // nodes is the full array of tree nodes.
      static void $name($word_t *rbhash, $word_t *parents) {
         $word_t pos= *parents--, newpos, parent;
         // if current is a black node, no rotations needed
         while (pos && RBHASH_IS_RED(pos)) {
            if (!(parent= *parents))
               break;
            // current is red, the imbalanced child is red, and parent is black.
            // if the current is on the left of the parent, the parent is to the right
            if (RBHASH_LEFT(parent) == pos) {
               // if the sibling is also red, we can pull down the color black from the parent
               if (RBHASH_IS_RED(RBHASH_RIGHT(parent))) {
                  RBHASH_SET_BLACK(RBHASH_RIGHT(parent));
                  RBHASH_SET_BLACK(pos);
                  RBHASH_SET_RED(parent);
               }
               else {
                  // if the imbalance (red node) is on the right, and the parent is on the right,
                  //  need to rotate those lower nodes over to the left.
                  if (RBHASH_IS_RED(RBHASH_RIGHT(pos))) {
                     // rotate pos left so parent's left now points to pos.right
                     newpos= RBHASH_RIGHT(pos);
                     RBHASH_SET_RIGHT(pos, RBHASH_LEFT(newpos));
                     RBHASH_SET_LEFT(newpos, pos);
                     pos= newpos;
                     // parent.left has not been updated here
                  }
                  // Now we can do our right rotation to balance the tree.
                  RBHASH_SET_LEFT(parent, RBHASH_RIGHT(pos));
                  RBHASH_SET_RED(parent);
                  RBHASH_SET_RIGHT(pos, parent);
                  RBHASH_SET_BLACK(pos);
                  // if the parent was the root of the tree, update the stack
                  // else update the grandparent to point to new parent.
                  if (!parents[-1])
                     *parents= pos;
                  else if (RBHASH_LEFT(parents[-1]) == parent)
                     RBHASH_SET_LEFT(parents[-1], pos);
                  else
                     RBHASH_SET_RIGHT(parents[-1], pos);
                  break;
               }
            }
            // else the parent is to the left.  Repeat mirror of code above
            else {
               // if the sibling is also red, we can pull down the color black from the parent
               if (RBHASH_IS_RED(RBHASH_LEFT(parent))) {
                  RBHASH_SET_BLACK(RBHASH_LEFT(parent));
                  RBHASH_SET_BLACK(pos);
                  RBHASH_SET_RED(parent);
               }
               else {
                  // if the imbalance (red node) is on the left, and the parent is on the left,
                  //  need to rotate those lower nodes over to the right.
                  if (RBHASH_IS_RED(RBHASH_LEFT(pos))) {
                     // rotate pos right so parent's right now points to pos.left
                     newpos= RBHASH_LEFT(pos);
                     RBHASH_SET_LEFT(pos, RBHASH_RIGHT(newpos));
                     RBHASH_SET_RIGHT(newpos, pos);
                     pos= newpos;
                     // parent.right has not been updated here
                  }
                  // Now we can do our left rotation to balance the tree.
                  RBHASH_SET_RIGHT(parent, RBHASH_LEFT(pos));
                  RBHASH_SET_RED(parent);
                  RBHASH_SET_LEFT(pos, parent);
                  RBHASH_SET_BLACK(pos);
                  // if the parent was the root of the tree, update the stack
                  // else update the grandparent to point to new parent.
                  if (!parents[-1])
                     *parents= pos;
                  else if (RBHASH_LEFT(parents[-1]) == parent)
                     RBHASH_SET_LEFT(parents[-1], pos);
                  else
                     RBHASH_SET_RIGHT(parents[-1], pos);
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

sub treecheck_fn($self, $word_idx) {
   my $bits= ((8 << $word_idx)-1);
   my $name= $self->common_namespace.'_treecheck_'.$bits;
   $self->generate_once($self->private_impl, $name, sub {
      my $word_t= $self->word_types->[$word_idx];
      my $word_max= $self->word_max_capacity->[$word_idx];
      my $max_tree_height= $self->word_max_tree_height->[$word_idx];
      <<~C
      // Gets called recursively to verify the Red/Black properties of the subtree at 'node'
      // Returns a message describing what was wrong, or NULL on success.
      static bool $name($word_t *rbhash, $word_t max_node, $word_t node, int depth,
         int *depth_out, int *blackcount_out,
         const char **err_out, $word_t *err_node_out
      ) {
         $word_t subtree;
         const char *err= NULL;
         int i, blackcount[2]= { 0, 0 };
         if (depth == 0 && RBHASH_IS_RED(node)) {
            if (err_out) *err_out= "root node is red";
            if (err_node_out) *err_node_out= node;
            return false;
         }
         ++depth;
         if (depth > $max_tree_height) {
            if (err_out) *err_out= "mex depth exceeded";
            if (err_node_out) *err_node_out= node;
            return false;
         }
         if (depth_out && depth > *depth_out)
            *depth_out= depth;
         for (i=0; i < 2 && !err; i++) {
            subtree= i? RBHASH_RIGHT(node) : RBHASH_LEFT(node);
            if (subtree) {
               if (subtree > max_node) { // out of bounds?
                  if (err_out) *err_out= "node pointer out of bounds";
                  if (err_node_out) *err_node_out= node;
                  return false;
               }
               else if (RBHASH_IS_RED(node) && RBHASH_IS_RED(subtree)) { // two adjacent reds?
                  if (err_out) *err_out= "adjacent red nodes";
                  if (err_node_out) *err_node_out= node;
                  return false;
               }
               else if (!$name(rbhash, max_node, subtree, depth,
                  depth_out, blackcount+i, err_out, err_node_out))
                  return false;
            }
         }
         if (blackcount[0] != blackcount[1]) {
            if (err_out) *err_out= "subtree black node mismatch";
            if (err_node_out) *err_node_out= node;
            return false;
         }
         if (blackcount_out)
            *blackcount_out= blackcount[0] + (RBHASH_IS_RED(node) ^ 1);
         return true;
      }
      C
   });
}

sub treeprint_fn($self, $word_idx) {
   my $bits= ((8 << $word_idx)-1);
   my $name= $self->common_namespace.'_treeprint_'.$bits;
   $self->generate_once($self->private_impl, $name, sub {
      my $word_t= $self->word_types->[$word_idx];
      my $word_max= $self->word_max_capacity->[$word_idx];
      my $max_tree_height= $self->word_max_tree_height->[$word_idx];
      <<~C
      static size_t $name($word_t *rbhash, $word_t max_node, $word_t node, $word_t mark_node, FILE * out) {
         $word_t node_path[ 1+$max_tree_height ];
         bool cycle;
         int i, pos, step= 0;
         size_t nodecount= 0;
         if (!node) {
            fprintf(out, "(empty tree)\\n");
            return 0;
         }
         node_path[0]= 0;
         node_path[pos= 1]= node << 1;
         while (node && pos) {
            switch (step) {
            case 0:
               // Check for cycles
               cycle= false;
               for (i= 1; i < pos; i++)
                  if ((node_path[i]>>1) == (node_path[pos]>>1))
                     cycle= true;
               
               // Proceed down right subtree if possible
               if (!cycle && pos < $max_tree_height && node <= max_node && RBHASH_RIGHT(node)) {
                  node= RBHASH_RIGHT(node);
                  node_path[++pos]= node << 1;
                  continue;
               }
            case 1:
               // Print tree branches for nodes up until this one
               for (i= 2; i < pos; i++)
                  fprintf(out, (node_path[i]&1) == (node_path[i+1]&1)? "    " : "   |");
               if (pos > 1)
                  fprintf(out, (node_path[pos]&1)? "   \`" : "   ,");
               
               // Print content of this node
               fprintf(out, "--%c%c%c %ld %ld%s\\n",
                  (node == mark_node? '(' : '-'),
                  (node > max_node? '!' : RBHASH_IS_RED(node)? 'R':'B'),
                  (node == mark_node? ')' : ' '),
                  (long) node, (long)sizeof(node),
                  cycle? " CYCLE DETECTED"
                     : pos >= $max_tree_height? " MAX DEPTH EXCEEDED"
                     : node > max_node? " VALUE OUT OF BOUNDS"
                     : ""
               );
               ++nodecount;
               
               // Proceed down left subtree if possible
               if (!cycle && pos < $max_tree_height && node <= max_node && RBHASH_LEFT(node)) {
                  node= RBHASH_LEFT(node);
                  node_path[++pos]= (node << 1) | 1;
                  step= 0;
                  continue;
               }
            case 2:
               // Return to parent
               step= (node_path[pos]&1) + 1;
               node= node_path[--pos] >> 1;
               cycle= false;
            }
         }
         return nodecount;
      }
      C
   });
}

sub print_fn($self) {
   my $name= $self->common_namespace . '_print';
   $self->generate_once($self->private_impl, $name, sub {
      push $self->public_decl->@* , <<~C;
      void $name(void *rbhash, size_t capacity, FILE *out);
      C
      my $code= <<~C;
      void $name(void *rbhash, size_t capacity, FILE *out) {
         size_t n_buckets= @{[ $self->macro_table_buckets('capacity') ]}, node, used= 0, collision= 0;
         fprintf(out, "# rbhash for %ld elements, %ld hash buckets\\n", (long) capacity, (long) n_buckets);
      C
      for (0..$self->max_word_idx) {
         my $bits= ((8 << $_)-1);
         my $word_t= $self->word_types->[$_];
         my $word_max= $self->word_max_capacity->[$_];
         my $treeprint= $self->treeprint_fn($_);
         $code .= <<~C
         @{[ $_? "else ":"" ]}if (capacity <= @{[ sprintf("0x%X", $word_max) ]} ) {
            $word_t *nodes= ($word_t*) rbhash;
            $word_t *table= nodes + (1 + capacity)*2;
            int i;
            for (i= 0; i < n_buckets; i++) {
               if (i && (i & 0xF) == 0)
                  fprintf(out, "# bucket 0x%lx\\n", i);
               if (table[i]) {
                  ++used;
                  collision += $treeprint(rbhash, capacity, table[i], 0, out) - 1;
               } else
                  fprintf(out, "-\\n");
            }
         }
      C
      }
      $code .= <<~C
         fprintf(out, "# used %ld / %ld buckets, %ld collisions\\n", (long) used, (long) n_buckets, (long) collision);
      }
      C
   });
}

sub structcheck_fn($self) {
   my $name= $self->namespace . "_structcheck";
   $self->generate_once($self->private_impl, $name, sub {
      my $elemdata_t= $self->elemdata_type;
      push $self->public_decl->@* , <<~C;
         bool $name(pTHX_ void* rbhash, size_t capacity, $elemdata_t elemdata, size_t max_el);
         C
      my $code= <<~C;
         // Verify that every filled bucket refers to a valid tree,
         // and that every element can be found.
         bool $name(pTHX_ void* rbhash, size_t capacity, $elemdata_t elemdata, size_t max_el) {
         C

      for (0..$self->max_word_idx) {
         my $bits= ((8 << $_)-1);
         my $word_t= $self->word_types->[$_];
         my $word_max= $self->word_max_capacity->[$_];
         my $max_tree_height= $self->word_max_tree_height->[$_];
         my $treecheck= $self->treecheck_fn($_);
         my $treeprint= $self->treeprint_fn($_);
         my $name_with_bitsuffix= $name.'_'.$bits;
         push $self->private_impl->@* , <<~C;
         // Verify that every filled bucket refers to a valid tree,
         // and that every node can be found.
         static bool $name_with_bitsuffix(pTHX_ $word_t *rbhash, size_t capacity, $elemdata_t elemdata, size_t max_el) {
            size_t n_buckets= @{[ $self->macro_table_buckets('capacity') ]}, node;
            size_t el_hashcode, i_hashcode;
            int cmp, i, depth, blackcount;
            const char *err_msg;
            $word_t *bucket, *table= rbhash + (1 + capacity)*2, err_node;
            bool success= true;
            for (bucket= table + n_buckets - 1; bucket >= table; bucket--) {
               if (*bucket > max_el) {
                  warn("Bucket %ld refers to element %ld which is greater than max_el %ld", (long)(bucket-table), (long)*bucket, (long)max_el);
                  success= false;
               } else if (*bucket) {
                  if (!$treecheck(rbhash, max_el, *bucket, 0,
                     NULL, &blackcount, &err_msg, &err_node
                  )) {
                     $treeprint(rbhash, max_el, *bucket, err_node, stderr);
                     warn("Tree rooted at %ld is corrupt, %s at node %d", (long) *bucket, err_msg, (long) err_node);
                     success= false;
                  }
               }
            }
            // Check properties of sentinel node
            if (RBHASH_LEFT(0) || RBHASH_RIGHT(0)) {
               warn("Sentinel node has sub-trees");
               success= false;
            }
            if (RBHASH_IS_RED(0)) {
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
                     else node= (cmp < 0? RBHASH_LEFT(node) : RBHASH_RIGHT(node));
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
            if (capacity <= @{[ sprintf("0x%X", $word_max) ]})
               return $name_with_bitsuffix(aTHX_ ($word_t*)rbhash, capacity, elemdata, max_el);
         C
      }
      $code .= <<~C
            return false;
         }
         C
   });
}

1;
