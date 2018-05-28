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
    enc.pack_def a16, MY_FIELD_A         ; s += "13 000c0210" # THFIELD Raw, indeX: 0, typeid:0x0c (TBYTES), id:02, len:16 (0x10)
    enc.pack_def 23, MY_FIELD_B          ; s += "13 010236" # THFIELD (Raw), index:0, id:02, type:
    enc.pack_def true, MY_FIELD_C        ; s += "13 020966"

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
end
