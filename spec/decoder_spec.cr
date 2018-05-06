require "./spec_helper"

def hex_to_io(hexstr)
  io = IO::Memory.new
  io.write hexstr.hexbytes
  io.rewind
  io
end

def decode(io)
  dec = Crow::Decoder.new io
  s = ""
  rowdata = dec.read_row
  while !(rowdata.nil? || rowdata.empty?)
    s += Crow.to_csv(rowdata) + "||"
    rowdata = dec.read_row
  end
  [ rowdata, s ]
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
    io = hex_to_io "0100010000046e616d6503626f620101020000036167652e010209000006616374697665010380056a65727279817482000380056c696e646181428201"
    rowdata, s = decode(io)
    s.should eq "\"bob\",23,1||\"jerry\",58,0||\"linda\",33,1||"
  end

  it "decodes floats" do
    io = hex_to_io "01000b02000066660afbe45ae64101010a36000079e9f642038066660afbe45ae6418179e9f642"
    rowdata, s = decode(io)
    s.should eq "3000444888.325,123.456||3000444888.325,123.456||"
  end

  it "decodes using field id" do
    io = hex_to_io "010001020000054c617272790101023600002e010209660000010380034d6f65817c820003"
    rowdata, str = decode(io)
    str.should eq "\"Larry\",23,1||\"Moe\",62,0||"
  end


end
