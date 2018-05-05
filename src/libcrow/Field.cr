module Crow

  # Tag definitions.
  enum CrowTag
    TUNKNOWN
    TFIELDINFO      # 1
    TNEXT           # 2
    TROWSEP         # 3
    TBLOCK          # 4
    TSET            # 5
    TSETREF         # 6
    TRSVD1
    TRSVD2

    # type tags

    TSTRING         # 9
    TINT32          # 10
    TUINT32         # 11
    TINT64          # 12
    TUINT64         # 13
    TINT16          # 14
    TUINT16         # 15
    TINT8           # 16
    TUINT8          # 17

    TFLOAT32        # 18
    TFLOAT64        # 19
    TBYTES          # 20

    NUM_TYPES

    def self.is_type (tagid : CrowTag ) : Bool
      !(tagid < TSTRING || tagid >= NUM_TYPES)
    end

    def self.to_tag (val : UInt8)
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
      end
    end
  end


  class Field

    property name : String = ""
    property id : UInt32 = 0_u32
    property subid : UInt32 = 0_u32
    property tagid : CrowTag = CrowTag::TUNKNOWN

    property index : UInt8 = 0_u8

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
      "Field id:#{@id} tagid:#{@tagid} name:'#{@name}' subid:#{@subid} index:#{@index}"
    end

  end

end
