require "./spec_helper"


struct Person
  property age : Int32 = 0
  property active : Bool = false
  property namez# of UInt8 [16]

  def initialize()
    @namez = [16] of UInt8
  end

  def name()
    String.new namez
  end
end

describe Crow::Encoder do

  it "encodes struct packed fields" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio

    s = ""
    a16 = Bytes.new 16
    enc.struct_hdr a16, MY_FIELD_A         ; s += "13 000c0210" # THFIELD Raw, indeX: 0, typeid:0x0c (TBYTES), id:02, len:16 (0x10)
    enc.struct_hdr 23, MY_FIELD_B          ; s += "13 010236" # THFIELD (Raw), index:0, id:02, type:
    enc.struct_hdr true, MY_FIELD_C        ; s += "13 020966"

    enc.start_row ; s += "05"
    enc.pack "Larry"     ; s += "4c61727279 0000000000000000000000"
    enc.pack 23          ; s += "17000000"
    enc.pack true        ; s += "01"

    enc.start_row ; s += "05"
    enc.pack "Moe"       ; s += "4d6f65 00000000000000000000000000"
    enc.pack 12          ; s += "0c000000"
    enc.pack false       ; s += "00"

    enc.flush
    destio.to_slice.hexstring.should eq s.gsub(" ","")

  end

  it "encodes struct and variable fields" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio

    s = ""
    enc.struct_hdr 64_u64, MY_FIELD_A      ; s += "13 000502" # THFIELD Raw, indeX: 0, typeid:0x05 (TUINT64), id:02
    enc.struct_hdr 23, MY_FIELD_B          ; s += "13 010236" # THFIELD (Raw), index:0, id:02, type:
    enc.hdr 1, MY_FIELD_C               ; s += "03 020266"

    enc.start_row ; s += "05"
    enc.pack 1_u64       ; s += "01000000 00000000"
    enc.pack 23          ; s += "17000000"
                           s += "02"  # length of varlen fields portion
    enc.put 1, MY_FIELD_C          ; s += "8202" # zigzag(1) = 2

    enc.start_row        ; s += "05"
    enc.pack 2_u64       ; s += "02000000 00000000"
    enc.pack 0xabcd       ; s += "cdab0000"
                           s += "02"  # length of varlen fields portion
    enc.put 3, MY_FIELD_C       ; s += "8206" # zigzag(3)

    enc.start_row        ; s += "05"
    enc.pack 3_u64       ; s += "03000000 00000000"
    enc.pack 0xabcd      ; s += "cdab0000"
                           s += "00"  # length of varlen fields portion

    enc.flush
    destio.to_slice.hexstring.should eq s.gsub(" ","")
  end

end
