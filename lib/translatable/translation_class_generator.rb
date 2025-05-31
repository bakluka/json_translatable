module Translatable
  class TranslationClassGenerator
    def self.generate_for(model_class_name)
      class_name = "#{model_class_name}Translation"
      
      return Translatable.const_get(class_name) if Translatable.const_defined?(class_name)
      
      translation_class = Class.new do
        def initialize(attributes = {})
          @attributes = attributes.dup
          @locale = attributes[:locale]
        end
        
        def locale
          @locale
        end
        
        def method_missing(method_name, *args, &block)
          if @attributes.key?(method_name)
            @attributes[method_name]
          else
            super
          end
        end
        
        def respond_to_missing?(method_name, include_private = false)
          @attributes.key?(method_name) || super
        end
        
        def [](key)
          @attributes[key]
        end
        
        def []=(key, value)
          @attributes[key] = value
        end
        
        def to_h
          @attributes.dup
        end
        
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