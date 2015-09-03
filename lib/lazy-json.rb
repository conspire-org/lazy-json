require 'oj'

module LazyJson

  def self.attach(json)
    LazyValue.new(Sequence.new(json))
  end

  # A sequence of json JSON characters
  class Sequence

    # See http://stackoverflow.com/questions/16042274/definition-of-whitespace-in-json
    WHITESPACE = [
      0x20, # Space
      0x09, # Horizontal tab
      0x0A, # Line feed or New line
      0x0D  # Carriage return
    ]

    # Note positions are in bytes, not characters
    def initialize(json, start_pos = 0, end_pos = json.bytesize)
      raise "Sequence end ${ end_pos } is before start #{ start_pos }" if end_pos < start_pos
      @json = json
      @start_pos = start_pos
      @end_pos = end_pos
    end

    attr_reader :json
    attr_reader :start_pos
    attr_reader :end_pos

    def to_s
      @json.byteslice(@start_pos...@end_pos)
    end

    def byte_at(i)
      @json.getbyte(@start_pos + i)
    end

    def first
      byte_at(0)
    end

    def empty?
      @start_pos == @end_pos
    end

    def prefix(end_pos)
      Sequence.new(@json, @start_pos, end_pos)
    end

    def suffix(start_pos)
      Sequence.new(@json, start_pos, @end_pos)
    end

    def remainder(enclosing_seq)
      Sequence.new(@json, @end_pos, enclosing_seq.end_pos)
    end

    def read_whitespace
      prefix(skim_whitespace(@start_pos))
    end

    def skip_whitespace
      suffix(skim_whitespace(@start_pos))
    end

    def read_byte(byte, required = true)
      prefix(skim_byte(@start_pos, byte, required))
    end

    def skip_byte(byte, required = true)
      suffix(skim_byte(@start_pos, byte, required))
    end

    def read_until(terminator, include_terminator)
      prefix(skim_until(@start_pos, false, terminator, include_terminator))
    end

    def skip_until(terminator, include_terminator)
      suffix(skim_until(@start_pos, false, terminator, include_terminator))
    end

    private

    def skim_whitespace(start)
      i = start
      while i < @end_pos && WHITESPACE.include?(@json.getbyte(i))
        i += 1
      end
      i
    end

    def skim_byte(at, byte, required)
      byte = [ byte ] unless byte.is_a?(::Array)
      if byte.include?(@json.getbyte(at))
        at + 1
      elsif required
        raise "Expected #{ byte } but got '#{ @json.getbyte(at) }'"
      else
        at
      end
    end

    def skim_until(start, in_string, terminator, include_terminator)
      terminator = [ terminator ] unless terminator.is_a?(::Array)
      i = start
      while i < @end_pos
        byte = @json.getbyte(i)

        # Skip unicode characters. See table at https://en.wikipedia.org/wiki/UTF-8.
        if byte & 0b11100000 == 0b11000000
          i += 2
        elsif byte & 0b11110000 == 0b11100000
          i += 3
        elsif byte & 0b11111000 == 0b11110000
          i += 4

        elsif in_string && byte == 92 # '\\'.ord
          i += escape_sequence_length(i) # String escape sequence
        elsif terminator.include?(byte)
          i += 1 if include_terminator
          break
        else
          i += 1
          if ! in_string
            if byte == 34 # '"'.ord
              i = skim_until(i, true, 34, true) # '"'.ord - String start
            elsif byte == 91 # '['.ord
              i = skim_until(i, false, 93, true) # ']'.ord - Array start
            elsif byte == 123 # '{'.ord
              i = skim_until(i, false, 125, true) # '}'.ord - Object start
            end
          end
        end
      end
      i
    end

    def escape_sequence_length(start)
      raise 'Escape sequence must start with \\' if @json.getbyte(start) != 92 # '\\'.ord
      byte = @json.getbyte(start + 1)
      if byte == 120 # 'x'.ord - \x followed by 2 hex digits
        4
      elsif byte == 117 # 'u'.ord - \u followed by 4 hex digits
        6
      elsif byte >= 48 && byte <= 57 # '0'.ord, '9'.ord - \ followed by 3 octal digits
        4
      else # \ followed by single escaped character
        2
      end
    end

  end

  class Value

    def initialize(seq)
      @seq = seq
    end

    def parse
      Oj.load(@seq.to_s) # Note JSON.parse fails on primitives since they're invalid as documents
    end

  end

  class LazyValue < Value

    def initialize(seq)
      super(seq)
      @parsed = false
      @value = nil
    end

    def value
      if ! @parsed
        byte = @seq.skip_whitespace.first
        if byte == 123 # '{'.ord
          @value = Object.new(@seq)
        elsif byte == 91 # '['.ord
          @value = Array.new(@seq)
        else
          @value = Primitive.new(@seq)
        end
        @parsed = true
      end
      @value
    end

    def [](key_or_index)
      value[key_or_index]
    end

  end

  class Object < Value

    def initialize(seq)
      super(seq)
      @fields = {}
      @fseq = @seq.skip_whitespace.skip_byte(123) # '{'.ord
    end

    # Access a field, lazily parsing if not yet parsed
    def [](key)
      if ! @fields.has_key?(key) && ! @fseq.empty?
        while true
          @fseq = @fseq.skip_whitespace
          if @fseq.first == 125 # '}'.ord
            @fseq = @fseq.skip_byte(125).skip_whitespace # '}'.ord
            break
          end
          new_key, new_value = read_field_and_consume
          @fields[new_key] = new_value
          break if new_key == key
        end
      end
      @fields[key]
    end

    private

    def read_field_and_consume
      key_seq = @fseq.read_until(58, false) # ':'.ord
      key = Value.new(key_seq).parse
      raise "Non-string object key #{ key }" unless key.is_a?(String)
      @fseq = key_seq.remainder(@fseq)
      @fseq = @fseq.skip_byte(58) # ':'.ord
      value_seq = @fseq.read_until([ 44, 125 ], false) # ','.ord, '}'.ord
      @fseq = value_seq.remainder(@fseq)
      sep_seq = @fseq.read_byte([ 44, 125 ]) # ','.ord, '}'.ord
      @fseq = sep_seq.remainder(@fseq) if sep_seq.first == 44 # ','.ord - Consume , but not }
      [ key, LazyValue.new(value_seq) ]
    end

  end

  class Array < Value

    def initialize(seq)
      super(seq)
      @elements = []
      @eseq = @seq.skip_whitespace.skip_byte(91) # '['.ord
    end

    # Access an element, lazily parsing if not yet parsed
    def [](i)
      if @elements.size <= i && ! @eseq.empty?
        while true
          @eseq = @eseq.skip_whitespace
          if @eseq.first == 93 # ']'.ord
            @eseq = @eseq.skip_byte(93).skip_whitespace # ']'.ord
            break
          end
          new_value = read_value_and_consume
          @elements << new_value
          break if @elements.size > i
        end
      end
      @elements[i]
    end

    private

    def read_value_and_consume
      value_seq = @eseq.read_until([ 44, 93 ], false) # ','.ord, ']'.ord
      @eseq = value_seq.remainder(@eseq)
      sep_seq = @eseq.read_byte([ 44, 93 ]) # ','.ord, ']'.ord
      @eseq = sep_seq.remainder(@eseq) if sep_seq.first == 44 # ','.ord - Consume , but not ]
      LazyValue.new(value_seq)
    end

  end

  class Primitive < Value

    def initialize(seq)
      super(seq)
    end

  end

end
