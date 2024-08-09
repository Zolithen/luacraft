function random_int(min, max)
    return math.floor(min + (math.random())*(max+1-min))
end

function math.point_in_cube(px,py,pz,cx,cy,cz,l)
    return px >= cx and py >= cy and pz >= cz and px<=cx+l and py<=cy+l and pz<=cz+l;
end

function math.distance_point_plane(x, y, z, a, b, c, d)
    return math.abs(a*x + b*y + c*z + d)/math.sqrt(a^2 + b^2 + c^2)
end

-- checks if 2 cuboids are intersecting
-- note: im an idiot
function math.intersection_cuboid(ax1, ay1, az1, ax2, ay2, az2, bx1, by1, bz1, bx2, by2, bz2)
    return ax1 <= bx2 and
        ax2 >= bx1 and
        ay1 <= by2 and
        ay2 >= by1 and
        az1 <= bz2 and
        az2 >= bz1
end
--[[
function intersect(a, b) {
  return (
    a.minX <= b.maxX &&
    a.maxX >= b.minX &&
    a.minY <= b.maxY &&
    a.maxY >= b.minY &&
    a.minZ <= b.maxZ &&
    a.maxZ >= b.minZ
  );
}

]]

local function reversedipairsiter(t, i)
    i = i - 1
    if i ~= 0 then
        return i, t[i]
    end
end
function reversed_ipairs(t)
    return reversedipairsiter, t, #t + 1
end