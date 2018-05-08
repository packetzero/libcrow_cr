
module Crow



class Encoder

  def initialize(destio : IO)
    @rownum=0
    @destio=destio
    @fields = {} of UInt64 => Field
    @endian = IO::ByteFormat::LittleEndian

    @setio=IO::Memory.new
    @sets = {} of UInt8 => Bytes
    @setModeEnabled = false
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
    when "Bytes" then CrowType::TBYTES
    when "Slice(UInt8)" then CrowType::TBYTES
    else
      puts "typeid_of(#{value.class}) unknown"
      CrowType::NONE
    end
  end

  def put(value, fld : Field)
    fld.typeid = typeid_of(value) if fld.typeid === CrowType::NONE

    which_io = ( @setModeEnabled ? @setio : @destio)

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

      if @setModeEnabled
        write_field_tag curField, @setio
      end

    else

      # seen before, write the tag

      write_field_tag curField, which_io
    end

    write_value value, curField, which_io
  end

  def write_value (value : String, curField : Field, io)
    raise Exception.new "typeid should be TSTRING #{curField.to_s}" if curField.typeid != CrowType::TSTRING
      write_varint value.size
      io.write value.to_slice
  end

  def write_value (value : Bytes | Array(UInt8), curField : Field, io)
    raise Exception.new "typeid should be TBYTES #{curField.to_s}" if curField.typeid != CrowType::TBYTES
      write_varint value.size, io
      io.write value
  end

  def write_value (value : Bool, curField, io)
    write_varint (value ? 1 : 0), io
  end

  def write_value (value, curField, io)
    case curField.typeid
    when CrowType::TINT32 then write_varint (Encoder.zigzag_encode32 value.to_i32), io
    when CrowType::TINT64 then write_varint (Encoder.zigzag_encode64 value.to_i64), io
    when CrowType::TUINT32 then write_varint value.to_u32, io
    when CrowType::TUINT64 then write_varint value.to_u64, io
    when CrowType::TINT8 then write_varint value.to_i8, io
    when CrowType::TUINT8 then write_varint value.to_u8, io
    when CrowType::TINT16 then write_varint value.to_i16, io
    when CrowType::TUINT16 then write_varint value.to_u16, io

    when CrowType::TFLOAT32 then io.write_bytes value.to_f32, @endian
    when CrowType::TFLOAT64 then io.write_bytes value.to_f64, @endian

    else
      raise Exception.new "Unsupported typeid type #{curField.typeid}"
    end
  end

  def put_row_sep(flags : UInt8 = 0_u8)
    end_set if @setModeEnabled # should not happen with correct app code

    @destio.write_byte CrowTag::TROWSEP.to_u8 | ((flags & 0x07_u8) << 4)
  end

  # ignores bits 3-7, encodes bits 0-2 to output stream
  def put_flags(value : UInt8)
    flags = value & 0x07_u8
    @destio.write_byte CrowTag::TFLAGS.to_u8 | (flags << 4)
  end

  def start_set()
    @setModeEnabled = true
    @setio.clear
  end

  # return setid
  def end_set()
    @setModeEnabled = false
    setBytes = @setio.to_slice
    setid = @sets.size.to_u8
    @sets[setid] = setBytes

    @destio.write_byte CrowTag::TSET.to_u8
    @destio.write_byte setid
    write_varint setBytes.size
    @destio.write setBytes

    return setid
  end

  def put_set(setid : UInt8, flags : UInt8 = 0_u8)
    setBytes = @sets[setid]
    raise Exception.new "put_set for setid=#{setid.to_s} not found" if setBytes.nil?
    @destio.write_byte CrowTag::TSETREF.to_u8 | ((flags & 0x07_u8) << 4)
    @destio.write_byte setid
  end

  # write FIELDINFO data
  #
  # TFIELDINFO
  # index | 0x80 if have subid
  # typeid | 0x80 if have name
  # id
  # subid
  # namelen
  # name bytes
  #
  def write_field_info(fld : Field)

    # if writing set, need to output fieldinfo, but no value just yet

    flag = (@setModeEnabled ? 0x10_u8 : 0_u8)
    @destio.write_byte CrowTag::TFIELDINFO.to_u8 | flag

    if fld.subid > 0
      @destio.write_byte fld.index | 0x80_u8
    else
      @destio.write_byte fld.index
    end

    if fld.name.size > 0
      @destio.write_byte fld.typeid.to_u8 | 0x80_u8
    else
      @destio.write_byte fld.typeid.to_u8
    end

    write_varint fld.id

    write_varint fld.subid if fld.subid > 0

    if fld.name.size > 0
      write_varint fld.name.size
      @destio.write fld.name.to_slice
    end
  end


  def write_field_tag(fld : Field, io)
    io.write_byte fld.index | 0x80_u8
  end

  def write_varint(rawval, io = nil)
    io = @destio if io.nil?
    value = rawval.to_u64
    i=0
    while true
      i += 1;
      b = (value & 0x07F).to_u8
      value = value >> 7
      if 0_u64 === value
        io.write_byte b
        break
      end
      io.write_byte b | 0x80_u8
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
