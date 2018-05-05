module Crow

  # 16 :
  enum CrowTag
    TUNKNOWN
    TFIELDINFO      # 1
    TNEXT           # 2

    TINT32          # 3
    TUINT32         # 4
    TINT64          # 5
    TUINT64         # 6
    TDOUBLE         # 7
    TBOOL           # 8
    TSTRING         # 9

    TBYTES          # 10

    TROWSEP         # 11

    TSET            # 12
    TSETREF         # 13

    TIPADDR         # 14
    TMACADDR

    NUM_TYPES
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

    def initialize(id : UInt32, subid : UInt32 = 0)
      @id = id
      @subid = subid
    end

    def hash(hasher)
      hasher = @id.hash(hasher)
      hasher = @name.hash(hasher)
#      hasher = @tagid.hash(hasher)
      hasher = @subid.hash(hasher)
      hasher
    end

    def to_s()
      "Field id:#{@id} tagid:#{@tagid} name:'#{@name}' subid:#{@subid} index:#{@index}"
    end

  end

end
