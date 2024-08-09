local a, b, c, d, e, f, g, index, BLOCKS, BLOCKS_IDMAP, BLOCKS_IS_TRANSPARENT, BLOCKS_RENDERTYPE, BLOCKS_TEXTURE = ...
local ffi    = require "ffi"
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
local yplus,yminus,xplus,xminus,zplus,zminus
local main   = ffi.cast("struct block_data *", a:getFFIPointer());
if b then yplus  = ffi.cast("struct block_data *", b:getFFIPointer()); end
if c then yminus = ffi.cast("struct block_data *", c:getFFIPointer()); end
if d then xplus  = ffi.cast("struct block_data *", d:getFFIPointer()); end
if e then xminus = ffi.cast("struct block_data *", e:getFFIPointer()); end
if f then zplus  = ffi.cast("struct block_data *", f:getFFIPointer()); end
if g then zminus = ffi.cast("struct block_data *", g:getFFIPointer()); end

local FACING_ZPLUS = 1
local FACING_ZMINUS = 2
local FACING_XPLUS = 3
local FACING_XMINUS = 4
local FACING_YPLUS = 5
local FACING_YMINUS = 6
local bit = require "bit"

-- Local stuff is faster than globals
local function get_block(x, y, z)
    return main[z*256+y*16+x]
end

local function is_transparent(x, y, z)
    local b = false;
    if x>15 or x<0 or y>15 or y<0 or z>15 or z<0 then
        if x == 16 and xplus then
            b = xplus[z*256+y*16].id;
        elseif x == -1 and xminus then
            b = xminus[z*256+y*16+15].id;
        elseif y == 16 and yplus then
            b = yplus[z*256+x].id;
        elseif y == -1 and yminus then
            b = yminus[z*256+240+x].id;
        elseif z == 16 and zplus then
            b = zplus[y*16+x].id;
        elseif z == -1 and zminus then
            b = zminus[3840+y*16+x].id;
        end
        return BLOCKS_IS_TRANSPARENT[b];
    end;
    b = main[z*256+y*16+x].id
    return BLOCKS_IS_TRANSPARENT[b];
end

-- Look at doc for an explanation of this absolute beauty
local function orientation_choose_face(orientation, face)
    if orientation == 0 or orientation == 1 then
        return face;
    elseif orientation == 2 then
        return 2*math.floor((face+1)/2)-(face+1)%2;
    elseif orientation == 3 then
        if face == 5 or face == 6 then return face end;
        if face == 3 or face == 4 then return 1+(face%2) end;
        if face == 1 or face == 2 then return face+2 end;
    elseif orientation == 4 then
        if face == 5 or face == 6 then return face end;
        if face == 3 or face == 4 then return face-2 end;
        if face == 1 or face == 2 then return 3+(face%2) end;
    elseif orientation == 5 then
        if face == 5 or face == 6 then return 1+(face%2) end;
        if face == 3 or face == 4 then return face end;
        if face == 1 or face == 2 then return 6-(face%2) end;
    elseif orientation == 6 then
        if face == 5 or face == 6 then return 2-(face%2) end;
        if face == 3 or face == 4 then return face end;
        if face == 1 or face == 2 then return 5+(face%2) end;
    end
end

local dataindex = 0;
local vertex_count = 0;

-- 147456 vertices because we trade off a bit of memory to skip a whole loop on every block of the chunk to make it work faster (may need more vertices)
-- TODO: make it so we use realloc to make practically infinite cap
local data = love.data.newByteData(ffi.sizeof("struct cvertex") * 147456)
local datapointer = ffi.cast("struct cvertex *", data:getFFIPointer())

local function add_vertex_to_data(x, y, z, u, v, r, g, b, a)
    datapointer[dataindex].x = x;
    datapointer[dataindex].y = y;
    datapointer[dataindex].z = z;
    datapointer[dataindex].u = u;
    datapointer[dataindex].v = v;
    datapointer[dataindex].r = r;
    datapointer[dataindex].g = g;
    datapointer[dataindex].b = b;
    datapointer[dataindex].a = a;
    dataindex = dataindex + 1;
end


local function add_quad(x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4, u1, v1, u2, v2, u3, v3, u4, v4, r, g, b, a)
    add_vertex_to_data(x1, y1, z1, u1, v1, r, g, b, a);
    add_vertex_to_data(x2, y2, z2, u2, v2, r, g, b, a);
    add_vertex_to_data(x4, y4, z4, u4, v4, r, g, b, a);
    
    add_vertex_to_data(x2, y2, z2, u2, v2, r, g, b, a);
    add_vertex_to_data(x3, y3, z3, u3, v3, r, g, b, a);
    add_vertex_to_data(x4, y4, z4, u4, v4, r, g, b, a);
end
-- Minecraft does this really clever thing of making faces of one axis darker to make the game not look like trash
local function face_yplus(x, y, z, u, v)
    add_vertex_to_data(x+1, y+1, z, u/64, (v+1)/64, 180, 180, 180, 255);
    add_vertex_to_data(x, y+1, z, (u+1)/64, (v+1)/64, 180, 180, 180, 255);
    add_vertex_to_data(x, y+1, z+1, (u+1)/64, v/64, 180, 180, 180, 255);
            
    add_vertex_to_data(x+1, y+1, z, u/64, (v+1)/64, 180, 180, 180, 255);
    add_vertex_to_data(x+1, y+1, z+1, u/64, v/64, 180, 180, 180, 255);
    add_vertex_to_data(x, y+1, z+1, (u+1)/64, v/64, 180, 180, 180, 255);
end
local function face_yminus(x, y, z, u, v)
    add_vertex_to_data(x+1, y, z, (u+1)/64, (v+1)/64, 180, 180, 180, 255);
    add_vertex_to_data(x, y, z, u/64, (v+1)/64, 180, 180, 180, 255);
    add_vertex_to_data(x, y, z+1, u/64, v/64, 180, 180, 180, 255);
            
    add_vertex_to_data(x+1, y, z, (u+1)/64, (v+1)/64, 180, 180, 180, 255);
    add_vertex_to_data(x+1, y, z+1, (u+1)/64, v/64, 180, 180, 180, 255);
    add_vertex_to_data(x, y, z+1, u/64, v/64, 180, 180, 180, 255);
end
local function face_zplus(x, y, z, u, v)
    add_vertex_to_data(x, y, z+1, u/64,     (v+1)/64, 255, 255, 255, 255);
    add_vertex_to_data(x, y+1, z+1, u/64,      v/64, 255, 255, 255, 255);
    add_vertex_to_data(x+1, y+1, z+1, (u+1)/64,  v/64, 255, 255, 255, 255);
            
    add_vertex_to_data(x, y, z+1, u/64,     (v+1)/64, 255, 255, 255, 255);
    add_vertex_to_data(x+1, y, z+1, (u+1)/64, (v+1)/64, 255, 255, 255, 255);
    add_vertex_to_data(x+1, y+1, z+1, (u+1)/64,  v/64, 255, 255, 255, 255);
end
local function face_zminus(x, y, z, u, v)
    add_vertex_to_data(x, y, z, (u+1)/64, (v+1)/64, 255, 255, 255, 255);
    add_vertex_to_data(x, y+1, z, u/64, (v+1)/64, 255, 255, 255, 255);
    add_vertex_to_data(x+1, y+1, z, u/64, v/64, 255, 255, 255, 255);
            
    add_vertex_to_data(x, y, z, (u+1)/64, (v+1)/64, 255, 255, 255, 255);
    add_vertex_to_data(x+1, y, z, (u+1)/64, v/64, 255, 255, 255, 255);
    add_vertex_to_data(x+1, y+1, z, u/64, v/64, 255, 255, 255, 255);
end
local function face_xplus(x, y, z, u, v)
    add_vertex_to_data(x+1, y, z, u/64, (v+1)/64, 255, 255, 255, 255);
    add_vertex_to_data(x+1, y+1, z, (u+1)/64, (v+1)/64, 255, 255, 255, 255);
    add_vertex_to_data(x+1, y+1, z+1, (u+1)/64, v/64, 255, 255, 255, 255);
            
    add_vertex_to_data(x+1, y, z, u/64, (v+1)/64, 255, 255, 255, 255);
    add_vertex_to_data(x+1, y, z+1, u/64, v/64, 255, 255, 255, 255);
    add_vertex_to_data(x+1, y+1, z+1, (u+1)/64, v/64, 255, 255, 255, 255);
end
local function face_xminus(x, y, z, u, v)
    add_vertex_to_data(x, y, z, (u+1)/64, (v+1)/64, 255, 255, 255, 255);
    add_vertex_to_data(x, y+1, z, u/64, (v+1)/64, 255, 255, 255, 255);
    add_vertex_to_data(x, y+1, z+1, u/64, v/64, 255, 255, 255, 255);
            
    add_vertex_to_data(x, y, z, (u+1)/64, (v+1)/64, 255, 255, 255, 255);
    add_vertex_to_data(x, y, z+1, (u+1)/64, v/64, 255, 255, 255, 255);
    add_vertex_to_data(x, y+1, z+1, u/64, v/64, 255, 255, 255, 255);
end

local prev_u = 0;
local prev_v = 0;
local prev_b = 0;

for x=0,15 do
for y=0,15 do
for z=0, 15 do
    local b = get_block(x,y,z).id
        
    if BLOCKS_RENDERTYPE[b]==1 then -- BLOCK
        local block_table = BLOCKS[BLOCKS_IDMAP[b]]
        if is_transparent(x, y+1, z) then
            face_yplus(x, y, z, block_table.yplus[1], block_table.yplus[2])
        end
        if is_transparent(x, y-1, z) then
            face_yminus(x, y, z, block_table.yminus[1], block_table.yminus[2])
        end
        if is_transparent(x, y, z+1) then
            face_zplus(x, y, z, block_table.top[1], block_table.top[2])
        end
        if is_transparent(x, y, z-1) then
            face_zminus(x, y, z, block_table.bottom[1], block_table.bottom[2])
        end
        if is_transparent(x+1, y, z) then
            face_xplus(x, y, z, block_table.xplus[1], block_table.xplus[2])
        end
        if is_transparent(x-1, y, z) then
            face_xminus(x, y, z, block_table.xminus[1], block_table.xminus[2]);
        end
    elseif BLOCKS_RENDERTYPE[b]==2 then -- SLAB
        local state = get_block(x, y, z).flag;
        local block_table = BLOCKS[BLOCKS_IDMAP[b]]
        local u,v = block_table.texture[1], block_table.texture[2]
        local z_offset = 0; -- Offset to render the slab if it's on top or bottom
        if state == 1 then  z_offset = 0.5 end;
        face_zplus(x, y, z-0.5+z_offset, u, v)
        face_zminus(x, y, z+z_offset, u, v)
        --yplus
        add_vertex_to_data(x+1, y+1, z+z_offset, u/64, (v+0.5)/64, 180, 180, 180, 255);
        add_vertex_to_data(x, y+1, z+z_offset, (u+1)/64, (v+0.5)/64, 180, 180, 180, 255);
        add_vertex_to_data(x, y+1, z+0.5+z_offset, (u+1)/64, v/64, 180, 180, 180, 255);
            
        add_vertex_to_data(x+1, y+1, z+z_offset, u/64, (v+0.5)/64, 180, 180, 180, 255);
        add_vertex_to_data(x+1, y+1, z+0.5+z_offset, u/64, v/64, 180, 180, 180, 255);
        add_vertex_to_data(x, y+1, z+0.5+z_offset, (u+1)/64, v/64, 180, 180, 180, 255);
        --yminus
        add_vertex_to_data(x+1, y, z+z_offset, (u+1)/64, (v+0.5)/64, 180, 180, 180, 255);
        add_vertex_to_data(x, y, z+z_offset, u/64, (v+0.5)/64, 180, 180, 180, 255);
        add_vertex_to_data(x, y, z+0.5+z_offset, u/64, v/64, 180, 180, 180, 255);
            
        add_vertex_to_data(x+1, y, z+z_offset, (u+1)/64, (v+0.5)/64, 180, 180, 180, 255);
        add_vertex_to_data(x+1, y, z+0.5+z_offset, (u+1)/64, v/64, 180, 180, 180, 255);
        add_vertex_to_data(x, y, z+0.5+z_offset, u/64, v/64, 180, 180, 180, 255);
        --xplus
        add_vertex_to_data(x+1, y, z+z_offset, u/64, (v+0.5)/64, 255, 255, 255, 255);
        add_vertex_to_data(x+1, y+1, z+z_offset, (u+1)/64, (v+0.5)/64, 255, 255, 255, 255);
        add_vertex_to_data(x+1, y+1, z+0.5+z_offset, (u+1)/64, v/64, 255, 255, 255, 255);
            
        add_vertex_to_data(x+1, y, z+z_offset, u/64, (v+0.5)/64, 255, 255, 255, 255);
        add_vertex_to_data(x+1, y, z+0.5+z_offset, u/64, v/64, 255, 255, 255, 255);
        add_vertex_to_data(x+1, y+1, z+0.5+z_offset, (u+1)/64, v/64, 255, 255, 255, 255);
        --xminus
        add_vertex_to_data(x, y, z+z_offset, (u+1)/64, (v+0.5)/64, 255, 255, 255, 255);
        add_vertex_to_data(x, y+1, z+z_offset, u/64, (v+0.5)/64, 255, 255, 255, 255);
        add_vertex_to_data(x, y+1, z+0.5+z_offset, u/64, v/64, 255, 255, 255, 255);
            
        add_vertex_to_data(x, y, z+z_offset, (u+1)/64, (v+0.5)/64, 255, 255, 255, 255);
        add_vertex_to_data(x, y, z+0.5+z_offset, (u+1)/64, v/64, 255, 255, 255, 255);
        add_vertex_to_data(x, y+1, z+0.5+z_offset, u/64, v/64, 255, 255, 255, 255);
    elseif BLOCKS_RENDERTYPE[b] == 3 then
        local flag = get_block(x,y,z).flag;
        local texture_table = BLOCKS_TEXTURE[b];
        local orientation = bit.band(flag, 7);
        if is_transparent(x, y+1, z) then
            face_yplus(x, y, z, texture_table[orientation_choose_face(orientation, 5)][1], texture_table[orientation_choose_face(orientation, 3)][2])
        end
        
        if is_transparent(x, y-1, z) then
            face_yminus(x, y, z, texture_table[orientation_choose_face(orientation, 6)][1], texture_table[orientation_choose_face(orientation, 4)][2])
        end
        if is_transparent(x, y, z+1) then
            face_zplus(x, y, z, texture_table[orientation_choose_face(orientation, 1)][1], texture_table[orientation_choose_face(orientation, 1)][2])
        end
        if is_transparent(x, y, z-1) then
            face_zminus(x, y, z, texture_table[orientation_choose_face(orientation, 2)][1], texture_table[orientation_choose_face(orientation, 2)][2])
        end
        if is_transparent(x+1, y, z) then
            face_xplus(x, y, z, texture_table[orientation_choose_face(orientation, 4)][1], texture_table[orientation_choose_face(orientation, 5)][2])
        end
        if is_transparent(x-1, y, z) then
            face_xminus(x, y, z, texture_table[orientation_choose_face(orientation, 3)][1], texture_table[orientation_choose_face(orientation, 6)][2]);
        end
    end
end
end
end

if a then a:release() end
if b then b:release() end
if c then c:release() end
if d then d:release() end
if e then e:release() end
if f then f:release() end
if g then g:release() end

local channel = love.thread.getChannel("goback"..index);

-- EFFECTIVELY casuing a memory leak
local t = {vertex_count=dataindex, data=data}
channel:push(t);
t = nil;

if data then data:release() end
datapointer = nil;