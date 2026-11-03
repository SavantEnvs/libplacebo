// Known-answer oracle for mayhem/test.sh: prints deterministic values computed by libplacebo.
// test.sh diffs `oracle <section>` against oracle/expected/<section>.txt, so a neutered program fails.
#include <stdio.h>
#include <string.h>

#include <libplacebo/colorspace.h>
#include <libplacebo/filters.h>
#include <libplacebo/options.h>
#include <libplacebo/shaders/lut.h>

static void lut(const char *name, const char *text)
{
    struct pl_custom_lut *l = pl_lut_parse_cube(NULL, text, strlen(text));
    if (!l) {
        printf("lut %s: parse failed\n", name);
        return;
    }
    int n = l->size[0] * (l->size[1] ? l->size[1] : 1) * (l->size[2] ? l->size[2] : 1);
    printf("lut %s: size=%dx%dx%d entries=%d\n", name, l->size[0], l->size[1], l->size[2], n);
    for (int i = 0; i < n; i++)
        printf("  [%d] %.5f %.5f %.5f\n", i, l->data[3 * i], l->data[3 * i + 1], l->data[3 * i + 2]);
    pl_lut_free(&l);
}

static void opts(pl_options o, const char *in)
{
    bool ok = pl_options_load(o, in);
    printf("options load(\"%s\") = %s -> \"%s\"\n", in, ok ? "ok" : "fail", pl_options_save(o));
}

static void s_lut_1d(void) { lut("1d", "LUT_1D_SIZE 3\n0.0 0.0 0.0\n0.25 0.5 0.75\n1.0 1.0 1.0\n"); }
static void s_lut_domain(void) { lut("domain", "LUT_1D_SIZE 3\nDOMAIN_MAX 255 255 255\n0 0 0\n51 102 204\n255 255 255\n"); }
static void s_lut_3d(void) { lut("3d", "LUT_3D_SIZE 2\n0 0 0\n1 0 0\n0 1 0\n1 1 0\n0 0 1\n1 0 1\n0 1 1\n1 1 1\n"); }
static void s_lut_truncated(void) { lut("truncated", "LUT_1D_SIZE 3\n0 0 0\n1 1 1\n"); }
static void s_lut_badrange(void) { lut("badrange", "LUT_1D_SIZE 2\nDOMAIN_MIN 1 1 1\nDOMAIN_MAX 1 1 1\n0 0 0\n1 1 1\n"); }

static void s_options(void)
{
    pl_options o = pl_options_alloc(NULL);
    opts(o, "upscaler=lanczos,downscaler=hermite,sigmoid=yes");
    opts(o, "preset=high_quality");
    pl_options_reset(o, NULL);
    opts(o, "no_such_option=1");
    opts(o, "peak_percentile=99.5,tile_size=48");
    pl_options_free(&o);
}

static void s_color(void)
{
    printf("color: bt709=%s pq=%s bt2020nc=%s\n", pl_color_primaries_name(PL_COLOR_PRIM_BT_709),
           pl_color_transfer_name(PL_COLOR_TRC_PQ), pl_color_system_name(PL_COLOR_SYSTEM_BT_2020_NC));
    printf("color: pq_peak=%.1f hlg_peak=%.2f sRGB_peak=%.1f\n",
           pl_color_transfer_nominal_peak(PL_COLOR_TRC_PQ),
           pl_color_transfer_nominal_peak(PL_COLOR_TRC_HLG),
           pl_color_transfer_nominal_peak(PL_COLOR_TRC_SRGB));
    struct pl_cie_xy d65 = pl_white_from_temp(6504);
    printf("color: d65=(%.4f, %.4f)\n", d65.x, d65.y);
    struct pl_color_repr repr = { .sys = PL_COLOR_SYSTEM_BT_709, .levels = PL_COLOR_LEVELS_LIMITED,
                                  .bits = { .sample_depth = 10, .color_depth = 10 } };
    printf("color: limited10 scale=%.6f ycbcr=%d\n", pl_color_repr_normalize(&repr),
           pl_color_system_is_ycbcr_like(repr.sys));
}

static void s_filter(void)
{
    struct pl_filter_ctx tri = { .radius = pl_filter_function_triangle.radius };
    struct pl_filter_ctx lan = { .radius = 3.0f };
    printf("filter: triangle(0.25)=%.4f triangle(1)=%.4f lanczos(0)=%.4f lanczos(1)=%.4f\n",
           pl_filter_function_triangle.weight(&tri, 0.25), pl_filter_function_triangle.weight(&tri, 1.0),
           pl_filter_function_sinc.weight(&lan, 0.0), pl_filter_function_sinc.weight(&lan, 1.0));
}

static const struct { const char *name; void (*fn)(void); } sections[] = {
    { "lut_1d", s_lut_1d }, { "lut_domain", s_lut_domain }, { "lut_3d", s_lut_3d },
    { "lut_truncated", s_lut_truncated }, { "lut_badrange", s_lut_badrange },
    { "options", s_options }, { "color", s_color }, { "filter", s_filter },
};

int main(int argc, char **argv)
{
    for (size_t i = 0; i < sizeof(sections) / sizeof(sections[0]); i++) {
        if (argc > 1 && !strcmp(argv[1], sections[i].name)) {
            sections[i].fn();
            return 0;
        }
    }
    fprintf(stderr, "usage: oracle <section>\n");
    return 2;
}
