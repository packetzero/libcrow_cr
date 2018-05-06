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

    # 01 00010000046e616d65 03 626f62
    # 01 0102000003616765 2e
    # 01 0209000006616374697665 01
    # 03

    enc.put "bob", "name"
    enc.put 23, "age"
    enc.put true, "active"
    enc.put_row_sep

    # 02 056a65727279
    # 02 74
    # 02 00
    # 03

    enc.put "jerry", "name"
    enc.put 58, "age"
    enc.put false, "active"
    enc.put_row_sep

    # 02 056c696e6461
    # 02 42
    # 02 01

    enc.put "linda", "name"
    enc.put 33, "age"
    enc.put true, "active"

    destio.to_slice.hexstring.should eq "0100010000046e616d6503626f620101020000036167652e010209000006616374697665010302056a65727279027402000302056c696e646102420201"
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

    # 01 0001020000054c61727279
    # 01 01023600002e
    # 01 020966000001
    # 03

    enc.put "Larry", MY_FIELD_A
    enc.put 23, MY_FIELD_B
    enc.put true, MY_FIELD_C
    enc.put_row_sep

    # 02 03 4d6f65
    # 02 7c
    # 02 00
    # 03

    enc.put "Moe", MY_FIELD_A
    enc.put 62, MY_FIELD_B
    enc.put false, MY_FIELD_C
    enc.put_row_sep

    #puts destio.to_slice.hexstring
    destio.to_slice.hexstring.should eq "010001020000054c617272790101023600002e010209660000010302034d6f65027c020003"
  end

  it "encodes out of order" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio

    # first row sets index order
    # each use TFIELDINFO followed by value
    #01 00 01020000 05 4c61727279
    #01 01 02360000 2e
    #01 02 09660000 01
    #03   # TROWSEP

    enc.put "Larry", MY_FIELD_A
    enc.put 23, MY_FIELD_B
    enc.put true, MY_FIELD_C
    enc.put_row_sep

    # enc C B A

    enc.put false, MY_FIELD_C
    enc.put 62, MY_FIELD_B
    enc.put "Moe", MY_FIELD_A
    enc.put_row_sep

    # 82 00
    # 81 7c
    # 80 03 4d6f65
    # 03

    #puts destio.to_slice.hexstring
    destio.to_slice.hexstring.should eq "010001020000054c617272790101023600002e01020966000001038200817c80034d6f6503"
  end

  it "encodes sparse" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio

    s = ""
    enc.put "Larry", MY_FIELD_A     ; s += "010001020000054c61727279"
    enc.put 23, MY_FIELD_B          ; s += "0101023600002e"
    enc.put_row_sep                 ; s += "03"

    enc.put true, MY_FIELD_C        ; s += "01020966000001"
    enc.put_row_sep                 ; s += "03"

    enc.put "Moe", MY_FIELD_A       ; s += "02034d6f65"
    enc.put_row_sep                 ; s += "03"

    enc.put 62, MY_FIELD_B          ; s += "817c"
    enc.put false, MY_FIELD_C       ; s += "0200"

    #puts destio.to_slice.hexstring
    destio.to_slice.hexstring.should eq s
  end


end
