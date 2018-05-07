# Crow Data Format Library in crystal-lang

Compact encoding for typed tabular data.  Think of it as a binary CSV file.

### Features

 - Uses protobuf encoding formats like varint, zigzag encoding
 - Does not require compilation of proto definitions
 - Fields (e.g. Columns) are defined inline
 - Data can be sparse

## Field class - describes a column

The application can refer to columns by IDs (like IPFIX) or Names (like a CSV file with header).
```
Field
  typeid : CrowType (TINT32, TSTRING, etc.)
  name : String
  id : UInt32
  subid : UInt32  # optional
```

## Usage : Encoding - Column names

```
enc = Crow::Encoder.new io

enc.put "bob", "name"
enc.put 23, "age"
enc.put true, "active"
enc.put_row_sep
```

## Usage : Decoding
```
dec = Crow::Decoder.new io
loop do
  rowdata = dec.read_row
  break if rowdata.nil? || rowdata.empty?

  rowdata.each do |item|
    # item.value is actual value (of type String, Int32, etc.)
    # item.field if Field object with id, name of column
  end
end
```
