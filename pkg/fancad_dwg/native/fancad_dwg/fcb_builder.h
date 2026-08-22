/* FanCAD Binary (FCB) writer.
 *
 * Mirrors pkg/fancad_dwg/lib/src/fcb/format.dart. Incompatible layout
 * changes must be made in both files and the format version bumped.
 * New optional TOC sections (unknown kinds are skipped) do not.
 *
 * The builder is deliberately dependency-free: it knows nothing about DWG, so
 * it can be compiled and unit tested on its own, and a future importer for a
 * different format reuses it unchanged.
 */
#ifndef FANCAD_FCB_BUILDER_H
#define FANCAD_FCB_BUILDER_H

#include <stddef.h>
#include <stdint.h>

#define FCB_MAGIC 0x31424346u /* 'F','C','B','1' little-endian */
#define FCB_VERSION 1
#define FCB_HEADER_SIZE 16
#define FCB_TOC_ENTRY_SIZE 24

/* Section identifiers. */
#define FCB_SECTION_STRINGS 1
#define FCB_SECTION_DOUBLE_POOL 2
#define FCB_SECTION_INT_POOL 3
#define FCB_SECTION_ENTITIES 4
#define FCB_SECTION_LAYERS 5
#define FCB_SECTION_LINETYPES 6
#define FCB_SECTION_TEXTSTYLES 7
#define FCB_SECTION_BLOCKS 8
#define FCB_SECTION_LAYOUTS 9
#define FCB_SECTION_HEADERVARS 10
#define FCB_SECTION_DIAGNOSTICS 11
#define FCB_SECTION_VIEWPORTS 12

/* Fixed record sizes. */
#define FCB_RECORD_ENTITY 104
#define FCB_RECORD_LAYER 32
#define FCB_RECORD_LINETYPE 24
#define FCB_RECORD_TEXTSTYLE 40
#define FCB_RECORD_BLOCK 48
#define FCB_RECORD_LAYOUT 32
#define FCB_RECORD_VIEWPORT 80

/* Entity type codes. Wire values: never renumber. */
#define FCB_TYPE_UNKNOWN 0
#define FCB_TYPE_LINE 1
#define FCB_TYPE_POLYLINE 2
#define FCB_TYPE_CIRCLE 3
#define FCB_TYPE_ARC 4
#define FCB_TYPE_ELLIPSE 5
#define FCB_TYPE_SPLINE 6
#define FCB_TYPE_POINT 7
#define FCB_TYPE_TEXT 8
#define FCB_TYPE_MTEXT 9
#define FCB_TYPE_INSERT 10
#define FCB_TYPE_HATCH 11
#define FCB_TYPE_DIMENSION 12
#define FCB_TYPE_LEADER 13
#define FCB_TYPE_SOLID 14
#define FCB_TYPE_RAY 15
#define FCB_TYPE_XLINE 16
#define FCB_TYPE_IMAGE 17

/* Entity flags. */
#define FCB_FLAG_CLOSED (1u << 0)
#define FCB_FLAG_SOLID_FILL (1u << 1)
#define FCB_FLAG_ARROW_HEAD (1u << 2)
#define FCB_FLAG_INVISIBLE (1u << 3)
#define FCB_FLAG_HAS_EXTENDED_PROPS (1u << 4)
#define FCB_FLAG_PAPER_SPACE (1u << 5)

/* Layer flags. */
#define FCB_LAYER_HIDDEN (1u << 0)
#define FCB_LAYER_FROZEN (1u << 1)
#define FCB_LAYER_LOCKED (1u << 2)
#define FCB_LAYER_NOPLOT (1u << 3)

/* Block flags. */
#define FCB_BLOCK_LAYOUT (1u << 0)
#define FCB_BLOCK_ANONYMOUS (1u << 1)
#define FCB_BLOCK_XREF (1u << 2)

/* Layout flags. */
#define FCB_LAYOUT_MODEL_SPACE (1u << 0)

/* Paper-viewport flags. */
#define FCB_VIEWPORT_ON (1u << 0)
#define FCB_VIEWPORT_LOCKED (1u << 1)

/* Colour kinds. */
#define FCB_COLOR_BY_LAYER 0
#define FCB_COLOR_BY_BLOCK 1
#define FCB_COLOR_INDEXED 2
#define FCB_COLOR_TRUE 3

/* A growable byte buffer. */
typedef struct {
  uint8_t *data;
  size_t length;
  size_t capacity;
  int failed; /* set on allocation failure; all further writes are no-ops */
} fcb_bytes;

/* An interning string table. */
typedef struct {
  fcb_bytes data;    /* concatenated UTF-8 */
  uint32_t *offsets; /* count + 1 entries */
  uint32_t count;
  uint32_t capacity;
  int failed;
} fcb_strings;

/* Accumulates one drawing. */
typedef struct {
  fcb_strings strings;
  fcb_bytes doubles;   /* raw double pool */
  fcb_bytes ints;      /* raw int64 pool */
  fcb_bytes entities;  /* FCB_RECORD_ENTITY records */
  fcb_bytes layers;
  fcb_bytes linetypes;
  fcb_bytes textstyles;
  fcb_bytes blocks;
  fcb_bytes layouts;
  fcb_bytes viewports;
  fcb_bytes headervars;
  fcb_bytes diagnostics;
  uint32_t entity_count;
  uint32_t layer_count;
  uint32_t linetype_count;
  uint32_t textstyle_count;
  uint32_t block_count;
  uint32_t layout_count;
  uint32_t viewport_count;
  uint32_t headervar_count;
  int failed;
} fcb_builder;

void fcb_builder_init(fcb_builder *b);
void fcb_builder_dispose(fcb_builder *b);

/* Interns a NUL-terminated UTF-8 string, returning its index.
 * A NULL or empty string always maps to index 0. */
uint32_t fcb_intern(fcb_builder *b, const char *utf8);

/* Appends a string without deduplication, so that a run of strings belonging
 * to one entity stays contiguous. Returns the index. */
uint32_t fcb_append_string(fcb_builder *b, const char *utf8);

/* Appends to the double pool, returning the index of the first value. */
uint64_t fcb_add_doubles(fcb_builder *b, const double *values, uint32_t count);
uint64_t fcb_add_double(fcb_builder *b, double value);

/* Appends to the int pool, returning the index of the first value. */
uint64_t fcb_add_ints(fcb_builder *b, const int64_t *values, uint32_t count);

/* The number of values currently in each pool. */
uint64_t fcb_double_pool_length(const fcb_builder *b);
uint64_t fcb_int_pool_length(const fcb_builder *b);

/* One entity record. Offsets and counts address the pools above. */
typedef struct {
  double min_x, min_y, max_x, max_y;
  uint64_t handle;
  uint64_t geom_offset;
  uint64_t int_offset;
  uint32_t geom_count;
  uint32_t int_count;
  uint32_t layer_index;
  uint32_t color_packed;
  uint32_t linetype_index;
  uint32_t owner_block_index;
  uint32_t string_offset;
  uint32_t string_count;
  uint32_t props_offset;
  int32_t line_weight;
  uint16_t type;
  uint16_t flags;
} fcb_entity;

void fcb_add_entity(fcb_builder *b, const fcb_entity *entity);

typedef struct {
  uint32_t name;
  uint32_t color_packed;
  uint32_t linetype_index;
  int32_t line_weight;
  uint32_t flags;
  int32_t transparency;
} fcb_layer;

void fcb_add_layer(fcb_builder *b, const fcb_layer *layer);

typedef struct {
  uint32_t name;
  uint32_t description;
  uint32_t pattern_offset;
  uint32_t pattern_count;
  double pattern_length;
} fcb_linetype;

void fcb_add_linetype(fcb_builder *b, const fcb_linetype *linetype);

typedef struct {
  uint32_t name;
  uint32_t font;
  uint32_t big_font;
  uint32_t flags;
  double height;
  double width_factor;
  double oblique_angle;
} fcb_textstyle;

void fcb_add_textstyle(fcb_builder *b, const fcb_textstyle *style);

typedef struct {
  double base_x, base_y;
  uint32_t name;
  uint32_t flags;
  uint32_t entity_first;
  uint32_t entity_count;
  uint32_t xref_path;
  uint32_t description;
  uint64_t handle;
} fcb_block;

void fcb_add_block(fcb_builder *b, const fcb_block *block);

typedef struct {
  uint32_t name;
  uint32_t block_index;
  uint32_t flags;
  uint32_t tab_order;
  double paper_width;
  double paper_height;
} fcb_layout;

void fcb_add_layout(fcb_builder *b, const fcb_layout *layout);

typedef struct {
  uint32_t layout_index;
  uint32_t flags;
  double paper_min_x, paper_min_y, paper_max_x, paper_max_y;
  double model_center_x, model_center_y;
  double scale;
  double rotation;
  uint32_t layer;
  uint32_t reserved;
} fcb_viewport;

void fcb_add_viewport(fcb_builder *b, const fcb_viewport *viewport);

void fcb_add_header_variable(fcb_builder *b, const char *key,
                             const char *value);

/* Appends a diagnostic line. */
void fcb_diagnose(fcb_builder *b, const char *message);

uint32_t fcb_pack_color(uint32_t kind, uint32_t value);

/* Serializes the accumulated drawing.
 * On success returns 0, stores a malloc'd buffer in *out_data and its size in
 * *out_length; the caller owns the buffer and frees it with free().
 * On failure returns non-zero and leaves the outputs untouched. */
int fcb_builder_finish(fcb_builder *b, uint8_t **out_data,
                       uint64_t *out_length);

#endif /* FANCAD_FCB_BUILDER_H */
