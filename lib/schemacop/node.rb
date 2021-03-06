module Schemacop
  class Node
    attr_reader :options

    class_attribute :allowed_options
    self.allowed_options = {}.freeze

    class_attribute :symbols
    self.symbols = [].freeze

    class_attribute :klasses
    self.klasses = [].freeze

    def self.option(key, default: nil)
      self.allowed_options = allowed_options.merge(key => default)
    end

    option :if
    option :check

    def type_label
      str = (symbols.first || 'unknown').to_s
      str += '*' if option?(:if)
      return str
    end

    def self.symbol(symbol)
      self.symbols += [symbol]
    end

    def self.clear_symbols
      self.symbols = [].freeze
    end

    def self.klass(klass)
      self.klasses += [klass]
    end

    def self.clear_klasses
      self.klasses = [].freeze
    end

    def self.register(symbols: [], klasses: [], clear: true)
      NodeResolver.register(self)
      symbols = [*symbols]
      klasses = [*klasses]
      if clear
        clear_symbols
        clear_klasses
      end
      symbols.each { |s| symbol s }
      klasses.each { |k| klass k }
    end

    def self.type_matches?(type)
      symbol_matches?(type) || class_matches?(type)
    end

    def self.symbol_matches?(type)
      return false unless type.is_a?(Symbol)
      symbols.include?(type)
    end

    def self.class_matches?(type)
      return false unless type.is_a?(Class)
      klasses.each do |klass|
        return true if type <= klass
      end
      return false
    end

    def self.build(options, &block)
      new(options, &block)
    end

    def initialize(options = {})
      # Check and save given options
      @options = self.class.allowed_options.merge(options)
      if (obsolete_opts = @options.keys - self.class.allowed_options.keys).any?
        fail Exceptions::InvalidSchemaError,
             "Unrecognized option(s) #{obsolete_opts.inspect} for #{self.class.inspect}, allowed options: #{self.class.allowed_options.keys.inspect}."
      end
    end

    def option(key)
      options[key]
    end

    def option?(key)
      # rubocop:disable Style/DoubleNegation
      !!options[key]
      # rubocop:enable Style/DoubleNegation
    end

    def exec_block
      fail Exceptions::InvalidSchemaError, 'Node does not support block.' if block_given?
    end

    def resolve_type_klass(type)
      klass = NodeResolver.resolve(type)
      unless klass
        fail Exceptions::InvalidSchemaError, "No validation class found for type #{type.inspect}."
      end
      return klass
    end

    def validate(data, collector)
      validate_custom_check(data, collector)
    end

    def type_matches?(data)
      self.class.type_matches?(data.class) && type_filter_matches?(data)
    end

    def type_filter_matches?(data)
      !option?(:if) || option(:if).call(data)
    end

    protected

    def validate_custom_check(data, collector)
      if option?(:check) && !option(:check).call(data)
        collector.error 'Custom :check failed.'
      end
    end
  end
end
