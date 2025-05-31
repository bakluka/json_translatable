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

      def migration_example(table_name, column_name)
        raise NotImplementedError, "Subclasses must implement migration_example"
      end

      def where_translations_scope(model_class, attributes, locales: [], case_sensitive: false)
        raise NotImplementedError, "#{self.class.name} does not support where_translations yet"
      end
    end
  end
end