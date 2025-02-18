/* BEGIN GENERATED FM_RBHASH IMPLEMENTATION */
static void fm_rbhash_rb_balance_7(uint8_t *rbhash, uint8_t *parents);
static void fm_rbhash_rb_balance_15(uint16_t *rbhash, uint16_t *parents);
static void fm_rbhash_rb_balance_31(uint32_t *rbhash, uint32_t *parents);
// Look up the search_key in the hashtable, walk the tree of conflicts, and
// return the element index which matched.
size_t fm_fieldset_rbhash_find(void *rbhash, size_t capacity, fm_fieldinfo_t ** elemdata, fm_fieldinfo_key_t * search_key) {
   size_t n_buckets= FM_RBHASH_TABLE_BUCKETS(capacity);
   size_t el_hashcode, key_hashcode;
   int cmp;
   if (!n_buckets) return 0;
   key_hashcode= ( (search_key)->name_hashcode );
    if (capacity <= 0x7F) {
      uint8_t node, *bucket= ((uint8_t *)rbhash) + (1 + capacity)*2 + (key_hashcode % n_buckets);
      if ((node= *bucket)) {
         do {
            el_hashcode= ( (elemdata)[(node)-1]->name_hashcode );
            cmp= (key_hashcode == el_hashcode)? (( sv_cmp((search_key)->name, (elemdata)[(node)-1]->name) ))
               : key_hashcode < el_hashcode? -1 : 1;
            if (!cmp) return node;
            node= ((uint8_t *)rbhash)[ node*2 + (cmp < 0? 0 : 1) ] >> 1;
         } while (node);
      }
   }
   else  if (capacity <= 0x7FFF) {
      uint16_t node, *bucket= ((uint16_t *)rbhash) + (1 + capacity)*2 + (key_hashcode % n_buckets);
      if ((node= *bucket)) {
         do {
            el_hashcode= ( (elemdata)[(node)-1]->name_hashcode );
            cmp= (key_hashcode == el_hashcode)? (( sv_cmp((search_key)->name, (elemdata)[(node)-1]->name) ))
               : key_hashcode < el_hashcode? -1 : 1;
            if (!cmp) return node;
            node= ((uint16_t *)rbhash)[ node*2 + (cmp < 0? 0 : 1) ] >> 1;
         } while (node);
      }
   }
   else  if (capacity <= 0x7FFFFFFF) {
      uint32_t node, *bucket= ((uint32_t *)rbhash) + (1 + capacity)*2 + (key_hashcode % n_buckets);
      if ((node= *bucket)) {
         do {
            el_hashcode= ( (elemdata)[(node)-1]->name_hashcode );
            cmp= (key_hashcode == el_hashcode)? (( sv_cmp((search_key)->name, (elemdata)[(node)-1]->name) ))
               : key_hashcode < el_hashcode? -1 : 1;
            if (!cmp) return node;
            node= ((uint32_t *)rbhash)[ node*2 + (cmp < 0? 0 : 1) ] >> 1;
         } while (node);
      }
   }
   return 0;
}
#define RBHASH_LEFT(n)        (rbhash[(n)*2] >> 1)
#define RBHASH_RIGHT(n)       (rbhash[(n)*2+1] >> 1)
#define RBHASH_IS_RED(n)      (rbhash[(n)*2] & 1)
#define RBHASH_SET_LEFT(n,v)  (rbhash[(n)*2]= (rbhash[(n)*2] & 1) | ((v)<<1))
#define RBHASH_SET_RIGHT(n,v) (rbhash[(n)*2+1]= ((v)<<1))
#define RBHASH_SET_RED(n)     (rbhash[(n)*2] |= 1)
#define RBHASH_SET_BLACK(n)   (rbhash[(n)*2]= rbhash[(n)*2] >> 1 << 1)
// balance a tree from parents[0] upward.  (parents is terminated by a 0 value)
// nodes is the full array of tree nodes.
static void fm_rbhash_rb_balance_7(uint8_t *rbhash, uint8_t *parents) {
   uint8_t pos= *parents--, newpos, parent;
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
// Gets called recursively to verify the Red/Black properties of the subtree at 'node'
// Returns a message describing what was wrong, or NULL on success.
static bool fm_rbhash_treecheck_7(uint8_t *rbhash, uint8_t max_node, uint8_t node, int depth,
   int *depth_out, int *blackcount_out,
   const char **err_out, uint8_t *err_node_out
) {
   uint8_t subtree;
   const char *err= NULL;
   int i, blackcount[2]= { 0, 0 };
   if (depth == 0 && RBHASH_IS_RED(node)) {
      if (err_out) *err_out= "root node is red";
      if (err_node_out) *err_node_out= node;
      return false;
   }
   ++depth;
   if (depth > 16) {
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
         else if (!fm_rbhash_treecheck_7(rbhash, max_node, subtree, depth,
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
static size_t fm_rbhash_treeprint_7(uint8_t *rbhash, uint8_t max_node, uint8_t node, uint8_t mark_node, FILE * out) {
   uint8_t node_path[ 1+16 ];
   bool cycle;
   int i, pos, step= 0;
   size_t nodecount= 0;
   if (!node) {
      fprintf(out, "(empty tree)\n");
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
         if (!cycle && pos < 16 && node <= max_node && RBHASH_RIGHT(node)) {
            node= RBHASH_RIGHT(node);
            node_path[++pos]= node << 1;
            continue;
         }
      case 1:
         // Print tree branches for nodes up until this one
         for (i= 2; i < pos; i++)
            fprintf(out, (node_path[i]&1) == (node_path[i+1]&1)? "    " : "   |");
         if (pos > 1)
            fprintf(out, (node_path[pos]&1)? "   `" : "   ,");
         
         // Print content of this node
         fprintf(out, "--%c%c%c %ld %ld%s\n",
            (node == mark_node? '(' : '-'),
            (node > max_node? '!' : RBHASH_IS_RED(node)? 'R':'B'),
            (node == mark_node? ')' : ' '),
            (long) node, (long)sizeof(node),
            cycle? " CYCLE DETECTED"
               : pos >= 16? " MAX DEPTH EXCEEDED"
               : node > max_node? " VALUE OUT OF BOUNDS"
               : ""
         );
         ++nodecount;
         
         // Proceed down left subtree if possible
         if (!cycle && pos < 16 && node <= max_node && RBHASH_LEFT(node)) {
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
// balance a tree from parents[0] upward.  (parents is terminated by a 0 value)
// nodes is the full array of tree nodes.
static void fm_rbhash_rb_balance_15(uint16_t *rbhash, uint16_t *parents) {
   uint16_t pos= *parents--, newpos, parent;
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
// Gets called recursively to verify the Red/Black properties of the subtree at 'node'
// Returns a message describing what was wrong, or NULL on success.
static bool fm_rbhash_treecheck_15(uint16_t *rbhash, uint16_t max_node, uint16_t node, int depth,
   int *depth_out, int *blackcount_out,
   const char **err_out, uint16_t *err_node_out
) {
   uint16_t subtree;
   const char *err= NULL;
   int i, blackcount[2]= { 0, 0 };
   if (depth == 0 && RBHASH_IS_RED(node)) {
      if (err_out) *err_out= "root node is red";
      if (err_node_out) *err_node_out= node;
      return false;
   }
   ++depth;
   if (depth > 32) {
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
         else if (!fm_rbhash_treecheck_15(rbhash, max_node, subtree, depth,
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
static size_t fm_rbhash_treeprint_15(uint16_t *rbhash, uint16_t max_node, uint16_t node, uint16_t mark_node, FILE * out) {
   uint16_t node_path[ 1+32 ];
   bool cycle;
   int i, pos, step= 0;
   size_t nodecount= 0;
   if (!node) {
      fprintf(out, "(empty tree)\n");
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
         if (!cycle && pos < 32 && node <= max_node && RBHASH_RIGHT(node)) {
            node= RBHASH_RIGHT(node);
            node_path[++pos]= node << 1;
            continue;
         }
      case 1:
         // Print tree branches for nodes up until this one
         for (i= 2; i < pos; i++)
            fprintf(out, (node_path[i]&1) == (node_path[i+1]&1)? "    " : "   |");
         if (pos > 1)
            fprintf(out, (node_path[pos]&1)? "   `" : "   ,");
         
         // Print content of this node
         fprintf(out, "--%c%c%c %ld %ld%s\n",
            (node == mark_node? '(' : '-'),
            (node > max_node? '!' : RBHASH_IS_RED(node)? 'R':'B'),
            (node == mark_node? ')' : ' '),
            (long) node, (long)sizeof(node),
            cycle? " CYCLE DETECTED"
               : pos >= 32? " MAX DEPTH EXCEEDED"
               : node > max_node? " VALUE OUT OF BOUNDS"
               : ""
         );
         ++nodecount;
         
         // Proceed down left subtree if possible
         if (!cycle && pos < 32 && node <= max_node && RBHASH_LEFT(node)) {
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
// balance a tree from parents[0] upward.  (parents is terminated by a 0 value)
// nodes is the full array of tree nodes.
static void fm_rbhash_rb_balance_31(uint32_t *rbhash, uint32_t *parents) {
   uint32_t pos= *parents--, newpos, parent;
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
// Gets called recursively to verify the Red/Black properties of the subtree at 'node'
// Returns a message describing what was wrong, or NULL on success.
static bool fm_rbhash_treecheck_31(uint32_t *rbhash, uint32_t max_node, uint32_t node, int depth,
   int *depth_out, int *blackcount_out,
   const char **err_out, uint32_t *err_node_out
) {
   uint32_t subtree;
   const char *err= NULL;
   int i, blackcount[2]= { 0, 0 };
   if (depth == 0 && RBHASH_IS_RED(node)) {
      if (err_out) *err_out= "root node is red";
      if (err_node_out) *err_node_out= node;
      return false;
   }
   ++depth;
   if (depth > 64) {
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
         else if (!fm_rbhash_treecheck_31(rbhash, max_node, subtree, depth,
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
static size_t fm_rbhash_treeprint_31(uint32_t *rbhash, uint32_t max_node, uint32_t node, uint32_t mark_node, FILE * out) {
   uint32_t node_path[ 1+64 ];
   bool cycle;
   int i, pos, step= 0;
   size_t nodecount= 0;
   if (!node) {
      fprintf(out, "(empty tree)\n");
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
         if (!cycle && pos < 64 && node <= max_node && RBHASH_RIGHT(node)) {
            node= RBHASH_RIGHT(node);
            node_path[++pos]= node << 1;
            continue;
         }
      case 1:
         // Print tree branches for nodes up until this one
         for (i= 2; i < pos; i++)
            fprintf(out, (node_path[i]&1) == (node_path[i+1]&1)? "    " : "   |");
         if (pos > 1)
            fprintf(out, (node_path[pos]&1)? "   `" : "   ,");
         
         // Print content of this node
         fprintf(out, "--%c%c%c %ld %ld%s\n",
            (node == mark_node? '(' : '-'),
            (node > max_node? '!' : RBHASH_IS_RED(node)? 'R':'B'),
            (node == mark_node? ')' : ' '),
            (long) node, (long)sizeof(node),
            cycle? " CYCLE DETECTED"
               : pos >= 64? " MAX DEPTH EXCEEDED"
               : node > max_node? " VALUE OUT OF BOUNDS"
               : ""
         );
         ++nodecount;
         
         // Proceed down left subtree if possible
         if (!cycle && pos < 64 && node <= max_node && RBHASH_LEFT(node)) {
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
bool fm_fieldset_rbhash_reindex(void *rbhash, size_t capacity, fm_fieldinfo_t ** elemdata, size_t el_i, size_t last_i) {
   size_t n_buckets= FM_RBHASH_TABLE_BUCKETS(capacity);
   size_t el_hashcode, new_hashcode, pos;
   IV cmp;
   if (el_i < 1 || last_i > capacity || !n_buckets)
      return false;
   if (capacity <= 0x7F) {
      uint8_t *bucket, node, tree_ref, parents[1+16], err_node;
      const char *err_msg;
      for (; el_i <= last_i; el_i++) {
         new_hashcode= ( (elemdata)[(el_i)-1]->name_hashcode );
         bucket= ((uint8_t *)rbhash) + (1 + capacity)*2 + new_hashcode % n_buckets;
         if (!(node= *bucket))
            *bucket= el_i;
         else {
            // red/black insert
            pos= 0;
            assert(node < el_i);
            do {
               parents[++pos]= node;
               el_hashcode= ( (elemdata)[(node)-1]->name_hashcode );
               cmp= new_hashcode == el_hashcode? (( sv_cmp((elemdata)[(el_i)-1]->name, (elemdata)[(node)-1]->name) ))
                  : new_hashcode < el_hashcode? -1 : 1;
               tree_ref= node*2 + (cmp < 0? 0 : 1);
               node= ((uint8_t *)rbhash)[tree_ref] >> 1;
            } while (node && pos < 16);
            if (pos > 16) {
               assert(pos <= 16);
               return false; // fatal error, should never happen unless datastruct corrupt
            }
            // Set left or right pointer of node to new node
            ((uint8_t *)rbhash)[tree_ref] |= el_i << 1;
            // Set color of new node to red. other fields should be initialized to zero already
            // Note that this is never the root of the tree because that happens automatically
            // above when *bucket= el_i and node[el_i] is assumed to be zeroed (black) already.
            ((uint8_t *)rbhash)[ el_i*2 ]= 1;
            if (pos > 1) { // no need to balance unless more than 1 parent
               parents[0]= 0; // mark end of list
               fm_rbhash_rb_balance_7((uint8_t *)rbhash, parents+pos);
               *bucket= parents[1]; // may have changed after tree balance
               // tree root is always black
               ((uint8_t *)rbhash)[ parents[1]*2 ]= ((uint8_t *)rbhash)[ parents[1]*2 ] >> 1 << 1; 
            }
         }
         if (!fm_rbhash_treecheck_7(rbhash, el_i, *bucket, 0,
            NULL, NULL, &err_msg, &err_node
         )) {
            fm_rbhash_treeprint_7(rbhash, capacity, *bucket, err_node, stderr);
            warn("Tree rooted at %ld is corrupt, %s at node %d", (long) *bucket, err_msg, (long) err_node);
            return false;
         }
      }
      return true;
   }
   if (capacity <= 0x7FFF) {
      uint16_t *bucket, node, tree_ref, parents[1+32], err_node;
      const char *err_msg;
      for (; el_i <= last_i; el_i++) {
         new_hashcode= ( (elemdata)[(el_i)-1]->name_hashcode );
         bucket= ((uint16_t *)rbhash) + (1 + capacity)*2 + new_hashcode % n_buckets;
         if (!(node= *bucket))
            *bucket= el_i;
         else {
            // red/black insert
            pos= 0;
            assert(node < el_i);
            do {
               parents[++pos]= node;
               el_hashcode= ( (elemdata)[(node)-1]->name_hashcode );
               cmp= new_hashcode == el_hashcode? (( sv_cmp((elemdata)[(el_i)-1]->name, (elemdata)[(node)-1]->name) ))
                  : new_hashcode < el_hashcode? -1 : 1;
               tree_ref= node*2 + (cmp < 0? 0 : 1);
               node= ((uint16_t *)rbhash)[tree_ref] >> 1;
            } while (node && pos < 32);
            if (pos > 32) {
               assert(pos <= 32);
               return false; // fatal error, should never happen unless datastruct corrupt
            }
            // Set left or right pointer of node to new node
            ((uint16_t *)rbhash)[tree_ref] |= el_i << 1;
            // Set color of new node to red. other fields should be initialized to zero already
            // Note that this is never the root of the tree because that happens automatically
            // above when *bucket= el_i and node[el_i] is assumed to be zeroed (black) already.
            ((uint16_t *)rbhash)[ el_i*2 ]= 1;
            if (pos > 1) { // no need to balance unless more than 1 parent
               parents[0]= 0; // mark end of list
               fm_rbhash_rb_balance_15((uint16_t *)rbhash, parents+pos);
               *bucket= parents[1]; // may have changed after tree balance
               // tree root is always black
               ((uint16_t *)rbhash)[ parents[1]*2 ]= ((uint16_t *)rbhash)[ parents[1]*2 ] >> 1 << 1; 
            }
         }
         if (!fm_rbhash_treecheck_15(rbhash, el_i, *bucket, 0,
            NULL, NULL, &err_msg, &err_node
         )) {
            fm_rbhash_treeprint_15(rbhash, capacity, *bucket, err_node, stderr);
            warn("Tree rooted at %ld is corrupt, %s at node %d", (long) *bucket, err_msg, (long) err_node);
            return false;
         }
      }
      return true;
   }
   if (capacity <= 0x7FFFFFFF) {
      uint32_t *bucket, node, tree_ref, parents[1+64], err_node;
      const char *err_msg;
      for (; el_i <= last_i; el_i++) {
         new_hashcode= ( (elemdata)[(el_i)-1]->name_hashcode );
         bucket= ((uint32_t *)rbhash) + (1 + capacity)*2 + new_hashcode % n_buckets;
         if (!(node= *bucket))
            *bucket= el_i;
         else {
            // red/black insert
            pos= 0;
            assert(node < el_i);
            do {
               parents[++pos]= node;
               el_hashcode= ( (elemdata)[(node)-1]->name_hashcode );
               cmp= new_hashcode == el_hashcode? (( sv_cmp((elemdata)[(el_i)-1]->name, (elemdata)[(node)-1]->name) ))
                  : new_hashcode < el_hashcode? -1 : 1;
               tree_ref= node*2 + (cmp < 0? 0 : 1);
               node= ((uint32_t *)rbhash)[tree_ref] >> 1;
            } while (node && pos < 64);
            if (pos > 64) {
               assert(pos <= 64);
               return false; // fatal error, should never happen unless datastruct corrupt
            }
            // Set left or right pointer of node to new node
            ((uint32_t *)rbhash)[tree_ref] |= el_i << 1;
            // Set color of new node to red. other fields should be initialized to zero already
            // Note that this is never the root of the tree because that happens automatically
            // above when *bucket= el_i and node[el_i] is assumed to be zeroed (black) already.
            ((uint32_t *)rbhash)[ el_i*2 ]= 1;
            if (pos > 1) { // no need to balance unless more than 1 parent
               parents[0]= 0; // mark end of list
               fm_rbhash_rb_balance_31((uint32_t *)rbhash, parents+pos);
               *bucket= parents[1]; // may have changed after tree balance
               // tree root is always black
               ((uint32_t *)rbhash)[ parents[1]*2 ]= ((uint32_t *)rbhash)[ parents[1]*2 ] >> 1 << 1; 
            }
         }
         if (!fm_rbhash_treecheck_31(rbhash, el_i, *bucket, 0,
            NULL, NULL, &err_msg, &err_node
         )) {
            fm_rbhash_treeprint_31(rbhash, capacity, *bucket, err_node, stderr);
            warn("Tree rooted at %ld is corrupt, %s at node %d", (long) *bucket, err_msg, (long) err_node);
            return false;
         }
      }
      return true;
   }
   return false; // happens if capacity is out of bounds
}
// Verify that every filled bucket refers to a valid tree,
// and that every node can be found.
static bool fm_fieldset_rbhash_structcheck_7(pTHX_ uint8_t *rbhash, size_t capacity, fm_fieldinfo_t ** elemdata, size_t max_el) {
   size_t n_buckets= FM_RBHASH_TABLE_BUCKETS(capacity), node;
   size_t el_hashcode, i_hashcode;
   int cmp, i, depth, blackcount;
   const char *err_msg;
   uint8_t *bucket, *table= rbhash + (1 + capacity)*2, err_node;
   bool success= true;
   for (bucket= table + n_buckets - 1; bucket >= table; bucket--) {
      if (*bucket > max_el) {
         warn("Bucket %ld refers to element %ld which is greater than max_el %ld", (long)(bucket-table), (long)*bucket, (long)max_el);
         success= false;
      } else if (*bucket) {
         if (!fm_rbhash_treecheck_7(rbhash, max_el, *bucket, 0,
            NULL, &blackcount, &err_msg, &err_node
         )) {
            fm_rbhash_treeprint_7(rbhash, max_el, *bucket, err_node, stderr);
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
            else node= (cmp < 0? RBHASH_LEFT(node) : RBHASH_RIGHT(node));
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
static bool fm_fieldset_rbhash_structcheck_15(pTHX_ uint16_t *rbhash, size_t capacity, fm_fieldinfo_t ** elemdata, size_t max_el) {
   size_t n_buckets= FM_RBHASH_TABLE_BUCKETS(capacity), node;
   size_t el_hashcode, i_hashcode;
   int cmp, i, depth, blackcount;
   const char *err_msg;
   uint16_t *bucket, *table= rbhash + (1 + capacity)*2, err_node;
   bool success= true;
   for (bucket= table + n_buckets - 1; bucket >= table; bucket--) {
      if (*bucket > max_el) {
         warn("Bucket %ld refers to element %ld which is greater than max_el %ld", (long)(bucket-table), (long)*bucket, (long)max_el);
         success= false;
      } else if (*bucket) {
         if (!fm_rbhash_treecheck_15(rbhash, max_el, *bucket, 0,
            NULL, &blackcount, &err_msg, &err_node
         )) {
            fm_rbhash_treeprint_15(rbhash, max_el, *bucket, err_node, stderr);
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
            else node= (cmp < 0? RBHASH_LEFT(node) : RBHASH_RIGHT(node));
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
static bool fm_fieldset_rbhash_structcheck_31(pTHX_ uint32_t *rbhash, size_t capacity, fm_fieldinfo_t ** elemdata, size_t max_el) {
   size_t n_buckets= FM_RBHASH_TABLE_BUCKETS(capacity), node;
   size_t el_hashcode, i_hashcode;
   int cmp, i, depth, blackcount;
   const char *err_msg;
   uint32_t *bucket, *table= rbhash + (1 + capacity)*2, err_node;
   bool success= true;
   for (bucket= table + n_buckets - 1; bucket >= table; bucket--) {
      if (*bucket > max_el) {
         warn("Bucket %ld refers to element %ld which is greater than max_el %ld", (long)(bucket-table), (long)*bucket, (long)max_el);
         success= false;
      } else if (*bucket) {
         if (!fm_rbhash_treecheck_31(rbhash, max_el, *bucket, 0,
            NULL, &blackcount, &err_msg, &err_node
         )) {
            fm_rbhash_treeprint_31(rbhash, max_el, *bucket, err_node, stderr);
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
            else node= (cmp < 0? RBHASH_LEFT(node) : RBHASH_RIGHT(node));
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
bool fm_fieldset_rbhash_structcheck(pTHX_ void* rbhash, size_t capacity, fm_fieldinfo_t ** elemdata, size_t max_el) {
   if (capacity <= 0x7F)
      return fm_fieldset_rbhash_structcheck_7(aTHX_ (uint8_t*)rbhash, capacity, elemdata, max_el);
   if (capacity <= 0x7FFF)
      return fm_fieldset_rbhash_structcheck_15(aTHX_ (uint16_t*)rbhash, capacity, elemdata, max_el);
   if (capacity <= 0x7FFFFFFF)
      return fm_fieldset_rbhash_structcheck_31(aTHX_ (uint32_t*)rbhash, capacity, elemdata, max_el);
   return false;
}
void fm_rbhash_print(void *rbhash, size_t capacity, FILE *out) {
   size_t n_buckets= FM_RBHASH_TABLE_BUCKETS(capacity), node, used= 0, collision= 0;
   fprintf(out, "# rbhash for %ld elements, %ld hash buckets\n", (long) capacity, (long) n_buckets);
   if (capacity <= 0x7F ) {
      uint8_t *nodes= (uint8_t*) rbhash;
      uint8_t *table= nodes + (1 + capacity)*2;
      int i;
      for (i= 0; i < n_buckets; i++) {
         if (i && (i & 0xF) == 0)
            fprintf(out, "# bucket 0x%lx\n", i);
         if (table[i]) {
            ++used;
            collision += fm_rbhash_treeprint_7(rbhash, capacity, table[i], 0, out) - 1;
         } else
            fprintf(out, "-\n");
      }
   }
   else if (capacity <= 0x7FFF ) {
      uint16_t *nodes= (uint16_t*) rbhash;
      uint16_t *table= nodes + (1 + capacity)*2;
      int i;
      for (i= 0; i < n_buckets; i++) {
         if (i && (i & 0xF) == 0)
            fprintf(out, "# bucket 0x%lx\n", i);
         if (table[i]) {
            ++used;
            collision += fm_rbhash_treeprint_15(rbhash, capacity, table[i], 0, out) - 1;
         } else
            fprintf(out, "-\n");
      }
   }
   else if (capacity <= 0x7FFFFFFF ) {
      uint32_t *nodes= (uint32_t*) rbhash;
      uint32_t *table= nodes + (1 + capacity)*2;
      int i;
      for (i= 0; i < n_buckets; i++) {
         if (i && (i & 0xF) == 0)
            fprintf(out, "# bucket 0x%lx\n", i);
         if (table[i]) {
            ++used;
            collision += fm_rbhash_treeprint_31(rbhash, capacity, table[i], 0, out) - 1;
         } else
            fprintf(out, "-\n");
      }
   }
   fprintf(out, "# used %ld / %ld buckets, %ld collisions\n", (long) used, (long) n_buckets, (long) collision);
}
// Look up the search_key in the hashtable, walk the tree of conflicts, and
// return the element index which matched.
size_t fm_fieldstorage_map_rbhash_find(void *rbhash, size_t capacity, fm_fieldstorage_t ** elemdata, fm_fieldset_t * search_key) {
   size_t n_buckets= FM_RBHASH_TABLE_BUCKETS(capacity);
   size_t el_hashcode, key_hashcode;
   int cmp;
   if (!n_buckets) return 0;
   key_hashcode= ( (size_t)(search_key) );
    if (capacity <= 0x7F) {
      uint8_t node, *bucket= ((uint8_t *)rbhash) + (1 + capacity)*2 + (key_hashcode % n_buckets);
      if ((node= *bucket)) {
         do {
            el_hashcode= ( (size_t)((elemdata)[(node)-1]->fieldset) );
            cmp= (key_hashcode == el_hashcode)? (( (search_key) < ((elemdata)[(node)-1]->fieldset)? -1 : (search_key) == ((elemdata)[(node)-1]->fieldset)? 0 : 1 ))
               : key_hashcode < el_hashcode? -1 : 1;
            if (!cmp) return node;
            node= ((uint8_t *)rbhash)[ node*2 + (cmp < 0? 0 : 1) ] >> 1;
         } while (node);
      }
   }
   else  if (capacity <= 0x7FFF) {
      uint16_t node, *bucket= ((uint16_t *)rbhash) + (1 + capacity)*2 + (key_hashcode % n_buckets);
      if ((node= *bucket)) {
         do {
            el_hashcode= ( (size_t)((elemdata)[(node)-1]->fieldset) );
            cmp= (key_hashcode == el_hashcode)? (( (search_key) < ((elemdata)[(node)-1]->fieldset)? -1 : (search_key) == ((elemdata)[(node)-1]->fieldset)? 0 : 1 ))
               : key_hashcode < el_hashcode? -1 : 1;
            if (!cmp) return node;
            node= ((uint16_t *)rbhash)[ node*2 + (cmp < 0? 0 : 1) ] >> 1;
         } while (node);
      }
   }
   else  if (capacity <= 0x7FFFFFFF) {
      uint32_t node, *bucket= ((uint32_t *)rbhash) + (1 + capacity)*2 + (key_hashcode % n_buckets);
      if ((node= *bucket)) {
         do {
            el_hashcode= ( (size_t)((elemdata)[(node)-1]->fieldset) );
            cmp= (key_hashcode == el_hashcode)? (( (search_key) < ((elemdata)[(node)-1]->fieldset)? -1 : (search_key) == ((elemdata)[(node)-1]->fieldset)? 0 : 1 ))
               : key_hashcode < el_hashcode? -1 : 1;
            if (!cmp) return node;
            node= ((uint32_t *)rbhash)[ node*2 + (cmp < 0? 0 : 1) ] >> 1;
         } while (node);
      }
   }
   return 0;
}
bool fm_fieldstorage_map_rbhash_reindex(void *rbhash, size_t capacity, fm_fieldstorage_t ** elemdata, size_t el_i, size_t last_i) {
   size_t n_buckets= FM_RBHASH_TABLE_BUCKETS(capacity);
   size_t el_hashcode, new_hashcode, pos;
   IV cmp;
   if (el_i < 1 || last_i > capacity || !n_buckets)
      return false;
   if (capacity <= 0x7F) {
      uint8_t *bucket, node, tree_ref, parents[1+16], err_node;
      const char *err_msg;
      for (; el_i <= last_i; el_i++) {
         new_hashcode= ( (size_t)((elemdata)[(el_i)-1]->fieldset) );
         bucket= ((uint8_t *)rbhash) + (1 + capacity)*2 + new_hashcode % n_buckets;
         if (!(node= *bucket))
            *bucket= el_i;
         else {
            // red/black insert
            pos= 0;
            assert(node < el_i);
            do {
               parents[++pos]= node;
               el_hashcode= ( (size_t)((elemdata)[(node)-1]->fieldset) );
               cmp= new_hashcode == el_hashcode? (( ((elemdata)[(el_i)-1]->fieldset) < ((elemdata)[(node)-1]->fieldset)? -1 : ((elemdata)[(el_i)-1]->fieldset) == ((elemdata)[(node)-1]->fieldset)? 0 : 1 ))
                  : new_hashcode < el_hashcode? -1 : 1;
               tree_ref= node*2 + (cmp < 0? 0 : 1);
               node= ((uint8_t *)rbhash)[tree_ref] >> 1;
            } while (node && pos < 16);
            if (pos > 16) {
               assert(pos <= 16);
               return false; // fatal error, should never happen unless datastruct corrupt
            }
            // Set left or right pointer of node to new node
            ((uint8_t *)rbhash)[tree_ref] |= el_i << 1;
            // Set color of new node to red. other fields should be initialized to zero already
            // Note that this is never the root of the tree because that happens automatically
            // above when *bucket= el_i and node[el_i] is assumed to be zeroed (black) already.
            ((uint8_t *)rbhash)[ el_i*2 ]= 1;
            if (pos > 1) { // no need to balance unless more than 1 parent
               parents[0]= 0; // mark end of list
               fm_rbhash_rb_balance_7((uint8_t *)rbhash, parents+pos);
               *bucket= parents[1]; // may have changed after tree balance
               // tree root is always black
               ((uint8_t *)rbhash)[ parents[1]*2 ]= ((uint8_t *)rbhash)[ parents[1]*2 ] >> 1 << 1; 
            }
         }
         if (!fm_rbhash_treecheck_7(rbhash, el_i, *bucket, 0,
            NULL, NULL, &err_msg, &err_node
         )) {
            fm_rbhash_treeprint_7(rbhash, capacity, *bucket, err_node, stderr);
            warn("Tree rooted at %ld is corrupt, %s at node %d", (long) *bucket, err_msg, (long) err_node);
            return false;
         }
      }
      return true;
   }
   if (capacity <= 0x7FFF) {
      uint16_t *bucket, node, tree_ref, parents[1+32], err_node;
      const char *err_msg;
      for (; el_i <= last_i; el_i++) {
         new_hashcode= ( (size_t)((elemdata)[(el_i)-1]->fieldset) );
         bucket= ((uint16_t *)rbhash) + (1 + capacity)*2 + new_hashcode % n_buckets;
         if (!(node= *bucket))
            *bucket= el_i;
         else {
            // red/black insert
            pos= 0;
            assert(node < el_i);
            do {
               parents[++pos]= node;
               el_hashcode= ( (size_t)((elemdata)[(node)-1]->fieldset) );
               cmp= new_hashcode == el_hashcode? (( ((elemdata)[(el_i)-1]->fieldset) < ((elemdata)[(node)-1]->fieldset)? -1 : ((elemdata)[(el_i)-1]->fieldset) == ((elemdata)[(node)-1]->fieldset)? 0 : 1 ))
                  : new_hashcode < el_hashcode? -1 : 1;
               tree_ref= node*2 + (cmp < 0? 0 : 1);
               node= ((uint16_t *)rbhash)[tree_ref] >> 1;
            } while (node && pos < 32);
            if (pos > 32) {
               assert(pos <= 32);
               return false; // fatal error, should never happen unless datastruct corrupt
            }
            // Set left or right pointer of node to new node
            ((uint16_t *)rbhash)[tree_ref] |= el_i << 1;
            // Set color of new node to red. other fields should be initialized to zero already
            // Note that this is never the root of the tree because that happens automatically
            // above when *bucket= el_i and node[el_i] is assumed to be zeroed (black) already.
            ((uint16_t *)rbhash)[ el_i*2 ]= 1;
            if (pos > 1) { // no need to balance unless more than 1 parent
               parents[0]= 0; // mark end of list
               fm_rbhash_rb_balance_15((uint16_t *)rbhash, parents+pos);
               *bucket= parents[1]; // may have changed after tree balance
               // tree root is always black
               ((uint16_t *)rbhash)[ parents[1]*2 ]= ((uint16_t *)rbhash)[ parents[1]*2 ] >> 1 << 1; 
            }
         }
         if (!fm_rbhash_treecheck_15(rbhash, el_i, *bucket, 0,
            NULL, NULL, &err_msg, &err_node
         )) {
            fm_rbhash_treeprint_15(rbhash, capacity, *bucket, err_node, stderr);
            warn("Tree rooted at %ld is corrupt, %s at node %d", (long) *bucket, err_msg, (long) err_node);
            return false;
         }
      }
      return true;
   }
   if (capacity <= 0x7FFFFFFF) {
      uint32_t *bucket, node, tree_ref, parents[1+64], err_node;
      const char *err_msg;
      for (; el_i <= last_i; el_i++) {
         new_hashcode= ( (size_t)((elemdata)[(el_i)-1]->fieldset) );
         bucket= ((uint32_t *)rbhash) + (1 + capacity)*2 + new_hashcode % n_buckets;
         if (!(node= *bucket))
            *bucket= el_i;
         else {
            // red/black insert
            pos= 0;
            assert(node < el_i);
            do {
               parents[++pos]= node;
               el_hashcode= ( (size_t)((elemdata)[(node)-1]->fieldset) );
               cmp= new_hashcode == el_hashcode? (( ((elemdata)[(el_i)-1]->fieldset) < ((elemdata)[(node)-1]->fieldset)? -1 : ((elemdata)[(el_i)-1]->fieldset) == ((elemdata)[(node)-1]->fieldset)? 0 : 1 ))
                  : new_hashcode < el_hashcode? -1 : 1;
               tree_ref= node*2 + (cmp < 0? 0 : 1);
               node= ((uint32_t *)rbhash)[tree_ref] >> 1;
            } while (node && pos < 64);
            if (pos > 64) {
               assert(pos <= 64);
               return false; // fatal error, should never happen unless datastruct corrupt
            }
            // Set left or right pointer of node to new node
            ((uint32_t *)rbhash)[tree_ref] |= el_i << 1;
            // Set color of new node to red. other fields should be initialized to zero already
            // Note that this is never the root of the tree because that happens automatically
            // above when *bucket= el_i and node[el_i] is assumed to be zeroed (black) already.
            ((uint32_t *)rbhash)[ el_i*2 ]= 1;
            if (pos > 1) { // no need to balance unless more than 1 parent
               parents[0]= 0; // mark end of list
               fm_rbhash_rb_balance_31((uint32_t *)rbhash, parents+pos);
               *bucket= parents[1]; // may have changed after tree balance
               // tree root is always black
               ((uint32_t *)rbhash)[ parents[1]*2 ]= ((uint32_t *)rbhash)[ parents[1]*2 ] >> 1 << 1; 
            }
         }
         if (!fm_rbhash_treecheck_31(rbhash, el_i, *bucket, 0,
            NULL, NULL, &err_msg, &err_node
         )) {
            fm_rbhash_treeprint_31(rbhash, capacity, *bucket, err_node, stderr);
            warn("Tree rooted at %ld is corrupt, %s at node %d", (long) *bucket, err_msg, (long) err_node);
            return false;
         }
      }
      return true;
   }
   return false; // happens if capacity is out of bounds
}
// Verify that every filled bucket refers to a valid tree,
// and that every node can be found.
static bool fm_fieldstorage_map_rbhash_structcheck_7(pTHX_ uint8_t *rbhash, size_t capacity, fm_fieldstorage_t ** elemdata, size_t max_el) {
   size_t n_buckets= FM_RBHASH_TABLE_BUCKETS(capacity), node;
   size_t el_hashcode, i_hashcode;
   int cmp, i, depth, blackcount;
   const char *err_msg;
   uint8_t *bucket, *table= rbhash + (1 + capacity)*2, err_node;
   bool success= true;
   for (bucket= table + n_buckets - 1; bucket >= table; bucket--) {
      if (*bucket > max_el) {
         warn("Bucket %ld refers to element %ld which is greater than max_el %ld", (long)(bucket-table), (long)*bucket, (long)max_el);
         success= false;
      } else if (*bucket) {
         if (!fm_rbhash_treecheck_7(rbhash, max_el, *bucket, 0,
            NULL, &blackcount, &err_msg, &err_node
         )) {
            fm_rbhash_treeprint_7(rbhash, max_el, *bucket, err_node, stderr);
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
            else node= (cmp < 0? RBHASH_LEFT(node) : RBHASH_RIGHT(node));
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
static bool fm_fieldstorage_map_rbhash_structcheck_15(pTHX_ uint16_t *rbhash, size_t capacity, fm_fieldstorage_t ** elemdata, size_t max_el) {
   size_t n_buckets= FM_RBHASH_TABLE_BUCKETS(capacity), node;
   size_t el_hashcode, i_hashcode;
   int cmp, i, depth, blackcount;
   const char *err_msg;
   uint16_t *bucket, *table= rbhash + (1 + capacity)*2, err_node;
   bool success= true;
   for (bucket= table + n_buckets - 1; bucket >= table; bucket--) {
      if (*bucket > max_el) {
         warn("Bucket %ld refers to element %ld which is greater than max_el %ld", (long)(bucket-table), (long)*bucket, (long)max_el);
         success= false;
      } else if (*bucket) {
         if (!fm_rbhash_treecheck_15(rbhash, max_el, *bucket, 0,
            NULL, &blackcount, &err_msg, &err_node
         )) {
            fm_rbhash_treeprint_15(rbhash, max_el, *bucket, err_node, stderr);
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
            else node= (cmp < 0? RBHASH_LEFT(node) : RBHASH_RIGHT(node));
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
static bool fm_fieldstorage_map_rbhash_structcheck_31(pTHX_ uint32_t *rbhash, size_t capacity, fm_fieldstorage_t ** elemdata, size_t max_el) {
   size_t n_buckets= FM_RBHASH_TABLE_BUCKETS(capacity), node;
   size_t el_hashcode, i_hashcode;
   int cmp, i, depth, blackcount;
   const char *err_msg;
   uint32_t *bucket, *table= rbhash + (1 + capacity)*2, err_node;
   bool success= true;
   for (bucket= table + n_buckets - 1; bucket >= table; bucket--) {
      if (*bucket > max_el) {
         warn("Bucket %ld refers to element %ld which is greater than max_el %ld", (long)(bucket-table), (long)*bucket, (long)max_el);
         success= false;
      } else if (*bucket) {
         if (!fm_rbhash_treecheck_31(rbhash, max_el, *bucket, 0,
            NULL, &blackcount, &err_msg, &err_node
         )) {
            fm_rbhash_treeprint_31(rbhash, max_el, *bucket, err_node, stderr);
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
            else node= (cmp < 0? RBHASH_LEFT(node) : RBHASH_RIGHT(node));
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
bool fm_fieldstorage_map_rbhash_structcheck(pTHX_ void* rbhash, size_t capacity, fm_fieldstorage_t ** elemdata, size_t max_el) {
   if (capacity <= 0x7F)
      return fm_fieldstorage_map_rbhash_structcheck_7(aTHX_ (uint8_t*)rbhash, capacity, elemdata, max_el);
   if (capacity <= 0x7FFF)
      return fm_fieldstorage_map_rbhash_structcheck_15(aTHX_ (uint16_t*)rbhash, capacity, elemdata, max_el);
   if (capacity <= 0x7FFFFFFF)
      return fm_fieldstorage_map_rbhash_structcheck_31(aTHX_ (uint32_t*)rbhash, capacity, elemdata, max_el);
   return false;
}
/* END GENERATED FM_RBHASH IMPLEMENTATION */
