require 'active_support'
require_relative 'translatable/version'
require_relative 'translatable/configuration'
require_relative 'translatable/database_strategies/base'
require_relative 'translatable/database_strategies/postgresql'
require_relative 'translatable/database_strategies/mysql'
require_relative 'translatable/database_strategies/sqlite'
require_relative 'translatable/translation_class_generator'
require_relative 'translatable/concern'


module Translatable
  extend ActiveSupport::Concern
  include Translatable::Concern

  class << self
    attr_accessor :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end