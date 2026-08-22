#include "fcb_builder.h"

#include <stdlib.h>
#include <string.h>

/* ------------------------------------------------------------------------- */
/* Byte buffers                                                              */
/* ------------------------------------------------------------------------- */

static void bytes_init(fcb_bytes *b) {
  b->data = NULL;
  b->length = 0;
  b->capacity = 0;
  b->failed = 0;
}

static void bytes_dispose(fcb_bytes *b) {
  free(b->data);
  bytes_init(b);
}

static int bytes_reserve(fcb_bytes *b, size_t extra) {
  size_t needed;
  size_t capacity;
  uint8_t *grown;

  if (b->failed) return 0;
  needed = b->length + extra;
  if (needed <= b->capacity) return 1;
  capacity = b->capacity ? b->capacity : 4096;
  while (capacity < needed) {
    size_t doubled = capacity * 2;
    if (doubled < capacity) { /* overflow */
      b->failed = 1;
      return 0;
    }
    capacity = doubled;
  }
  grown = (uint8_t *)realloc(b->data, capacity);
  if (!grown) {
    b->failed = 1;
    return 0;
  }
  b->data = grown;
  b->capacity = capacity;
  return 1;
}

static void bytes_append(fcb_bytes *b, const void *src, size_t size) {
  if (size == 0) return;
  if (!bytes_reserve(b, size)) return;
  memcpy(b->data + b->length, src, size);
  b->length += size;
}

/* All integers are written little-endian explicitly rather than by memcpy of a
 * native value, so the format does not depend on the host byte order. */
static void put_u16(uint8_t *p, uint16_t v) {
  p[0] = (uint8_t)(v & 0xFF);
  p[1] = (uint8_t)((v >> 8) & 0xFF);
}

static void put_u32(uint8_t *p, uint32_t v) {
  p[0] = (uint8_t)(v & 0xFF);
  p[1] = (uint8_t)((v >> 8) & 0xFF);
  p[2] = (uint8_t)((v >> 16) & 0xFF);
  p[3] = (uint8_t)((v >> 24) & 0xFF);
}

static void put_u64(uint8_t *p, uint64_t v) {
  int i;
  for (i = 0; i < 8; i++) {
    p[i] = (uint8_t)((v >> (8 * i)) & 0xFF);
  }
}

static void put_f64(uint8_t *p, double v) {
  uint64_t bits;
  memcpy(&bits, &v, sizeof(bits));
  put_u64(p, bits);
}

static size_t align_up8(size_t value) { return (value + 7u) & ~(size_t)7u; }

/* ------------------------------------------------------------------------- */
/* String table                                                              */
/* ------------------------------------------------------------------------- */

static void strings_init(fcb_strings *s) {
  bytes_init(&s->data);
  s->offsets = NULL;
  s->count = 0;
  s->capacity = 0;
  s->failed = 0;
}

static void strings_dispose(fcb_strings *s) {
  bytes_dispose(&s->data);
  free(s->offsets);
  strings_init(s);
}

static int strings_reserve(fcb_strings *s, uint32_t extra) {
  uint32_t capacity;
  uint32_t *grown;

  if (s->failed) return 0;
  if (s->count + extra + 1 <= s->capacity) return 1;
  capacity = s->capacity ? s->capacity : 256;
  while (capacity < s->count + extra + 1) capacity *= 2;
  grown = (uint32_t *)realloc(s->offsets, capacity * sizeof(uint32_t));
  if (!grown) {
    s->failed = 1;
    return 0;
  }
  s->offsets = grown;
  s->capacity = capacity;
  return 1;
}

/* Appends without deduplication. Index 0 is reserved for the empty string and
 * is created by fcb_builder_init. */
static uint32_t strings_append(fcb_strings *s, const char *utf8) {
  size_t size;
  if (!strings_reserve(s, 1)) return 0;
  s->offsets[s->count] = (uint32_t)s->data.length;
  size = utf8 ? strlen(utf8) : 0;
  if (size > 0) bytes_append(&s->data, utf8, size);
  s->count++;
  s->offsets[s->count] = (uint32_t)s->data.length;
  return s->count - 1;
}

static uint32_t strings_find(const fcb_strings *s, const char *utf8) {
  uint32_t i;
  size_t size = utf8 ? strlen(utf8) : 0;
  for (i = 0; i < s->count; i++) {
    uint32_t start = s->offsets[i];
    uint32_t end = s->offsets[i + 1];
    if ((size_t)(end - start) != size) continue;
    if (size == 0) return i;
    if (memcmp(s->data.data + start, utf8, size) == 0) return i;
  }
  return UINT32_MAX;
}

/* ------------------------------------------------------------------------- */
/* Builder                                                                   */
/* ------------------------------------------------------------------------- */

void fcb_builder_init(fcb_builder *b) {
  memset(b, 0, sizeof(*b));
  strings_init(&b->strings);
  bytes_init(&b->doubles);
  bytes_init(&b->ints);
  bytes_init(&b->entities);
  bytes_init(&b->layers);
  bytes_init(&b->linetypes);
  bytes_init(&b->textstyles);
  bytes_init(&b->blocks);
  bytes_init(&b->layouts);
  bytes_init(&b->viewports);
  bytes_init(&b->headervars);
  bytes_init(&b->diagnostics);
  /* Reserve index 0 for the empty string so a zeroed field reads as absent. */
  strings_append(&b->strings, "");
}

void fcb_builder_dispose(fcb_builder *b) {
  strings_dispose(&b->strings);
  bytes_dispose(&b->doubles);
  bytes_dispose(&b->ints);
  bytes_dispose(&b->entities);
  bytes_dispose(&b->layers);
  bytes_dispose(&b->linetypes);
  bytes_dispose(&b->textstyles);
  bytes_dispose(&b->blocks);
  bytes_dispose(&b->layouts);
  bytes_dispose(&b->viewports);
  bytes_dispose(&b->headervars);
  bytes_dispose(&b->diagnostics);
}

uint32_t fcb_intern(fcb_builder *b, const char *utf8) {
  uint32_t existing;
  if (!utf8 || !*utf8) return 0;
  existing = strings_find(&b->strings, utf8);
  if (existing != UINT32_MAX) return existing;
  return strings_append(&b->strings, utf8);
}

uint32_t fcb_append_string(fcb_builder *b, const char *utf8) {
  return strings_append(&b->strings, utf8 ? utf8 : "");
}

uint64_t fcb_double_pool_length(const fcb_builder *b) {
  return (uint64_t)(b->doubles.length / 8);
}

uint64_t fcb_int_pool_length(const fcb_builder *b) {
  return (uint64_t)(b->ints.length / 8);
}

uint64_t fcb_add_doubles(fcb_builder *b, const double *values,
                         uint32_t count) {
  uint64_t start = fcb_double_pool_length(b);
  uint32_t i;
  if (count == 0) return start;
  if (!bytes_reserve(&b->doubles, (size_t)count * 8)) return start;
  for (i = 0; i < count; i++) {
    put_f64(b->doubles.data + b->doubles.length + (size_t)i * 8, values[i]);
  }
  b->doubles.length += (size_t)count * 8;
  return start;
}

uint64_t fcb_add_double(fcb_builder *b, double value) {
  return fcb_add_doubles(b, &value, 1);
}

uint64_t fcb_add_ints(fcb_builder *b, const int64_t *values, uint32_t count) {
  uint64_t start = fcb_int_pool_length(b);
  uint32_t i;
  if (count == 0) return start;
  if (!bytes_reserve(&b->ints, (size_t)count * 8)) return start;
  for (i = 0; i < count; i++) {
    put_u64(b->ints.data + b->ints.length + (size_t)i * 8,
            (uint64_t)values[i]);
  }
  b->ints.length += (size_t)count * 8;
  return start;
}

void fcb_add_entity(fcb_builder *b, const fcb_entity *e) {
  uint8_t record[FCB_RECORD_ENTITY];
  memset(record, 0, sizeof(record));
  put_f64(record + 0, e->min_x);
  put_f64(record + 8, e->min_y);
  put_f64(record + 16, e->max_x);
  put_f64(record + 24, e->max_y);
  put_u64(record + 32, e->handle);
  put_u64(record + 40, e->geom_offset);
  put_u64(record + 48, e->int_offset);
  put_u32(record + 56, e->geom_count);
  put_u32(record + 60, e->int_count);
  put_u32(record + 64, e->layer_index);
  put_u32(record + 68, e->color_packed);
  put_u32(record + 72, e->linetype_index);
  put_u32(record + 76, e->owner_block_index);
  put_u32(record + 80, e->string_offset);
  put_u32(record + 84, e->string_count);
  put_u32(record + 88, e->props_offset);
  put_u32(record + 92, (uint32_t)e->line_weight);
  put_u16(record + 96, e->type);
  put_u16(record + 98, e->flags);
  bytes_append(&b->entities, record, sizeof(record));
  b->entity_count++;
}

void fcb_add_layer(fcb_builder *b, const fcb_layer *l) {
  uint8_t record[FCB_RECORD_LAYER];
  memset(record, 0, sizeof(record));
  put_u32(record + 0, l->name);
  put_u32(record + 4, l->color_packed);
  put_u32(record + 8, l->linetype_index);
  put_u32(record + 12, (uint32_t)l->line_weight);
  put_u32(record + 16, l->flags);
  put_u32(record + 20, (uint32_t)l->transparency);
  bytes_append(&b->layers, record, sizeof(record));
  b->layer_count++;
}

void fcb_add_linetype(fcb_builder *b, const fcb_linetype *l) {
  uint8_t record[FCB_RECORD_LINETYPE];
  memset(record, 0, sizeof(record));
  put_u32(record + 0, l->name);
  put_u32(record + 4, l->description);
  put_u32(record + 8, l->pattern_offset);
  put_u32(record + 12, l->pattern_count);
  put_f64(record + 16, l->pattern_length);
  bytes_append(&b->linetypes, record, sizeof(record));
  b->linetype_count++;
}

void fcb_add_textstyle(fcb_builder *b, const fcb_textstyle *s) {
  uint8_t record[FCB_RECORD_TEXTSTYLE];
  memset(record, 0, sizeof(record));
  put_u32(record + 0, s->name);
  put_u32(record + 4, s->font);
  put_u32(record + 8, s->big_font);
  put_u32(record + 12, s->flags);
  put_f64(record + 16, s->height);
  put_f64(record + 24, s->width_factor);
  put_f64(record + 32, s->oblique_angle);
  bytes_append(&b->textstyles, record, sizeof(record));
  b->textstyle_count++;
}

void fcb_add_block(fcb_builder *b, const fcb_block *bl) {
  uint8_t record[FCB_RECORD_BLOCK];
  memset(record, 0, sizeof(record));
  put_f64(record + 0, bl->base_x);
  put_f64(record + 8, bl->base_y);
  put_u32(record + 16, bl->name);
  put_u32(record + 20, bl->flags);
  put_u32(record + 24, bl->entity_first);
  put_u32(record + 28, bl->entity_count);
  put_u32(record + 32, bl->xref_path);
  put_u32(record + 36, bl->description);
  put_u64(record + 40, bl->handle);
  bytes_append(&b->blocks, record, sizeof(record));
  b->block_count++;
}

void fcb_add_layout(fcb_builder *b, const fcb_layout *l) {
  uint8_t record[FCB_RECORD_LAYOUT];
  memset(record, 0, sizeof(record));
  put_u32(record + 0, l->name);
  put_u32(record + 4, l->block_index);
  put_u32(record + 8, l->flags);
  put_u32(record + 12, l->tab_order);
  put_f64(record + 16, l->paper_width);
  put_f64(record + 24, l->paper_height);
  bytes_append(&b->layouts, record, sizeof(record));
  b->layout_count++;
}

void fcb_add_viewport(fcb_builder *b, const fcb_viewport *v) {
  uint8_t record[FCB_RECORD_VIEWPORT];
  memset(record, 0, sizeof(record));
  put_u32(record + 0, v->layout_index);
  put_u32(record + 4, v->flags);
  put_f64(record + 8, v->paper_min_x);
  put_f64(record + 16, v->paper_min_y);
  put_f64(record + 24, v->paper_max_x);
  put_f64(record + 32, v->paper_max_y);
  put_f64(record + 40, v->model_center_x);
  put_f64(record + 48, v->model_center_y);
  put_f64(record + 56, v->scale);
  put_f64(record + 64, v->rotation);
  put_u32(record + 72, v->layer);
  put_u32(record + 76, v->reserved);
  bytes_append(&b->viewports, record, sizeof(record));
  b->viewport_count++;
}

void fcb_add_header_variable(fcb_builder *b, const char *key,
                             const char *value) {
  uint8_t record[8];
  put_u32(record + 0, fcb_intern(b, key));
  put_u32(record + 4, fcb_intern(b, value));
  bytes_append(&b->headervars, record, sizeof(record));
  b->headervar_count++;
}

void fcb_diagnose(fcb_builder *b, const char *message) {
  if (!message || !*message) return;
  if (b->diagnostics.length > 0) bytes_append(&b->diagnostics, "\n", 1);
  bytes_append(&b->diagnostics, message, strlen(message));
}

uint32_t fcb_pack_color(uint32_t kind, uint32_t value) {
  return ((kind & 0xFFu) << 24) | (value & 0xFFFFFFu);
}

/* ------------------------------------------------------------------------- */
/* Serialization                                                             */
/* ------------------------------------------------------------------------- */

typedef struct {
  uint32_t kind;
  const uint8_t *header; /* optional count prefix */
  size_t header_size;
  const uint8_t *payload;
  size_t payload_size;
} fcb_section;

static int builder_failed(const fcb_builder *b) {
  return b->failed || b->strings.failed || b->strings.data.failed ||
         b->doubles.failed || b->ints.failed || b->entities.failed ||
         b->layers.failed || b->linetypes.failed || b->textstyles.failed ||
         b->blocks.failed || b->layouts.failed || b->viewports.failed ||
         b->headervars.failed || b->diagnostics.failed;
}

int fcb_builder_finish(fcb_builder *b, uint8_t **out_data,
                       uint64_t *out_length) {
  fcb_section sections[12];
  uint8_t counts[12][8];
  size_t section_count = 0;
  size_t strings_size;
  uint8_t *strings_blob = NULL;
  size_t total;
  size_t offset;
  size_t toc_at;
  uint8_t *buffer;
  size_t i;

  if (builder_failed(b)) return -1;

  /* The string table needs its own framing: count, data length, offsets. */
  {
    size_t offsets_size = ((size_t)b->strings.count + 1) * 4;
    strings_size = align_up8(8 + offsets_size + b->strings.data.length);
    strings_blob = (uint8_t *)calloc(1, strings_size);
    if (!strings_blob) return -1;
    put_u32(strings_blob + 0, b->strings.count);
    put_u32(strings_blob + 4, (uint32_t)b->strings.data.length);
    for (i = 0; i <= (size_t)b->strings.count; i++) {
      put_u32(strings_blob + 8 + i * 4, b->strings.offsets[i]);
    }
    if (b->strings.data.length > 0) {
      memcpy(strings_blob + 8 + offsets_size, b->strings.data.data,
             b->strings.data.length);
    }
  }

#define ADD_SECTION(KIND, COUNT, BUF)                                     \
  do {                                                                    \
    put_u64(counts[section_count], (uint64_t)(COUNT));                    \
    sections[section_count].kind = (KIND);                                \
    sections[section_count].header = counts[section_count];               \
    sections[section_count].header_size = 8;                              \
    sections[section_count].payload = (BUF).data;                         \
    sections[section_count].payload_size = (BUF).length;                  \
    section_count++;                                                      \
  } while (0)

  sections[section_count].kind = FCB_SECTION_STRINGS;
  sections[section_count].header = NULL;
  sections[section_count].header_size = 0;
  sections[section_count].payload = strings_blob;
  sections[section_count].payload_size = strings_size;
  section_count++;

  ADD_SECTION(FCB_SECTION_DOUBLE_POOL, fcb_double_pool_length(b), b->doubles);
  ADD_SECTION(FCB_SECTION_INT_POOL, fcb_int_pool_length(b), b->ints);
  ADD_SECTION(FCB_SECTION_ENTITIES, b->entity_count, b->entities);
  ADD_SECTION(FCB_SECTION_LAYERS, b->layer_count, b->layers);
  ADD_SECTION(FCB_SECTION_LINETYPES, b->linetype_count, b->linetypes);
  ADD_SECTION(FCB_SECTION_TEXTSTYLES, b->textstyle_count, b->textstyles);
  ADD_SECTION(FCB_SECTION_BLOCKS, b->block_count, b->blocks);
  ADD_SECTION(FCB_SECTION_LAYOUTS, b->layout_count, b->layouts);
  ADD_SECTION(FCB_SECTION_VIEWPORTS, b->viewport_count, b->viewports);
  ADD_SECTION(FCB_SECTION_HEADERVARS, b->headervar_count, b->headervars);

#undef ADD_SECTION

  if (b->diagnostics.length > 0) {
    sections[section_count].kind = FCB_SECTION_DIAGNOSTICS;
    sections[section_count].header = NULL;
    sections[section_count].header_size = 0;
    sections[section_count].payload = b->diagnostics.data;
    sections[section_count].payload_size = b->diagnostics.length;
    section_count++;
  }

  total = align_up8(FCB_HEADER_SIZE + section_count * FCB_TOC_ENTRY_SIZE);
  for (i = 0; i < section_count; i++) {
    total += align_up8(sections[i].header_size + sections[i].payload_size);
  }

  buffer = (uint8_t *)calloc(1, total);
  if (!buffer) {
    free(strings_blob);
    return -1;
  }

  put_u32(buffer + 0, FCB_MAGIC);
  put_u16(buffer + 4, FCB_VERSION);
  put_u16(buffer + 6, 0);
  put_u32(buffer + 8, (uint32_t)section_count);
  put_u32(buffer + 12, 0);

  toc_at = FCB_HEADER_SIZE;
  offset = align_up8(FCB_HEADER_SIZE + section_count * FCB_TOC_ENTRY_SIZE);
  for (i = 0; i < section_count; i++) {
    size_t size = sections[i].header_size + sections[i].payload_size;
    put_u32(buffer + toc_at + 0, sections[i].kind);
    put_u32(buffer + toc_at + 4, 0);
    put_u64(buffer + toc_at + 8, (uint64_t)offset);
    put_u64(buffer + toc_at + 16, (uint64_t)size);
    if (sections[i].header_size > 0) {
      memcpy(buffer + offset, sections[i].header, sections[i].header_size);
    }
    if (sections[i].payload_size > 0) {
      memcpy(buffer + offset + sections[i].header_size, sections[i].payload,
             sections[i].payload_size);
    }
    offset += align_up8(size);
    toc_at += FCB_TOC_ENTRY_SIZE;
  }

  free(strings_blob);
  *out_data = buffer;
  *out_length = (uint64_t)total;
  return 0;
}
