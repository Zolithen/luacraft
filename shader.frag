vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
{
    vec4 texcolor = Texel(tex, texture_coords);
    return texcolor * color;
    //return vec4(color.a,color.a,color.a,color.a);
}