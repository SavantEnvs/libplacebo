#include <stddef.h>
#include <stdint.h>

#include <libplacebo/dummy.h>
#include <libplacebo/shaders/custom.h>

static pl_gpu gpu;

int LLVMFuzzerInitialize(int *argc, char ***argv)
{
    gpu = pl_gpu_dummy_create(NULL, NULL);
    return gpu ? 0 : 1;
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    const struct pl_hook *hook = pl_mpv_user_shader_parse(gpu, (const char *) data, size);
    pl_mpv_user_shader_destroy(&hook);
    return 0;
}
