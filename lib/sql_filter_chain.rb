# SqlFilterChain
module SqlFilterChain
  def self.included base
    base.extend ClassMethods
  end

  module ClassMethods
    # Accepts named scopes as arguments, returns a new anonymous named
    # scope equivalent to chaining the named scopes together but does
    # it using temporary tables and evaluates them in sequence.
    #
    # >>> ModelName.sql_filter_chain(ModelName.named_scope_1, ModelName.named_scope_2)
    #  => [elems satisfying both named_scope1 and named_scope 2 conditions]
    def sql_filter_chain *scopes
      sql = self.send :construct_finder_sql, scopes.shift.current_scoped_methods[:find]
      scopes.each_with_index do |scope, index|
        # Wrap the existing query up into a sub-query
        sql = "select tmp#{index}.* from (#{sql}) as tmp#{index} "

        # Rewrite any joins and conditions for this additional filter
        # to be against the most recent temp table representing the
        # aggregated sub-query results.
        sql << "".tap do |tmp|
          self.send :add_joins!, tmp, scope.current_scoped_methods[:find][:joins], nil
        end.sub(/#{self.table_name}/, "tmp#{index}")
        self.send :add_conditions!, sql, scope.current_scoped_methods[:find][:conditions], nil
      end

      # Return a anonymous named scope representing a join table to be
      # used to filter the result set.
      self.scoped :joins => "inner join (select outer_tmp.id from (#{sql}) as outer_tmp) as join_filter on join_filter.id = #{self.table_name}.id"
    end
  end
end

ActiveRecord::Base.send(:include, SqlFilterChain)
