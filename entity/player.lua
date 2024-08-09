player = {
    force = { -- x, y, z
        0, 0, -9.8
    },
    speed = {
        0, 0, 0
    },
    hitbox = { -- relative to player
        
    },
    position = {
        0, 0, 32
    },
    previous_block_pos = {
        0, 0, 0
    },
    block_pos = {
        0, 0, 0
    },
    camera_person = 1
}

-- Some code adapted from g3d's first person movement function
function player_move(dt)
    player.block_pos[1] = math.floor(player.position[1]/16)
    player.block_pos[2] = math.floor(player.position[2]/16)
    player.block_pos[3] = math.floor(player.position[3]/16)
    if player.block_pos[1] ~= player.previous_block_pos[1] or player.block_pos[2] ~= player.previous_block_pos[2] or player.block_pos[3] ~= player.previous_block_pos[3] then
        
    end
    
    local move_x, move_y = 0, 0
    local camera_moved = false
    local speed = 9
    if love.keyboard.isDown("lshift") then speed = 2; end
    if love.keyboard.isDown "w" then move_x = move_x + 1 end
    if love.keyboard.isDown "a" then move_y = move_y + 1 end
    if love.keyboard.isDown "s" then move_x = move_x - 1 end
    if love.keyboard.isDown "d" then move_y = move_y - 1 end

    -- do some trigonometry on the inputs to make movement relative to camera's direction
    -- also to make the player not move faster in diagonal directions
    local dir, pitch = g3d.camera.getDirectionPitch();
    if move_x ~= 0 or move_y ~= 0 then
        local angle = math.atan2(move_y, move_x)
        local supposed_x, supposed_y = player.position[1] + math.cos(dir + angle) * speed * dt, player.position[2] + math.sin(dir + angle) * speed * dt;
        
        if world_block_get(math.floor(supposed_x), math.floor(supposed_y), math.floor(player.position[3])).id == 1 and
           world_block_get(math.floor(supposed_x+0.5), math.floor(supposed_y), math.floor(player.position[3])).id == 1 and
           world_block_get(math.floor(supposed_x), math.floor(supposed_y+0.5), math.floor(player.position[3])).id == 1 and
           world_block_get(math.floor(supposed_x+0.5), math.floor(supposed_y+0.5), math.floor(player.position[3])).id == 1 and
           world_block_get(math.floor(supposed_x), math.floor(supposed_y), math.floor(player.position[3])+1).id == 1 and
           world_block_get(math.floor(supposed_x+0.5), math.floor(supposed_y), math.floor(player.position[3])+1).id == 1 and
           world_block_get(math.floor(supposed_x), math.floor(supposed_y+0.5), math.floor(player.position[3])+1).id == 1 and
           world_block_get(math.floor(supposed_x+0.5), math.floor(supposed_y+0.5), math.floor(player.position[3])+1).id == 1
        then -- best collision detection ever (WIP)
            player.position[1] = supposed_x;
            player.position[2] = supposed_y;
            camera_moved = true 
        end
    end
    
    player.speed[3] = player.speed[3] + player.force[3]*dt/2;
    local supposed_z = player.position[3] + player.speed[3]*dt;
    local px, py = player.position[1], player.position[2]
    if  world_block_get(math.floor(px), math.floor(py), math.floor(supposed_z)).id == 1 and
        world_block_get(math.floor(px+0.5), math.floor(py), math.floor(supposed_z)).id == 1 and
        world_block_get(math.floor(px), math.floor(py+0.5), math.floor(supposed_z)).id == 1 and
        world_block_get(math.floor(px+0.5), math.floor(py+0.5), math.floor(supposed_z)).id == 1 and
        world_block_get(math.floor(px), math.floor(py), math.floor(supposed_z)+1).id == 1 and
        world_block_get(math.floor(px+0.5), math.floor(py), math.floor(supposed_z)+1).id == 1 and
        world_block_get(math.floor(px), math.floor(py+0.5), math.floor(supposed_z)+1).id == 1 and
        world_block_get(math.floor(px+0.5), math.floor(py+0.5), math.floor(supposed_z)+1).id == 1 and
        world_block_get(math.floor(px), math.floor(py), math.floor(supposed_z)+2).id == 1 and
        world_block_get(math.floor(px+0.5), math.floor(py), math.floor(supposed_z)+2).id == 1 and
        world_block_get(math.floor(px), math.floor(py+0.5), math.floor(supposed_z)+2).id == 1 and
        world_block_get(math.floor(px+0.5), math.floor(py+0.5), math.floor(supposed_z)+2).id == 1 
    then
        player.position[3] = supposed_z
        camera_moved = true;
    end

    -- update the camera's in the shader
    -- only if the camera moved, for a slight performance benefit
    
    if player.camera_person == 1 then
        g3d.camera.position = {
            player.position[1] + 0.25,
            player.position[2] + 0.25,
            player.position[3] + 1.5
        }
    end
    if camera_moved then
        g3d.camera.lookInDirection()
    end
    
    local bx, by, bz = math.floor(player.position[1]), math.floor(player.position[2]), math.floor(player.position[3])
    if world_block_get(bx, by, math.floor(player.position[3]-0.05)).id ~= 1 then
        player.speed[3] = 0;
    elseif world_block_get(bx, by, bz).id == 1 then
        --player.force[3] = player.force[3]/1.01
        -- formula comes from the arbitrary difference of -(x+a)^2 + b :  (-(x+h+a)^2 + b) - (-(x+a)^2 + b) = -h^2 - 2xh - 2ha
        -- where h is the timestep, b is meaningless here and a is negative the x coord of the vertex of the parabola
        player.speed[3] = player.speed[3] - (dt)^2 - 2*player.speed[3]*dt - 2*40*dt
        --if player.force[3] < 0 then player.force[3] = 0 end
    end
    
    player.previous_block_pos[1] = math.floor(player.position[1]/16)
    player.previous_block_pos[2] = math.floor(player.position[2]/16)
    player.previous_block_pos[3] = math.floor(player.position[3]/16)
    
end

function player_keypress(key)
    if key == "space" then
        player.speed[3] = 40;
    end
end

-- F = ma -> a = F/m