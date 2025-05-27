module Translatable
  module DatabaseStrategies
    class Base
      def self.for_adapter(adapter_name)
        case adapter_name.downcase
        when /postgresql/
          PostgreSQL.new
        when /mysql/
          MySQL.new
        when /sqlite/
          SQLite.new
        else
          raise ArgumentError, "Unsupported database adapter: #{adapter_name}"
        end
      end

      def column_type
        raise NotImplementedError, "Subclasses must implement column_type"
      end

      def expected_column_type
        raise NotImplementedError, "Subclasses must implement expected_column_type"
      end

      def migration_example(table_name, column_name)
        raise NotImplementedError, "Subclasses must implement migration_example"
      end

      def validate_index_recommendation(model_class, column_name)
        nil
      end
    end
  end
end