
module ForestForTheTrees
  module TreeNode
    module ClassMethods

      # Performs a depth-first traversal of the tree, yielding each node to the given block 
      def traverse(nodes = nil, &block)
        nodes ||= self.roots
        nodes.each do |node|
          yield node
          traverse(node.children, &block)
        end
      end

      # Traverse the whole tree from roots to leaves and rebuild the dotted_ids path
      # Call it from your migration to upgrade an existing acts_as_tree model.
      def rebuild_dotted_ids!
        transaction do
          traverse { |node| node.dotted_ids = nil; node.save! }
        end
      end

    end

    module InstanceMethods

      # Returns list of ancestors, starting from parent until root.
      #
      #   subchild1.ancestors # => [child1, root]
      def ancestors
        if self.dotted_ids
          ids = self.dotted_ids.split('.')[0...-1]
          self.class.find(:all, :conditions => {:id => ids}, :order => 'dotted_ids DESC')
        else
          node, nodes = self, []
          nodes << node = node.parent while node.parent
          nodes
        end
      end

      # 
      def self_and_ancestors
        [self] + ancestors
      end

      # Returns the root node of the tree.
      def root
        if self.dotted_ids
          self.class.find(self.dotted_ids.split('.').first)
        else
          node = self
          node = node.parent while node.parent
          node
        end
      end

      # Returns all siblings of the current node.
      #
      #   subchild1.siblings # => [subchild2]
      def siblings
        self_and_siblings - [self]
      end

      # Returns all siblings and a reference to the current node.
      #
      #   subchild1.self_and_siblings # => [subchild1, subchild2]
      def self_and_siblings
        #parent ? parent.children : self.class.roots
        self.class.find(:all, :conditions => {:parent_id => self.parent_id})
      end

      #
      # root.ancestor_of?(subchild1) # => true
      # subchild1.ancestor_of?(child1) # => false
      def ancestor_of?(node)
        node.dotted_ids.length > self.dotted_ids.length && node.dotted_ids.starts_with?(self.dotted_ids)
      end

      #
      # subchild1.descendant_of?(child1) # => true
      # root.descendant_of?(subchild1) # => false
      def descendant_of?(node)
        self.dotted_ids.length > node.dotted_ids.length && self.dotted_ids.starts_with?(node.dotted_ids)
      end

      # Returns all children of the current node
      # root.all_children # => [child1, subchild1, subchild2]
      def all_children
        find_all_children_with_dotted_ids
      end

      # Returns all children of the current node
      # root.self_and_all_children # => [root, child1, subchild1, subchild2]
      def self_and_all_children
        [self] + all_children
      end

      # Returns the depth of the node, root nodes have a depth of 0
      def depth
        self.dotted_ids.scan(/\./).size
      end
      
    protected

      # Tranforms a dotted_id string into a pattern usable with a SQL LIKE statement
      def dotted_id_like_pattern(prefix = nil)
        (prefix || self.dotted_ids) + '.%'
      end

      # Find all children with the given dotted_id prefix
      # *options* will be passed to to find(:all)
      # FIXME: use merge_conditions when it will be part of the public API
      def find_all_children_with_dotted_ids(prefix = nil, options = {})
        self.class.find(:all, options.update(:conditions => ['dotted_ids LIKE ?', dotted_id_like_pattern(prefix)]))
      end

      # Generates the dotted_ids for this node
      def build_dotted_ids
        self.parent ? "#{self.parent.dotted_ids}.#{self.id}" : self.id.to_s
      end

      # After create, adds the dotted id's
      def assign_dotted_ids
        self.update_attribute(:dotted_ids, build_dotted_ids) if self.dotted_ids.blank?
      end

      # After validation on update, rebuild dotted ids if necessary
      def update_dotted_ids
        return unless parent_foreign_key_changed?
        old_dotted_ids = self.dotted_ids
        old_dotted_ids_regex = Regexp.new("^#{Regexp.escape(old_dotted_ids)}(.*)")
        self.dotted_ids = build_dotted_ids
        replace_pattern = "#{self.dotted_ids}\\1"          
        find_all_children_with_dotted_ids(old_dotted_ids).each do |node|
          new_dotted_ids = node.dotted_ids.gsub(old_dotted_ids_regex, replace_pattern)
          node.update_attribute(:dotted_ids, new_dotted_ids)
        end
      end
      
    end
  end
end
