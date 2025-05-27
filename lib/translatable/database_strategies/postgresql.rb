module Translatable
  module DatabaseStrategies
    class PostgreSQL < Base
      def column_type
        :jsonb
      end

      def expected_column_type
        :jsonb
      end

      def migration_example(table_name, column_name)
        "add_column :#{table_name}, :#{column_name}, :jsonb, default: {}, null: false"
      end

      def validate_index_recommendation(model_class, column_name)
        return if @gin_index_warning_issued

        indexes = model_class.connection.indexes(model_class.table_name)
        has_gin_index = indexes.any? do |index|
          index.columns == [column_name.to_s] && index.using == :gin
        end

        unless has_gin_index
          Rails.logger.warn "TRANSLATABLE WARNING: Model #{model_class.name} is using the '#{column_name}' JSONB column " \
                            "without a GIN index. For optimal query performance, consider adding: \n" \
                            "add_index :#{model_class.table_name}, :#{column_name}, using: :gin, opclass: :jsonb_path_ops"
        end
        
        @gin_index_warning_issued = true
      end
    end
  end
end
