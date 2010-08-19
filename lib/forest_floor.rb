module ForestForTheTrees
  module ForestFloor
    
    module ClassMethods
      
    end
    
    module InstanceMethods
      def roots
        find(:all, :conditions => "#{configuration[:foreign_key]} IS NULL AND #{self.class.class_name.foreign_key} = #{self.id}", :order => @@order)
      end
      
      
    end
    
  end
end