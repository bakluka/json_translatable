module Translatable
  module DatabaseStrategies
    class SQLite < Base
      def column_type
        :json
      end

      def migration_example(table_name, column_name)
        "add_column :#{table_name}, :#{column_name}, :json, default: '{}', null: false"
      end

      def where_translations_scope(model_class, attributes, locales: [], case_sensitive: false)
        column_name = model_class.translations_column_name
        search_locales = locales.present? ? locales.map(&:to_s) : model_class.translatable_locales.map(&:to_s)
        
        return model_class.none if attributes.blank?
        
        conditions = []
        bind_values = []
        
        search_locales.each do |locale|
          attributes.each do |field, value|
            json_path = "$.#{locale}.#{field}"
            
            if case_sensitive
              conditions << "json_extract(#{column_name}, ?) = ?"
              bind_values += [json_path, value.to_s]
            else
              conditions << "json_extract(#{column_name}, ?) LIKE ? COLLATE NOCASE"
              bind_values += [json_path, value.to_s]
            end
          end
        end
        
        where_clause = conditions.join(' OR ')
        model_class.where(where_clause, *bind_values)
      end
    end
  end
end
