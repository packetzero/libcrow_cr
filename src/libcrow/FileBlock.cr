module Crow

MB_IN_KB              = 1024
DEFAULT_BLOCK_SIZE_KB = 1 * MB_IN_KB

class FileHeader
  property magic = ['C','r']
  property version : UInt8 = 0_u8
  property flags : UInt8 = 0_u8
end

class FileBlock
  property ts : UInt64 = 0_u64  # in Hundred Nanos
  property maxSizeKB : UInt16 = DEFAULT_BLOCK_SIZE_KB.to_u16
  property dataSetId : UInt16 = 0_u16  # application defined - give context to data
end

end # module
