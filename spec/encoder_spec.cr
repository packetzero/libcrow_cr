require "./spec_helper"

ENC_SPEC_LOG_ENABLED = false

describe Crow::Encoder do

  it "encodes varint" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio
    enc.write_varint 0
    enc.flush
    destio.to_slice.hexstring.should eq "0500"

    destio.clear
    enc.write_varint 512
    enc.flush
    destio.to_slice.hexstring.should eq "058004"

    destio.clear
    enc.write_varint 16238729857298578_u64
    enc.flush
    destio.to_slice.hexstring.should eq "0592e1fde59ea1ec1c"

  end

  it "encodes bytes" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio
    a = Bytes[ 0x0b_u8, 0xad_u8, 0xca_u8, 0xfe_u8 ]
    b = Bytes.new(a.to_unsafe, a.size)
    s = ""
    enc.put b, MY_FIELD_A               ; s += "03000c02"  # index:0, type:0c, :id:02
                                        ; s += "05"
                                        ; s += "80040badcafe"
    enc.start_row                       ; s += "05"
    enc.put b, MY_FIELD_A
                                        ; s += "80040badcafe"
    enc.flush
    destio.to_slice.hexstring.should eq s
  end

  it "encodes using field name" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio

    s = ""

    enc.put "bob", "name"           ; s += "43 000100046e616d65" # header - field def
    enc.put 23, "age"               ; s += "43 01020003616765" # header - field def
    enc.put true, "active"          ; s += "43 02090006616374697665" # header - field def
    # row data
    s += "05"
    s += "80 03 626f62"
    s += "812e"
    s += "8201"

    enc.start_row                 ; s += "05"
    enc.put "jerry", "name"         ; s += "80 05 6a65727279"
    enc.put 58, "age"               ; s += "81 74"
    enc.put false, "active"         ; s += "82 00"

    enc.start_row                 ; s += "05"
    enc.put "linda", "name"         ; s += "80 05 6c696e6461"
    enc.put 33, "age"               ; s += "81 42"
    enc.put true, "active"          ; s += "82 01"
    enc.flush

    puts destio.to_slice.hexstring if ENC_SPEC_LOG_ENABLED
    destio.to_slice.hexstring.should eq s.gsub(" ","")
  end

  it "encodes floats" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio
    s = ""


    # 0b typeid : Float64
    enc.put 3000444888.325, MY_FIELD_A    ; s += "03 00 0b 02";
    # 0a # typeid : Float32
    enc.put 123.456_f32, MY_FIELD_B       ; s += "03 01 0a 36";
    s += "05"
    s += "80 66 66 0a fb e4 5a e6 41"
    s += "81 79 e9 f6 42"

    enc.start_row                       ; s += "05"

    enc.put 3000444888.325, MY_FIELD_A    ; s += "80 66 66 0a fb e4 5a e6 41"
    enc.put 123.456_f32, MY_FIELD_B       ; s += "81 79 e9 f6 42"
    enc.flush

    puts destio.to_slice.hexstring if ENC_SPEC_LOG_ENABLED
    destio.to_slice.hexstring.should eq s.gsub(" ","")
  end

  it "encodes using field id" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio
    s = ""

    enc.put "Larry", MY_FIELD_A     ; s += "03 000102"
    enc.put 23, MY_FIELD_B          ; s += "03 010236"
    enc.put true, MY_FIELD_C        ; s += "03 020966"

    s += "05" # row data start
    s += "80054c61727279"
    s += "812e"
    s += "8201"

    enc.start_row                 ; s += "05"

    enc.put "Moe", MY_FIELD_A       ; s += "80 03 4d6f65"
    enc.put 62, MY_FIELD_B          ; s += "81 7c"
    enc.put false, MY_FIELD_C       ; s += "82 00"

    enc.flush

    puts destio.to_slice.hexstring if ENC_SPEC_LOG_ENABLED
    destio.to_slice.hexstring.should eq s.gsub(" ","")
  end

  it "encodes out of order" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio
    s = ""

    # first row sets index order
    # each use TFIELDINFO followed by value

    enc.put "Larry", MY_FIELD_A     ; s += "03 000102"
    enc.put 23, MY_FIELD_B          ; s += "03 010236"
    enc.put true, MY_FIELD_C        ; s += "03 020966"

    s += "05" # row data start
    s += "80054c61727279"
    s += "812e"
    s += "8201"

    # enc C B A

    enc.start_row                     ; s += "05"
    enc.put false, MY_FIELD_C           ; s += "82 00"
    enc.put 62, MY_FIELD_B              ; s += "81 7c"
    enc.put "Moe", MY_FIELD_A           ; s += "80 03 4d6f65"

    enc.flush

    puts destio.to_slice.hexstring if ENC_SPEC_LOG_ENABLED
    destio.to_slice.hexstring.should eq s.gsub(" ","")
  end

  it "encodes sparse" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio

    s = ""

    enc.start_row
    enc.put "Larry", MY_FIELD_A     ; s += "03 000102" # field def
    enc.put 23, MY_FIELD_B          ; s += "03 010236" # field def

    s += "05" # row data start
    s += "80054c61727279"
    s += "812e"

    enc.start_row
    enc.put true, MY_FIELD_C        ; s += "03 020966" # field def
    s += "05" # row data start
    s += "8201"

    enc.start_row                 ; s += "05"
    enc.put "Moe", MY_FIELD_A       ; s += "80 03 4d6f65"

    enc.start_row                 ; s += "05"
    enc.put 62, MY_FIELD_B          ; s += "81 7c"
    enc.put false, MY_FIELD_C       ; s += "82 00"

    enc.flush

    puts destio.to_slice.hexstring  if ENC_SPEC_LOG_ENABLED
    destio.to_slice.hexstring.should eq s.gsub(" ","")
  end

  it "encodes flags" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio
    s = ""

    enc.start_row
    enc.put 3_u32, MY_FIELD_A       ; s += "03 000302"
    s += "05" # row data start
    s += "8003"

    enc.start_row                   ; s += "05"
    enc.put_flags 1_u8              ; s += "17"
    enc.put 4_u32, MY_FIELD_A       ; s += "8004"

    enc.start_row                   ; s += "05"
    enc.put 5_u32, MY_FIELD_A       ; s += "8005"
    enc.flush

    puts destio.to_slice.hexstring if ENC_SPEC_LOG_ENABLED
    destio.to_slice.hexstring.should eq s.gsub(" ","")
  end

end
