import gleam/bit_array
import gleam/bool

pub type BinaryReader
{
    BinaryReader
    (
        data: BitArray,
        current_position: Int,
    )
}

pub fn create(from data: BitArray) -> BinaryReader
{
    BinaryReader(data: data, current_position: 0)
}

pub fn bytes_read(from reader: BinaryReader) -> Int
{
    reader.current_position
}

pub fn is_empty(reader: BinaryReader) -> Bool
{
    reader.data == <<>>
}

pub fn can_read(reader: BinaryReader) -> Bool
{
    reader.current_position < bit_array.byte_size(reader.data)
}

pub fn read(from reader: BinaryReader, take count: Int) -> Result(#(BinaryReader, BitArray), String)
{
    use <- bool.guard(when: reader.current_position + count > bit_array.byte_size(reader.data), return: Error("no enough bytes"))
    case bit_array.slice(at: reader.current_position, from: reader.data, take: count)
    {
        Ok(data_read) -> Ok(#(BinaryReader(current_position: reader.current_position + count, data: reader.data), data_read))
        _ -> Error("")
    }
}

pub fn advance(from reader: BinaryReader, up_to count: Int) -> BinaryReader
{
    BinaryReader(..reader, current_position: reader.current_position + count)
}

pub fn get_remaining(from reader: BinaryReader) -> Result(BitArray, String)
{
    case bit_array.slice(at: reader.current_position, from: reader.data, take: bit_array.byte_size(reader.data) - reader.current_position)
    {
        Ok(remaining_data) -> Ok(remaining_data)
        _ -> Error("")
    }
}

pub fn read_remaining(from reader: BinaryReader) -> Result(#(BinaryReader, BitArray), String)
{
    read(from: reader, take: bit_array.byte_size(reader.data) - reader.current_position)
}