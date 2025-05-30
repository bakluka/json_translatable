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

      def where_translations_scope(model_class, attributes, locales: [], case_sensitive: false)
        column_name = model_class.translations_column_name
        search_locales = locales.present? ? locales.map(&:to_s) : model_class.translatable_locales.map(&:to_s)
        
        return model_class.none if attributes.blank?
        
        conditions = []
        bind_values = []
        
        if case_sensitive
          search_locales.each do |locale|
            locale_attributes = { locale => attributes }
            conditions << "JSON_CONTAINS(#{column_name}, ?)"
            bind_values << locale_attributes.to_json
          end
        else
          search_locales.each do |locale|
            attributes.each do |field, value|
              conditions << "UPPER(JSON_UNQUOTE(JSON_EXTRACT(#{column_name}, ?))) LIKE UPPER(?)"
              bind_values += ["$.#{locale}.#{field}", value.to_s]
            end
          end
        end
        
        where_clause = conditions.join(' OR ')
        model_class.where(where_clause, *bind_values)
      end
    end
  end
end
