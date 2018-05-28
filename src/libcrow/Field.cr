module Crow

  # Tag definitions.
  enum CrowTag
    TUNKNOWN
    TBLOCK          # 1    # optional
    TTABLE          # 2    # optional

    THFIELD         # 3    # HEADER : Describes field
    THREF           # 4    # HEADER : Declares reference to subtable

    TROW            # 5
    TREF            # 6
    TFLAGS          # 7

    NUMTAGS
  end

  # the tagid byte has following scenarios:
  #
  # 1nnn nnnn    Upper bit set - lower 7 bits contain index of field, value bytes follow
  # 0FFF 0011    TFIELDINFO, if bit 4 set, no value follows definition, bit 5: subid present, bit 6: value present
  # 0FFF 0101    TROW, bits 4-6 contain app specific flags
  # 0FFF 0111    TFLAGS, bits 4-6 contain app specific flags
  ##### 0FFF 0101    THREF, bits 4-6 contain app specific flags
  # 0000 TTTT    Tagid in bits 0-3

  FIELDINFO_FLAG_RAW        = 0x10_u8  # Part of packed struct
  FIELDINFO_FLAG_HAS_SUBID  = 0x20_u8
  FIELDINFO_FLAG_HAS_NAME   = 0x40_u8

  enum CrowType
    NONE
    TSTRING         # 1
    TINT32          # 2
    TUINT32         # 3
    TINT64          # 4
    TUINT64         # 5
    TINT16          # 6
    TUINT16         # 7
    TINT8           # 8
    TUINT8          # 9

    TFLOAT32        # 10
    TFLOAT64        # 11
    TBYTES          # 12

    NUM_TYPES

    def self.to_type (val : UInt8)
      case val
      when TSTRING.to_u8 then TSTRING
      when TINT8.to_u8 then TINT8
      when TUINT8.to_u8 then TUINT8
      when TINT16.to_u8 then TINT16
      when TUINT16.to_u8 then TUINT16
      when TINT32.to_u8 then TINT32
      when TUINT32.to_u8 then TUINT32
      when TINT64.to_u8 then TINT64
      when TUINT64.to_u8 then TUINT64
      when TFLOAT32.to_u8 then TFLOAT32
      when TFLOAT64.to_u8 then TFLOAT64
      when TBYTES.to_u8 then TBYTES
      else
        NONE
      end
    end
  end


  class Field

    property name : String = ""
    property id : UInt32 = 0_u32
    property subid : UInt32 = 0_u32
    property typeid : CrowType = CrowType::NONE

    property index : UInt8 = 0_u8
    property isRaw : Bool = false
    property fixedLen = 0_u32

    def initialize(name : String)
      @name = name
    end

    def initialize(id : UInt32, subid : UInt32 = 0_u32)
      @id = id
      @subid = subid
    end

    def hash(hasher)
      hasher = @id.hash(hasher)
      hasher = @name.hash(hasher)
      hasher = @subid.hash(hasher)
      hasher
    end

    def to_s()
      "Field id:#{@id} type:#{@typeid} #{@typeid.to_s} name:'#{@name}' subid:#{@subid} index:#{@index} raw:#{@isRaw} fixedLen:#{@fixedLen}"
    end

  end


end
