require "./spec_helper"

# miscellaneous tests

MY_FIELD_A = 2
MY_FIELD_B = 54
MY_FIELD_C = 102

describe Crow do

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
