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

      def where_translations_scope(model_class, attributes, locales: [], case_sensitive: false)
        column_name = model_class.translations_column_name
        search_locales = locales.present? ? locales.map(&:to_s) : model_class.translatable_locales.map(&:to_s)
        
        return model_class.none if attributes.blank?
        
        conditions = []
        bind_values = []
        
        if case_sensitive
          search_locales.each do |locale|
            locale_attributes = { locale => attributes }
            conditions << "#{column_name} @> ?"
            bind_values << locale_attributes.to_json
          end
        else
          search_locales.each do |locale|
            attributes.each do |field, value|
              conditions << "(#{column_name} -> ? ->> ?) ILIKE ?"
              bind_values += [locale, field.to_s, value.to_s]
            end
          end
        end
        
        where_clause = conditions.join(' OR ')
        model_class.where(where_clause, *bind_values)
      end
    end
  end
end
