import gleam/bit_array
import gleam/bool

pub type ByteReader
{
    ByteReader
    (
        data: BitArray,
        current_position: Int,
    )
}

pub fn create(from data: BitArray) -> ByteReader
{
    ByteReader(data: data, current_position: 0)
}

pub fn bytes_read(from reader: ByteReader) -> Int
{
    reader.current_position
}

pub fn is_empty(reader: ByteReader) -> Bool
{
    reader.data == <<>>
}

pub fn can_read(reader: ByteReader) -> Bool
{
    reader.current_position < bit_array.byte_size(reader.data)
}

pub fn read(from reader: ByteReader, take count: Int) -> Result(#(ByteReader, BitArray), String)
{
    use <- bool.guard(when: reader.current_position + count > bit_array.byte_size(reader.data), return: Error("no enough bytes"))
    case bit_array.slice(at: reader.current_position, from: reader.data, take: count)
    {
        Ok(data_read) -> Ok(#(ByteReader(current_position: reader.current_position + count, data: reader.data), data_read))
        _ -> Error("")
    }
}

pub fn advance(from reader: ByteReader, up_to count: Int) -> ByteReader
{
    ByteReader(..reader, current_position: reader.current_position + count)
}

pub fn get_remaining(from reader: ByteReader) -> Result(BitArray, String)
{
    case bit_array.slice(at: reader.current_position, from: reader.data, take: bit_array.byte_size(reader.data) - reader.current_position)
    {
        Ok(remaining_data) -> Ok(remaining_data)
        _ -> Error("")
    }
}

pub fn read_remaining(from reader: ByteReader) -> Result(#(ByteReader, BitArray), String)
{
    read(from: reader, take: bit_array.byte_size(reader.data) - reader.current_position)
}