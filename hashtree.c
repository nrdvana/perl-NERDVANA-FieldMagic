/* BEGIN GENERATED NF_HASHTREE IMPLEMENTATION */
static void nf_hashtree_rb_balance_7(uint8_t *hashtree, uint8_t *parents);

static void nf_hashtree_rb_balance_15(uint16_t *hashtree, uint16_t *parents);

static void nf_hashtree_rb_balance_31(uint32_t *hashtree, uint32_t *parents);

// Look up the search_key in the hashtable, walk the tree of conflicts, and
// return the element index which matched.
size_t nf_fieldset_find(void *hashtree, size_t capacity, nf_fieldinfo_t ** elemdata, nf_fieldinfo_key_t * search_key) {
   size_t n_buckets= NF_HASHTREE_TABLE_BUCKETS(capacity), node;
   size_t el_hashcode, key_hashcode= ( (search_key)->name_hashcode );
   int cmp;
   if (capacity <= 0x7F) {
      uint8_t *bucket= ((uint8_t *)hashtree) + (1 + capacity + key_hashcode % n_buckets);
      if ((node= *bucket)) {
         do {
            el_hashcode= ( (elemdata)[(node)-1]->name_hashcode );
            cmp= (key_hashcode == el_hashcode)? (( sv_cmp((search_key)->name, (elemdata)[(node)-1]->name) ))
               : key_hashcode < el_hashcode? -1 : 1;
            if (!cmp) return node;
            node= ((uint8_t *)hashtree)[ node*2 + (cmp < 0)? 0 : 1 ] >> 1;
         } while (node);
      }
      return node;
   }
   if (capacity <= 0x7FFF) {
      uint16_t *bucket= ((uint16_t *)hashtree) + (1 + capacity + key_hashcode % n_buckets);
      if ((node= *bucket)) {
         do {
            el_hashcode= ( (elemdata)[(node)-1]->name_hashcode );
            cmp= (key_hashcode == el_hashcode)? (( sv_cmp((search_key)->name, (elemdata)[(node)-1]->name) ))
               : key_hashcode < el_hashcode? -1 : 1;
            if (!cmp) return node;
            node= ((uint16_t *)hashtree)[ node*2 + (cmp < 0)? 0 : 1 ] >> 1;
         } while (node);
      }
      return node;
   }
   if (capacity <= 0x7FFFFFFF) {
      uint32_t *bucket= ((uint32_t *)hashtree) + (1 + capacity + key_hashcode % n_buckets);
      if ((node= *bucket)) {
         do {
            el_hashcode= ( (elemdata)[(node)-1]->name_hashcode );
            cmp= (key_hashcode == el_hashcode)? (( sv_cmp((search_key)->name, (elemdata)[(node)-1]->name) ))
               : key_hashcode < el_hashcode? -1 : 1;
            if (!cmp) return node;
            node= ((uint32_t *)hashtree)[ node*2 + (cmp < 0)? 0 : 1 ] >> 1;
         } while (node);
      }
      return node;
   }
   return 0;
}

#define HASHTREE_LEFT(n)        (hashtree[(n)*2] >> 1)
#define HASHTREE_RIGHT(n)       (hashtree[(n)*2+1] >> 1)
#define HASHTREE_IS_RED(n)      (hashtree[(n)*2] & 1)
#define HASHTREE_SET_LEFT(n,v)  (hashtree[(n)*2]= (hashtree[(n)*2] & 1) | ((v)<<1))
#define HASHTREE_SET_RIGHT(n,v) (hashtree[(n)*2]= ((v)<<1))
#define HASHTREE_SET_RED(n)     (hashtree[(n)*2] |= 1)
#define HASHTREE_SET_BLACK(n)   (hashtree[(n)*2]= hashtree[(n)*2] >> 1 << 1)

// balance a tree from parents[0] upward.  (parents is terminated by a 0 value)
// nodes is the full array of tree nodes.
static void nf_hashtree_rb_balance_7(uint8_t *hashtree, uint8_t *parents) {
   uint8_t pos= *parents--, newpos, parent;
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

// balance a tree from parents[0] upward.  (parents is terminated by a 0 value)
// nodes is the full array of tree nodes.
static void nf_hashtree_rb_balance_15(uint16_t *hashtree, uint16_t *parents) {
   uint16_t pos= *parents--, newpos, parent;
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

// balance a tree from parents[0] upward.  (parents is terminated by a 0 value)
// nodes is the full array of tree nodes.
static void nf_hashtree_rb_balance_31(uint32_t *hashtree, uint32_t *parents) {
   uint32_t pos= *parents--, newpos, parent;
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

bool nf_fieldset_reindex(void *hashtree, size_t capacity, nf_fieldinfo_t ** elemdata, size_t el_i, size_t last_i) {
   size_t n_buckets= NF_HASHTREE_TABLE_BUCKETS(capacity), node;
   size_t el_hashcode, new_hashcode, pos;
   IV cmp;
   if (capacity <= 0x7F) {
      uint8_t *bucket, *parent_ptr, parents[1+16];
      for (; el_i <= last_i; el_i++) {
         new_hashcode= ( (elemdata)[(el_i)-1]->name_hashcode );
         bucket= ((uint8_t *)hashtree) + (1 + capacity + new_hashcode % n_buckets);
         if (!(node= *bucket))
            *bucket= el_i;
         else {
            // red/black insert
            parents[0]= 0; // mark end of list
            pos= 0;
            assert(node < el_i);
            do {
               parents[++pos]= node;
               el_hashcode= ( (elemdata)[(node)-1]->name_hashcode );
               cmp= new_hashcode == el_hashcode? (( sv_cmp((elemdata)[(el_i)-1]->name, (elemdata)[(node)-1]->name) ))
                  : new_hashcode < el_hashcode? -1 : 1;
               parent_ptr= &((uint8_t *)hashtree)[ node*2 + (cmp < 0)? 0 : 1 ];
               node= *parent_ptr >> 1;
            } while (node && pos < 16);
            if (pos > 16) {
               assert(pos <= 16);
               return false; // fatal error, should never happen unless datastruct corrupt
            }
            // Set left or right pointer of node to new node
            *parent_ptr |= el_i << 1;
            // Set color of new node to red. other fields should be initialized to zero already
            // Note that this is never the root of the tree because that happens automatically
            // above when *bucket= el_i and node[el_i] is assumed to be zeroed (black) already.
            ((uint8_t *)hashtree)[ el_i*2 ]= 1;
            if (pos > 1) { // no need to balance unless more than 1 parent
               nf_hashtree_rb_balance_7((uint8_t *)hashtree, parents+pos);
               *bucket= parents[1]; // may have changed after tree balance
               // tree root is always black
               ((uint8_t *)hashtree)[ parents[1]*2 ]= ((uint8_t *)hashtree)[ parents[1]*2 ] >> 1 << 1; 
            }
         }
      }
      return true;
   }
   if (capacity <= 0x7FFF) {
      uint16_t *bucket, *parent_ptr, parents[1+32];
      for (; el_i <= last_i; el_i++) {
         new_hashcode= ( (elemdata)[(el_i)-1]->name_hashcode );
         bucket= ((uint16_t *)hashtree) + (1 + capacity + new_hashcode % n_buckets);
         if (!(node= *bucket))
            *bucket= el_i;
         else {
            // red/black insert
            parents[0]= 0; // mark end of list
            pos= 0;
            assert(node < el_i);
            do {
               parents[++pos]= node;
               el_hashcode= ( (elemdata)[(node)-1]->name_hashcode );
               cmp= new_hashcode == el_hashcode? (( sv_cmp((elemdata)[(el_i)-1]->name, (elemdata)[(node)-1]->name) ))
                  : new_hashcode < el_hashcode? -1 : 1;
               parent_ptr= &((uint16_t *)hashtree)[ node*2 + (cmp < 0)? 0 : 1 ];
               node= *parent_ptr >> 1;
            } while (node && pos < 32);
            if (pos > 32) {
               assert(pos <= 32);
               return false; // fatal error, should never happen unless datastruct corrupt
            }
            // Set left or right pointer of node to new node
            *parent_ptr |= el_i << 1;
            // Set color of new node to red. other fields should be initialized to zero already
            // Note that this is never the root of the tree because that happens automatically
            // above when *bucket= el_i and node[el_i] is assumed to be zeroed (black) already.
            ((uint16_t *)hashtree)[ el_i*2 ]= 1;
            if (pos > 1) { // no need to balance unless more than 1 parent
               nf_hashtree_rb_balance_15((uint16_t *)hashtree, parents+pos);
               *bucket= parents[1]; // may have changed after tree balance
               // tree root is always black
               ((uint16_t *)hashtree)[ parents[1]*2 ]= ((uint16_t *)hashtree)[ parents[1]*2 ] >> 1 << 1; 
            }
         }
      }
      return true;
   }
   if (capacity <= 0x7FFFFFFF) {
      uint32_t *bucket, *parent_ptr, parents[1+64];
      for (; el_i <= last_i; el_i++) {
         new_hashcode= ( (elemdata)[(el_i)-1]->name_hashcode );
         bucket= ((uint32_t *)hashtree) + (1 + capacity + new_hashcode % n_buckets);
         if (!(node= *bucket))
            *bucket= el_i;
         else {
            // red/black insert
            parents[0]= 0; // mark end of list
            pos= 0;
            assert(node < el_i);
            do {
               parents[++pos]= node;
               el_hashcode= ( (elemdata)[(node)-1]->name_hashcode );
               cmp= new_hashcode == el_hashcode? (( sv_cmp((elemdata)[(el_i)-1]->name, (elemdata)[(node)-1]->name) ))
                  : new_hashcode < el_hashcode? -1 : 1;
               parent_ptr= &((uint32_t *)hashtree)[ node*2 + (cmp < 0)? 0 : 1 ];
               node= *parent_ptr >> 1;
            } while (node && pos < 64);
            if (pos > 64) {
               assert(pos <= 64);
               return false; // fatal error, should never happen unless datastruct corrupt
            }
            // Set left or right pointer of node to new node
            *parent_ptr |= el_i << 1;
            // Set color of new node to red. other fields should be initialized to zero already
            // Note that this is never the root of the tree because that happens automatically
            // above when *bucket= el_i and node[el_i] is assumed to be zeroed (black) already.
            ((uint32_t *)hashtree)[ el_i*2 ]= 1;
            if (pos > 1) { // no need to balance unless more than 1 parent
               nf_hashtree_rb_balance_31((uint32_t *)hashtree, parents+pos);
               *bucket= parents[1]; // may have changed after tree balance
               // tree root is always black
               ((uint32_t *)hashtree)[ parents[1]*2 ]= ((uint32_t *)hashtree)[ parents[1]*2 ] >> 1 << 1; 
            }
         }
      }
      return true;
   }
   return false; // happens if capacity is out of bounds
}

// Gets called recursively to verify the Red/Black properties of the subtree at 'idx'
// Returns the number of black nodes in the current subtree, or -1 if there was an error.
static int nf_hashtree_treecheck_7(uint8_t *hashtree, size_t max_node, size_t node, int *blackcount_out) {
   uint8_t subtree;
   int i, depth[2]= { 0, 0 }, blackcount[2]= { 0, 0 };
   for (i=0; i < 2; i++) {
      if ((subtree= (hashtree[node*2 + i]>>1))) {
         if (subtree > max_node) // out of bounds?
            return -1;
         if (HASHTREE_IS_RED(node) && HASHTREE_IS_RED(subtree)) // two adjacent reds?
            return -1;
         depth[i]= nf_hashtree_treecheck_7(hashtree, max_node, subtree, blackcount+i);
         if (depth[i] < 0) return -1;
      }
   }
   if (blackcount[0] != blackcount[1])
      return -1;
   *blackcount_out= blackcount[0] + (HASHTREE_IS_RED(node) ^ 1);
   return 1 + (depth[0] > depth[1]? depth[0] : depth[1]);
}

// Verify that every filled bucket refers to a valid tree,
// and that every node can be found.
static bool nf_fieldset_structcheck_7(pTHX_ uint8_t *hashtree, size_t capacity, nf_fieldinfo_t ** elemdata, size_t max_el) {
   size_t n_buckets= NF_HASHTREE_TABLE_BUCKETS(capacity), node;
   size_t el_hashcode, i_hashcode;
   int cmp, i, depth, blackcount;
   uint8_t *bucket, *table= hashtree + 1 + capacity;
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
         depth= nf_hashtree_treecheck_7(hashtree, max_el, *bucket, &blackcount);
         if (depth < 0) {
            warn("Tree at node %ld is corrupt", (long) *bucket);
            success= false;
         } else if (depth > 16) {
            warn("Tree at node %ld exceeds maximum height (%ld > %ld)", (long) *bucket, (long) depth, (long) 16);
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
         i_hashcode= ( (elemdata)[(i)-1]->name_hashcode );
         bucket= table + i_hashcode % n_buckets;
         node= *bucket;
         while (node && node != i) {
            el_hashcode= ( (elemdata)[(node)-1]->name_hashcode );
            cmp= i_hashcode == el_hashcode? (( sv_cmp((elemdata)[(i)-1]->name, (elemdata)[(node)-1]->name) ))
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

// Gets called recursively to verify the Red/Black properties of the subtree at 'idx'
// Returns the number of black nodes in the current subtree, or -1 if there was an error.
static int nf_hashtree_treecheck_15(uint16_t *hashtree, size_t max_node, size_t node, int *blackcount_out) {
   uint16_t subtree;
   int i, depth[2]= { 0, 0 }, blackcount[2]= { 0, 0 };
   for (i=0; i < 2; i++) {
      if ((subtree= (hashtree[node*2 + i]>>1))) {
         if (subtree > max_node) // out of bounds?
            return -1;
         if (HASHTREE_IS_RED(node) && HASHTREE_IS_RED(subtree)) // two adjacent reds?
            return -1;
         depth[i]= nf_hashtree_treecheck_15(hashtree, max_node, subtree, blackcount+i);
         if (depth[i] < 0) return -1;
      }
   }
   if (blackcount[0] != blackcount[1])
      return -1;
   *blackcount_out= blackcount[0] + (HASHTREE_IS_RED(node) ^ 1);
   return 1 + (depth[0] > depth[1]? depth[0] : depth[1]);
}

// Verify that every filled bucket refers to a valid tree,
// and that every node can be found.
static bool nf_fieldset_structcheck_15(pTHX_ uint16_t *hashtree, size_t capacity, nf_fieldinfo_t ** elemdata, size_t max_el) {
   size_t n_buckets= NF_HASHTREE_TABLE_BUCKETS(capacity), node;
   size_t el_hashcode, i_hashcode;
   int cmp, i, depth, blackcount;
   uint16_t *bucket, *table= hashtree + 1 + capacity;
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
         depth= nf_hashtree_treecheck_15(hashtree, max_el, *bucket, &blackcount);
         if (depth < 0) {
            warn("Tree at node %ld is corrupt", (long) *bucket);
            success= false;
         } else if (depth > 32) {
            warn("Tree at node %ld exceeds maximum height (%ld > %ld)", (long) *bucket, (long) depth, (long) 32);
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
         i_hashcode= ( (elemdata)[(i)-1]->name_hashcode );
         bucket= table + i_hashcode % n_buckets;
         node= *bucket;
         while (node && node != i) {
            el_hashcode= ( (elemdata)[(node)-1]->name_hashcode );
            cmp= i_hashcode == el_hashcode? (( sv_cmp((elemdata)[(i)-1]->name, (elemdata)[(node)-1]->name) ))
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

// Gets called recursively to verify the Red/Black properties of the subtree at 'idx'
// Returns the number of black nodes in the current subtree, or -1 if there was an error.
static int nf_hashtree_treecheck_31(uint32_t *hashtree, size_t max_node, size_t node, int *blackcount_out) {
   uint32_t subtree;
   int i, depth[2]= { 0, 0 }, blackcount[2]= { 0, 0 };
   for (i=0; i < 2; i++) {
      if ((subtree= (hashtree[node*2 + i]>>1))) {
         if (subtree > max_node) // out of bounds?
            return -1;
         if (HASHTREE_IS_RED(node) && HASHTREE_IS_RED(subtree)) // two adjacent reds?
            return -1;
         depth[i]= nf_hashtree_treecheck_31(hashtree, max_node, subtree, blackcount+i);
         if (depth[i] < 0) return -1;
      }
   }
   if (blackcount[0] != blackcount[1])
      return -1;
   *blackcount_out= blackcount[0] + (HASHTREE_IS_RED(node) ^ 1);
   return 1 + (depth[0] > depth[1]? depth[0] : depth[1]);
}

// Verify that every filled bucket refers to a valid tree,
// and that every node can be found.
static bool nf_fieldset_structcheck_31(pTHX_ uint32_t *hashtree, size_t capacity, nf_fieldinfo_t ** elemdata, size_t max_el) {
   size_t n_buckets= NF_HASHTREE_TABLE_BUCKETS(capacity), node;
   size_t el_hashcode, i_hashcode;
   int cmp, i, depth, blackcount;
   uint32_t *bucket, *table= hashtree + 1 + capacity;
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
         depth= nf_hashtree_treecheck_31(hashtree, max_el, *bucket, &blackcount);
         if (depth < 0) {
            warn("Tree at node %ld is corrupt", (long) *bucket);
            success= false;
         } else if (depth > 64) {
            warn("Tree at node %ld exceeds maximum height (%ld > %ld)", (long) *bucket, (long) depth, (long) 64);
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
         i_hashcode= ( (elemdata)[(i)-1]->name_hashcode );
         bucket= table + i_hashcode % n_buckets;
         node= *bucket;
         while (node && node != i) {
            el_hashcode= ( (elemdata)[(node)-1]->name_hashcode );
            cmp= i_hashcode == el_hashcode? (( sv_cmp((elemdata)[(i)-1]->name, (elemdata)[(node)-1]->name) ))
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

// Verify that every filled bucket refers to a valid tree,
// and that every element can be found.
bool nf_fieldset_structcheck(pTHX_ void* hashtree, size_t capacity, nf_fieldinfo_t ** elemdata, size_t max_el) {
   if (capacity < 0x7F)
      return nf_fieldset_structcheck_7(aTHX_ (uint8_t*)hashtree, capacity, elemdata, max_el);
   if (capacity < 0x7FFF)
      return nf_fieldset_structcheck_15(aTHX_ (uint16_t*)hashtree, capacity, elemdata, max_el);
   if (capacity < 0x7FFFFFFF)
      return nf_fieldset_structcheck_31(aTHX_ (uint32_t*)hashtree, capacity, elemdata, max_el);
   return false;
}

// Look up the search_key in the hashtable, walk the tree of conflicts, and
// return the element index which matched.
size_t nf_fieldstorage_map_find(void *hashtree, size_t capacity, nf_fieldstorage_t ** elemdata, nf_fieldset_t * search_key) {
   size_t n_buckets= NF_HASHTREE_TABLE_BUCKETS(capacity), node;
   size_t el_hashcode, key_hashcode= ( (size_t)(search_key) );
   int cmp;
   if (capacity <= 0x7F) {
      uint8_t *bucket= ((uint8_t *)hashtree) + (1 + capacity + key_hashcode % n_buckets);
      if ((node= *bucket)) {
         do {
            el_hashcode= ( (size_t)((elemdata)[(node)-1]->fieldset) );
            cmp= (key_hashcode == el_hashcode)? (( (search_key) < ((elemdata)[(node)-1]->fieldset)? -1 : (search_key) == ((elemdata)[(node)-1]->fieldset)? 0 : 1 ))
               : key_hashcode < el_hashcode? -1 : 1;
            if (!cmp) return node;
            node= ((uint8_t *)hashtree)[ node*2 + (cmp < 0)? 0 : 1 ] >> 1;
         } while (node);
      }
      return node;
   }
   if (capacity <= 0x7FFF) {
      uint16_t *bucket= ((uint16_t *)hashtree) + (1 + capacity + key_hashcode % n_buckets);
      if ((node= *bucket)) {
         do {
            el_hashcode= ( (size_t)((elemdata)[(node)-1]->fieldset) );
            cmp= (key_hashcode == el_hashcode)? (( (search_key) < ((elemdata)[(node)-1]->fieldset)? -1 : (search_key) == ((elemdata)[(node)-1]->fieldset)? 0 : 1 ))
               : key_hashcode < el_hashcode? -1 : 1;
            if (!cmp) return node;
            node= ((uint16_t *)hashtree)[ node*2 + (cmp < 0)? 0 : 1 ] >> 1;
         } while (node);
      }
      return node;
   }
   if (capacity <= 0x7FFFFFFF) {
      uint32_t *bucket= ((uint32_t *)hashtree) + (1 + capacity + key_hashcode % n_buckets);
      if ((node= *bucket)) {
         do {
            el_hashcode= ( (size_t)((elemdata)[(node)-1]->fieldset) );
            cmp= (key_hashcode == el_hashcode)? (( (search_key) < ((elemdata)[(node)-1]->fieldset)? -1 : (search_key) == ((elemdata)[(node)-1]->fieldset)? 0 : 1 ))
               : key_hashcode < el_hashcode? -1 : 1;
            if (!cmp) return node;
            node= ((uint32_t *)hashtree)[ node*2 + (cmp < 0)? 0 : 1 ] >> 1;
         } while (node);
      }
      return node;
   }
   return 0;
}

bool nf_fieldstorage_map_reindex(void *hashtree, size_t capacity, nf_fieldstorage_t ** elemdata, size_t el_i, size_t last_i) {
   size_t n_buckets= NF_HASHTREE_TABLE_BUCKETS(capacity), node;
   size_t el_hashcode, new_hashcode, pos;
   IV cmp;
   if (capacity <= 0x7F) {
      uint8_t *bucket, *parent_ptr, parents[1+16];
      for (; el_i <= last_i; el_i++) {
         new_hashcode= ( (size_t)((elemdata)[(el_i)-1]->fieldset) );
         bucket= ((uint8_t *)hashtree) + (1 + capacity + new_hashcode % n_buckets);
         if (!(node= *bucket))
            *bucket= el_i;
         else {
            // red/black insert
            parents[0]= 0; // mark end of list
            pos= 0;
            assert(node < el_i);
            do {
               parents[++pos]= node;
               el_hashcode= ( (size_t)((elemdata)[(node)-1]->fieldset) );
               cmp= new_hashcode == el_hashcode? (( ((elemdata)[(el_i)-1]->fieldset) < ((elemdata)[(node)-1]->fieldset)? -1 : ((elemdata)[(el_i)-1]->fieldset) == ((elemdata)[(node)-1]->fieldset)? 0 : 1 ))
                  : new_hashcode < el_hashcode? -1 : 1;
               parent_ptr= &((uint8_t *)hashtree)[ node*2 + (cmp < 0)? 0 : 1 ];
               node= *parent_ptr >> 1;
            } while (node && pos < 16);
            if (pos > 16) {
               assert(pos <= 16);
               return false; // fatal error, should never happen unless datastruct corrupt
            }
            // Set left or right pointer of node to new node
            *parent_ptr |= el_i << 1;
            // Set color of new node to red. other fields should be initialized to zero already
            // Note that this is never the root of the tree because that happens automatically
            // above when *bucket= el_i and node[el_i] is assumed to be zeroed (black) already.
            ((uint8_t *)hashtree)[ el_i*2 ]= 1;
            if (pos > 1) { // no need to balance unless more than 1 parent
               nf_hashtree_rb_balance_7((uint8_t *)hashtree, parents+pos);
               *bucket= parents[1]; // may have changed after tree balance
               // tree root is always black
               ((uint8_t *)hashtree)[ parents[1]*2 ]= ((uint8_t *)hashtree)[ parents[1]*2 ] >> 1 << 1; 
            }
         }
      }
      return true;
   }
   if (capacity <= 0x7FFF) {
      uint16_t *bucket, *parent_ptr, parents[1+32];
      for (; el_i <= last_i; el_i++) {
         new_hashcode= ( (size_t)((elemdata)[(el_i)-1]->fieldset) );
         bucket= ((uint16_t *)hashtree) + (1 + capacity + new_hashcode % n_buckets);
         if (!(node= *bucket))
            *bucket= el_i;
         else {
            // red/black insert
            parents[0]= 0; // mark end of list
            pos= 0;
            assert(node < el_i);
            do {
               parents[++pos]= node;
               el_hashcode= ( (size_t)((elemdata)[(node)-1]->fieldset) );
               cmp= new_hashcode == el_hashcode? (( ((elemdata)[(el_i)-1]->fieldset) < ((elemdata)[(node)-1]->fieldset)? -1 : ((elemdata)[(el_i)-1]->fieldset) == ((elemdata)[(node)-1]->fieldset)? 0 : 1 ))
                  : new_hashcode < el_hashcode? -1 : 1;
               parent_ptr= &((uint16_t *)hashtree)[ node*2 + (cmp < 0)? 0 : 1 ];
               node= *parent_ptr >> 1;
            } while (node && pos < 32);
            if (pos > 32) {
               assert(pos <= 32);
               return false; // fatal error, should never happen unless datastruct corrupt
            }
            // Set left or right pointer of node to new node
            *parent_ptr |= el_i << 1;
            // Set color of new node to red. other fields should be initialized to zero already
            // Note that this is never the root of the tree because that happens automatically
            // above when *bucket= el_i and node[el_i] is assumed to be zeroed (black) already.
            ((uint16_t *)hashtree)[ el_i*2 ]= 1;
            if (pos > 1) { // no need to balance unless more than 1 parent
               nf_hashtree_rb_balance_15((uint16_t *)hashtree, parents+pos);
               *bucket= parents[1]; // may have changed after tree balance
               // tree root is always black
               ((uint16_t *)hashtree)[ parents[1]*2 ]= ((uint16_t *)hashtree)[ parents[1]*2 ] >> 1 << 1; 
            }
         }
      }
      return true;
   }
   if (capacity <= 0x7FFFFFFF) {
      uint32_t *bucket, *parent_ptr, parents[1+64];
      for (; el_i <= last_i; el_i++) {
         new_hashcode= ( (size_t)((elemdata)[(el_i)-1]->fieldset) );
         bucket= ((uint32_t *)hashtree) + (1 + capacity + new_hashcode % n_buckets);
         if (!(node= *bucket))
            *bucket= el_i;
         else {
            // red/black insert
            parents[0]= 0; // mark end of list
            pos= 0;
            assert(node < el_i);
            do {
               parents[++pos]= node;
               el_hashcode= ( (size_t)((elemdata)[(node)-1]->fieldset) );
               cmp= new_hashcode == el_hashcode? (( ((elemdata)[(el_i)-1]->fieldset) < ((elemdata)[(node)-1]->fieldset)? -1 : ((elemdata)[(el_i)-1]->fieldset) == ((elemdata)[(node)-1]->fieldset)? 0 : 1 ))
                  : new_hashcode < el_hashcode? -1 : 1;
               parent_ptr= &((uint32_t *)hashtree)[ node*2 + (cmp < 0)? 0 : 1 ];
               node= *parent_ptr >> 1;
            } while (node && pos < 64);
            if (pos > 64) {
               assert(pos <= 64);
               return false; // fatal error, should never happen unless datastruct corrupt
            }
            // Set left or right pointer of node to new node
            *parent_ptr |= el_i << 1;
            // Set color of new node to red. other fields should be initialized to zero already
            // Note that this is never the root of the tree because that happens automatically
            // above when *bucket= el_i and node[el_i] is assumed to be zeroed (black) already.
            ((uint32_t *)hashtree)[ el_i*2 ]= 1;
            if (pos > 1) { // no need to balance unless more than 1 parent
               nf_hashtree_rb_balance_31((uint32_t *)hashtree, parents+pos);
               *bucket= parents[1]; // may have changed after tree balance
               // tree root is always black
               ((uint32_t *)hashtree)[ parents[1]*2 ]= ((uint32_t *)hashtree)[ parents[1]*2 ] >> 1 << 1; 
            }
         }
      }
      return true;
   }
   return false; // happens if capacity is out of bounds
}

// Verify that every filled bucket refers to a valid tree,
// and that every node can be found.
static bool nf_fieldstorage_map_structcheck_7(pTHX_ uint8_t *hashtree, size_t capacity, nf_fieldstorage_t ** elemdata, size_t max_el) {
   size_t n_buckets= NF_HASHTREE_TABLE_BUCKETS(capacity), node;
   size_t el_hashcode, i_hashcode;
   int cmp, i, depth, blackcount;
   uint8_t *bucket, *table= hashtree + 1 + capacity;
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
         depth= nf_hashtree_treecheck_7(hashtree, max_el, *bucket, &blackcount);
         if (depth < 0) {
            warn("Tree at node %ld is corrupt", (long) *bucket);
            success= false;
         } else if (depth > 16) {
            warn("Tree at node %ld exceeds maximum height (%ld > %ld)", (long) *bucket, (long) depth, (long) 16);
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
         i_hashcode= ( (size_t)((elemdata)[(i)-1]->fieldset) );
         bucket= table + i_hashcode % n_buckets;
         node= *bucket;
         while (node && node != i) {
            el_hashcode= ( (size_t)((elemdata)[(node)-1]->fieldset) );
            cmp= i_hashcode == el_hashcode? (( ((elemdata)[(i)-1]->fieldset) < ((elemdata)[(node)-1]->fieldset)? -1 : ((elemdata)[(i)-1]->fieldset) == ((elemdata)[(node)-1]->fieldset)? 0 : 1 ))
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

// Verify that every filled bucket refers to a valid tree,
// and that every node can be found.
static bool nf_fieldstorage_map_structcheck_15(pTHX_ uint16_t *hashtree, size_t capacity, nf_fieldstorage_t ** elemdata, size_t max_el) {
   size_t n_buckets= NF_HASHTREE_TABLE_BUCKETS(capacity), node;
   size_t el_hashcode, i_hashcode;
   int cmp, i, depth, blackcount;
   uint16_t *bucket, *table= hashtree + 1 + capacity;
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
         depth= nf_hashtree_treecheck_15(hashtree, max_el, *bucket, &blackcount);
         if (depth < 0) {
            warn("Tree at node %ld is corrupt", (long) *bucket);
            success= false;
         } else if (depth > 32) {
            warn("Tree at node %ld exceeds maximum height (%ld > %ld)", (long) *bucket, (long) depth, (long) 32);
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
         i_hashcode= ( (size_t)((elemdata)[(i)-1]->fieldset) );
         bucket= table + i_hashcode % n_buckets;
         node= *bucket;
         while (node && node != i) {
            el_hashcode= ( (size_t)((elemdata)[(node)-1]->fieldset) );
            cmp= i_hashcode == el_hashcode? (( ((elemdata)[(i)-1]->fieldset) < ((elemdata)[(node)-1]->fieldset)? -1 : ((elemdata)[(i)-1]->fieldset) == ((elemdata)[(node)-1]->fieldset)? 0 : 1 ))
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

// Verify that every filled bucket refers to a valid tree,
// and that every node can be found.
static bool nf_fieldstorage_map_structcheck_31(pTHX_ uint32_t *hashtree, size_t capacity, nf_fieldstorage_t ** elemdata, size_t max_el) {
   size_t n_buckets= NF_HASHTREE_TABLE_BUCKETS(capacity), node;
   size_t el_hashcode, i_hashcode;
   int cmp, i, depth, blackcount;
   uint32_t *bucket, *table= hashtree + 1 + capacity;
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
         depth= nf_hashtree_treecheck_31(hashtree, max_el, *bucket, &blackcount);
         if (depth < 0) {
            warn("Tree at node %ld is corrupt", (long) *bucket);
            success= false;
         } else if (depth > 64) {
            warn("Tree at node %ld exceeds maximum height (%ld > %ld)", (long) *bucket, (long) depth, (long) 64);
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
         i_hashcode= ( (size_t)((elemdata)[(i)-1]->fieldset) );
         bucket= table + i_hashcode % n_buckets;
         node= *bucket;
         while (node && node != i) {
            el_hashcode= ( (size_t)((elemdata)[(node)-1]->fieldset) );
            cmp= i_hashcode == el_hashcode? (( ((elemdata)[(i)-1]->fieldset) < ((elemdata)[(node)-1]->fieldset)? -1 : ((elemdata)[(i)-1]->fieldset) == ((elemdata)[(node)-1]->fieldset)? 0 : 1 ))
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

// Verify that every filled bucket refers to a valid tree,
// and that every element can be found.
bool nf_fieldstorage_map_structcheck(pTHX_ void* hashtree, size_t capacity, nf_fieldstorage_t ** elemdata, size_t max_el) {
   if (capacity < 0x7F)
      return nf_fieldstorage_map_structcheck_7(aTHX_ (uint8_t*)hashtree, capacity, elemdata, max_el);
   if (capacity < 0x7FFF)
      return nf_fieldstorage_map_structcheck_15(aTHX_ (uint16_t*)hashtree, capacity, elemdata, max_el);
   if (capacity < 0x7FFFFFFF)
      return nf_fieldstorage_map_structcheck_31(aTHX_ (uint32_t*)hashtree, capacity, elemdata, max_el);
   return false;
}

/* END GENERATED NF_HASHTREE IMPLEMENTATION */
