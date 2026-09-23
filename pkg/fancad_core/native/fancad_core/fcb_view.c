#include "fcb_view.h"

#include <string.h>

static const uint8_t *section_at(const fcb_view *v, uint32_t kind,
                                 uint64_t *size_out) {
  uint32_t count;
  uint32_t i;
  if (!v->data || v->length < FCB_HEADER_SIZE) return NULL;
  count = fcb_u32(v->data + 8);
  for (i = 0; i < count; i++) {
    const uint8_t *toc = v->data + FCB_HEADER_SIZE + (size_t)i * FCB_TOC_ENTRY_SIZE;
    uint32_t k;
    uint64_t offset;
    uint64_t size;
    if ((uint64_t)(toc - v->data) + FCB_TOC_ENTRY_SIZE > v->length) return NULL;
    k = fcb_u32(toc);
    offset = fcb_u64(toc + 8);
    size = fcb_u64(toc + 16);
    if (k != kind) continue;
    if (offset > v->length || size > v->length - offset) return NULL;
    if (size_out) *size_out = size;
    return v->data + offset;
  }
  return NULL;
}

static const uint8_t *counted(const fcb_view *v, uint32_t kind, uint32_t rec,
                              uint64_t *count_out) {
  uint64_t size = 0;
  const uint8_t *p = section_at(v, kind, &size);
  uint64_t count;
  if (!p || size < 8) {
    if (count_out) *count_out = 0;
    return NULL;
  }
  count = fcb_u64(p);
  if (count_out) *count_out = count;
  if (count == 0) return p + 8;
  if ((uint64_t)rec * count > size - 8) {
    if (count_out) *count_out = 0;
    return NULL;
  }
  return p + 8;
}

uint16_t fcb_u16(const uint8_t *p) {
  uint16_t v;
  memcpy(&v, p, 2);
  return v;
}

uint32_t fcb_u32(const uint8_t *p) {
  uint32_t v;
  memcpy(&v, p, 4);
  return v;
}

uint64_t fcb_u64(const uint8_t *p) {
  uint64_t v;
  memcpy(&v, p, 8);
  return v;
}

int32_t fcb_i32(const uint8_t *p) {
  int32_t v;
  memcpy(&v, p, 4);
  return v;
}

double fcb_f64(const uint8_t *p) {
  double v;
  memcpy(&v, p, 8);
  return v;
}

int fcb_view_open(fcb_view *v, const uint8_t *data, uint64_t length) {
  uint32_t magic;
  uint16_t version;
  uint32_t toc_count;
  uint64_t size;
  const uint8_t *sec;

  memset(v, 0, sizeof(*v));
  if (!data || length < FCB_HEADER_SIZE) {
    v->failed = 1;
    return -1;
  }
  v->data = data;
  v->length = length;
  magic = fcb_u32(data);
  version = fcb_u16(data + 4);
  toc_count = fcb_u32(data + 8);
  if (magic != FCB_MAGIC || version != FCB_VERSION) {
    v->failed = 1;
    return -1;
  }
  if ((uint64_t)FCB_HEADER_SIZE + (uint64_t)toc_count * FCB_TOC_ENTRY_SIZE >
      length) {
    v->failed = 1;
    return -1;
  }

  sec = section_at(v, FCB_SECTION_STRINGS, &size);
  if (sec && size >= 8) {
    uint32_t count = fcb_u32(sec);
    uint32_t data_len = fcb_u32(sec + 4);
    uint64_t offsets_bytes = ((uint64_t)count + 1) * 4;
    if (8 + offsets_bytes + data_len <= size) {
      v->string_count = count;
      v->string_data_len = data_len;
      v->string_offsets = sec + 8;
      v->string_bytes = sec + 8 + offsets_bytes;
    }
  }

  sec = section_at(v, FCB_SECTION_DOUBLE_POOL, &size);
  if (sec && size >= 8) {
    uint64_t count = fcb_u64(sec);
    if (count > 0 && 8 + count * 8 <= size) {
      v->doubles = (const double *)(sec + 8);
      v->double_count = count;
    }
  }

  sec = section_at(v, FCB_SECTION_INT_POOL, &size);
  if (sec && size >= 8) {
    uint64_t count = fcb_u64(sec);
    if (count > 0 && 8 + count * 8 <= size) {
      v->ints = (const int64_t *)(sec + 8);
      v->int_count = count;
    }
  }

  v->entities = counted(v, FCB_SECTION_ENTITIES, FCB_RECORD_ENTITY,
                        &v->entity_count);
  v->layers = counted(v, FCB_SECTION_LAYERS, FCB_RECORD_LAYER, &v->layer_count);
  v->linetypes =
      counted(v, FCB_SECTION_LINETYPES, FCB_RECORD_LINETYPE, &v->linetype_count);
  v->textstyles = counted(v, FCB_SECTION_TEXTSTYLES, FCB_RECORD_TEXTSTYLE,
                          &v->textstyle_count);
  v->blocks = counted(v, FCB_SECTION_BLOCKS, FCB_RECORD_BLOCK, &v->block_count);
  v->layouts =
      counted(v, FCB_SECTION_LAYOUTS, FCB_RECORD_LAYOUT, &v->layout_count);
  v->viewports = counted(v, FCB_SECTION_VIEWPORTS, FCB_RECORD_VIEWPORT,
                         &v->viewport_count);
  v->dimstyles = counted(v, FCB_SECTION_DIMSTYLES, FCB_RECORD_DIMSTYLE,
                         &v->dimstyle_count);
  v->headervars = counted(v, FCB_SECTION_HEADERVARS, FCB_RECORD_HEADERVAR,
                          &v->headervar_count);
  return 0;
}

void fcb_view_str(const fcb_view *v, uint32_t index, char *buf, size_t cap) {
  uint32_t start;
  uint32_t end;
  uint32_t n;
  if (!buf || cap == 0) return;
  buf[0] = '\0';
  if (!v || index >= v->string_count || !v->string_offsets || !v->string_bytes) {
    return;
  }
  start = fcb_u32(v->string_offsets + (size_t)index * 4);
  end = fcb_u32(v->string_offsets + ((size_t)index + 1) * 4);
  if (end < start || end > v->string_data_len) return;
  n = end - start;
  if (n >= cap) n = (uint32_t)cap - 1;
  memcpy(buf, v->string_bytes + start, n);
  buf[n] = '\0';
}

const uint8_t *fcb_view_entity(const fcb_view *v, uint64_t index) {
  if (!v->entities || index >= v->entity_count) return NULL;
  return v->entities + index * FCB_RECORD_ENTITY;
}

const uint8_t *fcb_view_layer(const fcb_view *v, uint64_t index) {
  if (!v->layers || index >= v->layer_count) return NULL;
  return v->layers + index * FCB_RECORD_LAYER;
}

const uint8_t *fcb_view_linetype(const fcb_view *v, uint64_t index) {
  if (!v->linetypes || index >= v->linetype_count) return NULL;
  return v->linetypes + index * FCB_RECORD_LINETYPE;
}

const uint8_t *fcb_view_textstyle(const fcb_view *v, uint64_t index) {
  if (!v->textstyles || index >= v->textstyle_count) return NULL;
  return v->textstyles + index * FCB_RECORD_TEXTSTYLE;
}

const uint8_t *fcb_view_block(const fcb_view *v, uint64_t index) {
  if (!v->blocks || index >= v->block_count) return NULL;
  return v->blocks + index * FCB_RECORD_BLOCK;
}

const uint8_t *fcb_view_layout(const fcb_view *v, uint64_t index) {
  if (!v->layouts || index >= v->layout_count) return NULL;
  return v->layouts + index * FCB_RECORD_LAYOUT;
}

const uint8_t *fcb_view_viewport(const fcb_view *v, uint64_t index) {
  if (!v->viewports || index >= v->viewport_count) return NULL;
  return v->viewports + index * FCB_RECORD_VIEWPORT;
}

const uint8_t *fcb_view_dimstyle(const fcb_view *v, uint64_t index) {
  if (!v->dimstyles || index >= v->dimstyle_count) return NULL;
  return v->dimstyles + index * FCB_RECORD_DIMSTYLE;
}

const uint8_t *fcb_view_header_var(const fcb_view *v, uint64_t index) {
  if (!v->headervars || index >= v->headervar_count) return NULL;
  return v->headervars + index * FCB_RECORD_HEADERVAR;
}
