require_dependency 'query'

module TimeTrackerQueryPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods) # obj.method

    base.class_eval do
      alias_method_chain :available_filters, :time_tracker
      alias_method_chain :joins_for_order_statement, :time_tracker

      base.add_available_column(QueryColumn.new(:spent_on, :sortable => "#{TimeEntry.table_name}.spent_on", :default_order => 'desc', :caption => :field_time_trackers_spent_on))
      base.add_available_column(QueryColumn.new(:time_trackers_buttons))
    end
  end

  module InstanceMethods # obj.method
    # add new filters
    def available_filters_with_time_tracker
      return @available_filters if @available_filters
      @available_filters = available_filters_without_time_tracker

      @available_filters['spent_by'] = {:name => l(:field_spent_by), :type => :list, :order => 21, :values => @available_filters['author_id'][:values] }
      @available_filters['spent_on'] = {:name => l(:field_time_trackers_spent_on), :type => :date, :order => 22}
      @available_filters['updated_by'] = { :name => l(:field_updated_by), :type => :list, :order => 9, :values => @available_filters['author_id'][:values] }

      @available_filters
    end

    # Additional joins required for the given sort options
    def joins_for_order_statement_with_time_tracker(order_options)
      joins = []
      joins << joins_for_order_statement_without_time_tracker(order_options)
      if order_options && order_options.include?('spent_on')
        joins << "LEFT OUTER JOIN (SELECT `#{TimeEntry.table_name}`.issue_id, MAX(spent_on) spent_on FROM `time_entries` WHERE `time_entries`.user_id = #{User.current.id.to_s}"
        joins << "GROUP BY issue_id) time_entries ON `#{TimeEntry.table_name}`.issue_id = `#{Issue.table_name}`.id"
      end
      joins.any? ? joins.join(' ') : nil
    end

  end
end

class Query < ActiveRecord::Base
  # SQL
  def sql_for_spent_by_field(field, operator, value)
    db_table = TimeEntry.table_name

    if value.include?('me') && value.delete('me')
      if User.current.logged?
        value.push(User.current.id.to_s)
      elsif value.empty?
        value.push("0")
      end
    end
    op = ('=' == operator)? 'IN' : 'NOT IN'

    sql = "#{Issue.table_name}.id #{op} (SELECT #{db_table}.issue_id FROM #{db_table} WHERE " + sql_for_field(field, '=', value, db_table, 'user_id') + ")"

    return sql
  end

  def sql_for_spent_on_field(field, operator, value)
    db_table = TimeEntry.table_name

    sql = "#{Issue.table_name}.id IN (SELECT #{db_table}.issue_id FROM #{db_table} WHERE " + sql_for_field(field, operator, value, db_table, 'spent_on') + ")"
    return sql
  end

  def sql_for_updated_by_field(field, operator, value)
    db_table = Journal.table_name

    if value.include?('me') && value.delete('me')
      if User.current.logged?
        value.push(User.current.id.to_s)
      elsif value.empty?
        value.push("0")
      end
    end
    op = ('=' == operator)? 'IN' : 'NOT IN'

    sql = "#{Issue.table_name}.`id` #{op} (SELECT `#{db_table}`.`journalized_id` FROM `#{db_table}` WHERE " +
      sql_for_field(field, '=', value, db_table, 'user_id') + " AND `#{db_table}`.`journalized_type` = 'Issue')"

    return sql
  end

end

Query.send(:include, TimeTrackerQueryPatch)
