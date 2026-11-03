#include <stddef.h>
#include <stdint.h>

#include <libplacebo/shaders/lut.h>

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    struct pl_custom_lut *lut = pl_lut_parse_cube(NULL, (const char *) data, size);
    pl_lut_free(&lut);
    return 0;
}
