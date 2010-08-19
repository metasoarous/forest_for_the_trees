require "tree_node.rb"
require "forest_floor.rb"

# Specify this +acts_as+ extension if you want to model a tree structure by providing a parent association and a children
# association. This requires that you have a foreign key column, which by default is called +parent_id+ and a string or 
# text column called +dotted_ids+ which will be used to store the path to each node in the tree.
#
#   class Category < ActiveRecord::Base
#     acts_as_tree_with_dotted_ids :order => "name"
#   end
#
#   Example:
#   root
#    \_ child1
#         \_ subchild1
#         \_ subchild2
#
#   root      = Category.create("name" => "root")
#   child1    = root.children.create("name" => "child1")
#   subchild1 = child1.children.create("name" => "subchild1")
#
#   root.parent   # => nil
#   child1.parent # => root
#   root.children # => [child1]
#   root.children.first.children.first # => subchild1
#
# In addition to the parent and children associations, the following instance methods are added to the class
# after calling <tt>acts_as_tree_with_dotted_ids</tt>:
# * <tt>siblings</tt> - Returns all the children of the parent, excluding the current node (<tt>[subchild2]</tt> when called on <tt>subchild1</tt>)
# * <tt>self_and_siblings</tt> - Returns all the children of the parent, including the current node (<tt>[subchild1, subchild2]</tt> when called on <tt>subchild1</tt>)
# * <tt>ancestors</tt> - Returns all the ancestors of the current node (<tt>[child1, root]</tt> when called on <tt>subchild2</tt>)
# * <tt>self_and_ancestors</tt> - Returns all the ancestors of the current node (<tt>[subchild2, child1, root]</tt> when called on <tt>subchild2</tt>)
# * <tt>root</tt> - Returns the root of the current node (<tt>root</tt> when called on <tt>subchild2</tt>)
# * <tt>depth</tt> - Returns the depth of the current node starting from 0 as the depth of root nodes.
#
# The following class methods are added
# * <tt>traverse</tt> - depth-first traversal of the tree (warning: it does *not* rely on the dotted_ids as it is used to rebuild the tree)
# * <tt>rebuild_dotted_ids!</tt> - rebuilt the dotted IDs for the whole tree, use this once to migrate an existing +acts_as_tree+ model to +acts_as_tree_with_dotted_ids+
module ForestForTheTrees
  
  module ActivationMethods
    # Configuration options are:
    #
    # * <tt>foreign_key</tt> - specifies the column name to use for tracking of the tree (default: +parent_id+)
    # * <tt>order</tt> - makes it possible to sort the children according to this SQL snippet.
    # * <tt>counter_cache</tt> - keeps a count in a +children_count+ column if set to +true+ (default: +false+).
    def acts_as_tree_node(options = {}, &b)
      configuration = { :foreign_key => "parent_id", :order => nil, :counter_cache => nil }
      configuration.update(options) if options.is_a?(Hash)

      belongs_to :parent, :class_name => name, :foreign_key => configuration[:foreign_key], :counter_cache => configuration[:counter_cache]


      has_many :children, :class_name => name, :foreign_key => configuration[:foreign_key], 
        :order => configuration[:order], :dependent => :destroy, &b

      class_eval <<-EOV
        
        include ForestForTheTrees::TreeNode::InstanceMethods
        extend ForestForTheTrees::TreeNode::ClassMethods
        
        def self.order
          @@order
        end
        
        @@order = #{configuration[:order]}
        
        def self.roots
          res = find(:all, :conditions => "#{configuration[:foreign_key]} IS NULL", :order => #{configuration[:order].nil? ? "nil" : %Q{"#{configuration[:order]}"}})
        end

        def self.root
          find(:first, :conditions => "#{configuration[:foreign_key]} IS NULL", :order => #{configuration[:order].nil? ? "nil" : %Q{"#{configuration[:order]}"}})
        end

        def parent_foreign_key_changed?
          #{configuration[:foreign_key]}_changed?
        end
      EOV
      
      
      after_save                 :assign_dotted_ids
      after_update               :update_dotted_ids
      
    end
    
    # Configuration options are:
    #
    # * <tt></tt> - specifies the model which these class objects serve as the forest floor for
    # * <tt>order</tt> - specifies the order of the tree roots (defaults to whatever is in the tree_node class)
    def acts_as_forest_floor(tree_class, options = {}, &b)
      
      has_many tree_class.to_s.plural.to_sym, options
      
      tree_class = eval(tree_class.to_s.camelize)
      options[:order] ||= tree_class.order
      @@order = options[:order]
      
      has_many tree_class.to_s.plural.to_sym, options

      has_many :children, :class_name => tree_class, :foreign_key => configuration[:foreign_key], 
        :order => configuration[:order], :dependent => :destroy, &b


      class_eval <<-EOV
        include ForestForTheTrees::ForestFloor::InstanceMethods
        extend ForestForTheTrees::ForestFloor::ClassMethods



        def self.root
          find(:first, :conditions => "#{configuration[:foreign_key]} IS NULL", :order => #{configuration[:order].nil? ? "nil" : %Q{"#{configuration[:order]}"}})
        end

        def parent_foreign_key_changed?
          #{configuration[:foreign_key]}_changed?
        end

      EOV
    end
  end
end

