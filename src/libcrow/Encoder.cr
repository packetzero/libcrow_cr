
module Crow

class Encoder

  def initialize(destio : IO)
    @rownum=0
    @destio=destio
    @lastIndex = -1
    @fields = {} of UInt64 => Field
    @endian = IO::ByteFormat::LittleEndian
  end

  # put a field value, defining by id
  def put(value, fieldId : UInt32, fieldSubId : UInt32 = 0_u32)
    field = Field.new fieldId, fieldSubId
    put(value, field)
  end

  def put(value, fieldId : Int32, fieldSubId : Int32 = 0)
    field = Field.new fieldId.to_u32, fieldSubId.to_u32
    put(value, field)
  end


  def put(value, fieldName : String)
    field = Field.new fieldName
    put(value, field)
  end

  def tagid_of (value)
    case value.class.to_s
    when "Int32" then CrowTag::TINT32
    when "UInt32" then CrowTag::TUINT32
    when "Int64" then CrowTag::TINT64
    when "UInt64" then CrowTag::TUINT64
    when "String" then CrowTag::TSTRING
    when "Int8" then CrowTag::TINT8
    when "UInt8" then CrowTag::TUINT8
    when "Int16" then CrowTag::TINT16
    when "UInt16" then CrowTag::TUINT16
    when "Float32" then CrowTag::TFLOAT32
    when "Float64" then CrowTag::TFLOAT64
    when "Bool" then CrowTag::TUINT8
    else
      puts "tagid_of(#{value.class}) unknown"
      CrowTag::TUNKNOWN
    end
  end

  def put(value, fld : Field)

    fld.tagid = tagid_of(value) if fld.tagid === CrowTag::TUNKNOWN

    curField = @fields.fetch(fld.hash, nil)
    if curField.nil?
      # first time for this field, encode the def
      raise Exception.new "No type given for field at index #{fld.to_s}" if fld.tagid == CrowTag::TUNKNOWN

      # assign a 0-based index

      fld.index = @fields.size.to_u8

      # write

      write_field_info fld

      # update state

      @fields[fld.hash] = fld
      curField = fld
    else

      # seen before, write the tag

      write_tag curField
    end

    @lastIndex = fld.index.to_i

    write_value value, curField
  end

  def write_value (value : String, curField : Field)
    raise Exception.new "tagid should be TSTRING #{curField.tagid}" if curField.tagid != CrowTag::TSTRING
      write_varint value.as(String).size
      @destio.write value.as(String).to_slice
  end

  def write_value (value : Bool, curField)
    write_varint (value ? 1 : 0)
  end

  def write_value (value, curField)
    case curField.tagid
    when CrowTag::TINT32 then write_varint (Encoder.zigzag_encode32 value.to_i32)
    when CrowTag::TINT64 then write_varint (Encoder.zigzag_encode64 value.to_i64)
    when CrowTag::TUINT32 then write_varint value.to_u32
    when CrowTag::TUINT64 then write_varint value.to_u64
    when CrowTag::TINT8 then write_varint value.to_i8
    when CrowTag::TUINT8 then write_varint value.to_u8

    when CrowTag::TFLOAT32 then write_fixed32 value.to_u32
    when CrowTag::TFLOAT64 then write_fixed64 value.to_u64

    #when CrowTag::TUINT32
    #when CrowTag::TUINT64
    else
      raise Exception.new "Unsupported tagid type #{curField.tagid}"
    end
  end

  def put_row_sep()
    @destio.write_byte CrowTag::TROWSEP.to_u8
    @lastIndex = -1
  end

  def write_field_info(fld : Field)
    @destio.write_byte CrowTag::TFIELDINFO.to_u8
    write_varint fld.index
    write_varint fld.tagid
    write_varint fld.id
    write_varint fld.subid
    write_varint fld.name.size
    @destio.write fld.name.to_slice
  end


  def write_tag(fld : Field)
    if (fld.index - @lastIndex) === 1
      @destio.write_byte CrowTag::TNEXT.to_u8
    else
      @destio.write_byte fld.tagid.to_u8 & 0x7F
      @destio.write_byte fld.index & 0x7F
    end
  end

  def write_varint(rawval)
    value = rawval.to_u64
    i=0
    while true
      i += 1;
      b = (value & 0x07F).to_u8
      value = value >> 7
      if 0_u64 === value
        @destio.write_byte b
        break
      end
      @destio.write_byte b | 0x80_u8
    end

    return i;
  end

  def write_fixed32(n : UInt32)
    @destio.write_bytes(n, @endian)
  end

  def write_fixed64(n : UInt64)
    @destio.write_bytes(n, @endian)
  end

  def self.zigzag_encode32(n : Int32) : UInt32
    #   return (static_cast<uint32_t>(n) << 1) ^ static_cast<uint32_t>(n >> 31);
    ((n << 1) ^ (n >> 31)).to_u32
  end

  def self.zigzag_encode64(n : Int64) : UInt64
    #   return (static_cast<uint64_t>(n) << 1) ^ static_cast<uint64_t>(n >> 63);
    ((n << 1) ^ (n >> 63)).to_u64
  end

end

end
