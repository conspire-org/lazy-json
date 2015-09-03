require 'spec_helper'

describe LazyJson do

  describe 'primitives and null' do

    it 'should parse a number' do
      expect( LazyJson.attach('3.1415926').parse ).to eq(3.1415926)
    end

    it 'should parse a string' do
      expect( LazyJson.attach('"Hello world!"').parse ).to eq('Hello world!')
    end

    it 'should parse null' do
      expect( LazyJson.attach('null').parse ).to eq(nil)
    end

  end

  describe 'objects' do

    it 'should parse an empty object' do
      expect( LazyJson.attach('{}').parse ).to eq({})
    end

    it 'should eagerly parse a non-empty object' do
      expect( LazyJson.attach('{ "key" : 1 }').parse ).to eq({ 'key' => 1 })
    end

    it 'should lazily traverse an object and parse a value' do
      expect( LazyJson.attach('{ "key" : 1 }')['key'].parse ).to eq(1)
    end

    it 'should lazily traverse nested objects and parse a nested value' do
      expect( LazyJson.attach('{ "key" : { "sub" : 1 } }')['key']['sub'].parse ).to eq(1)
    end

    it 'should lazily traverse an object and parse the second field of a nested object' do
      expect( LazyJson.attach('{ "key" : { "a" : 1, "b" : 2 } }')['key']['b'].parse ).to eq(2)
    end

    it 'should lazily traverse an object and parse one field of a nested object then another' do
      lj = LazyJson.attach('{ "key" : { "a" : 1, "b" : 2 } }')
      expect( lj['key']['a'].parse ).to eq(1)
      expect( lj['key']['b'].parse ).to eq(2)
    end

    it 'should handle colons in keys and commas in string values' do
      expect( LazyJson.attach('{ "a:" : "," }')['a:'].parse ).to eq(',')
    end

    it 'should handle unmatched brackets/braces in skimmed string values' do
      expect( LazyJson.attach('{ "a" : "}}{[{[", "b" : 1 }')['b'].parse ).to eq(1)
    end

    it 'should handle unicode characters in skimmed string values' do
      expect( LazyJson.attach("{ \"a\" : \"\u2713\", \"b\" : 1 }")['b'].parse ).to eq(1)
    end

    describe 'escape sequences' do

      it 'should handle escaped quotes in skimmed string values' do
        expect( LazyJson.attach('{ "a" : "\\"", "b" : 1 }')['b'].parse ).to eq(1)
      end

      it 'should handle escaped backslashes in skimmed string values' do
        expect( LazyJson.attach('{ "a" : "\\\\", "b" : 1 }')['b'].parse ).to eq(1)
      end

      it 'should handle octal escape sequences in skimmed string values' do
        expect( LazyJson.attach('{ "a" : "\\111", "b" : 1 }')['b'].parse ).to eq(1)
      end

      it 'should handle hex escape sequences in skimmed string values' do
        expect( LazyJson.attach('{ "a" : "\\xFF", "b" : 1 }')['b'].parse ).to eq(1)
      end

      it 'should handle unicode escape sequences in skimmed string values' do
        expect( LazyJson.attach('{ "a" : "\\uFAFA", "b" : 1 }')['b'].parse ).to eq(1)
      end

    end

  end

  describe 'arrays' do

    it 'should parse an empty array' do
      expect( LazyJson.attach('[]').parse ).to eq([])
    end

    it 'should eagerly parse a non-empty array' do
      expect( LazyJson.attach('[ 1 ]').parse ).to eq([ 1 ])
    end

    it 'should lazily traverse an array and parse an element' do
      expect( LazyJson.attach('[ 1 ]')[0].parse ).to eq(1)
    end

    it 'should lazily traverse nested arrays and parse a nested element' do
      expect( LazyJson.attach('[ [ 1, 2 ], [ 3, 4 ] ]')[1][0].parse ).to eq(3)
    end

  end

  it 'should lazily traverse a complex JSON document' do

    # Ok, geeking out extra hard here
    json = <<-eos
      {
        "name" : "Shivan Dragon",
        "type" : "creature",
        "color" : "red",
        "casting_cost" : {
          "red" : 2,
          "colorless" : 4
        },
        "type_properties" : {
          "creature" : {
            "power" : 5,
            "toughness" : 5
          }
        },
        "capabilities" : [
          {
            "cost" : null,
            "effects" : [
              {
                "effect_type" : "flying"
              }
            ]
          },
          {
            "cost" : {
              "red" : 1
            },
            "effects" : [
              {
                "effect_type" : "power_delta",
                "delta" : 1
              },
              {
                "effect_type" : "toughness_delta",
                "delta" : 0
              }
            ]
          }
        ]
      }
    eos

    expect( LazyJson.attach(json)['casting_cost'].parse ).to eq({ 'red' => 2, 'colorless' => 4 })
    expect( LazyJson.attach(json)['capabilities'][1]['effects'][0]['delta'].parse ).to eq(1)
    expect( LazyJson.attach(json)['capabilities'].parse.size ).to eq(2)

  end

end
