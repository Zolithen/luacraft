RNDTYP_BLOCK = 1
RNDTYP_SLAB = 2
RNDTYP_ORIENTABLE_BLOCK = 3

REGION_SIZE = 32*16; -- In blocks
THREAD_POOL_SIZE = 15;
MAX_VERTEX_PER_CHUNK = 12288

FACING_ZPLUS = 1
FACING_ZMINUS = 2
FACING_XPLUS = 3
FACING_XMINUS = 4
FACING_YPLUS = 5
FACING_YMINUS = 6

RENDER_DISTANCE = 6;
-- Comes from doing algebra on ((2r+1)^3 - 1)/2. To turn cartesian relative coordinates to consecutive relative coordinates when rendering chunks
RENDER_DISTANCE_INDEX = 4*RENDER_DISTANCE^3 + 6*RENDER_DISTANCE^2 + 3*RENDER_DISTANCE

RENDER_DISTANCE_CONSECUTIVE_Y = 2*RENDER_DISTANCE + 1
RENDER_DISTANCE_CONSECUTIVE_Z = RENDER_DISTANCE_CONSECUTIVE_Y^2

FACING_ID_TO_STRING = {
    "ZPLUS",
    "ZMINUS",
    "XPLUS",
    "XMINUS",
    "YPLUS",
    "YMINUS",
    "INVALID"
}

-- With origin as the center of the block, format (ax + by + cz + d = 0) <=> {a, b, c, d}
BLOCK_FACES_AS_PLANES = {
    {0,  0, 1,  -0.5},
    {0,  0, -1, -0.5},
    {1,  0, 0,  -0.5},
    {-1, 0, 0,  -0.5},
    {0,  1, 0,  -0.5},
    {0, -1, 0,  -0.5}
}