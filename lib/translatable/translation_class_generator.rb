module Translatable
  class TranslationClassGenerator
    def self.generate_for(model_class_name)
      class_name = "#{model_class_name}Translation"
      
      return Translatable.const_get(class_name) if Translatable.const_defined?(class_name)
      
      model_class = Object.const_get(model_class_name)
      translatable_fields = model_class.translatable_fields
      
      translation_class = Class.new do
        include Enumerable

        translatable_fields.each do |field|
          define_method(field) do
            @attributes[field]
          end
        end
        
        def initialize(attributes = {})
          @attributes = attributes.dup
          @locale = attributes[:locale]
        end
        
        def locale
          @locale
        end
        
        def [](key)
          @attributes[key.to_sym] 
        end
        
        def to_h
          @attributes.dup
        end

        def each(&block)
          return enum_for(:each) unless block_given?
          
          @attributes.each do |key, value|
            next if key == :locale
            yield(key, value)
          end
        end

        def keys
          @attributes.keys.reject { |k| k == :locale }
        end
        
        def values
          keys.map { |key| @attributes[key] }
        end
        
        def empty?
          keys.empty? || values.all?(&:blank?)
        end
        
        def size
          keys.size
        end
        
        alias_method :length, :size
        
        def inspect
          fields = @attributes.reject { |k, _| k == :locale }
                              .map { |field, value| "#{field}: #{value.inspect.to_s[0, 30]}" }
                              .append("locale: #{@locale.inspect}")
                              .join(', ')
          "#<#{self.class} #{fields}>"
        end
        
        def to_s
          inspect
        end
      end
      
      translation_class.define_singleton_method(:name) { class_name }
      
      Translatable.const_set(class_name, translation_class)
      translation_class
    end
  end
end
