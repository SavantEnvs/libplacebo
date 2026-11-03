#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <libplacebo/options.h>

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    if (!size)
        return -1;

    char *str = malloc(size + 1);
    if (!str)
        return -1;
    memcpy(str, data, size);
    str[size] = '\0';

    pl_options opts = pl_options_alloc(NULL);
    pl_options_load(opts, str);
    pl_options_save(opts);
    pl_options_reset(opts, NULL);
    pl_options_free(&opts);
    free(str);
    return 0;
}
