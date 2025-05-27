module Translatable
  module DatabaseStrategies
    class SQLite < Base
      def column_type
        :text
      end

      def expected_column_type
        :text
      end

      def migration_example(table_name, column_name)
        "add_column :#{table_name}, :#{column_name}, :text, default: '{}', null: false"
      end

      def validate_index_recommendation(model_class, column_name)
        nil
      end
    end
  end
end
