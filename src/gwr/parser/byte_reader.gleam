import gleam/result
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

pub fn read_while(from reader: ByteReader, with eval: fn (BitArray) -> Bool) -> Result(#(ByteReader, BitArray), String)
{
    do_read_while(reader, eval, <<>>)
}

pub fn do_read_while(reader: ByteReader, eval: fn (BitArray) -> Bool, accumulator: BitArray) -> Result(#(ByteReader, BitArray), String)
{
    use #(reader_dirty, data) <- result.try(read(from: reader, take: 1))
    case eval(data)
    {
        True -> do_read_while(reader_dirty, eval, bit_array.append(accumulator, data))
        False -> Ok(#(reader, accumulator))
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

pub fn peek(from reader: ByteReader) -> Result(BitArray, String)
{
    case bit_array.slice(at: reader.current_position, from: reader.data, take: 1)
    {
        Ok(next) -> Ok(next)
        _ -> Error("")
    }
}

pub fn read_remaining(from reader: ByteReader) -> Result(#(ByteReader, BitArray), String)
{
    read(from: reader, take: bit_array.byte_size(reader.data) - reader.current_position)
}