module Translatable
  module Concern
    extend ActiveSupport::Concern

    class Error < StandardError; end 
    class MissingTranslationsColumnError < Error; end
    class UndefinedTranslatableFieldsError < Error; end
    class DatabaseColumnConflictError < Error; end

    included do
      class_attribute :translatable_fields, instance_writer: false, default: []
      class_attribute :translatable_locales, instance_writer: false, default: []
      class_attribute :translation_validations, instance_writer: false, default: []
      class_attribute :translations_column_name, instance_writer: false, default: :translations

      validate :validate_translations_structure
      validate :validate_translation_fields

      after_initialize -> { 
        self.class.validate_translatable

        column_name = self.class.translations_column_name.to_s
        current_translations = send(column_name) || {}
        
        self.class.translatable_locales.map(&:to_s).uniq.each do |locale|
          current_translations[locale] ||= {}
          self.class.translatable_fields.map(&:to_s).uniq.each do |field|
            unless current_translations[locale].key?(field)
              current_translations[locale][field] = nil
            end
          end
        end
        
        send("#{column_name}=", current_translations)
      }

      def translate(locale = I18n.locale)
        translation_class = self.class.translation_class
        column_name = self.class.translations_column_name.to_s
        translations_data = send(column_name) || {}
        
        translated_data = self.class.translatable_fields.index_with do |field|
          translations_data.dig(locale.to_s, field.to_s)
        end

        translation_class.new(translated_data.merge(locale: locale.to_sym))
      end

      private

      def validate_translations_structure
        column_name = self.class.translations_column_name.to_s
        translations_data = send(column_name)
        return unless translations_data.present?
        
        translations_data.each do |locale, fields|
          unless translatable_locales.map(&:to_s).include?(locale)
            errors.add(column_name.to_sym, "contains invalid locale: #{locale}")
          end
          
          next unless fields.is_a?(Hash)
          
          fields.each_key do |field|
            unless translatable_fields.map(&:to_s).include?(field)
              errors.add(column_name.to_sym, "contains invalid field: #{field} for locale #{locale}")
            end
          end
        end
      end

      def validate_translation_fields
        column_name = self.class.translations_column_name.to_s
        translations_data = send(column_name) || {}
        
        self.class.translation_validations.each do |validation|
          field = validation[:field]
          options = validation[:options]
          locales = validation[:locales] || self.class.translatable_locales
          
          locales.each do |locale|
            field_value = translations_data.dig(locale.to_s, field.to_s)
            error_key = "#{column_name}.#{locale}.#{field}"

            if options[:custom]
              options[:custom].call(self, locale, field, field_value)
            end
            
            if options[:presence] && field_value.blank?
              errors.add(column_name.to_sym, :blank, translation_key: error_key)
            end
            
            if options[:length] && field_value.present?
              length_options = options[:length]
              if length_options[:minimum] && field_value.length < length_options[:minimum]
                errors.add(column_name.to_sym, :too_short, count: length_options[:minimum], translation_key: error_key)
              end
              if length_options[:maximum] && field_value.length > length_options[:maximum]
                errors.add(column_name.to_sym, :too_long, count: length_options[:maximum], translation_key: error_key)
              end
            end
            
            if options[:format] && field_value.present?
              format_options = options[:format]
              if format_options[:with] && !field_value.match?(format_options[:with])
                errors.add(column_name.to_sym, :invalid, translation_key: error_key)
              end
            end
          end
        end
      end
    end

    class_methods do
      def translatable(*fields, locales: nil, column: nil)
        resolved_locales = locales || Translatable.configuration.default_locales.call
        resolved_column = column || Translatable.configuration.default_column_name
        
        self.translatable_fields = fields.map(&:to_sym)
        self.translatable_locales = resolved_locales.map(&:to_sym)
        self.translations_column_name = resolved_column.to_sym
        
        strategy = database_strategy
        attribute resolved_column.to_sym, strategy.column_type, default: {}
      end

      def where_translations(attributes, locales: [], case_sensitive: false)
        return none if attributes.blank?
        
        strategy = database_strategy
        strategy.where_translations_scope(self, attributes, locales: locales, case_sensitive: case_sensitive)
      end

      def validates_translation(*fields, **options, &block)
        fields.flatten.each do |field|
          if !translatable_fields.include?(field.to_sym)
            raise ArgumentError, "Field :#{field} is not defined as translatable. " \
                                "Available translatable fields: #{translatable_fields.map(&:inspect).join(', ')}"
          end

          valid_options = [:presence, :length, :format, :locales]
          invalid_options = options.keys - valid_options
          if invalid_options.any?
            raise ArgumentError, "Invalid validation option(s): #{invalid_options.map(&:inspect).join(', ')}. " \
                                "Valid options are: #{valid_options.map(&:inspect).join(', ')}"
          end

          if options[:locales]
            invalid_locales = options[:locales].map(&:to_sym) - translatable_locales
            if invalid_locales.any?
              raise ArgumentError, "Invalid locale(s): #{invalid_locales.map(&:inspect).join(', ')}. " \
                                  "Available locales: #{translatable_locales.map(&:inspect).join(', ')}"
            end
          end
          
          if block_given?
            validation_options = options.merge(custom: block)
          else
            validation_options = options
          end
          
          locales = validation_options.delete(:locales)
          
          self.translation_validations = self.translation_validations + [{
            field: field.to_sym,
            options: validation_options,
            locales: locales&.map(&:to_sym)
          }]
        end
      end

      def translations_permit_list
        column_name = translations_column_name.to_s
        {
          column_name => self.translatable_locales.map do |locale|
            [locale.to_s, self.translatable_fields.map(&:to_s)]
          end.to_h
        }
      end

      def database_strategy
        @database_strategy ||= DatabaseStrategies::Base.for_adapter(connection.adapter_name)
      end

      def translation_class
        @translation_class ||= TranslationClassGenerator.generate_for(self.name)
      end

      def validate_translatable
        column_name = translations_column_name.to_s
        strategy = database_strategy
        
        unless self.column_names.include?(column_name) && 
               self.columns_hash[column_name]&.type == strategy.expected_column_type
          raise MissingTranslationsColumnError, 
                "Model #{self.name} is missing a '#{column_name}' #{strategy.column_type} column. " \
                "Please add it via a migration:\n#{strategy.migration_example(self.table_name, column_name)}"
        end
    
        unless self.respond_to?(:translatable_fields) && self.translatable_fields.present?
          raise UndefinedTranslatableFieldsError,
                "Model #{self.name} must call the class method `translatable` with field names. " \
                "Example: \n" \
                "class #{self.name} < ApplicationRecord\n" \
                "  include Translatable\n" \
                "  translatable :title, :content\n" \
                "end"
        end

        conflicting_columns = self.column_names.select { |column| self.translatable_fields.include?(column.to_sym) }
        if conflicting_columns.any?
          raise DatabaseColumnConflictError,
                "Model #{self.name} has database columns that conflict with translatable fields. " \
                "Translatable fields should not exist as actual database columns." \
                "\n\nConflicting columns: #{conflicting_columns.join(', ')}"
        end
      end
    end
  end
end
