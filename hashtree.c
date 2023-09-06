/* BEGIN GENERATED HashTree IMPLEMENTATION */
struct nf_hashtree__rbnode_uint8_t;
static void nf_hashtree__rbbalance_uint8_t(uint8_t *tree, uint8_t *parents);
// Max tree height of N nodes is log2(N) * 2
// Max array index range for this implementation is 0..(2^(n-1)-2)
// because one bit is used for flags, and zero is used as NULL.
#define NF_HASHTREE_TREE_HEIGHT_LIMIT_UINT8_T ((1 * 8 - 1)*2)

struct nf_hashtree__rbnode_uint16_t;
static void nf_hashtree__rbbalance_uint16_t(uint16_t *tree, uint16_t *parents);
// Max tree height of N nodes is log2(N) * 2
// Max array index range for this implementation is 0..(2^(n-1)-2)
// because one bit is used for flags, and zero is used as NULL.
#define NF_HASHTREE_TREE_HEIGHT_LIMIT_UINT16_T ((2 * 8 - 1)*2)

struct nf_hashtree__rbnode_IV;
static void nf_hashtree__rbbalance_IV(IV *tree, IV *parents);
// Max tree height of N nodes is log2(N) * 2
// Max array index range for this implementation is 0..(2^(n-1)-2)
// because one bit is used for flags, and zero is used as NULL.
#define NF_HASHTREE_TREE_HEIGHT_LIMIT_IV ((IVSIZE * 8 - 1)*2)

struct nf_hashtree__rbnode_uint8_t {
   uint8_t
      left  :7, is_red: 1,
      right :7, is_righttree: 1;
};

struct nf_hashtree__rbnode_uint16_t {
   uint16_t
      left  :15, is_red: 1,
      right :15, is_righttree: 1;
};

struct nf_hashtree__rbnode_IV {
   IV
#if IVSIZE == 1
   left  :7, is_red: 1,
   right :7, is_righttree: 1;
#endif
#if IVSIZE == 2
   left  :15, is_red: 1,
   right :15, is_righttree: 1;
#endif
#if IVSIZE == 4
   left  :31, is_red: 1,
   right :31, is_righttree: 1;
#endif
#if IVSIZE == 8
   left  :63, is_red: 1,
   right :63, is_righttree: 1;
#endif
};

// Look up the search_key in the hashtable, walk the tree of conflicts, and
// return the el_array element which matched.
nf_fieldstorage_t * * nf_fieldstorage_map_find_uint8_t(nf_fieldstorage_t * *el_array, size_t capacity, nf_fieldset_t * search_key) {
   size_t table_count= NF_HASHTREE_TABLE_COUNT(capacity), hash_code, node;
   struct nf_hashtree__rbnode_uint8_t *nodes= (struct nf_hashtree__rbnode_uint8_t*) (el_array + capacity);
   uint8_t *table= (uint8_t*) (nodes + 1 + capacity);
   hash_code= (x).fieldset->hashcode(el_array[i]) % table_count;
   IV cmp;
   if ((node= table[hash_code])) {
      do {
         cmp= ((IV)((b)-(a)))((x).fieldset(el_array[node-1]), search_key);
         if (!cmp)
            return &el_array[node-1];
         node= (cmp < 0)? nodes[node].left : nodes[node].right;
      } while (node);
   }
   return NULL;
}

// balance a tree from parents[0] upward.  (parents is terminated by a 0 value)
// nodes is the full array of tree nodes.
static void nf_hashtree__rbbalance_uint8_t(uint8_t *nodes, uint8_t *parents) {
   uint8_t pos= *parents--, parent;
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

// For an array of 'capacity' elements followed by 1+ that number of
// tree nodes, followed by table_count hash buckets (which scales per capacity),
// reindex the elements from first_i to last_i.
// If this returns false, it means there is a fatal error in the data structure.
bool nf_fieldstorage_map_reindex_uint8_t(nf_fieldstorage_t * *el_array, size_t capacity, size_t i, size_t until_i) {
   size_t table_count= NF_HASHTREE_TABLE_COUNT(capacity), hash_code, pos, node;
   IV cmp;
   struct nf_hashtree__rbnode_uint8_t *nodes= (struct nf_hashtree__rbnode_uint8_t*) (el_array + capacity);
   uint8_t *table= (uint8_t*) (nodes + 1 + capacity);
   uint8_t parents[1+NF_HASHTREE_TREE_HEIGHT_LIMIT_UINT8_T];
   assert(((to_i + 1) >> (1*4) >> (1*4)) == 0); // to_i should never be more than 2^N - 2
   for (; i < until_i; i++) {
      hash_code= (x).fieldset->hashcode(el_array[i]) % table_count;
      if (!table[hash_code])
         table[hash_code]= i+1; // element i uses node i+1, because 0 means NULL
      else {
         // red/black insert
         parents[0]= 0; // mark end of list
         pos= 0, node= table[hash_code];
         assert(node <= i);
         do {
            parents[++pos]= node;
            cmp= ((IV)((b)-(a)))((x).fieldset(el_array[i]), (x).fieldset(el_array[node-1]));
            node= cmp < 0? nodes[node].left : nodes[node].right;
         } while (node && pos < NF_HASHTREE_TREE_HEIGHT_LIMIT_UINT8_T) {
         if (pos >= NF_HASHTREE_TREE_HEIGHT_LIMIT_UINT8_T)
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
            nf_hashtree__rbbalance_uint8_t(nodes, parents+pos-1);
            table[hash_code]= parents[1]; // may have changed after tree balance
            nodes[parents[1]].is_red= 0; // tree root is always black
         }
      }
   }
   return true;
}

// Look up the search_key in the hashtable, walk the tree of conflicts, and
// return the el_array element which matched.
nf_fieldstorage_t * * nf_fieldstorage_map_find_uint16_t(nf_fieldstorage_t * *el_array, size_t capacity, nf_fieldset_t * search_key) {
   size_t table_count= NF_HASHTREE_TABLE_COUNT(capacity), hash_code, node;
   struct nf_hashtree__rbnode_uint16_t *nodes= (struct nf_hashtree__rbnode_uint16_t*) (el_array + capacity);
   uint16_t *table= (uint16_t*) (nodes + 1 + capacity);
   hash_code= (x).fieldset->hashcode(el_array[i]) % table_count;
   IV cmp;
   if ((node= table[hash_code])) {
      do {
         cmp= ((IV)((b)-(a)))((x).fieldset(el_array[node-1]), search_key);
         if (!cmp)
            return &el_array[node-1];
         node= (cmp < 0)? nodes[node].left : nodes[node].right;
      } while (node);
   }
   return NULL;
}

// balance a tree from parents[0] upward.  (parents is terminated by a 0 value)
// nodes is the full array of tree nodes.
static void nf_hashtree__rbbalance_uint16_t(uint16_t *nodes, uint16_t *parents) {
   uint16_t pos= *parents--, parent;
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

// For an array of 'capacity' elements followed by 1+ that number of
// tree nodes, followed by table_count hash buckets (which scales per capacity),
// reindex the elements from first_i to last_i.
// If this returns false, it means there is a fatal error in the data structure.
bool nf_fieldstorage_map_reindex_uint16_t(nf_fieldstorage_t * *el_array, size_t capacity, size_t i, size_t until_i) {
   size_t table_count= NF_HASHTREE_TABLE_COUNT(capacity), hash_code, pos, node;
   IV cmp;
   struct nf_hashtree__rbnode_uint16_t *nodes= (struct nf_hashtree__rbnode_uint16_t*) (el_array + capacity);
   uint16_t *table= (uint16_t*) (nodes + 1 + capacity);
   uint16_t parents[1+NF_HASHTREE_TREE_HEIGHT_LIMIT_UINT16_T];
   assert(((to_i + 1) >> (2*4) >> (2*4)) == 0); // to_i should never be more than 2^N - 2
   for (; i < until_i; i++) {
      hash_code= (x).fieldset->hashcode(el_array[i]) % table_count;
      if (!table[hash_code])
         table[hash_code]= i+1; // element i uses node i+1, because 0 means NULL
      else {
         // red/black insert
         parents[0]= 0; // mark end of list
         pos= 0, node= table[hash_code];
         assert(node <= i);
         do {
            parents[++pos]= node;
            cmp= ((IV)((b)-(a)))((x).fieldset(el_array[i]), (x).fieldset(el_array[node-1]));
            node= cmp < 0? nodes[node].left : nodes[node].right;
         } while (node && pos < NF_HASHTREE_TREE_HEIGHT_LIMIT_UINT16_T) {
         if (pos >= NF_HASHTREE_TREE_HEIGHT_LIMIT_UINT16_T)
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
            nf_hashtree__rbbalance_uint16_t(nodes, parents+pos-1);
            table[hash_code]= parents[1]; // may have changed after tree balance
            nodes[parents[1]].is_red= 0; // tree root is always black
         }
      }
   }
   return true;
}

// Look up the search_key in the hashtable, walk the tree of conflicts, and
// return the el_array element which matched.
nf_fieldstorage_t * * nf_fieldstorage_map_find_IV(nf_fieldstorage_t * *el_array, size_t capacity, nf_fieldset_t * search_key) {
   size_t table_count= NF_HASHTREE_TABLE_COUNT(capacity), hash_code, node;
   struct nf_hashtree__rbnode_IV *nodes= (struct nf_hashtree__rbnode_IV*) (el_array + capacity);
   IV *table= (IV*) (nodes + 1 + capacity);
   hash_code= (x).fieldset->hashcode(el_array[i]) % table_count;
   IV cmp;
   if ((node= table[hash_code])) {
      do {
         cmp= ((IV)((b)-(a)))((x).fieldset(el_array[node-1]), search_key);
         if (!cmp)
            return &el_array[node-1];
         node= (cmp < 0)? nodes[node].left : nodes[node].right;
      } while (node);
   }
   return NULL;
}

// balance a tree from parents[0] upward.  (parents is terminated by a 0 value)
// nodes is the full array of tree nodes.
static void nf_hashtree__rbbalance_IV(IV *nodes, IV *parents) {
   IV pos= *parents--, parent;
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

// For an array of 'capacity' elements followed by 1+ that number of
// tree nodes, followed by table_count hash buckets (which scales per capacity),
// reindex the elements from first_i to last_i.
// If this returns false, it means there is a fatal error in the data structure.
bool nf_fieldstorage_map_reindex_IV(nf_fieldstorage_t * *el_array, size_t capacity, size_t i, size_t until_i) {
   size_t table_count= NF_HASHTREE_TABLE_COUNT(capacity), hash_code, pos, node;
   IV cmp;
   struct nf_hashtree__rbnode_IV *nodes= (struct nf_hashtree__rbnode_IV*) (el_array + capacity);
   IV *table= (IV*) (nodes + 1 + capacity);
   IV parents[1+NF_HASHTREE_TREE_HEIGHT_LIMIT_IV];
   assert(((to_i + 1) >> (IVSIZE*4) >> (IVSIZE*4)) == 0); // to_i should never be more than 2^N - 2
   for (; i < until_i; i++) {
      hash_code= (x).fieldset->hashcode(el_array[i]) % table_count;
      if (!table[hash_code])
         table[hash_code]= i+1; // element i uses node i+1, because 0 means NULL
      else {
         // red/black insert
         parents[0]= 0; // mark end of list
         pos= 0, node= table[hash_code];
         assert(node <= i);
         do {
            parents[++pos]= node;
            cmp= ((IV)((b)-(a)))((x).fieldset(el_array[i]), (x).fieldset(el_array[node-1]));
            node= cmp < 0? nodes[node].left : nodes[node].right;
         } while (node && pos < NF_HASHTREE_TREE_HEIGHT_LIMIT_IV) {
         if (pos >= NF_HASHTREE_TREE_HEIGHT_LIMIT_IV)
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
            nf_hashtree__rbbalance_IV(nodes, parents+pos-1);
            table[hash_code]= parents[1]; // may have changed after tree balance
            nodes[parents[1]].is_red= 0; // tree root is always black
         }
      }
   }
   return true;
}

/* END GENERATED HashTree IMPLEMENTATION */
ON */
}
      }
   }
   return true;
}

/* END GENERATED HashTree IMPLEMENTATION */
ON */
