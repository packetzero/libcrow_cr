require "./spec_helper"

def hex_to_io(hexstr)
  io = IO::Memory.new
  io.write hexstr.hexbytes
  io.rewind
  io
end

describe Crow::Decoder do

  it "decodes varint" do
    io = hex_to_io "00"
    dec = Crow::Decoder.new io
    val = dec.read_varint
    val.should eq 0

    io = hex_to_io "8004"
    dec = Crow::Decoder.new io
    val = dec.read_varint
    val.should eq 512

    io = hex_to_io "92e1fde59ea1ec1c"
    dec = Crow::Decoder.new io
    val = dec.read_varint
    val.should eq 16238729857298578_u64

  end

  it "decodes using field name" do
    io = hex_to_io "0100090000046e616d6503626f6201010a0000036167652e010211000006616374697665010302056a6572727902741102000302056c696e64610242110201"
    dec = Crow::Decoder.new io
    s = ""
    while true
      rowdata = dec.read_row
      break if rowdata.nil? || rowdata.empty?

      s += Crow.to_csv(rowdata) + "||"
    end
    s.should eq "\"bob\",23,1||\"jerry\",58,0||\"linda\",33,1||"
  end

  it "decodes floats" do
    io = hex_to_io "01001302000066660afbe45ae64101011236000079e9f642030266660afbe45ae6410279e9f642"
    dec = Crow::Decoder.new io
    s = ""
    rowdata = dec.read_row
    while !(rowdata.nil? || rowdata.empty?)
      s += Crow.to_csv(rowdata) + "||"
      rowdata = dec.read_row
    end
    s.should eq "3000444888.325,123.456||3000444888.325,123.456||"
  end

  it "decodes using field id" do
#    destio = IO::Memory.new
#    enc = Crow::Encoder.new destio


#    enc.put "Larry", MY_FIELD_A
#    enc.put 23, MY_FIELD_B
#    enc.put true, MY_FIELD_C
#    enc.put_row_sep

#    enc.put "Moe", MY_FIELD_A
#    enc.put 62, MY_FIELD_B
#    enc.put false, MY_FIELD_C
#    enc.put_row_sep

    #puts destio.to_slice.hexstring
#    destio.to_slice.hexstring.should eq "010009020000054c6172727901010a3600002e010211660000010302034d6f65027c11020003"
  end


end
