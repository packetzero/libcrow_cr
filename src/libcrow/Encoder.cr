
module Crow

DBG_ENC = true


class Encoder

  def initialize(destio : IO)
    @rownum=0
    @destio=destio

    @hdrio = IO::Memory.new
    @iobuf = IO::Memory.new
    @structbuf = IO::Memory.new

    @endian = IO::ByteFormat::LittleEndian
    @isHeaderFinalized = false
    @fields = {} of UInt64 => Field
    @fieldArray = [] of Field
    @curIndex = 0

    @haveRowStart = false
    @numPackedFields = 0
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

  def _pack_def(field, value)
    field.typeid = typeid_of(value)
    field.isRaw = true

    if field.typeid == CrowType::TSTRING
      raise Exception.new "Need to define field as sized Slice() for string"
    end

    # TODO : if any varlen fields, throw exception.  All StructPacked fields have to be defined first.

    field.index = @fields.size.to_u8
    _set_fixed_len(field, value)

    # write definition

    write_field_info field, @hdrio

    # store it

    @fields[field.hash] = field
    @fieldArray.push field
    @numPackedFields += 1

  end

  # put a field value, defining by id
  def pack_def(value, fieldId : UInt32, fieldSubId : UInt32 = 0_u32)
    field = Field.new fieldId, fieldSubId
    _pack_def field, value
  end

  def pack_def(value, fieldId : Int32, fieldSubId : Int32 = 0)
    field = Field.new fieldId.to_u32, fieldSubId.to_u32
    _pack_def field, value
  end

  def pack_def(value, fieldName : String)
    field = Field.new fieldName
    _pack_def field, value
  end

  def pack(value : String)
    pack(value.as(String).to_slice)
  end


  def pack(value)
    typeid = typeid_of(value)
    if @curIndex >= @fieldArray.size
      raise Exception.new "pack for undefined field. Index:#{@curIndex} NumFields:#{@fieldArray.size}"
    end
    field = @fieldArray[@curIndex]

    raise Exception.new "type mismatch #{typeid.to_s} vs Field #{field.to_s}" if field.typeid != typeid

    _pack_value field, value

    @curIndex += 1
  end

  def _set_fixed_len (field, value : Int8 | Int16 | Int32 | Int64 | UInt8 | UInt16 | UInt32 | UInt64 | Float32 | Float64 | Bool | String)
  end

  def _set_fixed_len (field, value : Bytes)
    field.fixedLen = value.size.to_u32
    #puts "_pack_def idx:#{field.index} typeid:#{field.typeid}, size:#{value.size}" if (DBG_ENC)
  end

  def _pack_value (field, value : Int8 | Int16 | Int32 | Int64 | UInt8 | UInt16 | UInt32 | UInt64 | Float32 | Float64)
    len = @iobuf.write_bytes value # TODO: endian
    #puts "wrote #{len} bytes for #{field.to_s}"
  end

  def _pack_value (field, value : Bool)
    _pack_value field, (value ? 1_u8 : 0_u8)
  end

  def _pack_value (field, value : Bytes)
    raise Exception.new "_pack_value : field does not define length #{field.to_s}" if field.fixedLen <= 0
    a = value
    if (value.size > field.fixedLen)
      a = value[0, field.fixedLen]
    end
    len = a.size
    @iobuf.write value
    pad = field.fixedLen - len
    #puts "wrote #{len} bytes pad:#{pad} for #{field.to_s}"
    while pad > 0
      @iobuf.write_byte 0_u8
      pad -= 1
    end
  end

  def _pack_value (field, value : String)
    raise Exception.new "cannot pack String, should have been slice"
  end

  def typeid_of (value)
    case value.class
    when Int32.class then CrowType::TINT32
    when UInt32.class then CrowType::TUINT32
    when Int64.class then CrowType::TINT64
    when UInt64.class then CrowType::TUINT64
    when String.class then CrowType::TSTRING
    when Int8.class then CrowType::TINT8
    when UInt8.class then CrowType::TUINT8
    when Int16.class then CrowType::TINT16
    when UInt16.class then CrowType::TUINT16
    when Float32.class then CrowType::TFLOAT32
    when Float64.class then CrowType::TFLOAT64
    when Bool.class then CrowType::TUINT8
    when Bytes.class then CrowType::TBYTES
    when Slice(UInt8).class then CrowType::TBYTES
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

      write_field_info fld, @hdrio

      # update state

      @fields[fld.hash] = fld
      @fieldArray.push fld
      curField = fld

      write_field_tag curField, @iobuf

    else

      # seen before, write the tag

      write_field_tag curField, @iobuf
    end

    write_value value, curField, @iobuf
  end

  def write_value (value : String, curField : Field, io)
    raise Exception.new "typeid should be TSTRING #{curField.to_s}" if curField.typeid != CrowType::TSTRING
      write_varint value.size, io
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

#  def put_row_sep(flags : UInt8 = 0_u8)
#    start_row(flags)
#  end

  def flush()
    if @hdrio.size > 0 || @iobuf.size > 0
      @hdrio.rewind
      @iobuf.rewind
      @destio.write @hdrio.to_slice
      unless @haveRowStart || @iobuf.size == 0
        @destio.write_byte CrowTag::TROW.to_u8
      end
      @destio.write @iobuf.to_slice if @iobuf.size > 0
      @hdrio.clear
      @iobuf.clear
    end
    @haveRowStart = false
  end

  def start_row(flags : UInt8 = 0_u8)
    flush
    @rownum += 1
    @curIndex = 0
    unless @haveRowStart
      @haveRowStart = true
      @iobuf.write_byte CrowTag::TROW.to_u8 | ((flags & 0x07_u8) << 4)
    end
  end

  # ignores bits 3-7, encodes bits 0-2 to output stream
  def put_flags(value : UInt8)
    flags = value & 0x07_u8
    @iobuf.write_byte CrowTag::TFLAGS.to_u8 | (flags << 4)
  end

  # write THFIELD data
  #
  # THFIELD
  # index | 0x80 if have subid
  # typeid | 0x80 if have name
  # id
  # subid
  # namelen
  # name bytes
  #
  def write_field_info(fld : Field, io)

    tagbyte = CrowTag::THFIELD.to_u8
    tagbyte |= FIELDINFO_FLAG_HAS_SUBID if fld.subid > 0
    tagbyte |= FIELDINFO_FLAG_HAS_NAME if fld.name.size > 0
    tagbyte |= FIELDINFO_FLAG_RAW if fld.isRaw

    flag = 0_u8
    io.write_byte tagbyte

    io.write_byte fld.index
    io.write_byte fld.typeid.to_u8

    write_varint fld.id, io

    write_varint fld.subid, io if fld.subid > 0

    if fld.name.size > 0
      write_varint fld.name.size, io
      io.write fld.name.to_slice
    end

    #puts "write_field_info #{fld.to_s}"

    if fld.isRaw && fld.fixedLen > 0
      #puts "writing size of Raw #{fld.fixedLen}"
      write_varint fld.fixedLen, io
    end
  end


  def write_field_tag(fld : Field, io)
    io.write_byte fld.index | 0x80_u8
  end

  def write_varint(rawval, io = nil)
    io = @iobuf if io.nil?
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
    @io.write_bytes(n, @endian)
  end

  def write_fixed64(n : UInt64)
    @io.write_bytes(n, @endian)
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
