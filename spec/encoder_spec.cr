require "./spec_helper"

ENC_SPEC_LOG_ENABLED = false

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

  it "encodes bytes" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio
    a = Bytes[ 0x0b_u8, 0xad_u8, 0xca_u8, 0xfe_u8 ]
    b = Bytes.new(a.to_unsafe, a.size)
    enc.put b, MY_FIELD_A
    enc.put_row_sep
    enc.put b, MY_FIELD_A
    destio.to_slice.hexstring.should eq "01000c02040badcafe0380040badcafe"
  end

  it "encodes flags" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio
    s = ""

    enc.put 3_u32, MY_FIELD_A       ; s += "01 00030203"
    enc.put_row_sep                 ; s += "03"

    enc.put_flags 1_u8              ; s += "16"
    enc.put 4_u32, MY_FIELD_A       ; s += "8004"
    enc.put_row_sep 0_u8            ; s += "03"

    enc.put 5_u32, MY_FIELD_A       ; s += "8005"

    puts destio.to_slice.hexstring if ENC_SPEC_LOG_ENABLED
    destio.to_slice.hexstring.should eq s.gsub(" ","")
  end

  it "encodes using field name" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio

    s = ""

    enc.put "bob", "name"           ; s += "41 000100046e616d65 03 626f62"
    enc.put 23, "age"               ; s += "41 01020003616765 2e"
    enc.put true, "active"          ; s += "41 02090006616374697665 01"
    enc.put_row_sep                 ; s += "03"

    enc.put "jerry", "name"         ; s += "80 05 6a65727279"
    enc.put 58, "age"               ; s += "81 74"
    enc.put false, "active"         ; s += "82 00"
    enc.put_row_sep                 ; s += "03"

    enc.put "linda", "name"         ; s += "80 05 6c696e6461"
    enc.put 33, "age"               ; s += "81 42"
    enc.put true, "active"          ; s += "82 01"

    puts destio.to_slice.hexstring if ENC_SPEC_LOG_ENABLED
    destio.to_slice.hexstring.should eq s.gsub(" ","")
  end

  it "encodes floats" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio
    s = ""


    # 0b typeid : Float64
    enc.put 3000444888.325, MY_FIELD_A    ; s += "01 00 0b 02 66 66 0a fb e4 5a e6 41"
    # 0a # typeid : Float32
    enc.put 123.456_f32, MY_FIELD_B       ; s += "01 01 0a 36 79 e9 f6 42"
    enc.put_row_sep                       ; s += "03"

    enc.put 3000444888.325, MY_FIELD_A    ; s += "80 66 66 0a fb e4 5a e6 41"
    enc.put 123.456_f32, MY_FIELD_B       ; s += "81 79 e9 f6 42"

    puts destio.to_slice.hexstring if ENC_SPEC_LOG_ENABLED
    destio.to_slice.hexstring.should eq s.gsub(" ","")
  end

  it "encodes using field id" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio
    s = ""

    enc.put "Larry", MY_FIELD_A     ; s += "01 000102054c61727279"
    enc.put 23, MY_FIELD_B          ; s += "01 0102362e"
    enc.put true, MY_FIELD_C        ; s += "01 02096601"
    enc.put_row_sep                 ; s += "03"

    enc.put "Moe", MY_FIELD_A       ; s += "80 03 4d6f65"
    enc.put 62, MY_FIELD_B          ; s += "81 7c"
    enc.put false, MY_FIELD_C       ; s += "82 00"
    enc.put_row_sep                 ; s += "03"

    puts destio.to_slice.hexstring if ENC_SPEC_LOG_ENABLED
    destio.to_slice.hexstring.should eq s.gsub(" ","")
  end

  it "encodes out of order" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio
    s = ""

    # first row sets index order
    # each use TFIELDINFO followed by value

    enc.put "Larry", MY_FIELD_A         ; s += "01 00 0102 05 4c61727279"
    enc.put 23, MY_FIELD_B              ; s += "01 01 0236 2e"
    enc.put true, MY_FIELD_C            ; s += "01 02 0966 01"
    enc.put_row_sep                     ; s += "03"

    # enc C B A

    enc.put false, MY_FIELD_C           ; s += "82 00"
    enc.put 62, MY_FIELD_B              ; s += "81 7c"
    enc.put "Moe", MY_FIELD_A           ; s += "80 03 4d6f65"
    enc.put_row_sep                     ; s += "03"

    puts destio.to_slice.hexstring if ENC_SPEC_LOG_ENABLED
    destio.to_slice.hexstring.should eq s.gsub(" ","")
  end

  it "encodes sparse" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio

    s = ""
    enc.put "Larry", MY_FIELD_A     ; s += "01000102054c61727279"
    enc.put 23, MY_FIELD_B          ; s += "010102362e"
    enc.put_row_sep                 ; s += "03"

    enc.put true, MY_FIELD_C        ; s += "0102096601"
    enc.put_row_sep                 ; s += "03"

    enc.put "Moe", MY_FIELD_A       ; s += "80 03 4d6f65"
    enc.put_row_sep                 ; s += "03"

    enc.put 62, MY_FIELD_B          ; s += "81 7c"
    enc.put false, MY_FIELD_C       ; s += "82 00"

    puts destio.to_slice.hexstring  if ENC_SPEC_LOG_ENABLED
    destio.to_slice.hexstring.should eq s.gsub(" ","")
  end

  it "encodes set" do
    destio = IO::Memory.new
    enc = Crow::Encoder.new destio
    s = ""

    enc.put "Larry", MY_FIELD_A     ; s += "01 000102054c61727279"

    enc.start_set
    enc.put 23, MY_FIELD_B          ; s += "11 010236"   # fieldinfo - no value
    enc.put true, MY_FIELD_C        ; s += "11 020966"   # fieldinfo - no value
    setid = enc.end_set             ; s += "04 00 04 812e 8201" # SET id:0 length:4 [placement data]

    enc.put_set setid               ; s += "0500"
    enc.put_row_sep                 ; s += "03"

    enc.put "Moe", MY_FIELD_A       ; s += "80 03 4d6f65"
    enc.put_set setid, 0x03_u8      ; s += "3500"  # setref 0, flags=0x03, setid:0

    puts destio.to_slice.hexstring if ENC_SPEC_LOG_ENABLED
    destio.to_slice.hexstring.should eq s.gsub(" ","")
  end

end
