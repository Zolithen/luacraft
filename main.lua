-- Setup profiling stuff
PROF_CAPTURE = true;
prof = require("jprof");

-- Coordinate system is lenght, lenght, height (y is NOT height)
require "constants"
WANTS_TO_RENDER = true;
math.randomseed(5);
love.graphics.setDefaultFilter("nearest", "nearest")
BLOCK_ATLAS = love.graphics.newImage("assets/atlas.png")
g3d = require "g3d"
require "cmath"
require "ffi_defs"
require "register/block"
require "world/chunk"
require "world/world"
require "entity/player"
local bit = require "bit";

-- Biomes
require "world/biome/forest"

require "render/gizmo"
--gizmo_add_line({5, 5, 5}, {20, 20, 50})
player.gizmo_hitbox = gizmo_add_box({0.25, 0.25, 0}, {0.5, 0.5, 2});

-- Debug info
local major, minor = love.getVersion()
print("Running on LOVE " .. major.."."..minor);
print("Logical processor amount: ".. love.system.getProcessorCount());
print("Size of thread pool for meshing: " .. THREAD_POOL_SIZE );
print("Render constants: |Render distance ".. RENDER_DISTANCE .. "|Render distance index " .. RENDER_DISTANCE_INDEX .. "|Render distance consecutive Y " .. RENDER_DISTANCE_CONSECUTIVE_Y .. "|Render distance consecutive Z " .. RENDER_DISTANCE_CONSECUTIVE_Z .."|")
print("Region volume: " .. (REGION_SIZE*32)^3);


reg_block_gen_attributes();
world = {
    -- Chunk memory
    memory={},

    -- Useless stuff
    chunk={},
    zeroth_chunk={0,0,0},
    loaded_chunks={},
    first_render=true,
    noise_height = {},
    feature_list = {},

    -- Thread stuff for chunk meshing
    thread_pool={},
    thread_state={},
    thread_chunk={},
    mesh_stack={},

    -- Threaded stuff for chunk gen
    gen_input_channel = love.thread.getChannel("chunk_gen_input"),
    gen_output_channel = love.thread.getChannel("chunk_gen_output"),
    gen_thread = nil,
    has_to_gen_chunk = false, -- If true, will turn on the chunk gen thread next frame

    chunks_to_render = {}, -- Chunks that are getting drawn to the screen
    block_queue = {}, -- Blocks that have to be placed for when the chunk gets generated
    region = {} -- Regions
}

--g3d.camera.position = {0, 0, 0}
g3d.camera.updateViewMatrix();

-- Ripped straight out of g3d's voxel engine bcs I can't be bothered
local block_cursor_visible
local block_cursor = g3d.newModel("assets/cube.obj")

--local billboarded = g3d.newModel("assets/plane1.obj", "assets/moon.png", {0, 0, 32})
vertex_format = {
    {"VertexPosition", "float", 3},
    {"VertexTexCoord", "float", 2},
    {"VertexColor", "byte", 4},
}

local previous_chunk_x = math.floor(g3d.camera.position[1]/16);
local previous_chunk_y = math.floor(g3d.camera.position[2]/16);
local previous_chunk_z = math.floor(g3d.camera.position[3]/16);

local previous_region_x = math.floor(g3d.camera.position[1]/REGION_SIZE);
local previous_region_y = math.floor(g3d.camera.position[2]/REGION_SIZE);

world_region_gen(-1, 0);
world_region_gen(-1, -1);
world_region_gen(-1, 1);
world_region_gen(0, 0);
world_region_gen(0, -1);
world_region_gen(0, 1);
world_region_gen(1, 0);
world_region_gen(1, -1);
world_region_gen(1, 1);

local placing_bx = 0;
local placing_by = 0;
local placing_bz = 0;

local breaking_bx = 0;
local breaking_by = 0;
local breaking_bz = 0;

local gb_timer = 0; -- Timer for garbage collection
local placing_timer = 0; -- Timer for placing blocks
local placing_facing = 7;

--g3d.camera.position[3] = 40;

function love.load()
    if love.filesystem.getInfo("world") == nil then
        love.filesystem.createDirectory("world");
    end
    for i = 1, THREAD_POOL_SIZE do
        world.thread_pool[i] = love.thread.newThread("render/chunk_remesh_thread.lua");
        world.thread_chunk[i]={};
        world.thread_state[i] = {};
        world.thread_state[i].available = true;

    end
    world.gen_thread = love.thread.newThread("world/chunk_gen_thread.lua");
    love.mouse.setRelativeMode(true)
end

function love.update(dt)
    prof.push("frame")

    --Movement
    --g3d.camera.firstPersonMovement(dt)
    player_move(dt);
    
    prof.push("region_gen");
    -- TODO: gen regions before one of the chunks in them get rendered so we don't get weird things
    local current_region_x = math.floor(player.position[1]/REGION_SIZE);
    local current_region_y = math.floor(player.position[2]/REGION_SIZE);
    if current_region_x ~= previous_region_x or current_region_y ~= previous_region_y then
        world_region_gen(current_region_x-1, current_region_y);
        world_region_gen(current_region_x-1, current_region_y-1);
        world_region_gen(current_region_x-1, current_region_y+1);
        world_region_gen(current_region_x, current_region_y);
        world_region_gen(current_region_x, current_region_y-1);
        world_region_gen(current_region_x, current_region_y+1);
        world_region_gen(current_region_x+1, current_region_y);
        world_region_gen(current_region_x+1, current_region_y-1);
        world_region_gen(current_region_x+1, current_region_y+1);
    end
    prof.pop("region_gen");
    
    
    prof.push("main_remesh_call");
    local current_chunk_x = math.floor(player.position[1]/16);
    local current_chunk_y = math.floor(player.position[2]/16);
    local current_chunk_z = math.floor(player.position[3]/16);
    if current_chunk_x ~= previous_chunk_x or current_chunk_y ~= previous_chunk_y or current_chunk_z ~= previous_chunk_z then
        remesh_everything(current_chunk_x,current_chunk_y,current_chunk_z)
    end
    prof.pop("main_remesh_call");

    
    prof.push("block_cursor");
    -- Check the block the player is looking at
    local lx, ly, lz = g3d.camera.getLookVector()
    local x, y, z = g3d.camera.position[1], g3d.camera.position[2], g3d.camera.position[3]
    local step = 0.1
    block_cursor_visible = false;
    for i=step, 5, step do
        local bx, by, bz = math.floor(x + lx*i), math.floor(y + ly*i), math.floor(z + lz*i)
        local bcx, bcy, bcz = math.floor(bx/16), math.floor(by/16), math.floor(bz/16)
        local c = world_chunk_get(bcx, bcy, bcz);
        if not c then break end;
        
        if c.data[256*(bz%16)+16*(by%16)+(bx%16)].id ~= 1 then
            block_cursor:setTranslation(bx, by, bz)
            --block_cursor:setTranslation(0, 0, 40)
            block_cursor_visible = true;
            breaking_bx = bx;
            breaking_by = by;
            breaking_bz = bz;
            
            -- Get the facing to use for placing stuff like logs
            -- TODO: probably find a better way
            local min_distance_to_plane = 200;
            local point_x, point_y, point_z = x+lx*i - bx - 0.5, y+ly*i - by - 0.5, z+lz*i - bz - 0.5; -- We have to change the coordinates from world coords to relative-to-center-of-block coords
            for i = 1, 6 do
                local plane = BLOCK_FACES_AS_PLANES[i]
                local dist = math.distance_point_plane(point_x, point_y, point_z, plane[1], plane[2], plane[3], plane[4]);
                if dist < min_distance_to_plane then
                    min_distance_to_plane = dist;
                    placing_facing = i;
                end
            end
            break;
        else
            placing_bx = bx;
            placing_by = by;
            placing_bz = bz;
        end
    end
    prof.pop("block_cursor");
    
    prof.push("setup_meshing_threads");
    -- Start up meshing threads
    for i, v in reversed_ipairs(world.mesh_stack) do
        for j = 1, THREAD_POOL_SIZE do
            if world.thread_state[j].available and not world.thread_pool[j]:isRunning() then
                -- TODO: only copying references may cause some weird graphical glitches (what if I break a block on a chunk that is getting meshed)
                local x, y, z = v.x, v.y, v.z
                world.thread_chunk[j] = v
                world.thread_state[j].available = false;
                world.thread_pool[j]:start(
                    v.raw_data, 
                    world_chunk_get_raw_data(x, y+1, z), 
                    world_chunk_get_raw_data(x, y-1, z), 
                    world_chunk_get_raw_data(x+1, y, z), 
                    world_chunk_get_raw_data(x-1, y, z), 
                    world_chunk_get_raw_data(x, y, z+1), 
                    world_chunk_get_raw_data(x, y, z-1), 
                    j, BLOCKS, BLOCKS_IDMAP, BLOCKS_IS_TRANSPARENT, BLOCKS_RENDERTYPE, BLOCKS_TEXTURE
                )
                table.remove(world.mesh_stack, #world.mesh_stack)
                break;
            end
        end
    end
    prof.pop("setup_meshing_threads");
    
    prof.push("state_meshing_threads");
    -- Check state of the meshing threads
    for j = 1, THREAD_POOL_SIZE do
        if not world.thread_state[j].available and not world.thread_pool[j]:isRunning() then
            world.thread_state[j].available = true;
            local comms = love.thread.getChannel("goback"..j);
            local the_table = comms:pop();
            --the_table.data:release();
            --comms:clear();
            if not the_table then 
                break; 
            end
            local vertex_count = the_table.vertex_count;
            if vertex_count ~= 0 then
                local c = world.thread_chunk[j];
                c.model.mesh=love.graphics.newMesh(vertex_format, vertex_count, "triangles");
                c.model.mesh:setVertices(the_table.data);
                c.model.mesh:setTexture(BLOCK_ATLAS);
            else
                world.thread_chunk[j].model.mesh=nil;
            end
            the_table.data:release();
            the_table.data = nil;
            the_table = nil;
            --comms:clear();
        end
    end
    prof.pop("state_meshing_threads");
    
    prof.push("gb")
    -- TODO: Put a good time to garbage collect
    if gb_timer >= 240 then
        collectgarbage("collect");
        gb_timer = 0;
    end
    gb_timer = gb_timer + dt;
    placing_timer = placing_timer + dt;
    prof.pop("gb")
    
    if love.keyboard.isDown "escape" then
        love.event.push "quit"
    end
    
    previous_chunk_x = math.floor(player.position[1]/16);
    previous_chunk_y = math.floor(player.position[2]/16);
    previous_chunk_z = math.floor(player.position[3]/16);
    
    local hitbox = GIZMO_LIST[player.gizmo_hitbox];
    hitbox:setTranslation(player.position[1], player.position[2], player.position[3]);

    prof.push("setup_gen_thread")
    -- Handle chunk generation thread
    if world.has_to_gen_chunk then

        world.gen_thread:start(BLOCKS_REVERSE_IDMAP);
        world.has_to_gen_chunk = false;
    end
    prof.pop("setup_gen_thread")

    prof.push("finish_gen_thread")
    local outmsg = world.gen_output_channel:pop();
    while outmsg do
        local action = outmsg[1];
        local cx, cy, cz = outmsg[2], outmsg[3], outmsg[4];

        -- TODO: needs to be meshed n stuff for knowing which chunks need to get meshed
        -- We have to change it so we don't send a chunk for meshing that hasn't been generated yet
        local chunk = world.memory[cx][cy][cz];
        chunk.raw_data:release();
        chunk.raw_data = outmsg[5];
        chunk.data = ffi.cast("struct block_data *", chunk.raw_data:getFFIPointer());
        chunk.locked = false;
        table.insert(world.mesh_stack, chunk)
        chunk.needs_to_be_meshed = false;

        outmsg = world.gen_output_channel:pop();
    end
    --world.gen_output_channel:clear();
    prof.pop("finish_gen_thread")

    prof.push("debug_memory_thread")
    local outmsg = love.thread.getChannel("debug_memory_thread"):pop();
    while outmsg do
        print(string.format("Meshing thread uses %fkB of memory", outmsg))
        outmsg = love.thread.getChannel("debug_memory_thread"):pop();
    end
    prof.pop("debug_memory_thread")
end

function love.draw()
    prof.push("drawing")
    
    love.graphics.setColor(255, 255, 255, 255)
    -- Debug info
    love.graphics.setBackgroundColor(0.2, 0.2, 0.6, 1);
    love.graphics.print(tostring(love.timer.getFPS()) .. "FPS", 0, 0)
    love.graphics.print("Current player position: " .. player.position[1] .. "," .. player.position[2] .. "," .. player.position[3], 0, 16)
    love.graphics.print("Current chunk position: " .. math.floor(player.position[1]/16) .. "," .. math.floor(player.position[2]/16) .. "," .. math.floor(player.position[3]/16), 0, 32)
    love.graphics.print("kB:" .. collectgarbage("count"), 0, 48);
    love.graphics.print(FACING_ID_TO_STRING[placing_facing], 0, 64);
    love.graphics.print(player.force[3], 0, 80);
    
    local memory = world.memory;
    for i, v in ipairs(world.chunks_to_render) do
        if memory[v[1]][v[2]][v[3]].model.mesh then
            memory[v[1]][v[2]][v[3]].model:draw();
        end
    end
    
    local x, y, z = g3d.camera.getLookVector();
    local angle = math.atan2(y,x);
    
    -- billboarded test
    -- camera.x-entity.x
    --[[local cx = g3d.camera.position[1]
    local cy = g3d.camera.position[2]
    billboarded:setRotation(0, 0, math.pi/2+math.atan2(cy,cx));]]
    --billboarded:draw();
    
    love.graphics.setColor(255, 0, 0, 255);
    love.graphics.line(20, love.graphics.getHeight()-20, 20+math.cos(angle+math.pi/2)*10, love.graphics.getHeight()-20+math.sin(angle+math.pi/2)*10)
    love.graphics.line(20, love.graphics.getHeight()-20, 20-math.cos(angle+math.pi/2)*10, love.graphics.getHeight()-20-math.sin(angle+math.pi/2)*10)
    love.graphics.print("x", 35, love.graphics.getHeight()-20)
    
    love.graphics.line(love.graphics.getWidth()/2, love.graphics.getHeight()/2-20, love.graphics.getWidth()/2, love.graphics.getHeight()/2+20)
    love.graphics.line(love.graphics.getWidth()/2-20, love.graphics.getHeight()/2, love.graphics.getWidth()/2+20, love.graphics.getHeight()/2)
    
    love.graphics.setColor(0, 255, 0, 255);
    love.graphics.line(20, love.graphics.getHeight()-20, 20+math.cos(angle)*10, love.graphics.getHeight()-20+math.sin(angle)*10)
    love.graphics.line(20, love.graphics.getHeight()-20, 20-math.cos(angle)*10, love.graphics.getHeight()-20-math.sin(angle)*10)
    love.graphics.print("y", 45, love.graphics.getHeight()-20)
    love.graphics.setColor(255, 255, 255, 255)
    
    local x, y = g3d.camera.position[1]*32, g3d.camera.position[2]*32
    local player_block_x, player_block_y = math.floor(x), math.floor(y)
    
    if block_cursor_visible then
        love.graphics.setColor(0, 0, 0, 255)
        love.graphics.setWireframe(true);
        block_cursor:draw();
        love.graphics.setWireframe(false);
    end
    
    -- Debug stuff for seeing the noise
    if not WANTS_TO_RENDER then
        for i=0,love.graphics.getWidth()do
            for j=0,love.graphics.getHeight()do
                local noise = world_noise_height(player_block_x+i, player_block_y+j)/120;
                love.graphics.setColor(noise, noise, noise, 255);
                love.graphics.rectangle("fill", i, j, 1, 1);
            end
        end
    end
    
    love.graphics.setColor(255, 255, 255, 255)
    love.graphics.setWireframe(true);
    gizmo_draw_everything()
    love.graphics.setWireframe(false);

    prof.pop("drawing");
    prof.pop("frame");
end

function love.mousemoved(x,y, dx,dy)
    g3d.camera.firstPersonLook(dx,dy)
end

function love.mousepressed(x, y, button)
    if block_cursor_visible then
        if button == 1 then
            world_block_set(breaking_bx, breaking_by, breaking_bz, 1);
        elseif button == 2 and placing_timer > 0.1 then
            placing_timer = 0;
            
            --[[local x, y, z = g3d.camera.getLookVector();
            local lenght = math.sqrt(x^2 + y^2 + z^2)
            local angle_x = math.abs(math.asin(x/lenght));
            local angle_y = math.abs(math.asin(y/lenght));
            local angle_z = math.abs(math.asin(z/lenght));
            
            print(angle_x, angle_y, angle_z)
            if angle_x <= angle_y and angle_x <= angle_z then
                world_block_set(placing_bx, placing_by, placing_bz, reg_block_resolve_name("oak_log"), FACING_XPLUS);
            elseif angle_y <= angle_x and angle_y <= angle_z then
                world_block_set(placing_bx, placing_by, placing_bz, reg_block_resolve_name("oak_log"), FACING_YPLUS);
            elseif angle_z <= angle_x and angle_z <= angle_y then
                world_block_set(placing_bx, placing_by, placing_bz, reg_block_resolve_name("oak_log"), FACING_ZPLUS);
            end]]
            world_block_set(placing_bx, placing_by, placing_bz, reg_block_resolve_name("oak_log"), placing_facing);
        end
    end
end

function love.keypressed(key, scancode, isRepeat)
    if not isRepeat then player_keypress(key) end;
    if key == "f2" then
        love.graphics.captureScreenshot(os.time() .. ".png")
    end
    if key == "e" then
        player.force[3] = -9.8;
    end
end

function love.mousefocus(f)
   if f then love.mouse.setRelativeMode(true) else love.mouse.setRelativeMode(false) end 
end

function love.quit()
    for i = 1, THREAD_POOL_SIZE do
        if world.thread_pool[i]:isRunning() then world.thread_pool[i]:kill(); end
    end
    -- TODO: May cause problems when exitting a world while chunks are getting generated
    if world.gen_thread:isRunning() then world.gen_thread:kill() end;

    prof.write("prof.mpack")
end

function love.threaderror(thread, errorstr)
    print("Thread error!\n"..errorstr)
end