require "./spec_helper"

describe Crow::Encoder do

  it "encodes varint" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio
    enc.write_varint 0
    destio.to_slice.hexstring.should eq "00"

    destio.clear
    enc.write_varint 512
    destio.to_slice.hexstring.should eq "8004"

    destio.clear
    enc.write_varint 16238729857298578_u64
    destio.to_slice.hexstring.should eq "92e1fde59ea1ec1c"

  end

  it "encodes using field name" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio

    enc.put "bob", "name"
    enc.put 23, "age"
    enc.put true, "active"
    enc.put_row_sep

    enc.put "jerry", "name"
    enc.put 58, "age"
    enc.put false, "active"
    enc.put_row_sep

    enc.put "linda", "name"
    enc.put 33, "age"
    enc.put true, "active"

    destio.to_slice.hexstring.should eq "0100090000046e616d6503626f6201010a0000036167652e010211000006616374697665010302056a6572727902741102000302056c696e64610242110201"
    #puts destio.to_slice.hexstring
  end

  it "encodes floats" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio

    enc.put 3000444888.325, MY_FIELD_A
    enc.put 123.456_f32, MY_FIELD_B
    enc.put_row_sep

    # 01 TFIELDINFO
    # 00 index
    # 13 tagid : Float64
    # 02 id
    # 00 subid
    # 00 name len
    # d8 27 d7 b2 00 00 00 00 value bytes

    # 01 # TFIELDINFO
    # 01 # index
    # 12 # tagid : Float32
    # 36 # id
    # 00 # subid
    # 00 # name len
    # 7b 00 00 00 # value bytes

    # 03 # TROWSEP

    enc.put 3000444888.325, MY_FIELD_A
    enc.put 123.456_f32, MY_FIELD_B

    # 02 # TNEXT
    # d8 27 d7 b2 00 00 00 00 # value bytes
    # 02 # TNEXT
    # 7b 00 00 00 # value bytes

    #puts destio.to_slice.hexstring
    destio.to_slice.hexstring.should eq "01001302000066660afbe45ae64101011236000079e9f642030266660afbe45ae6410279e9f642"
  end

  it "encodes using field id" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio


    enc.put "Larry", MY_FIELD_A
    enc.put 23, MY_FIELD_B
    enc.put true, MY_FIELD_C
    enc.put_row_sep

    enc.put "Moe", MY_FIELD_A
    enc.put 62, MY_FIELD_B
    enc.put false, MY_FIELD_C
    enc.put_row_sep

    #puts destio.to_slice.hexstring
    destio.to_slice.hexstring.should eq "010009020000054c6172727901010a3600002e010211660000010302034d6f65027c11020003"
  end


end
