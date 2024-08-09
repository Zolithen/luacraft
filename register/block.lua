-- TODO: change this to a data folder or smth
BLOCKS = {
    air={
        transparent = true,
        render_type = 0
    },
    dirt={
        top={2,0},
        bottom={2,0},
        yplus={2,0},
        yminus={2,0},
        xplus={2,0},
        xminus={2,0},
        transparent = false,
        render_type = RNDTYP_BLOCK
    },
    grass={
        top={1,0},
        bottom={1,0},
        yplus={1,0},
        yminus={1,0},
        xplus={1,0},
        xminus={1,0},
        transparent = false,
        render_type = RNDTYP_BLOCK
    },
    planks={
        top={3,0},
        bottom={3,0},
        yplus={3,0},
        yminus={3,0},
        xplus={3,0},
        xminus={3,0},
        transparent = false,
        render_type = RNDTYP_BLOCK
    },
    plank_slab={
        texture={3,0},
        transparent = true,
        render_type = RNDTYP_SLAB
    },
    oak_log={
        top={4, 0},
        bottom={4, 0},
        yplus={5,0},
        yminus={5,0},
        xplus={5,0},
        xminus={5,0},
        transparent = false,
        render_type = RNDTYP_ORIENTABLE_BLOCK
    }
}
BLOCKS_IDMAP={}
BLOCKS_REVERSE_IDMAP={}
BLOCKS_IS_TRANSPARENT={}
BLOCKS_RENDERTYPE={}
BLOCKS_TEXTURE={}

function reg_block_gen_attributes()
    print("Generating block attributes...")
    local id = 2;
    BLOCKS_IDMAP[1] = "air"
    BLOCKS_IS_TRANSPARENT[1]=true;
    BLOCKS_RENDERTYPE[1]=0;
    for i, v in pairs(BLOCKS) do
        if i ~= "air" then
            BLOCKS_IDMAP[id] = i;
            BLOCKS_REVERSE_IDMAP[i]=id;
            BLOCKS_IS_TRANSPARENT[id]=v.transparent; -- can be nil
            BLOCKS_RENDERTYPE[id]=v.render_type;
            BLOCKS_TEXTURE[id]={
                v.top,
                v.bottom,
                v.xplus,
                v.xminus,
                v.yplus,
                v.yminus
            }
            id = id + 1;
        end
    end
    
    for i,v in ipairs(BLOCKS_IDMAP) do
        print(i, v);
    end
end

function reg_block_resolve_name(name)
    return BLOCKS_REVERSE_IDMAP[name];
end