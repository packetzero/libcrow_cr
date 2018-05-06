module Crow

MAX_NAME_LEN = 64

class RowValue
  property value : String | Int8 | Int16 | Int32 | Int64 | UInt8 | UInt16 | UInt32 | UInt64 | Float32 | Float64
  property field : Field

  def initialize(value, field)
    @value = value
    @field = field
  end

  def to_s
    case field.tagid
    when CrowTag::TSTRING
      "\"#{@value.to_s}\""      # TODO: CSV escape
    else
      @value.to_s
    end
  end
end

def self.to_csv(row) : String
  s = ""
  row.each_with_index {|rowval, i| s += (i > 0 ? "," : "") + rowval.to_s}
  s
end

#type RowData = [] of RowValue

class Decoder

  def initialize(srcio : IO)
    @rownum=0
    @io=srcio
    @lastIndex = -1
    @fields = {} of UInt8 => Field
    @endian = IO::ByteFormat::LittleEndian
  end

  def read_row()
    data = [] of RowValue
    while true
      tagid = @io.read_byte

      break if tagid.nil?      # no more data

      index = -1
      if tagid === CrowTag::TROWSEP.to_u8
        @lastIndex = -1
        break
      elsif tagid === CrowTag::TFIELDINFO.to_u8
        tmp = read_varint  # Index
        break if tmp.nil?
        index = tmp.to_u8

        tmp = read_varint  # tagid
        break if tmp.nil?
        tagid = CrowTag.to_tag(tmp.to_u8)

        raise Exception.new "FIELDINFO contains invalid tagid #{tmp.to_u8}" unless CrowTag.is_type tagid.not_nil!

        tmp = read_varint  # id
        break if tmp.nil?

        fld = Field.new tmp.to_u32
        fld.index = index
        fld.tagid = tagid.not_nil!

        tmp = read_varint # subid
        break if tmp.nil?
        fld.subid = tmp.to_u32

        tmp = read_varint # subid
        break if tmp.nil?
        len = tmp.to_u8
        raise Exception.new "FIELDINFO name len (#{len}) exceeds max #{MAX_NAME_LEN}" if len > MAX_NAME_LEN

        name_bytes = Bytes.new(len)
        tmp = @io.read name_bytes
        fld.name = String.new(name_bytes)

        @fields[fld.index] = fld

        value = read_value fld
        #puts "value:#{value.to_s} field:#{fld.to_s}"
        data.push RowValue.new value.not_nil!, fld

        @lastIndex = fld.index.to_i

      elsif tagid === CrowTag::TNEXT.to_u8

        index = @lastIndex + 1
        fld = @fields.fetch(index, nil)
        raise Exception.new "Index for field without definition #{index}" if fld.nil?
        value = read_value fld
        #puts "value:#{value.to_s} field:#{fld.to_s}"
        data.push RowValue.new value.not_nil!, fld

        @lastIndex = index.to_i
      end

    end
    data
  end

  def read_value(fld : Field)
    case fld.tagid
    when CrowTag::TSTRING
      len = read_varint
      return nil if len.nil?

      name_bytes = Bytes.new(len)
      tmp = @io.read name_bytes
      return String.new(name_bytes)

    when CrowTag::TINT32

      tmp = read_varint
      return nil if tmp.nil?
      return Decoder.zigzag_decode32(tmp.to_u32)

    when CrowTag::TUINT32

      tmp = read_varint
      return nil if tmp.nil?
      return tmp.to_u32

    when CrowTag::TINT64

      tmp = read_varint
      return nil if tmp.nil?
      return Decoder.zigzag_decode64(tmp)

    when CrowTag::TUINT64

      return read_varint

    when CrowTag::TINT8

      tmp = read_varint
      return nil if tmp.nil?
      return Decoder.zigzag_decode32(tmp.to_u32).to_u8

    when CrowTag::TUINT8

      tmp = read_varint
      return nil if tmp.nil?
      return tmp.to_u8

    when CrowTag::TFLOAT32

      tmp = @io.read_bytes Float32, @endian
      return nil if tmp.nil?
      return tmp.to_f32

    when CrowTag::TFLOAT64

      tmp = @io.read_bytes Float64, @endian
      return nil if tmp.nil?
      return tmp.to_f64
    else
      raise Exception.new "tagid not yet implemented #{fld.tagid}"
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

  def read_tag( tagid : UInt8,  fieldIndex : UInt8)

    # read type tag

    tagid = @io.read_byte

    return nil if tagid.nil?

    return tagid if tagid == CrowTag::TROWSEP  # no fieldIndex byte

    if tagid == CrowTag::TNEXT
      fieldIndex = @lastIndex + 1
      return tagid
    end

    # read field index byte

    fieldIndex = @io.read_byte
    return nil if fieldIndex.nil?
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

  def read_varint : UInt64
    n = shift = 0_u64
    while true
      if shift >= 64
        raise Exception.new("buffer overflow varint")
      end
      byte = @io.read_byte
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
