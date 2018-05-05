require "./spec_helper"

describe Crow do
  # TODO: Write tests

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

    puts destio.to_slice.hexstring
  end

  it "encodes using field name" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio

    idx : UInt32 = 0_u32
    enc.put "bob", idx
    enc.put 23, idx + 1
    enc.put true, idx + 2
    enc.put_row_sep


    puts destio.to_slice.hexstring
  end

  it "can zigzag 32" do

    val : Int32 = -234
    encval = Crow::Encoder.zigzag_encode32 val
    encval.should eq 0x01d3

    decval = Crow::Decoder.zigzag_decode32 encval
    decval.should eq val

    val = 234
    encval = Crow::Encoder.zigzag_encode32 val
    encval.should eq 0x01d4

    decval = Crow::Decoder.zigzag_decode32 encval
    decval.should eq val

    val = -12345
    encval = Crow::Encoder.zigzag_encode32 val
    encval.should eq 0x6071

    decval = Crow::Decoder.zigzag_decode32 encval
    decval.should eq val

    val = 12345
    encval = Crow::Encoder.zigzag_encode32 val
    encval.should eq 0x6072

    decval = Crow::Decoder.zigzag_decode32 encval
    decval.should eq val
  end

  it "can zigzag 64" do
    val : Int64 = 3000111222333_i64
    encval = Crow::Encoder.zigzag_encode64 val
    encval.should eq 6000222444666_u64

    decval = Crow::Decoder.zigzag_decode64 encval
    decval.should eq val

    val = -3000111222333_i64
    encval = Crow::Encoder.zigzag_encode64 val
    encval.should eq 6000222444665_u64

    decval = Crow::Decoder.zigzag_decode64 encval
    decval.should eq val
  end

end
