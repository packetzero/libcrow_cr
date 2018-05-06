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

    destio.to_slice.hexstring.should eq "0100010000046e616d6503626f620101020000036167652e010209000006616374697665010302056a65727279027482000302056c696e646102428201"
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
    # 0b typeid : Float64
    # 02 id
    # 00 subid
    # 00 name len
    # 66 66 0a fb e4 5a e6 41 value bytes

    # 01 # TFIELDINFO
    # 01 # index
    # 0a # typeid : Float32
    # 36 # id
    # 00 # subid
    # 00 # name len
    # 79 e9 f6 42 # value bytes

    # 03 # TROWSEP

    enc.put 3000444888.325, MY_FIELD_A
    enc.put 123.456_f32, MY_FIELD_B

    # 02 # TNEXT
    # 66 66 0a fb e4 5a e6 41 # value bytes
    # 02 # TNEXT
    # 79 e9 f6 42 # value bytes

    #puts destio.to_slice.hexstring
    destio.to_slice.hexstring.should eq "01000b02000066660afbe45ae64101010a36000079e9f642030266660afbe45ae6410279e9f642"
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
    destio.to_slice.hexstring.should eq "010001020000054c617272790101023600002e010209660000010302034d6f65027c820003"
  end


end
