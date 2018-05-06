module Crow

  @[Flags]
  enum MsgHdrFlags
    BigEndian      # 1 << 0
  end

  struct MsgHdr
    property magic =  [ 'C', 'r' ]
    property version = 0_u8
    property flags = 0_u8
  end

end # module Crow
