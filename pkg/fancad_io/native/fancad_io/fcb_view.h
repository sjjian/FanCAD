/* Read-only view over an FCB buffer.
 *
 * Mirrors pkg/fancad_io/lib/src/fcb/reader.dart. The view knows nothing
 * about DWG: it only locates sections and copies strings so the DWG exporter
 * and any future consumer can walk the same packed layout.
 */
#ifndef FANCAD_FCB_VIEW_H
#define FANCAD_FCB_VIEW_H

#include <stddef.h>
#include <stdint.h>

#include "fcb_builder.h"

typedef struct {
  const uint8_t *data;
  uint64_t length;
  int failed;

  uint32_t string_count;
  uint32_t string_data_len;
  const uint8_t *string_offsets; /* (count + 1) little-endian u32 */
  const uint8_t *string_bytes;

  const double *doubles;
  uint64_t double_count;
  const int64_t *ints;
  uint64_t int_count;

  const uint8_t *entities;
  uint64_t entity_count;
  const uint8_t *layers;
  uint64_t layer_count;
  const uint8_t *linetypes;
  uint64_t linetype_count;
  const uint8_t *textstyles;
  uint64_t textstyle_count;
  const uint8_t *blocks;
  uint64_t block_count;
  const uint8_t *layouts;
  uint64_t layout_count;
  const uint8_t *viewports;
  uint64_t viewport_count;
  const uint8_t *dimstyles;
  uint64_t dimstyle_count;
  const uint8_t *headervars;
  uint64_t headervar_count;
} fcb_view;

/* Entity record field offsets, matching FcbEntity in format.dart. */
#define FCB_ENT_HANDLE 32
#define FCB_ENT_GEOM_OFFSET 40
#define FCB_ENT_INT_OFFSET 48
#define FCB_ENT_GEOM_COUNT 56
#define FCB_ENT_INT_COUNT 60
#define FCB_ENT_LAYER_INDEX 64
#define FCB_ENT_COLOR 68
#define FCB_ENT_LINETYPE_INDEX 72
#define FCB_ENT_OWNER_BLOCK 76
#define FCB_ENT_STRING_OFFSET 80
#define FCB_ENT_STRING_COUNT 84
#define FCB_ENT_LINE_WEIGHT 92
#define FCB_ENT_TYPE 96
#define FCB_ENT_FLAGS 98

#define FCB_LAYER_NAME 0
#define FCB_LAYER_COLOR 4
#define FCB_LAYER_LINETYPE 8
#define FCB_LAYER_WEIGHT 12
#define FCB_LAYER_FLAGS 16

#define FCB_LAYOUT_NAME 0
#define FCB_LAYOUT_BLOCK 4
#define FCB_LAYOUT_FLAGS 8
#define FCB_LAYOUT_TAB 12
#define FCB_LAYOUT_WIDTH 16
#define FCB_LAYOUT_HEIGHT 24

#define FCB_VP_LAYOUT 0
#define FCB_VP_FLAGS 4
#define FCB_VP_PAPER_MIN_X 8
#define FCB_VP_PAPER_MIN_Y 16
#define FCB_VP_PAPER_MAX_X 24
#define FCB_VP_PAPER_MAX_Y 32
#define FCB_VP_MODEL_X 40
#define FCB_VP_MODEL_Y 48
#define FCB_VP_SCALE 56
#define FCB_VP_ROTATION 64
#define FCB_VP_LAYER 72
#define FCB_VP_FROZEN 76

#define FCB_DIMSTYLE_NAME 0
#define FCB_DIMSTYLE_TEXTSTYLE 4
#define FCB_DIMSTYLE_DECIMALS 8
#define FCB_DIMSTYLE_TEXT_HEIGHT 16
#define FCB_DIMSTYLE_ARROW 24
#define FCB_DIMSTYLE_EXO 32
#define FCB_DIMSTYLE_EXE 40
#define FCB_DIMSTYLE_GAP 48
#define FCB_DIMSTYLE_SCALE 56

#define FCB_LTYPE_NAME 0
#define FCB_LTYPE_DESCRIPTION 4
#define FCB_LTYPE_PATTERN_OFFSET 8
#define FCB_LTYPE_PATTERN_COUNT 12
#define FCB_LTYPE_PATTERN_LENGTH 16

#define FCB_STYLE_NAME 0
#define FCB_STYLE_FONT 4
#define FCB_STYLE_BIGFONT 8
#define FCB_STYLE_FLAGS 12
#define FCB_STYLE_HEIGHT 16
#define FCB_STYLE_WIDTH 24
#define FCB_STYLE_OBLIQUE 32

#define FCB_HEADERVAR_KEY 0
#define FCB_HEADERVAR_VALUE 4
#define FCB_RECORD_HEADERVAR 8

#define FCB_BLOCK_BASE_X 0
#define FCB_BLOCK_BASE_Y 8
#define FCB_BLOCK_NAME 16
#define FCB_BLOCK_FLAGS 20
#define FCB_BLOCK_ENT_FIRST 24
#define FCB_BLOCK_ENT_COUNT 28

int fcb_view_open(fcb_view *v, const uint8_t *data, uint64_t length);

/* Copies string [index] into [buf] (NUL-terminated). Empty on OOB. */
void fcb_view_str(const fcb_view *v, uint32_t index, char *buf, size_t cap);

const uint8_t *fcb_view_entity(const fcb_view *v, uint64_t index);
const uint8_t *fcb_view_layer(const fcb_view *v, uint64_t index);
const uint8_t *fcb_view_linetype(const fcb_view *v, uint64_t index);
const uint8_t *fcb_view_textstyle(const fcb_view *v, uint64_t index);
const uint8_t *fcb_view_block(const fcb_view *v, uint64_t index);
const uint8_t *fcb_view_layout(const fcb_view *v, uint64_t index);
const uint8_t *fcb_view_viewport(const fcb_view *v, uint64_t index);
const uint8_t *fcb_view_dimstyle(const fcb_view *v, uint64_t index);
const uint8_t *fcb_view_header_var(const fcb_view *v, uint64_t index);

uint16_t fcb_u16(const uint8_t *p);
uint32_t fcb_u32(const uint8_t *p);
uint64_t fcb_u64(const uint8_t *p);
int32_t fcb_i32(const uint8_t *p);
double fcb_f64(const uint8_t *p);

#endif /* FANCAD_FCB_VIEW_H */
