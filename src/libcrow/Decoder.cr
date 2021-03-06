module Crow

MAX_NAME_LEN = 64

class RowValue
  property value : String | Int8 | Int16 | Int32 | Int64 | UInt8 | UInt16 | UInt32 | UInt64 | Float32 | Float64 | Bytes
  property field : Field
  property flags : UInt8 = 0_u8

  def initialize(value, field, flags)
    @value = value
    @field = field
    @flags = flags
  end

  def value_to_s(value : Bytes)
    "#{value.hexstring}"
  end

  def value_to_s(value : String)
    Crow.quote_cell value
#    "\"#{@value.to_s}\""      # TODO: CSV escape
  end

  def value_to_s(value : Float32 | Float64 | Int16 | Int32 | Int64 | Int8 | String | UInt16 | UInt32 | UInt64 | UInt8)
    value.to_s
  end

  def to_s
    value_to_s value.not_nil!
  end
end

def self.quote_cell(value : String)
  return value unless Crow.needs_quotes? value
  s = ""
  value.each_char do |byte|
    case byte
    when '"'
      s +=  %("")
    else
      s += byte
    end
  end
  '"' + s + '"'
end

def self.needs_quotes?(value)
  value.each_byte do |byte|
    case byte.unsafe_chr
    when ',', '\n', '"'
      return true
    end
  end
  false
end

def self.to_csv(row) : String
  s = ""
  row.each_with_index {|rowval, i| s += (i > 0 ? "," : "") + rowval.to_s + (rowval.flags > 0 ? " FLAGS:#{rowval.flags.to_s(16)}" : "")}
  s
end

#type RowData = [] of RowValue

class Decoder

  def initialize(srcio : IO)
    @rownum=0
    @io=srcio
    @fields = {} of UInt8 => Field
    @endian = IO::ByteFormat::LittleEndian
    @flags = 0_u8
    @sets = {} of UInt8 => Bytes
  end

  # return map index => field
  def field_defs()
    return @fields
  end

  def read_row()
    data = [] of RowValue
    read_row_stuff data
    data
  end

  def read_row_stuff(data, io = nil )
    io = @io if io.nil?
    while true
      tagbyte = io.read_byte
      break if tagbyte.nil?      # no more data

      is_index = (tagbyte & 0x80_u8) == 0x80_u8
      tagid = tagbyte & 0x0F_u8


      index = -1
      if is_index
        index = tagid & 0x7F_u8
        fld = @fields.fetch(index, nil)
        raise Exception.new "Index for field without definition #{index}" if fld.nil?
        value = read_value fld, io
        #puts "value:#{value.to_s} field:#{fld.to_s}"
        data.push RowValue.new value.not_nil!, fld, @flags

      elsif tagid === CrowTag::TROWSEP.to_u8
        @flags = (tagbyte >> 4) & 0x07_u8
        break

      elsif tagid === CrowTag::TFLAGS.to_u8
        @flags = (tagbyte >> 4) & 0x07_u8

      elsif tagid === CrowTag::TSETREF.to_u8
        setid = io.read_byte
        break if setid.nil?

        bytes = @sets[setid]
        setio = IO::Memory.new bytes
        read_row_stuff(data, setio)

      elsif tagid === CrowTag::TSET.to_u8
        setid = io.read_byte
        break if setid.nil?

        setlen = read_varint io
        bytes = Bytes.new(setlen)
        tmp = io.read bytes
        raise Exception.new "unable to read all of set bytes #{tmp} < #{setlen}" if tmp < setlen
        @sets[setid] = bytes

      elsif tagid === CrowTag::TFIELDINFO.to_u8

        has_subid = (tagbyte & FIELDINFO_FLAG_HAS_SUBID) != 0
        has_name  = (tagbyte & FIELDINFO_FLAG_HAS_NAME) != 0
        has_value = (tagbyte & FIELDINFO_FLAG_NO_VALUE) === 0

        tmp = io.read_byte  # Index
        break if tmp.nil?

        # if upper bit set
        index = tmp.to_u8 & 0x7F_u8

        tmp = io.read_byte  # typeid
        break if tmp.nil?

        # if upper bit set
        typeid = CrowType.to_type(tmp.to_u8 & 0x0F_u8)

        raise Exception.new "FIELDINFO contains invalid typeid #{tmp.to_u8}" if typeid.not_nil! == CrowType::NONE

        tmp = read_varint io # id
        break if tmp.nil?

        fld = Field.new tmp.to_u32
        fld.index = index
        fld.typeid = typeid.not_nil!

        if has_subid
          tmp = read_varint io # subid
          break if tmp.nil?         # TODO: raise EOF
          fld.subid = tmp.to_u32
        end

        if has_name
          tmp = read_varint io # name len
          break if tmp.nil?
          len = tmp.to_u8
          raise Exception.new "FIELDINFO name len (#{len}) exceeds max #{MAX_NAME_LEN}" if len > MAX_NAME_LEN

          name_bytes = Bytes.new(len)
          tmp = io.read name_bytes
          fld.name = String.new(name_bytes)
        end

        @fields[fld.index] = fld

        if has_value
          value = read_value fld, io
          #puts "value:#{value.to_s} field:#{fld.to_s}"
          data.push RowValue.new value.not_nil!, fld, @flags
        end

      end

    end
  end

  def read_value(fld : Field, io = nil)
    io = @io if io.nil?
    case fld.typeid
    when CrowType::TSTRING
      len = read_varint io
      return nil if len.nil?

      name_bytes = Bytes.new(len)
      tmp = io.read name_bytes
      return String.new(name_bytes)

    when CrowType::TBYTES
      len = read_varint io
      return nil if len.nil?

      name_bytes = Bytes.new(len)
      readlen = io.read name_bytes
      raise Exception.new "EOF : unable to read entire BYTES #{readlen} of #{len}" if readlen < len
      return name_bytes

    when CrowType::TINT32

      tmp = read_varint io
      return nil if tmp.nil?
      return Decoder.zigzag_decode32(tmp.to_u32)

    when CrowType::TUINT32

      tmp = read_varint io
      return nil if tmp.nil?
      return tmp.to_u32

    when CrowType::TINT64

      tmp = read_varint io
      return nil if tmp.nil?
      return Decoder.zigzag_decode64(tmp)

    when CrowType::TUINT64

      return read_varint io

    when CrowType::TINT8

      tmp = read_varint io
      return nil if tmp.nil?
      return Decoder.zigzag_decode32(tmp.to_u32).to_u8

    when CrowType::TUINT8

      tmp = read_varint io
      return nil if tmp.nil?
      return tmp.to_u8

    when CrowType::TFLOAT32

      tmp = io.read_bytes Float32, @endian
      return nil if tmp.nil?
      return tmp.to_f32

    when CrowType::TFLOAT64

      tmp = io.read_bytes Float64, @endian
      return nil if tmp.nil?
      return tmp.to_f64
    else
      raise Exception.new "typeid not yet implemented #{fld.typeid}"
    end
  end

  def read_fixed32
    @io.read_bytes(UInt32, @endian)
  end

  def read_sfixed32
    @io.read_bytes(Int32, @endian)
  end

  def read_fixed64
    @io.read_bytes(UInt64, @endian)
  end

  def read_field_info(out fld : Field)

    fld.id = read_varint
    return nil if fld.id.nil?

    fld.subid = read_varint
    return nil if fld.subid.nil?

    len = read_varint
    return nil if len.nil?

    if len > 0
      tmp = Bytes.new(len)
      fld.name = String.new(tmp)
    else
      fld.name = ""
    end

  end

  def read_varint(io = nil) : UInt64
    io = @io if io.nil?
    n = shift = 0_u64
    while true
      if shift >= 64
        raise Exception.new("buffer overflow varint")
      end
      byte = io.read_byte
      if byte.nil?
        return 0_u64
      end
      b = byte.unsafe_chr.ord

      n |= ((b & 0x7F).to_u64 << shift)
      shift += 7
      if (b & 0x80) == 0
        return n.to_u64
      end
    end
  end

  def self.zigzag_decode32(n : UInt32) : Int32
    #   return static_cast<int32_t>((n >> 1) ^ (~(n & 1) + 1));
    (n >> 1).to_i32 ^ (~(n & 1) + 1)
  end

  def self.zigzag_decode64(n : UInt64) : Int64
    (n >> 1).to_i64 ^ (~(n & 1) + 1)
  end

end

end # module
