module Translatable
  class Configuration
    attr_accessor :default_column_name, :default_locales

    def initialize
      @default_column_name = :translations
      @default_locales = -> { I18n.available_locales }
    end
  end
end