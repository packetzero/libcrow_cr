module Crow

class Decoder

  def initialize(destio : IO)
    @rownum=0
    @destio=destio
    @lastIndex = -1
  end

  def read_tag( tagid : UInt8,  fieldIndex : UInt8)

    # read type tag

    tagid = @destio.read_byte

    return nil if tagid.nil?

    return tagid if tagid == TROWSEP  # no fieldIndex byte

    if tagid == TNEXT
      fieldIndex = @lastIndex + 1
      return tagid
    end

    # read field index byte

    fieldIndex = @destio.read_byte
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
    loop do
      if shift >= 64
        raise Error.new("buffer overflow varint")
      end
      byte = @io.read_byte
      if byte.nil?
        return nil
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
