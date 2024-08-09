local BLOCKS_REVERSE_IDMAP = ...;
local ffi    = require "ffi"; -- I love having to define this stuff again
ffi.cdef([[
    struct block_data {
        uint16_t id;
        uint8_t light_red;
        uint8_t light_blue;
        uint8_t light_green;
        uint8_t flag;
    }
]])
ffi.cdef([[
    struct cvertex {
        float x, y, z;
        float u, v;
        uint8_t r, g, b, a;
    }
]])

local input = love.thread.getChannel("chunk_gen_input");

local chunk_table = input:pop();
while chunk_table do
    local chunk_pointer = love.data.newByteData(ffi.sizeof("struct block_data") * 16*16*16);
    local cx = chunk_table[1];
    local cy = chunk_table[2];
    local cz = chunk_table[3];
    local chunk = ffi.cast("struct block_data *", chunk_pointer:getFFIPointer());
    --love.thread.getChannel("chunk_gen_output"):push(string.format("Chunk %d,%d,%d", cx, cy, cz));

    for x=0,15 do
        for y=0,15 do
            for z=0,15 do
                local i = z*256+y*16+x;
                chunk[i].id = 1
                if z+cz*16 > 0 then
                    chunk[i].id = 1;
                else
                    if (x+cx*16 + y+cy*16) % 2 == 0 then
                        chunk[i].id = BLOCKS_REVERSE_IDMAP["grass"];
                    else
                        chunk[i].id = BLOCKS_REVERSE_IDMAP["dirt"];
                    end
                end
            end
        end
    end
    love.thread.getChannel("chunk_gen_output"):push({"finished", cx, cy, cz, chunk_pointer});

    -- TODO: IT SHOULDN'T WORK
    --chunk_pointer:release();
    --chunk = nil;
    --chunk_table = nil;
    chunk_table = input:pop();
end

BLOCKS_REVERSE_IDMAP = nil;
ffi = nil;