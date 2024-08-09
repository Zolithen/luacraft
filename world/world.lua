SEED = os.time();

-- Gets a certain chunk from the world with actual checks
function world_chunk_get(x, y, z)
    if world.memory[x] then
        if world.memory[x][y] then
            return world.memory[x][y][z] 
        end
        world.memory[x][y] = {};
        return false;
    end
    world.memory[x] = {};
    world.memory[x][y]={}
    return false;
end

function world_chunk_get_raw_data(x, y, z)
    if world.memory[x] then
        if world.memory[x][y] then
            if world.memory[x][y][z] then
                return world.memory[x][y][z].raw_data
            end
        end
    end
    return nil;
end

function world_chunk_set(x, y, z, c)
    world_chunk_get(x, y, z) -- Ensure the correct array exists
    world.memory[x][y][z] = c;
end

-- This function is to be called when we know that world_chunk_get has been called at the same position before to use one less function call
function world_chunk_raw_set(x, y, z, c)
    world.memory[x][y][z] = c;
end

function world_chunk_gen(x, y, z)
    
    world_chunk_raw_set(x, y, z, chunk_new(x, y, z));
    
    world.gen_input_channel:push({x, y, z});
    world.has_to_gen_chunk = true;
    
    -- Queue is for placing blocks in chunks that haven't been generated yet (and placing features)
    --[[if world.block_queue[x] and world.block_queue[x][y] and world.block_queue[x][y][z] then
        for i, v in ipairs(world.block_queue[x][y][z]) do
            _world_block_set(x*16+v[1], y*16+v[2], z*16+v[3], v[4], v[5]);
        end
        world.block_queue[x][y][z] = nil;
    end]]
end

function world_block_is_loaded(x, y, z)
    return math.point_in_cube(x, y, z, math.floor(g3d.camera.position[1]/16)*16-RENDER_DISTANCE*16, math.floor(g3d.camera.position[2]/16)*16-RENDER_DISTANCE*16, math.floor(g3d.camera.position[3]/16)*16-RENDER_DISTANCE*16, (RENDER_DISTANCE*2+1)*16)
end

function world_block_get(x, y, z)
    if world_block_is_loaded(x, y, z) then
        
        local cx = math.floor(x/16)
        local cy = math.floor(y/16)
        local cz = math.floor(z/16)
        
        x=x-cx*16;
        y=y-cy*16;
        z=z-cz*16;
        if x<0 then x = 16-x end;
        if y<0 then y = 16-y end;
        if z<0 then z = 16-z end;
            
        world_chunk_get(cx, cy, cz);
        local c = world.memory[cx][cy][cz];
        if not c then return AIR_BLOCK end;
        return c.data[x+y*16+z*256];
    end
    return DIRT_BLOCK;
end

function world_block_set(x, y, z, id, flag)
    if world_block_is_loaded(x, y, z) then
        local cx = math.floor(x/16)
        local cy = math.floor(y/16)
        local cz = math.floor(z/16)
        
        local bx = x%16;
        local by = y%16;
        local bz = z%16;
        
        local c = world_chunk_get(cx, cy, cz);
        c.data[bx + by*16 + bz*256].id = id;
        if flag then c.data[bx + by*16 + bz*256].flag = flag else c.data[bx + by*16 + bz*256].flag = 0; end
        
        local vx, vy, vz = g3d.camera.getLookVector()
        table.insert(world.mesh_stack, c);
        
        if bx%16 == 0 then table.insert(world.mesh_stack, world.memory[cx-1][cy][cz]) end;
        if bx%16 == 15 then table.insert(world.mesh_stack, world.memory[cx+1][cy][cz]) end;
        if by%16 == 0 then table.insert(world.mesh_stack, world.memory[cx][cy-1][cz]) end;
        if by%16 == 15 then table.insert(world.mesh_stack, world.memory[cx][cy+1][cz]) end;
        if bz%16 == 0 then table.insert(world.mesh_stack, world.memory[cx][cy][cz-1]) end;
        if bz%16 == 15 then table.insert(world.mesh_stack, world.memory[cx][cy][cz+1]) end;
    end
end

function world_chunk_remesh(c)
    table.insert(world.mesh_stack, c);
end

-- Sets without meshing
function _world_block_set(x, y, z, id, flag)
    local cx = math.floor(x/16)
    local cy = math.floor(y/16)
    local cz = math.floor(z/16)
        
    local bx = x%16;
    local by = y%16;
    local bz = z%16;
        
    local c = world_chunk_get(cx, cy, cz);
    if not c then return end;
    c.data[bx + by*16 + bz*256].id = id;
    if flag then c.data[bx + by*16 + bz*256].flag = flag else c.data[bx + by*16 + bz*256].flag = 0; end
end

function _world_block_get(x, y, z, id)
    local cx = math.floor(x/16)
    local cy = math.floor(y/16)
    local cz = math.floor(z/16)
        
    x=x-cx*16;
    y=y-cy*16;
    z=z-cz*16;
    if x<0 then x = 16-x end;
    if y<0 then y = 16-y end;
    if z<0 then z = 16-z end;
    world_chunk_get(cx, cy, cz);
    local c = world.memory[cx][cy][cz];
    if not c then return AIR_BLOCK end;
    return c.data[x+y*16+z*256];
end

function _world_block_queue(x, y, z, id, flag)
    local cx = math.floor(x/16)
    local cy = math.floor(y/16)
    local cz = math.floor(z/16)
        
    local bx = x%16;
    local by = y%16;
    local bz = z%16;
        
    local block_queue = world.block_queue;
    if not block_queue[cx] then
        block_queue[cx] = {};
    end
    if not block_queue[cx][cy] then
        block_queue[cx][cy] = {};
    end
    if not block_queue[cx][cy][cz] then
        block_queue[cx][cy][cz] = {};
    end
    table.insert(block_queue[cx][cy][cz], {bx, by, bz, id, flag}) 
end

-- World noise functions
function world_noise_height(x, y)
    return 5*love.math.noise(x/32, y/32)
        +  40* ( 2^(2*love.math.noise(x/1024, y/1024))/4 )
end

function world_noise_caves(x, y, z)
        return 0.84*love.math.noise(x/40, y/40, z/40)
            +  0.05*love.math.noise(x/4, y/4, z/4)
end

function world_noise_cave_openings(x, y, z)
    return 0.65*love.math.noise(x/40, y/40, z/40)
            +  0.10*love.math.noise(x/4, y/4, z/4)
end

function world_region_gen(x, y)
    if not world.region[x] then world.region[x] = {} end;
    if world.region[x][y] then return end;
    local region = {};
    local tree_amount = 6000+math.floor(math.random()*1000);
    for i=1, tree_amount do
        local xx, yy = x*REGION_SIZE+math.floor(math.random()*REGION_SIZE), y*REGION_SIZE+math.floor(math.random()*REGION_SIZE);

        --be careful
        -- TODO: take into account cave opening noise
        local zz = math.floor(world_noise_height(xx, yy));
        local oak_log_id = reg_block_resolve_name("oak_log");
        _world_block_queue(xx, yy, zz+1, oak_log_id, FACING_ZPLUS);
        _world_block_queue(xx, yy, zz+2, oak_log_id, FACING_ZPLUS);
        _world_block_queue(xx, yy, zz+3, oak_log_id, FACING_ZPLUS);
        _world_block_queue(xx, yy, zz+4, oak_log_id, FACING_ZPLUS);
        
        _world_block_queue(xx+1, yy, zz+4, oak_log_id, FACING_ZPLUS);
        _world_block_queue(xx-1, yy, zz+4, oak_log_id, FACING_ZPLUS);
        _world_block_queue(xx, yy+1, zz+4, oak_log_id, FACING_ZPLUS);
        _world_block_queue(xx, yy-1, zz+4, oak_log_id, FACING_ZPLUS);
    end
    world.region[x][y] = region;
end

--[[
PLAINS
5*love.math.noise(x/32, y/32)
+  40* ( 2^(2*love.math.noise(x/1024, y/1024))/16 )

WEIRD STUFF
20*love.math.noise(x/256, y/256)
+  20*love.math.noise(x/32, y/32)
+  40*love.math.noise(x/8.4, y/8.4)

WIDE MOUNTAINS
5*love.math.noise(x/32, y/32)
+  80* ( 4^(4*love.math.noise(x/1024, y/1024))/256 )
]]
