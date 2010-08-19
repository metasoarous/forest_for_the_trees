require 'forest_for_the_trees'

ActiveRecord::Base.send :extend, ForestForTheTrees::ActivationMethods
