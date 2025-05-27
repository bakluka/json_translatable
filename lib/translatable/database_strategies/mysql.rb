module Translatable
  module DatabaseStrategies
    class MySQL < Base
      def column_type
        :json
      end

      def expected_column_type
        :json
      end

      def migration_example(table_name, column_name)
        "add_column :#{table_name}, :#{column_name}, :json, null: false"
      end

      def validate_index_recommendation(model_class, column_name)
        return if @index_warning_issued

        Rails.logger.warn "TRANSLATABLE INFO: Model #{model_class.name} is using MySQL with JSON column '#{column_name}'. " \
                          "Consider adding functional indexes for frequently queried translation fields for better performance."
        
        @index_warning_issued = true
      end
    end
  end
end
