VERTEX_ALLOC = {total=0}

function chunk_new(cx,cy,cz)
    local c = {
        x=cx,
        y=cy,
        z=cz,
        locked = true,
        raw_data=love.data.newByteData(ffi.sizeof("struct block_data") * 16*16*16),
        mesh_data=nil,
        needs_to_be_meshed = true,
        mesh=nil,
        model=g3d.newModel({{}}, BLOCK_ATLAS, {cx*16,cy*16,cz*16}),
        lifespan=0,
        index=0;
    }
    c.data = ffi.cast("struct block_data *", c.raw_data:getFFIPointer())
    --[[c.data = {}
    for i = 1, 16*16*16 do
        c.data[i-1] = {id = 0, f = 10, r = 23, g = 3, b = 1}
    end]]
    --if love.filesystem.getInfo("world/"..c.x.."_"..c.y.."_"..c.z..".data") == nil then
        --[[for x=0,15 do
            for y=0,15 do
                for z=0,15 do
                    local i = z*256+y*16+x;
                    c.data[i].id = 1
                    if z+cz*16 > 0 then
                        c.data[i].id = 1;
                    else
                        c.data[i].id = reg_block_resolve_name("grass");
                    end
                end
            end
        end]]

        --[[c.data[i].id=1;
                    -- Generate cave world
                    if z+cz*16 > 0 then
                        if (z+cz*16) <= world_noise_height(cx*16+x, cy*16+y) then
                            c.data[i].id=reg_block_resolve_name("grass");
                        end
                        if world_noise_cave_openings(cx*16+x, cy*16+y, cz*16+z) > 0.5 then
                            c.data[i].id=1;
                        end
                    else
                       if world_noise_caves(cx*16+x, cy*16+y, cz*16+z) <= 0.5 then
                            c.data[i].id=reg_block_resolve_name("grass");
                        end
                    end
                    c.data[i].flag=4;]]

        -- Doing three loops instead of one is faster
        --[[for i=0,16*16*16-1 do
            local x = i % 16;
            local z = math.floor(i/256);
            local y = math.floor(((i-z*256))/16);
            --c.data[i]={}
            c.data[i].id=1;
            if (cx+cy+cz)%2 == 0 then
                if (cz*16+z<10) then
                    c.data[i].id=3;
                end
            else
                if (cz*16+z<10) then
                    c.data[i].id=2;
                end
            end
            c.data[i].flag=4;
        end]]
    --[[else
        -- Load the chunk
        local data = love.filesystem.read("data", "world/"..c.x.."_"..c.y.."_"..c.z..".data");
        local datapointer = ffi.cast("struct block_data *", data:getFFIPointer())
        for x=0,15 do
            for y=0,15 do
                for z=0,15 do
                    local i = z*256+16*y+x;
                    --c.data[i]={}
                    c.data[i].id=datapointer[i].id;
                    c.data[i].flag=datapointer[i].flag;
                end
            end
        end
        
        data:release();
    end]]
    return c;
end

function chunk_release(c)
    if not c or not c.model.mesh then return end;
    c.model.mesh:release();
    c.model.mesh = nil;
end

-- TODO: Save the id map the chunk was saved with so it actually saves correctly
function chunk_save(c)
    local data = love.data.newByteData(ffi.sizeof("struct block_data") * 16*16*16)
    local datapointer = ffi.cast("struct block_data *", data:getFFIPointer())
    for x=0,15 do
        for y=0,15 do
            for z=0,15 do
                local i = z*256+y*16+x;
                datapointer[i].id=c.data[i].id;
                datapointer[i].flag=c.data[i].flag;
            end
        end
    end
    love.filesystem.write("world/"..c.x.."_"..c.y.."_"..c.z..".data", data);
    data:release();
end

function add_vertex_to_data(pointer, index, x, y, z, u, v, r, g, b, a)
    pointer[index].x = x;
    pointer[index].y = y;
    pointer[index].z = z;
    pointer[index].u = u;
    pointer[index].v = v;
    pointer[index].r = r;
    pointer[index].g = g;
    pointer[index].b = b;
    pointer[index].a = a;
end

AIR_BLOCK = {
    id=1
}
DIRT_BLOCK = {
    id=2
}
function get_chunk_block(c, x, y, z)
    if c.locked then return AIR_BLOCK end;
    -- Coords we want are out of the chunk
    if x>15 or x<0 or y>15 or y<0 or z>15 or z<0 then
        return AIR_BLOCK;
    end;
    return c.data[z*256+y*16+x]
end

-- Does no checks 
function chunk_block_set(c, x, y, z, id)
    if c.locked then return AIR_BLOCK end; -- TODO: Better please
   c.data[z*256+y*16+x].id = id; 
end

if WANTS_TO_RENDER then
function remesh_everything(x,y,z)
    -- Grab references so we have to index only one table when accessing these inside the loop (more performance)
    world.chunks_to_render = {};
    local memory = world.memory;
    local mesh_stack = world.mesh_stack;
    local chunks_to_render = world.chunks_to_render;
    
    for i=-RENDER_DISTANCE-1,RENDER_DISTANCE+1 do
        for j=-RENDER_DISTANCE-1,RENDER_DISTANCE+1 do
            for k=-RENDER_DISTANCE-1,RENDER_DISTANCE+1 do
                local cx, cy, cz = x+i, y+j, z+k
                if not world_chunk_get(cx, cy, cz) then
                    world_chunk_gen(cx, cy, cz);
                end
            end
        end
    end
    
    for i=-RENDER_DISTANCE,RENDER_DISTANCE do
        for j=-RENDER_DISTANCE,RENDER_DISTANCE do
            for k=-RENDER_DISTANCE,RENDER_DISTANCE do
                local index = (k)*RENDER_DISTANCE_CONSECUTIVE_Z+(j)*RENDER_DISTANCE_CONSECUTIVE_Y+(i)
                local cx, cy, cz = x+i, y+j, z+k
                local chunk = memory[cx][cy][cz];
                --[[if chunk.needs_to_be_meshed and not chunk.locked then
                    table.insert(mesh_stack, chunk)
                    chunk.needs_to_be_meshed = false;
                end]]
                table.insert(chunks_to_render, {cx, cy, cz})
            end
        end
    end
end
else
function remesh_everything(x, y, z)
    
end
end