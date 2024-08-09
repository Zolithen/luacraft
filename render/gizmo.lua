GIZMO_DEFAULT_TEXTURE = love.graphics.newImage("assets/gizmo.png");
GIZMO_LIST = {}

function gizmo_create_line(p_start, p_end)
    return g3d.newModel(
        {
            {0, 0, 0}, 
            {0, 0, 0}, 
            {g3d.vectors.subtract(p_end[1], p_end[2], p_end[3], p_start[1], p_start[2], p_start[3])}
        }, GIZMO_DEFAULT_TEXTURE, p_start
    )
    --return g3d.newModel("assets/cube.obj", "assets/gizmo.png", p_start)
end

function gizmo_add_line(p_start, p_end)
    table.insert(GIZMO_LIST, gizmo_create_line(p_start, p_end));
    return #GIZMO_LIST
end

function gizmo_add_box(p_start, length)
    table.insert(GIZMO_LIST, g3d.newModel(
        {
            -- Bottom part
            {0, 0, 0}, 
            {0, 0, 0}, 
            {length[1], 0, 0},
            
            {0, 0, 0}, 
            {0, 0, 0}, 
            {0, length[2], 0},
            
            {length[1], 0, 0}, 
            {length[1], 0, 0}, 
            {length[1], length[2], 0},
            
            {0, length[2], 0}, 
            {0, length[2], 0}, 
            {length[1], length[2], 0},
            
            -- Top part
            {0, 0, length[3]}, 
            {0, 0, length[3]}, 
            {length[1], 0, length[3]},
            
            {0, 0, length[3]}, 
            {0, 0, length[3]}, 
            {0, length[2], length[3]},
            
            {length[1], 0, length[3]}, 
            {length[1], 0, length[3]}, 
            {length[1], length[2], length[3]},
            
            {0, length[2], length[3]}, 
            {0, length[2], length[3]}, 
            {length[1], length[2], length[3]},
            
            -- Connections
            {0, 0, 0}, 
            {0, 0, 0}, 
            {0, 0, length[3]},
            
            {0, length[2], 0}, 
            {0, length[2], 0}, 
            {0, length[2], length[3]},
            
            {length[1], length[2], 0}, 
            {length[1], length[2], 0}, 
            {length[1], length[2], length[3]},
            
            {length[1], 0, 0}, 
            {length[1], 0, 0}, 
            {length[1], 0, length[3]}
        }, GIZMO_DEFAULT_TEXTURE, p_start
    ))
    return #GIZMO_LIST
end

function gizmo_draw_everything()
    for i, v in pairs(GIZMO_LIST) do
        v:draw();
    end
end