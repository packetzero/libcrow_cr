
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

  def typeid_of (value)
    case value.class.to_s
    when "Int32" then CrowType::TINT32
    when "UInt32" then CrowType::TUINT32
    when "Int64" then CrowType::TINT64
    when "UInt64" then CrowType::TUINT64
    when "String" then CrowType::TSTRING
    when "Int8" then CrowType::TINT8
    when "UInt8" then CrowType::TUINT8
    when "Int16" then CrowType::TINT16
    when "UInt16" then CrowType::TUINT16
    when "Float32" then CrowType::TFLOAT32
    when "Float64" then CrowType::TFLOAT64
    when "Bool" then CrowType::TUINT8
    else
      puts "typeid_of(#{value.class}) unknown"
      CrowType::NONE
    end
  end

  def put(value, fld : Field)

    fld.typeid = typeid_of(value) if fld.typeid === CrowType::NONE

    curField = @fields.fetch(fld.hash, nil)
    if curField.nil?
      # first time for this field, encode the def
      raise Exception.new "No type given for field at index #{fld.to_s}" if fld.typeid == CrowType::NONE

      # assign a 0-based index

      fld.index = @fields.size.to_u8

      # write

      write_field_info fld

      # update state

      @fields[fld.hash] = fld
      curField = fld
    else

      # seen before, write the tag

      write_field_tag curField
    end

    @lastIndex = curField.index.to_i

    write_value value, curField
  end

  def write_value (value : String, curField : Field)
    raise Exception.new "typeid should be TSTRING #{curField.typeid}" if curField.typeid != CrowType::TSTRING
      write_varint value.as(String).size
      @destio.write value.as(String).to_slice
  end

  def write_value (value : Bool, curField)
    write_varint (value ? 1 : 0)
  end

  def write_value (value, curField)
    case curField.typeid
    when CrowType::TINT32 then write_varint (Encoder.zigzag_encode32 value.to_i32)
    when CrowType::TINT64 then write_varint (Encoder.zigzag_encode64 value.to_i64)
    when CrowType::TUINT32 then write_varint value.to_u32
    when CrowType::TUINT64 then write_varint value.to_u64
    when CrowType::TINT8 then write_varint value.to_i8
    when CrowType::TUINT8 then write_varint value.to_u8
    when CrowType::TINT16 then write_varint value.to_i16
    when CrowType::TUINT16 then write_varint value.to_u16

    when CrowType::TFLOAT32 then @destio.write_bytes value.to_f32, @endian
    when CrowType::TFLOAT64 then @destio.write_bytes value.to_f64, @endian

    else
      raise Exception.new "Unsupported typeid type #{curField.typeid}"
    end
  end

  def put_row_sep()
    @destio.write_byte CrowTag::TROWSEP.to_u8
    @lastIndex = -1
  end

  def write_field_info(fld : Field)
    @destio.write_byte CrowTag::TFIELDINFO.to_u8
    write_varint fld.index
    write_varint fld.typeid
    write_varint fld.id
    write_varint fld.subid
    write_varint fld.name.size
    @destio.write fld.name.to_slice
  end


  def write_field_tag(fld : Field)
    if (fld.index.to_i - @lastIndex) === 1
      @destio.write_byte CrowTag::TNEXT.to_u8
    else
      @destio.write_byte fld.index | 0x80_u8
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
