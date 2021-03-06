require 'test_helper'

module Schemacop
  class TypesTest < Minitest::Test
    def setup
      @datatype_samples = { array: [],
                            boolean: true,
                            float: 2.3,
                            hash: {},
                            integer: -5,
                            number: -3.2,
                            symbol: :thing,
                            object: self,
                            string: 'miau' }.freeze
    end

    def test_multitype
      assert_only_types_allowed(
        Schema.new do
          type :integer
          type :boolean
        end, [:integer, :boolean]
      )

      assert_only_types_allowed(
        Schema.new([:integer, :boolean]),
        [:integer, :boolean]
      )
    end

    def test_all_data_types
      @datatype_samples.keys.each do |type|
        assert_only_types_allowed(Schema.new(type), type)
      end
    end

    def test_conditional_types
      s = Schema.new do
        type :boolean
        type :integer, min: 5
      end

      assert_nil s.validate! true
      assert_nil s.validate! false
      assert_nil s.validate! 5

      assert_verr { s.validate! 'sali' }
      assert_verr { s.validate! 4 }
    end

    # For short form test see short_forms_test.rb
    def test_array_subtype_explicit
      s = Schema.new do
        type :array do
          type :integer
        end
      end
      assert_nil s.validate! [5]
      assert_verr { s.validate! [nil] }
      assert_verr { s.validate! ['a'] }
      assert_verr { s.validate! [5, 'a'] }
      assert_verr { s.validate! [5, nil] }
    end

    private

    def assert_only_types_allowed(schema, allowed_types)
      allowed_types = [*allowed_types]
      @datatype_samples.each do |type, data|
        if allowed_types.include?(type) ||
           # All the weird cases need to be differentiated
           (type == :float && allowed_types.include?(:number)) ||
           (type == :integer && allowed_types.include?(:number)) ||
           (type == :number && allowed_types.include?(:float)) ||
           allowed_types.include?(:object)

          assert_nil schema.validate! data
        else
          assert_verr { schema.validate! data }
        end
      end
    end
  end
end
