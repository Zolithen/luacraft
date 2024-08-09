ffi = require "ffi"
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
ffi.cdef([[
    void *memcpy(void *dest, const void * src, size_t n);
    void free(void *ptr);
]])