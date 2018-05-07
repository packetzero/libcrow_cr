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
  loop do
    rowdata = dec.read_row
    break if rowdata.nil? || rowdata.empty?
    s += Crow.to_csv(rowdata) + "||"
  end
  [ header_line(dec.field_defs) , s ]
end

def header_line(field_defs)
  s = ""
  i = 0
  while i < field_defs.size
    fld = field_defs[i]

    s += "," if i > 0
    if fld.name.size > 0
      s += fld.name
    end
    if fld.id > 0
      s += " " if fld.name.size > 0
      s += "#{fld.id}"
      s += "_#{fld.subid}" if fld.subid > 0
    end
    i+=1
  end
  s
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
    io = hex_to_io "01008100046e616d6505626f222c6201018200036167652e0102890006616374697665010380056a65727279817482000380056c696e646181428201"
#    io = hex_to_io "01008100046e616d6503626f6201018200036167652e0102890006616374697665010380056a65727279817482000380056c696e646181428201"
    header_line, s = decode(io)

    s.should eq "\"bo\"\",b\",23,1||jerry,58,0||linda,33,1||"
    header_line.should eq "name,age,active"
  end

  it "decodes floats" do
    io = hex_to_io "01000b0266660afbe45ae64101010a3679e9f642038066660afbe45ae6418179e9f642"
    rowdata, s = decode(io)
    s.should eq "3000444888.325,123.456||3000444888.325,123.456||"
  end

  it "decodes using field id" do
    io = hex_to_io "01000102054c61727279010102362e01020966010380034d6f65817c820003"
    header_line, str = decode(io)
    str.should eq "Larry,23,1||Moe,62,0||"
    header_line.should eq "2,54,102"
  end

  it "decodes bytes" do
    io = hex_to_io "01000c02040badcafe0380040badcafe"
    header_line, str = decode(io)
    str.should eq "0badcafe||0badcafe||"
  end



end
