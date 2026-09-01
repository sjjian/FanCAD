#include "dwg_import.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "fancad_io.h"

#ifndef FANCAD_HAVE_LIBREDWG

/* -------------------------------------------------------------------------
 * No backend. The shim still links and reports its state honestly, so the
 * application builds and runs on a machine without LibreDWG.
 * ------------------------------------------------------------------------- */

int fcdwg_has_backend(void) { return 0; }

const char *fcdwg_backend_version(void) {
  return "no DWG backend (built without LibreDWG)";
}

int fcdwg_import(const char *path, fcb_builder *b, char *error_out,
                 size_t error_capacity) {
  (void)path;
  (void)b;
  if (error_out && error_capacity > 0) {
    snprintf(error_out, error_capacity,
             "This build has no DWG backend. Rebuild with LibreDWG available "
             "(see pkg/fancad_io/README.md) to open DWG files.");
  }
  return FC_STATUS_NO_BACKEND;
}

#else /* FANCAD_HAVE_LIBREDWG */

#include <dwg.h>
#include <dwg_api.h>

#include <math.h>
#if defined(__APPLE__) || defined(__linux__)
#include <iconv.h>
#define FANCAD_HAVE_ICONV 1
#endif

int fcdwg_has_backend(void) { return 1; }

#ifndef _FC_STRINGIFY
#define _FC_STRINGIFY_INNER(x) #x
#define _FC_STRINGIFY(x) _FC_STRINGIFY_INNER(x)
#endif

const char *fcdwg_backend_version(void) {
#ifdef PACKAGE_VERSION
  return "GNU LibreDWG " PACKAGE_VERSION;
#elif defined(LIBREDWG_VERSION_MAJOR)
  return "GNU LibreDWG " _FC_STRINGIFY(LIBREDWG_VERSION_MAJOR) "."
      _FC_STRINGIFY(LIBREDWG_VERSION_MINOR);
#else
  return "GNU LibreDWG";
#endif
}

/* -------------------------------------------------------------------------
 * A minimal open-addressing map from DWG absolute handle to a table index.
 *
 * Entity records reference layers, line types and blocks by index, and a
 * drawing can contain tens of thousands of blocks, so a linear scan per
 * entity is not acceptable.
 * ------------------------------------------------------------------------- */

typedef struct {
  uint64_t *keys;   /* 0 means empty */
  uint32_t *values;
  size_t capacity;  /* always a power of two */
  size_t count;
} handle_map;

static int hmap_init(handle_map *m, size_t hint) {
  size_t capacity = 16;
  while (capacity < hint * 2) capacity *= 2;
  m->keys = (uint64_t *)calloc(capacity, sizeof(uint64_t));
  m->values = (uint32_t *)calloc(capacity, sizeof(uint32_t));
  m->capacity = capacity;
  m->count = 0;
  return m->keys && m->values;
}

static void hmap_dispose(handle_map *m) {
  free(m->keys);
  free(m->values);
  m->keys = NULL;
  m->values = NULL;
  m->capacity = 0;
  m->count = 0;
}

static size_t hmap_slot(const handle_map *m, uint64_t key) {
  /* Fibonacci hashing: handles are dense small integers, so the low bits
   * alone would cluster badly. */
  uint64_t hash = key * 0x9E3779B97F4A7C15ull;
  return (size_t)(hash >> 40) & (m->capacity - 1);
}

static int hmap_grow(handle_map *m);

static int hmap_put(handle_map *m, uint64_t key, uint32_t value) {
  size_t slot;
  if (key == 0) return 0;
  if (m->count * 4 >= m->capacity * 3 && !hmap_grow(m)) return 0;
  slot = hmap_slot(m, key);
  while (m->keys[slot] != 0) {
    if (m->keys[slot] == key) {
      m->values[slot] = value;
      return 1;
    }
    slot = (slot + 1) & (m->capacity - 1);
  }
  m->keys[slot] = key;
  m->values[slot] = value;
  m->count++;
  return 1;
}

static int hmap_grow(handle_map *m) {
  handle_map grown;
  size_t i;
  if (!hmap_init(&grown, m->capacity)) return 0;
  for (i = 0; i < m->capacity; i++) {
    if (m->keys[i] != 0) hmap_put(&grown, m->keys[i], m->values[i]);
  }
  hmap_dispose(m);
  *m = grown;
  return 1;
}

/* Returns the stored value, or fallback when absent. */
static uint32_t hmap_get(const handle_map *m, uint64_t key, uint32_t fallback) {
  size_t slot;
  if (key == 0 || m->capacity == 0) return fallback;
  slot = hmap_slot(m, key);
  while (m->keys[slot] != 0) {
    if (m->keys[slot] == key) return m->values[slot];
    slot = (slot + 1) & (m->capacity - 1);
  }
  return fallback;
}

/* -------------------------------------------------------------------------
 * Small helpers
 * ------------------------------------------------------------------------- */

/* A growable double array used to stage one entity's coordinates before they
 * are handed to the pool in a single call. */
typedef struct {
  double *data;
  uint32_t length;
  uint32_t capacity;
  int failed;
} coords;

static void coords_init(coords *c) {
  c->data = NULL;
  c->length = 0;
  c->capacity = 0;
  c->failed = 0;
}

static void coords_reset(coords *c) { c->length = 0; }

static void coords_dispose(coords *c) {
  free(c->data);
  coords_init(c);
}

static void coords_push(coords *c, double value) {
  if (c->failed) return;
  if (c->length == c->capacity) {
    uint32_t capacity = c->capacity ? c->capacity * 2 : 64;
    double *grown = (double *)realloc(c->data, capacity * sizeof(double));
    if (!grown) {
      c->failed = 1;
      return;
    }
    c->data = grown;
    c->capacity = capacity;
  }
  c->data[c->length++] = value;
}

static void coords_push2(coords *c, double x, double y) {
  coords_push(c, x);
  coords_push(c, y);
}

/* Bounds accumulator. */
typedef struct {
  double min_x, min_y, max_x, max_y;
  int seen;
} box;

static void box_init(box *b) {
  b->min_x = b->min_y = b->max_x = b->max_y = 0.0;
  b->seen = 0;
}

static void box_add(box *b, double x, double y) {
  if (!b->seen) {
    b->min_x = b->max_x = x;
    b->min_y = b->max_y = y;
    b->seen = 1;
    return;
  }
  if (x < b->min_x) b->min_x = x;
  if (y < b->min_y) b->min_y = y;
  if (x > b->max_x) b->max_x = x;
  if (y > b->max_y) b->max_y = y;
}

static void box_add_coords(box *b, const coords *c, uint32_t stride) {
  uint32_t i;
  for (i = 0; i + 1 < c->length; i += stride) {
    box_add(b, c->data[i], c->data[i + 1]);
  }
}

/* R2007+ strings arrive as UTF-8 from LibreDWG. Pre-R2007 TV strings are
 * still in the drawing codepage (GBK / CP936 on Chinese R2004 files). The
 * dynapi returns those bytes unchanged, so FCB must convert them or Dart
 * will replace every CJK character with U+FFFD. */
#ifdef FANCAD_HAVE_ICONV
static int is_ascii(const unsigned char *s) {
  for (; *s; s++) {
    if (*s & 0x80) return 0;
  }
  return 1;
}

static int is_valid_utf8(const unsigned char *s) {
  while (*s) {
    if (*s < 0x80) {
      s++;
      continue;
    }
    if ((*s & 0xE0) == 0xC0) {
      if ((s[1] & 0xC0) != 0x80 || *s < 0xC2) return 0;
      s += 2;
      continue;
    }
    if ((*s & 0xF0) == 0xE0) {
      if ((s[1] & 0xC0) != 0x80 || (s[2] & 0xC0) != 0x80) return 0;
      s += 3;
      continue;
    }
    if ((*s & 0xF8) == 0xF0) {
      if ((s[1] & 0xC0) != 0x80 || (s[2] & 0xC0) != 0x80 ||
          (s[3] & 0xC0) != 0x80) {
        return 0;
      }
      s += 4;
      continue;
    }
    return 0;
  }
  return 1;
}

/* Chinese R2000–R2004 drawings often keep GBK even when $DWGCODEPAGE
 * is tagged ANSI_1252. A well-formed GBK stream is pairs of lead
 * 0x81–0xFE and a trail in 0x40–0x7E or 0x80–0xFE. */
static int looks_like_gbk(const unsigned char *s) {
  int pairs = 0;
  while (*s) {
    if (*s < 0x80) {
      s++;
      continue;
    }
    if (s[0] >= 0x81 && s[0] <= 0xFE && s[1] &&
        ((s[1] >= 0x40 && s[1] <= 0x7E) || (s[1] >= 0x80 && s[1] <= 0xFE))) {
      pairs++;
      s += 2;
      continue;
    }
    return 0;
  }
  return pairs > 0;
}

static char *iconv_to_utf8(const char *src, const char *from) {
  iconv_t cd;
  char *in;
  char *out;
  char *result;
  size_t inleft;
  size_t outleft;
  size_t outcap;
  if (!src || !from) return NULL;
  cd = iconv_open("UTF-8", from);
  if (cd == (iconv_t)-1) return NULL;
  inleft = strlen(src);
  outcap = inleft * 4 + 4;
  result = (char *)malloc(outcap);
  if (!result) {
    iconv_close(cd);
    return NULL;
  }
  in = (char *)src;
  out = result;
  outleft = outcap - 1;
  if (iconv(cd, &in, &inleft, &out, &outleft) == (size_t)-1) {
    free(result);
    iconv_close(cd);
    return NULL;
  }
  *out = '\0';
  iconv_close(cd);
  return result;
}

/* Numbering matches LibreDWG Dwg_Codepage / dwg->header.codepage. */
static const char *iconv_name_for_codepage(unsigned codepage) {
  switch (codepage) {
    case 0:
      return "UTF-8";
    case 1:
      return "US-ASCII";
    case 2:
      return "ISO-8859-1";
    case 30:
      return "WINDOWS-1252";
    case 31:
      return "GB2312";
    case 24:
      return "BIG5";
    case 38:
      return "CP932";
    case 39:
      return "CP936";
    case 40:
      return "CP949";
    case 41:
      return "CP950";
    default:
      return NULL;
  }
}
#endif

static char *tv_to_utf8(const char *src, unsigned codepage) {
#ifdef FANCAD_HAVE_ICONV
  char *converted;
  const char *from;
  if (!src || !*src) return NULL;
  if (is_ascii((const unsigned char *)src)) return NULL;
  if (is_valid_utf8((const unsigned char *)src)) return NULL;
  if (looks_like_gbk((const unsigned char *)src)) {
    converted = iconv_to_utf8(src, "GB18030");
    if (converted) return converted;
    converted = iconv_to_utf8(src, "GBK");
    if (converted) return converted;
    converted = iconv_to_utf8(src, "CP936");
    if (converted) return converted;
  }
  from = iconv_name_for_codepage(codepage);
  if (from && strcmp(from, "UTF-8") != 0) {
    converted = iconv_to_utf8(src, from);
    if (converted) return converted;
  }
#else
  (void)src;
  (void)codepage;
#endif
  return NULL;
}

static unsigned entity_codepage(void *entity) {
  int error = 0;
  const Dwg_Object *obj = dwg_obj_generic_to_object(entity, &error);
  if (!obj || !obj->parent) return 0;
  return (unsigned)obj->parent->header.codepage;
}

/* Reads a text field through the dynamic API, which transparently converts
 * the UTF-16 encoding used by R2007 and newer. The caller must call
 * dyn_text_free on the result. */
static char *dyn_text(void *entity, const char *type, const char *field,
                      int *needs_free) {
  char *value = NULL;
  char *converted;
  int is_new = 0;
  *needs_free = 0;
  if (!entity) return NULL;
  if (!dwg_dynapi_entity_utf8text(entity, type, field, &value, &is_new, NULL)) {
    return NULL;
  }
  if (is_new) {
    *needs_free = 1;
    return value;
  }
  converted = tv_to_utf8(value, entity_codepage(entity));
  if (converted) {
    *needs_free = 1;
    return converted;
  }
  return value;
}

static void dyn_text_free(char *value, int needs_free) {
  if (needs_free) free(value);
}

/* Reads a handle-valued field through the dynamic API. */
static Dwg_Object_Ref *dyn_handle(void *entity, const char *type,
                                  const char *field) {
  Dwg_Object_Ref *ref = NULL;
  if (!entity) return NULL;
  if (!dwg_dynapi_entity_value(entity, type, field, &ref, NULL)) return NULL;
  return ref;
}

static double dyn_double(void *entity, const char *type, const char *field,
                         double fallback) {
  double value = fallback;
  if (!entity) return fallback;
  if (!dwg_dynapi_entity_value(entity, type, field, &value, NULL)) {
    return fallback;
  }
  return value;
}

static uint64_t ref_handle(const Dwg_Object_Ref *ref) {
  return ref ? (uint64_t)ref->absolute_ref : 0u;
}

/* R2004 CMC often stores the ACI in the true-colour dword: method C3,
 * index 256, rgb 0xC30000nn. The low byte is the ACI, not RGB(0,0,n).
 * 折边线 on the HunterDouglas sheets is 0xC30000D5 = ACI 213 (magenta);
 * treating that as RGB paints a blue fold line. */
static uint32_t aci_from_cmc_rgb(const Dwg_Color *color) {
  uint32_t body;
  if (!color) return 0;
  body = (uint32_t)color->rgb & 0x00FFFFFFu;
  if (body >= 1 && body <= 255) return body;
  return 0;
}

/* True-colour payload when LibreDWG filled rgb / method. 0 means "not RGB".
 * Method 0xC3 is explicit RGB. 0xC2 is the entity ACI default; its rgb body
 * is not a 24-bit colour. 0x100 / 0x101 are the ByLayer / none sentinels.
 * A body of 1..255 is the R2004 ACI-in-slot encoding, not RGB(0,0,n). */
static uint32_t convert_true_color(const Dwg_Color *color) {
  uint32_t rgb;
  unsigned method;
  uint32_t body;
  if (!color) return 0;
  rgb = (uint32_t)color->rgb;
  method = color->method;
  if (method != 0xc3u && (rgb & 0xFF000000u) != 0xC3000000u) {
    return 0;
  }
  body = rgb & 0x00FFFFFFu;
  if (body == 0 || body <= 0xFFu || body == 0x100u || body == 0x101u) {
    return 0;
  }
  return fcb_pack_color(FCB_COLOR_TRUE, body);
}

/* Translates a DWG entity colour into the packed FCB representation. */
static uint32_t convert_color(const Dwg_Color *color) {
  int32_t index;
  uint32_t packed;
  uint32_t aci;
  if (!color) return fcb_pack_color(FCB_COLOR_BY_LAYER, 256);
  packed = convert_true_color(color);
  if (packed) return packed;
  index = (int32_t)color->index;
  if (index < 0) index = -index;
  if (index >= 1 && index <= 255) {
    return fcb_pack_color(FCB_COLOR_INDEXED, (uint32_t)index);
  }
  aci = aci_from_cmc_rgb(color);
  if (aci) return fcb_pack_color(FCB_COLOR_INDEXED, aci);
  if (index == 0) return fcb_pack_color(FCB_COLOR_BY_BLOCK, 0);
  return fcb_pack_color(FCB_COLOR_BY_LAYER, 256);
}

/* A LAYER table colour is never ByLayer / ByBlock. LibreDWG still reports
 * index 256 when the CMC is true-colour or the method byte is 0xC0; those
 * must not land in the layer table as a sentinel the resolver cannot paint. */
static uint32_t convert_layer_color(const Dwg_Color *color) {
  int32_t index;
  uint32_t packed;
  uint32_t aci;
  if (!color) return fcb_pack_color(FCB_COLOR_INDEXED, 7);
  index = (int32_t)color->index;
  if (index < 0) index = -index;
  if (index >= 1 && index <= 255) {
    return fcb_pack_color(FCB_COLOR_INDEXED, (uint32_t)index);
  }
  aci = aci_from_cmc_rgb(color);
  if (aci) return fcb_pack_color(FCB_COLOR_INDEXED, aci);
  packed = convert_true_color(color);
  if (packed) return packed;
  return fcb_pack_color(FCB_COLOR_INDEXED, 7);
}

/* The dynamic API name for a dimension subtype. Dimension records keep their
 * shared fields at different struct offsets per subtype, so they are read
 * through the dynamic API rather than by casting. */
static const char *dimension_type_name(Dwg_Object_Type type) {
  switch (type) {
    case DWG_TYPE_DIMENSION_ORDINATE: return "DIMENSION_ORDINATE";
    case DWG_TYPE_DIMENSION_LINEAR: return "DIMENSION_LINEAR";
    case DWG_TYPE_DIMENSION_ALIGNED: return "DIMENSION_ALIGNED";
    case DWG_TYPE_DIMENSION_ANG3PT: return "DIMENSION_ANG3PT";
    case DWG_TYPE_DIMENSION_ANG2LN: return "DIMENSION_ANG2LN";
    case DWG_TYPE_DIMENSION_RADIUS: return "DIMENSION_RADIUS";
    case DWG_TYPE_DIMENSION_DIAMETER: return "DIMENSION_DIAMETER";
    default: return NULL;
  }
}

/* -------------------------------------------------------------------------
 * Import state
 * ------------------------------------------------------------------------- */

typedef struct {
  Dwg_Data *dwg;
  fcb_builder *b;
  handle_map layer_index;
  handle_map linetype_index;
  handle_map block_index;
  /* Entity handle → owning block index, from BLOCK_HEADER.entities.
   * ownerhandle is often 0 on R2004 files, so the owned list is the
   * authority for which block a LINE actually belongs to. */
  handle_map entity_block;
  /* Anonymous block indices referenced by live DIMENSION entities. */
  handle_map referenced_dimension_blocks;
  /* One *D block is one dimension's pre-rendered geometry. Value is
   * the winning object-table index. A later DIMENSION.block that
   * resolves to the same header must not draw that *D again. */
  handle_map claimed_dimension_blocks;
  box *block_member_box;
  /* FCB entity ids already written. The first row keeps the DWG handle;
   * a later non-POINT row on that handle gets a synthetic id. */
  handle_map used_entity_ids;
  uint32_t synthetic_seq;
  /* First object-table index per entity handle. A later non-POINT row
   * on that handle is kept in model space; a later POINT is dropped. */
  handle_map first_entity;
  /* Block name per index, so INSERT can reference blocks by name. */
  char **block_names;
  double *block_base_x;
  double *block_base_y;
  uint32_t block_count;
  uint32_t model_space_block;
  uint32_t paper_space_block;
  coords staging;
  uint32_t skipped;
  uint32_t unsupported_hatch_segments;
  struct {
    char name[32];
    uint32_t count;
  } proxies[16];
  uint32_t proxy_tally_count;
} import_state;

/* -------------------------------------------------------------------------
 * Table extraction
 * ------------------------------------------------------------------------- */

static void import_layers(import_state *s) {
  uint32_t i;
  uint32_t index = 0;
  /* Layer "0" must exist even if the file omits it. */
  {
    fcb_layer layer;
    memset(&layer, 0, sizeof(layer));
    layer.name = fcb_intern(s->b, "0");
    layer.color_packed = fcb_pack_color(FCB_COLOR_INDEXED, 7);
    layer.line_weight = -3;
    layer.transparency = 0;
    fcb_add_layer(s->b, &layer);
    index++;
  }
  for (i = 0; i < s->dwg->num_objects; i++) {
    Dwg_Object *obj = &s->dwg->object[i];
    Dwg_Object_LAYER *entry;
    fcb_layer layer;
    char *name;
    int owned;

    if (obj->supertype != DWG_SUPERTYPE_OBJECT) continue;
    if (obj->fixedtype != DWG_TYPE_LAYER) continue;
    entry = obj->tio.object->tio.LAYER;
    if (!entry) continue;

    name = dyn_text(entry, "LAYER", "name", &owned);
    if (name && strcmp(name, "0") == 0) {
      /* Already emitted above; map the handle onto index 0 and refresh it. */
      hmap_put(&s->layer_index, (uint64_t)obj->handle.value, 0);
      dyn_text_free(name, owned);
      continue;
    }

    memset(&layer, 0, sizeof(layer));
    layer.name = fcb_intern(s->b, name ? name : "0");
    layer.color_packed = convert_layer_color(&entry->color);
    layer.linetype_index =
        hmap_get(&s->linetype_index, ref_handle(entry->ltype), 0);
    layer.line_weight = (int32_t)entry->linewt;
    layer.transparency = 0;
    if (!entry->on) layer.flags |= FCB_LAYER_HIDDEN;
    if (entry->frozen) layer.flags |= FCB_LAYER_FROZEN;
    if (entry->locked) layer.flags |= FCB_LAYER_LOCKED;
    if (!entry->plotflag) layer.flags |= FCB_LAYER_NOPLOT;
    fcb_add_layer(s->b, &layer);
    hmap_put(&s->layer_index, (uint64_t)obj->handle.value, index);
    index++;
    dyn_text_free(name, owned);
  }
}

static void import_linetypes(import_state *s) {
  uint32_t i;
  uint32_t index = 0;
  {
    fcb_linetype solid;
    memset(&solid, 0, sizeof(solid));
    solid.name = fcb_intern(s->b, "Continuous");
    solid.description = fcb_intern(s->b, "Solid line");
    fcb_add_linetype(s->b, &solid);
    index++;
  }
  for (i = 0; i < s->dwg->num_objects; i++) {
    Dwg_Object *obj = &s->dwg->object[i];
    Dwg_Object_LTYPE *entry;
    fcb_linetype linetype;
    char *name;
    char *description;
    int owned_name;
    int owned_description;
    uint32_t d;

    if (obj->supertype != DWG_SUPERTYPE_OBJECT) continue;
    if (obj->fixedtype != DWG_TYPE_LTYPE) continue;
    entry = obj->tio.object->tio.LTYPE;
    if (!entry) continue;

    name = dyn_text(entry, "LTYPE", "name", &owned_name);
    if (name && (strcmp(name, "Continuous") == 0 ||
                 strcmp(name, "CONTINUOUS") == 0)) {
      hmap_put(&s->linetype_index, (uint64_t)obj->handle.value, 0);
      dyn_text_free(name, owned_name);
      continue;
    }
    description = dyn_text(entry, "LTYPE", "description", &owned_description);

    coords_reset(&s->staging);
    for (d = 0; d < entry->numdashes; d++) {
      coords_push(&s->staging, entry->dashes ? entry->dashes[d].length : 0.0);
    }

    memset(&linetype, 0, sizeof(linetype));
    linetype.name = fcb_intern(s->b, name ? name : "Continuous");
    linetype.description = fcb_intern(s->b, description ? description : "");
    linetype.pattern_offset =
        (uint32_t)fcb_add_doubles(s->b, s->staging.data, s->staging.length);
    linetype.pattern_count = s->staging.length;
    linetype.pattern_length = entry->pattern_len;
    fcb_add_linetype(s->b, &linetype);
    hmap_put(&s->linetype_index, (uint64_t)obj->handle.value, index);
    index++;

    dyn_text_free(name, owned_name);
    dyn_text_free(description, owned_description);
  }
}

static void import_textstyles(import_state *s) {
  uint32_t i;
  {
    fcb_textstyle standard;
    memset(&standard, 0, sizeof(standard));
    standard.name = fcb_intern(s->b, "Standard");
    standard.font = fcb_intern(s->b, "txt");
    standard.width_factor = 1.0;
    fcb_add_textstyle(s->b, &standard);
  }
  for (i = 0; i < s->dwg->num_objects; i++) {
    Dwg_Object *obj = &s->dwg->object[i];
    Dwg_Object_STYLE *entry;
    fcb_textstyle style;
    char *name;
    char *font;
    char *bigfont;
    int owned_name;
    int owned_font;
    int owned_bigfont;

    if (obj->supertype != DWG_SUPERTYPE_OBJECT) continue;
    if (obj->fixedtype != DWG_TYPE_STYLE) continue;
    entry = obj->tio.object->tio.STYLE;
    if (!entry) continue;

    name = dyn_text(entry, "STYLE", "name", &owned_name);
    if (name && strcmp(name, "Standard") == 0) {
      dyn_text_free(name, owned_name);
      continue;
    }
    font = dyn_text(entry, "STYLE", "font_file", &owned_font);
    bigfont = dyn_text(entry, "STYLE", "bigfont_file", &owned_bigfont);

    memset(&style, 0, sizeof(style));
    style.name = fcb_intern(s->b, name ? name : "Standard");
    style.font = fcb_intern(s->b, font ? font : "txt");
    style.big_font = fcb_intern(s->b, bigfont ? bigfont : "");
    style.height = entry->text_size;
    style.width_factor = entry->width_factor == 0.0 ? 1.0 : entry->width_factor;
    style.oblique_angle = entry->oblique_angle;
    if (entry->generation & 2) style.flags |= 1; /* backwards */
    if (entry->generation & 4) style.flags |= 2; /* upside down */
    fcb_add_textstyle(s->b, &style);

    dyn_text_free(name, owned_name);
    dyn_text_free(font, owned_font);
    dyn_text_free(bigfont, owned_bigfont);
  }
}

static int block_name_taken(const import_state *s, uint32_t count,
                            const char *name) {
  uint32_t i;
  for (i = 0; i < count; i++) {
    if (strcmp(s->block_names[i], name) == 0) return 1;
  }
  return 0;
}

/* LibreDWG often reports every anonymous dimension block as "*D". The handle
 * suffix keeps them distinct so DIMENSION.block still resolves, and so the
 * Dart block map does not keep only the last one. */
static char *unique_block_name(import_state *s, uint32_t count,
                               const char *name, uint64_t handle) {
  char buffer[320];
  if (!name || !name[0]) name = "*Unnamed";
  if (!block_name_taken(s, count, name)) return strdup(name);
  snprintf(buffer, sizeof(buffer), "%s$%llx", name,
           (unsigned long long)handle);
  if (!block_name_taken(s, count, buffer)) return strdup(buffer);
  snprintf(buffer, sizeof(buffer), "%s$%llx_%u", name,
           (unsigned long long)handle, count);
  return strdup(buffer);
}

static int is_structural_entity(Dwg_Object_Type type);
static int dim_text_on_block(const import_state *s, uint32_t block, double x,
                             double y);

/* Relative OFFSETOBJHANDLE refs need the BLOCK_HEADER as the base; plain
 * dwg_ref_object leaves absolute_ref at 0 and the owned LINE never lands
 * in the block. */
static Dwg_Object *resolve_ref(Dwg_Data *dwg, Dwg_Object_Ref *ref,
                               const Dwg_Object *from) {
  Dwg_Object *obj;
  if (!ref) return NULL;
  obj = dwg_ref_object(dwg, ref);
  if (obj) return obj;
  if (from) {
    obj = dwg_ref_object_relative(dwg, ref, from);
    if (obj) return obj;
  }
  if (ref->absolute_ref) {
    return dwg_resolve_handle_silent(dwg, ref->absolute_ref);
  }
  return NULL;
}

static int is_layout_block(const import_state *s, uint32_t block) {
  const char *name;
  if (block == s->model_space_block) return 1;
  if (block >= s->block_count) return 0;
  name = s->block_names[block];
  return name && (strcmp(name, "*Model_Space") == 0 ||
                  strncmp(name, "*Paper_Space", 12) == 0);
}

static int is_dim_anon_block(const import_state *s, uint32_t block) {
  const char *name;
  if (block >= s->block_count) return 0;
  name = s->block_names[block];
  return name && name[0] == '*' && name[1] == 'D';
}

static int is_referenced_dimension_block(const import_state *s,
                                         uint32_t block) {
  return hmap_get(&s->referenced_dimension_blocks, (uint64_t)block + 1u, 0u) !=
         0u;
}

static uint32_t block_index_from_ref(const import_state *s,
                                     Dwg_Object_Ref *ref,
                                     const Dwg_Object *from) {
  uint32_t block =
      hmap_get(&s->block_index, ref_handle(ref), 0xFFFFFFFFu);
  Dwg_Object *resolved;
  if (block != 0xFFFFFFFFu) return block;
  resolved = resolve_ref(s->dwg, ref, from);
  if (!resolved) return 0xFFFFFFFFu;
  return hmap_get(&s->block_index, (uint64_t)resolved->handle.value,
                  0xFFFFFFFFu);
}

static int mark_referenced_dimension_block(import_state *s, Dwg_Object *obj) {
  const char *type_name;
  void *dimension;
  Dwg_Object_Ref *block_ref;
  uint32_t block;
  if (obj->supertype != DWG_SUPERTYPE_ENTITY || !obj->tio.entity) return 1;
  type_name = dimension_type_name(obj->fixedtype);
  if (!type_name) return 1;
  dimension = (void *)obj->tio.entity->tio.DIMENSION_LINEAR;
  if (!dimension) return 1;
  block_ref = dyn_handle(dimension, type_name, "block");
  block = block_index_from_ref(s, block_ref, obj);
  if (block == 0xFFFFFFFFu || !is_dim_anon_block(s, block)) return 1;
  return hmap_put(&s->referenced_dimension_blocks, (uint64_t)block + 1u, 1u);
}

static int index_referenced_dimension_blocks(import_state *s) {
  uint32_t i;
  if (!hmap_init(&s->referenced_dimension_blocks, s->block_count)) return 0;
  for (i = 0; i < s->dwg->num_objects; i++) {
    if (!mark_referenced_dimension_block(s, &s->dwg->object[i])) return 0;
  }
  return 1;
}

/* sort_ents can leave duplicate handles in the object table. Only the first
 * candidate is serialized, so a duplicate DIMENSION must not keep an
 * otherwise orphaned *D block hidden. */
static int reindex_live_dimension_blocks(import_state *s,
                                         const uint32_t *candidates,
                                         uint32_t candidate_count) {
  uint32_t i;
  hmap_dispose(&s->referenced_dimension_blocks);
  if (!hmap_init(&s->referenced_dimension_blocks, s->block_count)) return 0;
  for (i = 0; i < candidate_count; i++) {
    if (!mark_referenced_dimension_block(s, &s->dwg->object[candidates[i]])) {
      return 0;
    }
  }
  return 1;
}

static uint32_t insert_block_index(const import_state *s,
                                   const Dwg_Object *obj) {
  Dwg_Object_Ref *ref = NULL;
  if (!obj->tio.entity) return 0xFFFFFFFFu;
  if (obj->fixedtype == DWG_TYPE_INSERT && obj->tio.entity->tio.INSERT) {
    ref = obj->tio.entity->tio.INSERT->block_header;
  } else if (obj->fixedtype == DWG_TYPE_MINSERT &&
             obj->tio.entity->tio.MINSERT) {
    ref = obj->tio.entity->tio.MINSERT->block_header;
  }
  return hmap_get(&s->block_index, ref_handle(ref), 0xFFFFFFFFu);
}

/* _Oblique / _Close / … are the only INSERTs a *D block should own. */
static int is_acad_arrow_insert(const import_state *s, const Dwg_Object *obj) {
  uint32_t block;
  const char *name;
  if (obj->fixedtype != DWG_TYPE_INSERT &&
      obj->fixedtype != DWG_TYPE_MINSERT) {
    return 0;
  }
  block = insert_block_index(s, obj);
  if (block >= s->block_count) return 0;
  name = s->block_names[block];
  return name && name[0] == '_';
}

/* Exploded dimension graphics. A *D entities[] on R2004 also names
 * MULTILEADERs, HATCHes, and other DIMENSION objects; those are not
 * ticks and must stay on the layout. */
static int is_dim_anon_primitive(Dwg_Object_Type type) {
  switch (type) {
    case DWG_TYPE_LINE:
    case DWG_TYPE_SOLID:
    case DWG_TYPE_TRACE:
    case DWG_TYPE_POINT:
    case DWG_TYPE_TEXT:
    case DWG_TYPE_MTEXT:
    case DWG_TYPE_ATTDEF:
    case DWG_TYPE_ARC:
    case DWG_TYPE_LWPOLYLINE:
    case DWG_TYPE_POLYLINE_2D:
    case DWG_TYPE_INSERT:
    case DWG_TYPE_MINSERT:
      return 1;
    default:
      return 0;
  }
}

static uint32_t entity_layer_intern(const import_state *s,
                                    const Dwg_Object *obj) {
  uint32_t idx;
  uint32_t intern;
  const uint8_t *p;
  if (!obj || !obj->tio.entity || !s->b) return 0xFFFFFFFFu;
  /* The same handle map fill_common uses. resolve_ref on LAYER often
   * returns NULL on this R2004 file (relative ownerhandle). Interned
   * strings are length-prefixed, not NUL-terminated. */
  idx = hmap_get(&s->layer_index, ref_handle(obj->tio.entity->layer),
                 0xFFFFFFFFu);
  if (idx == 0xFFFFFFFFu || idx >= s->b->layer_count) return 0xFFFFFFFFu;
  p = s->b->layers.data + (size_t)idx * FCB_RECORD_LAYER;
  intern = (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) |
           ((uint32_t)p[3] << 24);
  if (intern >= s->b->strings.count) return 0xFFFFFFFFu;
  return intern;
}

static int interned_equals(const import_state *s, uint32_t intern,
                           const char *want) {
  uint32_t start;
  uint32_t end;
  size_t size;
  if (!s->b || intern >= s->b->strings.count) return 0;
  start = s->b->strings.offsets[intern];
  end = s->b->strings.offsets[intern + 1];
  size = want ? strlen(want) : 0;
  if ((size_t)(end - start) != size) return 0;
  return size == 0 ||
         memcmp(s->b->strings.data.data + start, want, size) == 0;
}

static int is_dimension_layer_intern(const import_state *s, uint32_t intern) {
  return interned_equals(s, intern, "dim") ||
         interned_equals(s, intern, "标注") ||
         interned_equals(s, intern, "标注线");
}

/* Fold / hole / mark layers on the HunterDouglas process sheets. A live
 * *D header still lists these as if they were ticks. */
static int is_profile_layer_intern(const import_state *s, uint32_t intern) {
  return interned_equals(s, intern, "折边线") ||
         interned_equals(s, intern, "角码孔") ||
         interned_equals(s, intern, "ATT") ||
         interned_equals(s, intern, "1金属板竖分格线") ||
         interned_equals(s, intern, "细实线") ||
         interned_equals(s, intern, "编号") ||
         interned_equals(s, intern, "xc") ||
         interned_equals(s, intern, "问号") ||
         interned_equals(s, intern, "虚线");
}

/* World-space span of a LINE or LWPOLYLINE, squared. 0 if the type has no
 * cheap extent (POLYLINE_2D vertices live in other objects). */
static int entity_span_sq(const Dwg_Object *obj, double *out) {
  if (!obj || !obj->tio.entity) return 0;
  if (obj->fixedtype == DWG_TYPE_LINE && obj->tio.entity->tio.LINE) {
    const Dwg_Entity_LINE *line = obj->tio.entity->tio.LINE;
    double dx = line->end.x - line->start.x;
    double dy = line->end.y - line->start.y;
    *out = dx * dx + dy * dy;
    return 1;
  }
  if (obj->fixedtype == DWG_TYPE_LWPOLYLINE &&
      obj->tio.entity->tio.LWPOLYLINE) {
    const Dwg_Entity_LWPOLYLINE *pl = obj->tio.entity->tio.LWPOLYLINE;
    double min_x, min_y, max_x, max_y, dx, dy;
    BITCODE_BL i;
    if (!pl->points || pl->num_points < 2) return 0;
    min_x = max_x = pl->points[0].x;
    min_y = max_y = pl->points[0].y;
    for (i = 1; i < pl->num_points; i++) {
      if (pl->points[i].x < min_x) min_x = pl->points[i].x;
      if (pl->points[i].x > max_x) max_x = pl->points[i].x;
      if (pl->points[i].y < min_y) min_y = pl->points[i].y;
      if (pl->points[i].y > max_y) max_y = pl->points[i].y;
    }
    dx = max_x - min_x;
    dy = max_y - min_y;
    *out = dx * dx + dy * dy;
    return 1;
  }
  return 0;
}

/* A later *D entities[] list repeats model-space INSERTs (title frames
 * `bk` / `TK1`, part ticks) and whole annotations. Those must stay on
 * the layout. */
static int dim_anon_cannot_own(const import_state *s, uint32_t block,
                               const Dwg_Object *obj) {
  uint32_t intern;
  double span_sq;
  if (!is_dim_anon_block(s, block)) return 0;
  /* This R2004 file has thousands of model-space entities listed under
   * orphaned *D headers. A live dimension never references those headers;
   * keeping their contents there hides complete profiles and sheet frames. */
  if (!is_referenced_dimension_block(s, block)) return 1;
  if (!is_dim_anon_primitive(obj->fixedtype)) return 1;
  intern = entity_layer_intern(s, obj);
  if (is_profile_layer_intern(s, intern)) return 1;
  if (obj->fixedtype == DWG_TYPE_INSERT ||
      obj->fixedtype == DWG_TYPE_MINSERT) {
    return !is_acad_arrow_insert(s, obj);
  }
  if (!is_dimension_layer_intern(s, intern) && entity_span_sq(obj, &span_sq) &&
      span_sq >= 50.0 * 50.0) {
    /* Oblique ticks stay under ~40. J19's 板2 top is 206, its height 1811;
     * both sat in a live *D list after the 2500 cutoff and only appeared
     * when that one dimension was on screen. */
    return 1;
  }
  return 0;
}

static Dwg_Object *first_entity_row(const import_state *s, Dwg_Object *obj) {
  uint64_t handle;
  uint32_t idx;
  if (!obj || !obj->handle.value) return obj;
  handle = (uint64_t)obj->handle.value;
  idx = hmap_get(&s->first_entity, handle, 0xFFFFFFFFu);
  if (idx >= s->dwg->num_objects) return obj;
  return &s->dwg->object[idx];
}

static int index_first_entities(import_state *s) {
  uint32_t i;
  if (!hmap_init(&s->first_entity, s->dwg->num_objects)) return 0;
  for (i = 0; i < s->dwg->num_objects; i++) {
    Dwg_Object *obj = &s->dwg->object[i];
    uint64_t handle;
    if (obj->supertype != DWG_SUPERTYPE_ENTITY || !obj->tio.entity) continue;
    if (is_structural_entity(obj->fixedtype)) continue;
    handle = (uint64_t)obj->handle.value;
    if (!handle) continue;
    if (hmap_get(&s->first_entity, handle, 0xFFFFFFFFu) != 0xFFFFFFFFu) {
      continue;
    }
    if (!hmap_put(&s->first_entity, handle, i)) return 0;
  }
  return 1;
}

static void claim_owned_entity(import_state *s, Dwg_Object *child,
                               uint32_t block) {
  uint64_t handle;
  uint32_t existing;
  uint32_t by_header;
  BITCODE_BB entmode;
  child = first_entity_row(s, child);
  if (!child || !child->handle.value) return;
  if (child->supertype != DWG_SUPERTYPE_ENTITY) return;
  if (is_structural_entity(child->fixedtype)) return;
  handle = (uint64_t)child->handle.value;
  existing = hmap_get(&s->entity_block, handle, 0xFFFFFFFFu);
  /* entities[] on this R2004 file overlaps. A later *D header repeats a
   * model-space INSERT (the title frame on sheets such as J15). The
   * entity's ownerhandle is the CAD owner; a claim that contradicts it
   * would hide the frame unless that one dimension happens to be in view. */
  if (child->tio.entity) {
    entmode = child->tio.entity->entmode;
    if (entmode == 2 && block != s->model_space_block) return;
    if (entmode == 1 && (s->paper_space_block == 0xFFFFFFFFu ||
                         block != s->paper_space_block)) {
      return;
    }
    by_header = hmap_get(&s->block_index,
                         ref_handle(child->tio.entity->ownerhandle),
                         0xFFFFFFFFu);
    if (by_header != 0xFFFFFFFFu && by_header != block) return;
  }
  if (dim_anon_cannot_own(s, block, child)) return;
  /* Named-block lists on this R2004 file overlap. The first named owner
   * wins, and a later named block may still take a member back from a
   * layout list (*Model_Space / *Paper_Space).
   *
   * *D is not a real named owner in that sense: its entities[] repeats
   * model-space hatches, MULTILEADERs, and part edges. If *D overwrites
   * the layout claim, those objects only exist inside an anonymous
   * dimension block and never appear on the canvas. Real *D-only
   * children (ticks, measurement MTEXT) stay unclaimed until *D runs
   * and DimensionEntity still emits them. */
  if (existing != 0xFFFFFFFFu) {
    if (is_dim_anon_block(s, block)) return;
    if (!is_layout_block(s, existing) && !is_dim_anon_block(s, existing)) {
      return;
    }
  }
  hmap_put(&s->entity_block, handle, block);
}

static int index_owned_entities(import_state *s) {
  uint32_t i;
  uint32_t k;
  Dwg_Version_Type version = s->dwg->header.version;
  if (!hmap_init(&s->entity_block, s->dwg->num_objects)) return 0;
  for (i = 0; i < s->dwg->num_objects; i++) {
    Dwg_Object *obj = &s->dwg->object[i];
    Dwg_Object_BLOCK_HEADER *header;
    uint32_t block;
    if (obj->supertype != DWG_SUPERTYPE_OBJECT) continue;
    if (obj->fixedtype != DWG_TYPE_BLOCK_HEADER) continue;
    header = obj->tio.object->tio.BLOCK_HEADER;
    if (!header) continue;
    block = hmap_get(&s->block_index, (uint64_t)obj->handle.value,
                     0xFFFFFFFFu);
    if (block == 0xFFFFFFFFu) continue;
    if (header->entities && header->num_owned) {
      for (k = 0; k < header->num_owned; k++) {
        claim_owned_entity(s, resolve_ref(s->dwg, header->entities[k], obj),
                           block);
      }
      continue;
    }
    /* R13–R2000 store a first/last chain. On R2004+ dwg_next_entity walks
     * the whole object table, so it must not be used as a fallback. */
    if (version >= R_13b1 && version <= R_2000) {
      Dwg_Object *child = resolve_ref(s->dwg, header->first_entity, obj);
      Dwg_Object *last = resolve_ref(s->dwg, header->last_entity, obj);
      uint32_t guard = 0;
      if (!child || !last) continue;
      while (child && guard++ < 1000000u) {
        claim_owned_entity(s, child, block);
        if (child == last) break;
        child = dwg_next_entity(child);
      }
    }
  }
  return 1;
}

static uint32_t owner_block(const import_state *s, const Dwg_Object *obj) {
  uint32_t owned;
  uint32_t by_header;
  uint32_t first;
  int is_first;
  BITCODE_BB entmode;
  if (!obj->tio.entity) return s->model_space_block;
  /* 2 = MSPACE, 1 = PSPACE. handle.value is not unique on this R2004
   * file; trusting the map alone stuffed plate edges into _Oblique. */
  entmode = obj->tio.entity->entmode;
  if (entmode == 2) return s->model_space_block;
  if (entmode == 1 && s->paper_space_block != 0xFFFFFFFFu) {
    return s->paper_space_block;
  }
  first = obj->handle.value
              ? hmap_get(&s->first_entity, (uint64_t)obj->handle.value,
                         0xFFFFFFFFu)
              : 0xFFFFFFFFu;
  is_first = first < s->dwg->num_objects && &s->dwg->object[first] == obj;
  /* A later row on the same handle is a different object. The first
   * row already has the block seat. */
  if (obj->handle.value && !is_first) {
    return s->model_space_block;
  }
  if (is_first) {
    owned = hmap_get(&s->entity_block, (uint64_t)obj->handle.value,
                     0xFFFFFFFFu);
    if (owned != 0xFFFFFFFFu && owned < s->block_count &&
        !dim_anon_cannot_own(s, owned, obj)) {
      return owned;
    }
  }
  by_header = hmap_get(&s->block_index,
                       ref_handle(obj->tio.entity->ownerhandle),
                       0xFFFFFFFFu);
  /* *D.ownerhandle on a handle-0 later row is the same echo: local
   * ticks already sit in the block under their real handles. */
  if (is_dim_anon_block(s, by_header) && !is_first) {
    return s->model_space_block;
  }
  if (by_header != 0xFFFFFFFFu && by_header < s->block_count &&
      !dim_anon_cannot_own(s, by_header, obj)) {
    return by_header;
  }
  return s->model_space_block;
}

static void add_entity_anchor(const Dwg_Object *obj, box *b) {
  const Dwg_Object_Entity *ent;
  if (!obj || !obj->tio.entity) return;
  ent = obj->tio.entity;
  if (obj->fixedtype == DWG_TYPE_LINE && ent->tio.LINE) {
    box_add(b, ent->tio.LINE->start.x, ent->tio.LINE->start.y);
    box_add(b, ent->tio.LINE->end.x, ent->tio.LINE->end.y);
  } else if (obj->fixedtype == DWG_TYPE_POINT && ent->tio.POINT) {
    box_add(b, ent->tio.POINT->x, ent->tio.POINT->y);
  } else if (obj->fixedtype == DWG_TYPE_INSERT && ent->tio.INSERT) {
    box_add(b, ent->tio.INSERT->ins_pt.x, ent->tio.INSERT->ins_pt.y);
  } else if (obj->fixedtype == DWG_TYPE_MTEXT && ent->tio.MTEXT) {
    box_add(b, ent->tio.MTEXT->ins_pt.x, ent->tio.MTEXT->ins_pt.y);
  }
}

static int index_block_member_boxes(import_state *s) {
  uint32_t i;
  s->block_member_box = (box *)calloc(s->block_count ? s->block_count : 1,
                                      sizeof(box));
  if (!s->block_member_box) return 0;
  for (i = 0; i < s->block_count; i++) box_init(&s->block_member_box[i]);
  for (i = 0; i < s->dwg->num_objects; i++) {
    Dwg_Object *obj = &s->dwg->object[i];
    uint32_t owner;
    uint64_t handle;
    if (obj->supertype != DWG_SUPERTYPE_ENTITY || !obj->tio.entity) continue;
    if (is_structural_entity(obj->fixedtype)) continue;
    handle = (uint64_t)obj->handle.value;
    owner = handle ? hmap_get(&s->entity_block, handle, 0xFFFFFFFFu)
                   : 0xFFFFFFFFu;
    if (owner == 0xFFFFFFFFu) {
      owner = hmap_get(&s->block_index,
                       ref_handle(obj->tio.entity->ownerhandle),
                       0xFFFFFFFFu);
    }
    if (owner >= s->block_count || !is_dim_anon_block(s, owner)) continue;
    add_entity_anchor(obj, &s->block_member_box[owner]);
  }
  return 1;
}

static int dimension_block_and_text(const import_state *s, Dwg_Object *obj,
                                    uint32_t *block, double *text_x,
                                    double *text_y) {
  const char *type_name;
  void *dimension;
  Dwg_Object_Ref *block_ref;
  BITCODE_2RD midpoint;
  if (!obj || obj->supertype != DWG_SUPERTYPE_ENTITY || !obj->tio.entity) {
    return 0;
  }
  type_name = dimension_type_name(obj->fixedtype);
  if (!type_name) return 0;
  dimension = (void *)obj->tio.entity->tio.DIMENSION_LINEAR;
  if (!dimension) return 0;
  block_ref = dyn_handle(dimension, type_name, "block");
  *block = block_index_from_ref(s, block_ref, obj);
  *text_x = 0.0;
  *text_y = 0.0;
  memset(&midpoint, 0, sizeof(midpoint));
  if (dwg_dynapi_entity_value(dimension, type_name, "text_midpt", &midpoint,
                              NULL)) {
    *text_x = midpoint.x;
    *text_y = midpoint.y;
  }
  return 1;
}

static int preclaim_fitting_dimension_blocks(import_state *s,
                                             const uint32_t *candidates,
                                             uint32_t candidate_count) {
  uint32_t i;
  for (i = 0; i < candidate_count; i++) {
    Dwg_Object *obj = &s->dwg->object[candidates[i]];
    uint32_t block;
    double text_x, text_y;
    if (!dimension_block_and_text(s, obj, &block, &text_x, &text_y)) continue;
    if (block >= s->block_count) continue;
    if (!dim_text_on_block(s, block, text_x, text_y)) continue;
    if (hmap_get(&s->claimed_dimension_blocks, (uint64_t)block + 1u,
                 0xFFFFFFFFu) != 0xFFFFFFFFu) {
      continue;
    }
    if (!hmap_put(&s->claimed_dimension_blocks, (uint64_t)block + 1u,
                  candidates[i])) {
      return 0;
    }
  }
  return 1;
}

static int dim_text_on_block(const import_state *s, uint32_t block, double x,
                             double y) {
  const box *b;
  if (block >= s->block_count || !s->block_member_box) return 0;
  b = &s->block_member_box[block];
  if (!b->seen) return 0;
  /* Measurement MTEXT sits just outside the ticks. */
  {
    double px = (b->max_x - b->min_x) * 0.1 + 1.0;
    double py = (b->max_y - b->min_y) * 0.1 + 1.0;
    return x >= b->min_x - px && x <= b->max_x + px &&
           y >= b->min_y - py && y <= b->max_y + py;
  }
}

static int is_structural_entity(Dwg_Object_Type type) {
  return type == DWG_TYPE_VERTEX_2D || type == DWG_TYPE_VERTEX_3D ||
         type == DWG_TYPE_VERTEX_MESH || type == DWG_TYPE_VERTEX_PFACE ||
         type == DWG_TYPE_VERTEX_PFACE_FACE || type == DWG_TYPE_SEQEND ||
         type == DWG_TYPE_ATTRIB || type == DWG_TYPE_BLOCK ||
         type == DWG_TYPE_ENDBLK || type == DWG_TYPE_VIEWPORT;
}

/* Collects block headers and assigns each one an index. Model space is placed
 * first so that a reader can start drawing before the whole table arrives. */
static int import_block_headers(import_state *s) {
  uint32_t i;
  uint32_t capacity = 0;
  uint32_t count = 0;
  Dwg_Object_Ref *model_ref;
  uint64_t model_handle;

  for (i = 0; i < s->dwg->num_objects; i++) {
    if (s->dwg->object[i].supertype == DWG_SUPERTYPE_OBJECT &&
        s->dwg->object[i].fixedtype == DWG_TYPE_BLOCK_HEADER) {
      capacity++;
    }
  }
  if (capacity == 0) capacity = 1;
  s->block_names = (char **)calloc(capacity, sizeof(char *));
  s->block_base_x = (double *)calloc(capacity, sizeof(double));
  s->block_base_y = (double *)calloc(capacity, sizeof(double));
  s->paper_space_block = 0xFFFFFFFFu;
  if (!s->block_names || !s->block_base_x || !s->block_base_y) return 0;

  model_ref = dwg_model_space_ref(s->dwg);
  model_handle = ref_handle(model_ref);

  /* Two passes so that model space lands at index 0. */
  for (int pass = 0; pass < 2; pass++) {
    for (i = 0; i < s->dwg->num_objects; i++) {
      Dwg_Object *obj = &s->dwg->object[i];
      Dwg_Object_BLOCK_HEADER *header;
      char *name;
      int owned;
      int is_model;

      if (obj->supertype != DWG_SUPERTYPE_OBJECT) continue;
      if (obj->fixedtype != DWG_TYPE_BLOCK_HEADER) continue;
      header = obj->tio.object->tio.BLOCK_HEADER;
      if (!header) continue;

      is_model = (model_handle != 0 &&
                  (uint64_t)obj->handle.value == model_handle);
      if ((pass == 0) != (is_model != 0)) continue;
      if (count >= capacity) continue;

      name = dyn_text(header, "BLOCK_HEADER", "name", &owned);
      s->block_names[count] = unique_block_name(
          s, count, name && *name ? name : "*Unnamed",
          (uint64_t)obj->handle.value);
      s->block_base_x[count] = header->base_pt.x;
      s->block_base_y[count] = header->base_pt.y;
      if (is_model) s->model_space_block = count;
      if (s->block_names[count] &&
          strcmp(s->block_names[count], "*Paper_Space") == 0) {
        s->paper_space_block = count;
      }
      hmap_put(&s->block_index, (uint64_t)obj->handle.value, count);
      count++;
      dyn_text_free(name, owned);
    }
  }
  s->block_count = count;
  return 1;
}

/* -------------------------------------------------------------------------
 * Entity extraction
 * ------------------------------------------------------------------------- */

/* First object keeps the DWG handle. A later non-POINT row on that
 * handle gets a synthetic id so both rows can exist. */
static uint64_t uniquify_entity_id(import_state *s, uint64_t handle) {
  if (handle != 0 && hmap_get(&s->used_entity_ids, handle, 0) == 0) {
    if (hmap_put(&s->used_entity_ids, handle, 1)) return handle;
  }
  for (;;) {
    uint64_t alt = (1ull << 40) + (uint64_t)++s->synthetic_seq;
    if (hmap_get(&s->used_entity_ids, alt, 0) != 0) continue;
    if (hmap_put(&s->used_entity_ids, alt, 1)) return alt;
    return handle != 0 ? handle : alt;
  }
}

/* Fills the common part of an entity record. */
static void fill_common(import_state *s, const Dwg_Object *obj,
                        fcb_entity *out) {
  const Dwg_Object_Entity *ent = obj->tio.entity;
  memset(out, 0, sizeof(*out));
  out->handle = uniquify_entity_id(s, (uint64_t)obj->handle.value);
  out->layer_index = hmap_get(&s->layer_index, ref_handle(ent->layer), 0);
  out->color_packed = convert_color(&ent->color);
  out->linetype_index = 0xFFFFFFFFu; /* ByLayer */
  if (ent->ltype) {
    uint32_t found =
        hmap_get(&s->linetype_index, ref_handle(ent->ltype), 0xFFFFFFFFu);
    out->linetype_index = found;
  }
  out->line_weight = (int32_t)(int8_t)ent->linewt;
  if (ent->invisible) out->flags |= FCB_FLAG_INVISIBLE;

  if (ent->ltype_scale != 1.0) {
    double props[3];
    props[0] = 0.0;              /* elevation, filled per type below */
    props[1] = ent->ltype_scale;
    props[2] = -1.0;             /* transparency inherits from the layer */
    out->props_offset = (uint32_t)fcb_add_doubles(s->b, props, 3);
    out->flags |= FCB_FLAG_HAS_EXTENDED_PROPS;
  }
}

static void commit(import_state *s, fcb_entity *e, const box *bounds,
                   uint32_t owner_block, uint16_t type) {
  e->type = type;
  e->owner_block_index = owner_block;
  if (bounds && bounds->seen) {
    e->min_x = bounds->min_x;
    e->min_y = bounds->min_y;
    e->max_x = bounds->max_x;
    e->max_y = bounds->max_y;
  }
  fcb_add_entity(s->b, e);
}

/* Pushes the staged coordinates into the double pool and records the range. */
static void attach_geometry(import_state *s, fcb_entity *e) {
  e->geom_offset = fcb_add_doubles(s->b, s->staging.data, s->staging.length);
  e->geom_count = s->staging.length;
}

static void note_proxy(import_state *s, const char *name) {
  uint32_t i;
  s->skipped++;
  if (!name || !name[0]) name = "UNKNOWN";
  for (i = 0; i < s->proxy_tally_count; i++) {
    if (strcmp(s->proxies[i].name, name) == 0) {
      s->proxies[i].count++;
      return;
    }
  }
  if (s->proxy_tally_count >= 16) return;
  strncpy(s->proxies[s->proxy_tally_count].name, name, 31);
  s->proxies[s->proxy_tally_count].name[31] = '\0';
  s->proxies[s->proxy_tally_count].count = 1;
  s->proxy_tally_count++;
}

static int push_one_polyline_vertex(coords *g, box *bounds,
                                    Dwg_Object *vertex_obj) {
  if (!vertex_obj || vertex_obj->supertype != DWG_SUPERTYPE_ENTITY ||
      !vertex_obj->tio.entity) {
    return 0;
  }
  if (vertex_obj->fixedtype == DWG_TYPE_VERTEX_2D &&
      vertex_obj->tio.entity->tio.VERTEX_2D) {
    Dwg_Entity_VERTEX_2D *v = vertex_obj->tio.entity->tio.VERTEX_2D;
    coords_push2(g, v->point.x, v->point.y);
    coords_push(g, v->bulge);
    box_add(bounds, v->point.x, v->point.y);
    return 1;
  }
  if ((vertex_obj->fixedtype == DWG_TYPE_VERTEX_3D ||
       vertex_obj->fixedtype == DWG_TYPE_VERTEX_MESH) &&
      vertex_obj->tio.entity->tio.VERTEX_3D) {
    Dwg_Entity_VERTEX_3D *v = vertex_obj->tio.entity->tio.VERTEX_3D;
    coords_push2(g, v->point.x, v->point.y);
    coords_push(g, 0.0);
    box_add(bounds, v->point.x, v->point.y);
    return 1;
  }
  return 0;
}

/* R2004 POLYLINE_2D often leaves vertex[] unresolved (relative handles).
 * first_vertex → SEQEND is the same chain BLOCK_HEADER.entities uses. */
static int push_owned_polyline_vertices(import_state *s, const Dwg_Object *from,
                                        coords *g, box *bounds,
                                        Dwg_Entity_POLYLINE_2D *o) {
  uint32_t written = 0;
  BITCODE_BL i;
  if (!o) return 0;
  for (i = 0; i < o->num_owned; i++) {
    if (!o->vertex || !o->vertex[i]) continue;
    written += (uint32_t)push_one_polyline_vertex(
        g, bounds, resolve_ref(s->dwg, o->vertex[i], from));
  }
  if (written == 0 && o->first_vertex) {
    Dwg_Object *child = resolve_ref(s->dwg, o->first_vertex, from);
    Dwg_Object *last = resolve_ref(s->dwg, o->last_vertex, from);
    uint32_t guard = 0;
    while (child && guard++ < 100000) {
      if (child->fixedtype == DWG_TYPE_SEQEND) break;
      written += (uint32_t)push_one_polyline_vertex(g, bounds, child);
      if (child == last) break;
      child = dwg_next_entity(child);
    }
  }
  return (int)written;
}

static int points_close(double ax, double ay, double bx, double by) {
  double dx = ax - bx;
  double dy = ay - by;
  return dx * dx + dy * dy < 1e-20;
}

static int import_multileader(import_state *s, Dwg_Entity_MULTILEADER *o,
                              fcb_entity *e, box *bounds) {
  Dwg_MLEADER_AnnotContext *ctx;
  int64_t path_counts[64];
  uint32_t path_count = 0;
  uint32_t n;
  char *text = NULL;
  int owned_text = 0;
  double text_x = 0.0;
  double text_y = 0.0;
  double text_h;
  double text_rot = 0.0;
  coords *g = &s->staging;

  if (!o) return 0;
  ctx = &o->ctx;
  text_h = ctx->text_height > 0.0 ? ctx->text_height : 2.5;

  for (n = 0; n < ctx->num_leaders && path_count < 64; n++) {
    Dwg_LEADER_Node *node = &ctx->leaders[n];
    uint32_t line;
    if (!ctx->leaders) break;
    for (line = 0; line < node->num_lines && path_count < 64; line++) {
      Dwg_LEADER_Line *ln = &node->lines[line];
      uint32_t p;
      uint32_t start = g->length;
      uint32_t points;
      if (!node->lines) break;
      for (p = 0; p < ln->num_points; p++) {
        if (!ln->points) break;
        coords_push2(g, ln->points[p].x, ln->points[p].y);
        box_add(bounds, ln->points[p].x, ln->points[p].y);
      }
      if (node->has_lastleaderlinepoint) {
        double lx = node->lastleaderlinepoint.x;
        double ly = node->lastleaderlinepoint.y;
        if (g->length < start + 2 ||
            !points_close(g->data[g->length - 2], g->data[g->length - 1], lx,
                          ly)) {
          coords_push2(g, lx, ly);
          box_add(bounds, lx, ly);
        }
        if (node->has_dogleg && node->dogleg_length != 0.0) {
          double hx = lx + node->dogleg_vector.x * node->dogleg_length;
          double hy = ly + node->dogleg_vector.y * node->dogleg_length;
          coords_push2(g, hx, hy);
          box_add(bounds, hx, hy);
        }
      }
      points = (g->length - start) / 2;
      if (points >= 2) {
        path_counts[path_count++] = (int64_t)points;
      } else {
        g->length = start;
      }
    }
  }

  if (ctx->has_content_txt) {
    char *raw = ctx->content.txt.default_text;
    char *converted;
    text_x = ctx->content.txt.location.x;
    text_y = ctx->content.txt.location.y;
    if (ctx->content.txt.height > 0.0) text_h = ctx->content.txt.height;
    text_rot = ctx->content.txt.rotation;
    converted = raw ? tv_to_utf8(raw, entity_codepage(o)) : NULL;
    if (converted) {
      text = converted;
      owned_text = 1;
    } else {
      text = raw;
    }
    box_add(bounds, text_x, text_y);
  } else {
    text_x = ctx->content_base.x;
    text_y = ctx->content_base.y;
    box_add(bounds, text_x, text_y);
  }

  coords_push2(g, text_x, text_y);
  coords_push(g, text_h);
  coords_push(g, text_rot);

  if (path_count > 0) {
    e->int_offset = fcb_add_ints(s->b, path_counts, path_count);
    e->int_count = path_count;
  }
  e->string_offset = fcb_append_string(s->b, text ? text : "");
  fcb_append_string(s->b, "Standard");
  e->string_count = 2;
  e->flags |= FCB_FLAG_ARROW_HEAD;
  attach_geometry(s, e);
  dyn_text_free(text, owned_text);
  return path_count > 0 || (text && text[0]);
}

static uint32_t append_solid_wires(coords *g, box *bounds, int64_t *runs,
                                   uint32_t run_cap, uint32_t run_count,
                                   Dwg_3DSOLID_wire *wires,
                                   BITCODE_BL num_wires) {
  BITCODE_BL w;
  if (!wires) return run_count;
  for (w = 0; w < num_wires && run_count < run_cap; w++) {
    Dwg_3DSOLID_wire *wire = &wires[w];
    BITCODE_BL p;
    uint32_t start = g->length;
    uint32_t points;
    if (!wire->points) continue;
    for (p = 0; p < wire->num_points; p++) {
      coords_push2(g, wire->points[p].x, wire->points[p].y);
      box_add(bounds, wire->points[p].x, wire->points[p].y);
    }
    points = (g->length - start) / 2;
    if (points >= 2) {
      runs[run_count++] = (int64_t)points;
    } else {
      g->length = start;
    }
  }
  return run_count;
}

/* Isolines first; silhouettes when the viewport cache is what LibreDWG kept.
 * The wireframe_data_present flag is often 0 on R2004 REGIONs that still
 * have a decoded wire array. */
static uint32_t extract_acis_wires(coords *g, box *bounds, int64_t *runs,
                                   uint32_t run_cap, Dwg_Entity__3DSOLID *solid) {
  uint32_t run_count = 0;
  BITCODE_BL s;
  if (!solid) return 0;
  run_count = append_solid_wires(g, bounds, runs, run_cap, 0, solid->wires,
                                 solid->num_wires);
  if (!solid->silhouettes) return run_count;
  for (s = 0; s < solid->num_silhouettes && run_count < run_cap; s++) {
    Dwg_3DSOLID_silhouette *sil = &solid->silhouettes[s];
    if (!sil->wires) continue;
    run_count = append_solid_wires(g, bounds, runs, run_cap, run_count,
                                   sil->wires, sil->num_wires);
  }
  return run_count;
}

/* SAB v2 ("ACIS BinaryFile") has no isolines on this R2004 file. LibreDWG
 * can rewrite it as SAT v1 text in encr_sat_data[]; `point … x y z` is then
 * enough to keep a REGION on the canvas. */
static char *solid_sat_text(Dwg_Entity__3DSOLID *solid) {
  size_t total = 0;
  BITCODE_BL i;
  char *out;
  char *dst;
  if (!solid) return NULL;
  if (solid->acis_data &&
      strncmp((const char *)solid->acis_data, "ACIS Binary", 11) == 0 &&
      !solid->_dxf_sab_converted) {
    dwg_convert_SAB_to_SAT1(solid);
  }
  if (solid->acis_data && solid->acis_data[0] &&
      strncmp((const char *)solid->acis_data, "ACIS Binary", 11) != 0) {
    size_t n = strlen((const char *)solid->acis_data);
    out = (char *)malloc(n + 1);
    if (!out) return NULL;
    memcpy(out, solid->acis_data, n + 1);
    return out;
  }
  if (!solid->encr_sat_data || !solid->block_size) return NULL;
  for (i = 0; i < solid->num_blocks; i++) {
    if (solid->encr_sat_data[i]) total += solid->block_size[i];
  }
  if (total == 0) return NULL;
  out = (char *)malloc(total + 1);
  if (!out) return NULL;
  dst = out;
  for (i = 0; i < solid->num_blocks; i++) {
    if (!solid->encr_sat_data[i]) continue;
    memcpy(dst, solid->encr_sat_data[i], solid->block_size[i]);
    dst += solid->block_size[i];
  }
  *dst = '\0';
  return out;
}

static uint32_t extract_sat_points(coords *g, box *bounds, int64_t *runs,
                                   uint32_t run_cap,
                                   Dwg_Entity__3DSOLID *solid) {
  char *sat;
  const char *p;
  uint32_t start;
  uint32_t n = 0;
  if (run_cap == 0 || !solid) return 0;
  sat = solid_sat_text(solid);
  if (!sat || sat[0] == '\0') {
    free(sat);
    return 0;
  }
  p = sat;
  start = g->length;
  while (*p) {
      if (strncmp(p, "point ", 6) == 0 &&
        (p == sat || p[-1] == '\n' || p[-1] == '\r' || p[-1] == ' ' ||
         p[-1] == '\t')) {
      const char *q = p + 6;
      double nums[16];
      int count = 0;
      while (count < 16) {
        char *end = NULL;
        double value;
        while (*q == ' ' || *q == '\t' || *q == '\n' || *q == '\r') q++;
        if (*q == '$') {
          q++;
          if (*q == '-') q++;
          while (*q >= '0' && *q <= '9') q++;
          continue;
        }
        if (*q != '-' && *q != '.' && (*q < '0' || *q > '9')) break;
        value = strtod(q, &end);
        if (end == q) break;
        nums[count++] = value;
        q = end;
      }
      if (count >= 3) {
        double x = nums[count - 3];
        double y = nums[count - 2];
        if (isfinite(x) && isfinite(y)) {
          coords_push2(g, x, y);
          box_add(bounds, x, y);
          n++;
        }
      }
      p = q;
      continue;
    }
    p++;
  }
  free(sat);
  if (n >= 2) {
    runs[0] = (int64_t)n;
    return 1;
  }
  g->length = start;
  return 0;
}

static void import_hatch_paths(import_state *s, Dwg_Entity_HATCH *hatch,
                               coords *out, int64_t *ints,
                               uint32_t *int_count) {
  uint32_t path;
  uint32_t loops = 0;

  for (path = 0; path < hatch->num_paths; path++) {
    Dwg_HATCH_Path *p = &hatch->paths[path];
    uint32_t point_count = 0;
    uint32_t start = out->length;
    int is_outer = (p->flag & 0x1) == 0 ? 1 : 1; /* outermost bit varies */

    if (p->flag & 0x2) {
      /* Polyline boundary: points are stored directly. */
      uint32_t v;
      for (v = 0; v < p->num_segs_or_paths; v++) {
        if (!p->polyline_paths) break;
        coords_push2(out, p->polyline_paths[v].point.x,
                     p->polyline_paths[v].point.y);
        point_count++;
      }
    } else {
      /* Edge boundary. Straight edges are exact; curved edges are reduced to
       * their chord for now, which keeps the region selectable and filled
       * while the exact tessellation is still to come. */
      uint32_t seg;
      for (seg = 0; seg < p->num_segs_or_paths; seg++) {
        Dwg_HATCH_PathSeg *e;
        if (!p->segs) break;
        e = &p->segs[seg];
        if (e->curve_type == 1) {
          if (point_count == 0) {
            coords_push2(out, e->first_endpoint.x, e->first_endpoint.y);
            point_count++;
          }
          coords_push2(out, e->second_endpoint.x, e->second_endpoint.y);
          point_count++;
        } else {
          s->unsupported_hatch_segments++;
          if (e->curve_type == 2) {
            /* Circular arc: emit start and end so the loop stays closed. */
            double cx = e->center.x;
            double cy = e->center.y;
            double r = e->radius;
            coords_push2(out, cx + r * cos(e->start_angle),
                         cy + r * sin(e->start_angle));
            coords_push2(out, cx + r * cos(e->end_angle),
                         cy + r * sin(e->end_angle));
            point_count += 2;
          }
        }
      }
    }

    if (point_count == 0) {
      out->length = start;
      continue;
    }
    ints[1 + loops * 2] = is_outer;
    ints[1 + loops * 2 + 1] = (int64_t)point_count;
    loops++;
  }
  ints[0] = (int64_t)loops;
  *int_count = 1 + loops * 2;
}

static void append_one_attrib(import_state *s, Dwg_Object *ao,
                              uint32_t *string_count) {
  Dwg_Entity_ATTRIB *a;
  char *tag;
  char *value;
  int owned_tag = 0;
  int owned_value = 0;
  if (!ao || ao->fixedtype != DWG_TYPE_ATTRIB || !ao->tio.entity) return;
  a = ao->tio.entity->tio.ATTRIB;
  if (!a) return;
  tag = dyn_text(a, "ATTRIB", "tag", &owned_tag);
  value = dyn_text(a, "ATTRIB", "text_value", &owned_value);
  fcb_append_string(s->b, tag ? tag : "");
  fcb_append_string(s->b, value ? value : "");
  *string_count += 2;
  dyn_text_free(tag, owned_tag);
  dyn_text_free(value, owned_value);
}

static void append_insert_attribs(import_state *s, Dwg_Object_Ref **refs,
                                  BITCODE_BL count, Dwg_Object_Ref *first,
                                  uint32_t *string_count) {
  BITCODE_BL i;
  if (refs && count) {
    for (i = 0; i < count; i++) {
      append_one_attrib(s, refs[i] ? dwg_ref_object(s->dwg, refs[i]) : NULL,
                        string_count);
    }
    return;
  }
  if (first) {
    Dwg_Object *ao = dwg_ref_object(s->dwg, first);
    while (ao && ao->fixedtype == DWG_TYPE_ATTRIB) {
      append_one_attrib(s, ao, string_count);
      ao = dwg_next_entity(ao);
    }
  }
}

/* Same arbitrary axis as Dart `Mat3.ocs` / `Mat3.ocsInsert`. Document
 * coordinates stay WCS; this bakes OCS at the import boundary. */
static void apply_ocs_insert(double nx, double ny, double nz, double *ins_x,
                             double *ins_y, double *scale_x, double *scale_y,
                             double *rotation) {
  double len, inv, axx, axy, axz, ax_x, ax_y, ax_z, ay_x, ay_y;
  double oa, ob, oc, od;
  double ca, sa, a, b, c, d, e, f;
  double rot, cr, sr;
  len = sqrt(nx * nx + ny * ny + nz * nz);
  if (len < 1e-20) {
    nx = 0.0;
    ny = 0.0;
    nz = 1.0;
  } else {
    nx /= len;
    ny /= len;
    nz /= len;
  }
  if (fabs(nx) < (1.0 / 64.0) && fabs(ny) < (1.0 / 64.0)) {
    axx = nz;
    axy = 0.0;
    axz = -nx;
  } else {
    axx = -ny;
    axy = nx;
    axz = 0.0;
  }
  len = sqrt(axx * axx + axy * axy + axz * axz);
  inv = len < 1e-20 ? 1.0 : 1.0 / len;
  ax_x = axx * inv;
  ax_y = axy * inv;
  ax_z = axz * inv;
  ay_x = ny * ax_z - nz * ax_y;
  ay_y = nz * ax_x - nx * ax_z;
  oa = ax_x;
  ob = ax_y;
  oc = ay_x;
  od = ay_y;
  if (oa == 1.0 && ob == 0.0 && oc == 0.0 && od == 1.0) return;

  ca = cos(*rotation);
  sa = sin(*rotation);
  /* T * R * S, then ocs * that. */
  a = ca * *scale_x;
  b = sa * *scale_x;
  c = -sa * *scale_y;
  d = ca * *scale_y;
  e = *ins_x;
  f = *ins_y;
  {
    double a2 = oa * a + oc * b;
    double b2 = ob * a + od * b;
    double c2 = oa * c + oc * d;
    double d2 = ob * c + od * d;
    double e2 = oa * e + oc * f;
    double f2 = ob * e + od * f;
    a = a2;
    b = b2;
    c = c2;
    d = d2;
    e = e2;
    f = f2;
  }
  rot = atan2(b, a);
  cr = cos(rot);
  sr = sin(rot);
  *ins_x = e;
  *ins_y = f;
  *scale_x = a * cr + b * sr;
  *scale_y = -c * sr + d * cr;
  *rotation = rot;
}

/* Translates one entity. Returns non-zero when a record was written. */
static int import_entity(import_state *s, const Dwg_Object *obj,
                         uint32_t owner_block) {
  const Dwg_Object_Entity *ent = obj->tio.entity;
  fcb_entity e;
  box bounds;
  coords *g = &s->staging;

  if (!ent) return 0;
  fill_common(s, obj, &e);
  box_init(&bounds);
  coords_reset(g);

  switch (obj->fixedtype) {
    case DWG_TYPE_LINE: {
      Dwg_Entity_LINE *o = ent->tio.LINE;
      if (!o) return 0;
      coords_push2(g, o->start.x, o->start.y);
      coords_push2(g, o->end.x, o->end.y);
      box_add_coords(&bounds, g, 2);
      attach_geometry(s, &e);
      commit(s, &e, &bounds, owner_block, FCB_TYPE_LINE);
      return 1;
    }

    case DWG_TYPE_POINT: {
      Dwg_Entity_POINT *o = ent->tio.POINT;
      if (!o) return 0;
      coords_push2(g, o->x, o->y);
      box_add(&bounds, o->x, o->y);
      attach_geometry(s, &e);
      commit(s, &e, &bounds, owner_block, FCB_TYPE_POINT);
      return 1;
    }

    case DWG_TYPE_CIRCLE: {
      Dwg_Entity_CIRCLE *o = ent->tio.CIRCLE;
      if (!o) return 0;
      coords_push2(g, o->center.x, o->center.y);
      coords_push(g, o->radius);
      box_add(&bounds, o->center.x - o->radius, o->center.y - o->radius);
      box_add(&bounds, o->center.x + o->radius, o->center.y + o->radius);
      attach_geometry(s, &e);
      commit(s, &e, &bounds, owner_block, FCB_TYPE_CIRCLE);
      return 1;
    }

    case DWG_TYPE_ARC: {
      Dwg_Entity_ARC *o = ent->tio.ARC;
      if (!o) return 0;
      coords_push2(g, o->center.x, o->center.y);
      coords_push(g, o->radius);
      coords_push(g, o->start_angle);
      coords_push(g, o->end_angle);
      /* A conservative box; Dart recomputes the exact one when indexing. */
      box_add(&bounds, o->center.x - o->radius, o->center.y - o->radius);
      box_add(&bounds, o->center.x + o->radius, o->center.y + o->radius);
      attach_geometry(s, &e);
      commit(s, &e, &bounds, owner_block, FCB_TYPE_ARC);
      return 1;
    }

    case DWG_TYPE_ELLIPSE: {
      Dwg_Entity_ELLIPSE *o = ent->tio.ELLIPSE;
      double reach;
      if (!o) return 0;
      coords_push2(g, o->center.x, o->center.y);
      coords_push2(g, o->sm_axis.x, o->sm_axis.y);
      coords_push(g, o->axis_ratio);
      coords_push(g, o->start_angle);
      coords_push(g, o->end_angle);
      reach = sqrt(o->sm_axis.x * o->sm_axis.x + o->sm_axis.y * o->sm_axis.y);
      box_add(&bounds, o->center.x - reach, o->center.y - reach);
      box_add(&bounds, o->center.x + reach, o->center.y + reach);
      attach_geometry(s, &e);
      commit(s, &e, &bounds, owner_block, FCB_TYPE_ELLIPSE);
      return 1;
    }

    case DWG_TYPE_LWPOLYLINE: {
      Dwg_Entity_LWPOLYLINE *o = ent->tio.LWPOLYLINE;
      uint32_t i;
      if (!o || !o->points) return 0;
      for (i = 0; i < o->num_points; i++) {
        coords_push2(g, o->points[i].x, o->points[i].y);
        coords_push(g, (o->bulges && i < o->num_bulges) ? o->bulges[i] : 0.0);
        box_add(&bounds, o->points[i].x, o->points[i].y);
      }
      if (o->flag & 512) e.flags |= FCB_FLAG_CLOSED;
      attach_geometry(s, &e);
      commit(s, &e, &bounds, owner_block, FCB_TYPE_POLYLINE);
      return 1;
    }

    case DWG_TYPE_POLYLINE_2D:
    case DWG_TYPE_POLYLINE_3D:
    case DWG_TYPE_POLYLINE_MESH:
    case DWG_TYPE_POLYLINE_PFACE: {
      Dwg_Entity_POLYLINE_2D *o = ent->tio.POLYLINE_2D;
      uint32_t written;
      BITCODE_BS flag = 0;
      if (!o) return 0;
      written = (uint32_t)push_owned_polyline_vertices(s, obj, g, &bounds, o);
      if (written == 0) {
        /* A 2D polyline with no resolved VERTEX would otherwise vanish,
         * which is how J18's 板2 开槽示意图 lost its white outline. */
        note_proxy(s, obj->dxfname ? obj->dxfname : "POLYLINE");
        return 0;
      }
      if (obj->fixedtype == DWG_TYPE_POLYLINE_2D) flag = o->flag;
      else if (obj->fixedtype == DWG_TYPE_POLYLINE_3D && ent->tio.POLYLINE_3D)
        flag = ent->tio.POLYLINE_3D->flag;
      else if (obj->fixedtype == DWG_TYPE_POLYLINE_MESH &&
               ent->tio.POLYLINE_MESH)
        flag = ent->tio.POLYLINE_MESH->flag;
      else if (obj->fixedtype == DWG_TYPE_POLYLINE_PFACE &&
               ent->tio.POLYLINE_PFACE)
        flag = ent->tio.POLYLINE_PFACE->flag;
      if (flag & 1) e.flags |= FCB_FLAG_CLOSED;
      attach_geometry(s, &e);
      commit(s, &e, &bounds, owner_block, FCB_TYPE_POLYLINE);
      return 1;
    }

    case DWG_TYPE_SPLINE: {
      Dwg_Entity_SPLINE *o = ent->tio.SPLINE;
      int64_t ints[5];
      uint32_t i;
      if (!o) return 0;
      ints[0] = (int64_t)o->degree;
      ints[1] = (int64_t)o->num_knots;
      ints[2] = (int64_t)o->num_ctrl_pts;
      ints[3] = o->weighted ? (int64_t)o->num_ctrl_pts : 0;
      ints[4] = (int64_t)o->num_fit_pts;
      for (i = 0; i < o->num_knots; i++) {
        coords_push(g, o->knots ? o->knots[i] : 0.0);
      }
      for (i = 0; i < o->num_ctrl_pts; i++) {
        if (!o->ctrl_pts) break;
        coords_push2(g, o->ctrl_pts[i].x, o->ctrl_pts[i].y);
        box_add(&bounds, o->ctrl_pts[i].x, o->ctrl_pts[i].y);
      }
      if (o->weighted) {
        for (i = 0; i < o->num_ctrl_pts; i++) {
          coords_push(g, o->ctrl_pts ? o->ctrl_pts[i].w : 1.0);
        }
      }
      for (i = 0; i < o->num_fit_pts; i++) {
        if (!o->fit_pts) break;
        coords_push2(g, o->fit_pts[i].x, o->fit_pts[i].y);
        box_add(&bounds, o->fit_pts[i].x, o->fit_pts[i].y);
      }
      if (o->closed_b) e.flags |= FCB_FLAG_CLOSED;
      e.int_offset = fcb_add_ints(s->b, ints, 5);
      e.int_count = 5;
      attach_geometry(s, &e);
      commit(s, &e, &bounds, owner_block, FCB_TYPE_SPLINE);
      return 1;
    }

    case DWG_TYPE_TEXT: {
      Dwg_Entity_TEXT *o = ent->tio.TEXT;
      int64_t ints[2];
      char *value;
      char *style_name = NULL;
      int owned_value;
      int owned_style = 0;
      Dwg_Object_Ref *style_ref;
      if (!o) return 0;
      value = dyn_text(o, "TEXT", "text_value", &owned_value);
      style_ref = o->style;
      if (style_ref && style_ref->obj &&
          style_ref->obj->supertype == DWG_SUPERTYPE_OBJECT &&
          style_ref->obj->tio.object->tio.STYLE) {
        style_name = dyn_text(style_ref->obj->tio.object->tio.STYLE, "STYLE",
                              "name", &owned_style);
      }
      coords_push2(g, o->ins_pt.x, o->ins_pt.y);
      box_add(&bounds, o->ins_pt.x, o->ins_pt.y);
      coords_push(g, o->height);
      coords_push(g, o->rotation);
      coords_push(g, o->width_factor == 0.0 ? 1.0 : o->width_factor);
      coords_push(g, o->oblique_angle);
      /* Justified TEXT paints from alignment_pt, not the first corner. */
      if (o->horiz_alignment != 0 || o->vert_alignment != 0) {
        coords_push2(g, o->alignment_pt.x, o->alignment_pt.y);
        box_add(&bounds, o->alignment_pt.x, o->alignment_pt.y);
      }
      ints[0] = (int64_t)o->horiz_alignment;
      ints[1] = (int64_t)o->vert_alignment;
      e.int_offset = fcb_add_ints(s->b, ints, 2);
      e.int_count = 2;
      e.string_offset = fcb_append_string(s->b, value ? value : "");
      fcb_append_string(s->b, style_name ? style_name : "Standard");
      e.string_count = 2;
      attach_geometry(s, &e);
      commit(s, &e, &bounds, owner_block, FCB_TYPE_TEXT);
      dyn_text_free(value, owned_value);
      dyn_text_free(style_name, owned_style);
      return 1;
    }

    case DWG_TYPE_ATTDEF: {
      Dwg_Entity_ATTDEF *o = ent->tio.ATTDEF;
      int64_t ints[3];
      char *value;
      char *tag;
      char *prompt;
      char *style_name = NULL;
      int owned_value;
      int owned_tag;
      int owned_prompt;
      int owned_style = 0;
      Dwg_Object_Ref *style_ref;
      if (!o) return 0;
      value = dyn_text(o, "ATTDEF", "default_value", &owned_value);
      tag = dyn_text(o, "ATTDEF", "tag", &owned_tag);
      prompt = dyn_text(o, "ATTDEF", "prompt", &owned_prompt);
      style_ref = o->style;
      if (style_ref && style_ref->obj &&
          style_ref->obj->supertype == DWG_SUPERTYPE_OBJECT &&
          style_ref->obj->tio.object->tio.STYLE) {
        style_name = dyn_text(style_ref->obj->tio.object->tio.STYLE, "STYLE",
                              "name", &owned_style);
      }
      coords_push2(g, o->ins_pt.x, o->ins_pt.y);
      box_add(&bounds, o->ins_pt.x, o->ins_pt.y);
      coords_push(g, o->height);
      coords_push(g, o->rotation);
      coords_push(g, o->width_factor == 0.0 ? 1.0 : o->width_factor);
      coords_push(g, o->oblique_angle);
      if (o->horiz_alignment != 0 || o->vert_alignment != 0) {
        coords_push2(g, o->alignment_pt.x, o->alignment_pt.y);
        box_add(&bounds, o->alignment_pt.x, o->alignment_pt.y);
      }
      ints[0] = (int64_t)o->horiz_alignment;
      ints[1] = (int64_t)o->vert_alignment;
      ints[2] = (int64_t)o->flags;
      e.int_offset = fcb_add_ints(s->b, ints, 3);
      e.int_count = 3;
      e.string_offset = fcb_append_string(s->b, value ? value : "");
      fcb_append_string(s->b, style_name ? style_name : "Standard");
      fcb_append_string(s->b, tag ? tag : "");
      fcb_append_string(s->b, prompt ? prompt : "");
      e.string_count = 4;
      attach_geometry(s, &e);
      commit(s, &e, &bounds, owner_block, FCB_TYPE_ATTDEF);
      dyn_text_free(value, owned_value);
      dyn_text_free(tag, owned_tag);
      dyn_text_free(prompt, owned_prompt);
      dyn_text_free(style_name, owned_style);
      return 1;
    }

    case DWG_TYPE_MTEXT: {
      Dwg_Entity_MTEXT *o = ent->tio.MTEXT;
      int64_t attachment;
      char *value;
      int owned_value;
      double rotation;
      if (!o) return 0;
      value = dyn_text(o, "MTEXT", "text", &owned_value);
      /* MTEXT stores a direction vector rather than an angle. */
      rotation = atan2(o->x_axis_dir.y, o->x_axis_dir.x);
      coords_push2(g, o->ins_pt.x, o->ins_pt.y);
      coords_push(g, o->text_height);
      coords_push(g, rotation);
      coords_push(g, o->rect_width);
      attachment = (int64_t)o->attachment;
      box_add(&bounds, o->ins_pt.x, o->ins_pt.y);
      e.int_offset = fcb_add_ints(s->b, &attachment, 1);
      e.int_count = 1;
      e.string_offset = fcb_append_string(s->b, value ? value : "");
      fcb_append_string(s->b, "Standard");
      e.string_count = 2;
      attach_geometry(s, &e);
      commit(s, &e, &bounds, owner_block, FCB_TYPE_MTEXT);
      dyn_text_free(value, owned_value);
      return 1;
    }

    case DWG_TYPE_INSERT:
    case DWG_TYPE_MINSERT: {
      const char *type_name =
          obj->fixedtype == DWG_TYPE_MINSERT ? "MINSERT" : "INSERT";
      void *o = obj->fixedtype == DWG_TYPE_MINSERT
                    ? (void *)ent->tio.MINSERT
                    : (void *)ent->tio.INSERT;
      Dwg_Object_Ref *block_ref;
      uint32_t block;
      int64_t ints[2];
      double ins_x, ins_y, scale_x, scale_y, rotation;
      if (!o) return 0;

      block_ref = dyn_handle(o, type_name, "block_header");
      block = hmap_get(&s->block_index, ref_handle(block_ref), 0xFFFFFFFFu);
      if (block == 0xFFFFFFFFu || block >= s->block_count) {
        s->skipped++;
        return 0;
      }

      if (obj->fixedtype == DWG_TYPE_MINSERT) {
        Dwg_Entity_MINSERT *m = ent->tio.MINSERT;
        ins_x = m->ins_pt.x;
        ins_y = m->ins_pt.y;
        scale_x = m->scale.x == 0.0 ? 1.0 : m->scale.x;
        scale_y = m->scale.y == 0.0 ? 1.0 : m->scale.y;
        rotation = m->rotation;
        apply_ocs_insert(m->extrusion.x, m->extrusion.y, m->extrusion.z,
                         &ins_x, &ins_y, &scale_x, &scale_y, &rotation);
        ints[0] = (int64_t)(m->num_cols ? m->num_cols : 1);
        ints[1] = (int64_t)(m->num_rows ? m->num_rows : 1);
        coords_push2(g, ins_x, ins_y);
        coords_push2(g, scale_x, scale_y);
        coords_push(g, rotation);
        coords_push(g, m->col_spacing);
        coords_push(g, m->row_spacing);
      } else {
        Dwg_Entity_INSERT *m = ent->tio.INSERT;
        ins_x = m->ins_pt.x;
        ins_y = m->ins_pt.y;
        scale_x = m->scale.x == 0.0 ? 1.0 : m->scale.x;
        scale_y = m->scale.y == 0.0 ? 1.0 : m->scale.y;
        rotation = m->rotation;
        apply_ocs_insert(m->extrusion.x, m->extrusion.y, m->extrusion.z,
                         &ins_x, &ins_y, &scale_x, &scale_y, &rotation);
        ints[0] = 1;
        ints[1] = 1;
        coords_push2(g, ins_x, ins_y);
        coords_push2(g, scale_x, scale_y);
        coords_push(g, rotation);
        coords_push(g, 0.0);
        coords_push(g, 0.0);
      }
      box_add(&bounds, ins_x, ins_y);
      e.int_offset = fcb_add_ints(s->b, ints, 2);
      e.int_count = 2;
      e.string_offset = fcb_append_string(s->b, s->block_names[block]);
      e.string_count = 1;
      if (obj->fixedtype == DWG_TYPE_MINSERT) {
        Dwg_Entity_MINSERT *m = ent->tio.MINSERT;
        append_insert_attribs(s, m->attribs, m->num_owned, m->first_attrib,
                              &e.string_count);
      } else {
        Dwg_Entity_INSERT *m = ent->tio.INSERT;
        append_insert_attribs(s, m->attribs, m->num_owned, m->first_attrib,
                              &e.string_count);
      }
      attach_geometry(s, &e);
      commit(s, &e, &bounds, owner_block, FCB_TYPE_INSERT);
      return 1;
    }

    case DWG_TYPE_HATCH: {
      Dwg_Entity_HATCH *o = ent->tio.HATCH;
      int64_t *ints;
      uint32_t int_count = 0;
      char *pattern;
      int owned_pattern;
      if (!o) return 0;
      ints = (int64_t *)calloc((size_t)o->num_paths * 2 + 2, sizeof(int64_t));
      if (!ints) return 0;

      coords_push(g, o->angle);
      coords_push(g, o->scale_spacing == 0.0 ? 1.0 : o->scale_spacing);
      import_hatch_paths(s, o, g, ints, &int_count);
      box_add_coords(&bounds, g, 2);

      pattern = dyn_text(o, "HATCH", "name", &owned_pattern);
      if (o->is_solid_fill) e.flags |= FCB_FLAG_SOLID_FILL;
      e.int_offset = fcb_add_ints(s->b, ints, int_count);
      e.int_count = int_count;
      e.string_offset = fcb_append_string(s->b, pattern ? pattern : "SOLID");
      e.string_count = 1;
      attach_geometry(s, &e);
      commit(s, &e, &bounds, owner_block, FCB_TYPE_HATCH);
      dyn_text_free(pattern, owned_pattern);
      free(ints);
      return 1;
    }

    case DWG_TYPE_LEADER: {
      Dwg_Entity_LEADER *o = ent->tio.LEADER;
      uint32_t i;
      if (!o || !o->points) return 0;
      for (i = 0; i < o->num_points; i++) {
        coords_push2(g, o->points[i].x, o->points[i].y);
        box_add(&bounds, o->points[i].x, o->points[i].y);
      }
      e.flags |= FCB_FLAG_ARROW_HEAD;
      e.string_offset = fcb_append_string(s->b, "Standard");
      e.string_count = 1;
      attach_geometry(s, &e);
      commit(s, &e, &bounds, owner_block, FCB_TYPE_LEADER);
      return 1;
    }

    case DWG_TYPE_SOLID:
    case DWG_TYPE_TRACE: {
      Dwg_Entity_SOLID *o = ent->tio.SOLID;
      if (!o) return 0;
      coords_push2(g, o->corner1.x, o->corner1.y);
      coords_push2(g, o->corner2.x, o->corner2.y);
      /* DWG stores the quadrilateral in a Z order: corners 3 and 4 are
       * swapped relative to a boundary walk. */
      coords_push2(g, o->corner4.x, o->corner4.y);
      coords_push2(g, o->corner3.x, o->corner3.y);
      box_add_coords(&bounds, g, 2);
      attach_geometry(s, &e);
      commit(s, &e, &bounds, owner_block, FCB_TYPE_SOLID);
      return 1;
    }

    case DWG_TYPE_RAY:
    case DWG_TYPE_XLINE: {
      Dwg_Entity_RAY *o = ent->tio.RAY;
      if (!o) return 0;
      coords_push2(g, o->point.x, o->point.y);
      coords_push2(g, o->vector.x, o->vector.y);
      box_add(&bounds, o->point.x, o->point.y);
      attach_geometry(s, &e);
      commit(s, &e, &bounds, owner_block,
             obj->fixedtype == DWG_TYPE_RAY ? FCB_TYPE_RAY : FCB_TYPE_XLINE);
      return 1;
    }

    case DWG_TYPE_IMAGE: {
      Dwg_Entity_IMAGE *o = ent->tio.IMAGE;
      if (!o) return 0;
      coords_push2(g, o->pt0.x, o->pt0.y);
      coords_push2(g, o->uvec.x * o->size.x, o->uvec.y * o->size.x);
      coords_push2(g, o->vvec.x * o->size.y, o->vvec.y * o->size.y);
      box_add_coords(&bounds, g, 2);
      e.string_offset = fcb_append_string(s->b, "");
      e.string_count = 1;
      attach_geometry(s, &e);
      commit(s, &e, &bounds, owner_block, FCB_TYPE_IMAGE);
      return 1;
    }

    case DWG_TYPE_MULTILEADER: {
      if (!import_multileader(s, ent->tio.MULTILEADER, &e, &bounds)) return 0;
      commit(s, &e, &bounds, owner_block, FCB_TYPE_MLEADER);
      return 1;
    }

    case DWG_TYPE__3DFACE: {
      Dwg_Entity__3DFACE *o = ent->tio._3DFACE;
      if (!o) return 0;
      coords_push2(g, o->corner1.x, o->corner1.y);
      coords_push2(g, o->corner2.x, o->corner2.y);
      coords_push2(g, o->corner3.x, o->corner3.y);
      if (!points_close(o->corner3.x, o->corner3.y, o->corner4.x,
                        o->corner4.y)) {
        coords_push2(g, o->corner4.x, o->corner4.y);
      }
      box_add_coords(&bounds, g, 2);
      attach_geometry(s, &e);
      commit(s, &e, &bounds, owner_block, FCB_TYPE_SOLID);
      return 1;
    }

    case DWG_TYPE_MLINE: {
      Dwg_Entity_MLINE *o = ent->tio.MLINE;
      uint32_t i;
      if (!o || !o->verts) return 0;
      for (i = 0; i < o->num_verts; i++) {
        coords_push2(g, o->verts[i].vertex.x, o->verts[i].vertex.y);
        coords_push(g, 0.0);
        box_add(&bounds, o->verts[i].vertex.x, o->verts[i].vertex.y);
      }
      if (g->length < 6) return 0;
      attach_geometry(s, &e);
      commit(s, &e, &bounds, owner_block, FCB_TYPE_POLYLINE);
      return 1;
    }

    case DWG_TYPE_WIPEOUT: {
      Dwg_Entity_WIPEOUT *o = ent->tio.WIPEOUT;
      uint32_t i;
      if (!o) return 0;
      if (o->clip_verts && o->num_clip_verts >= 2) {
        for (i = 0; i < o->num_clip_verts; i++) {
          coords_push2(g, o->clip_verts[i].x, o->clip_verts[i].y);
          coords_push(g, 0.0);
          box_add(&bounds, o->clip_verts[i].x, o->clip_verts[i].y);
        }
      } else {
        double ux = o->uvec.x * o->size.x;
        double uy = o->uvec.y * o->size.x;
        double vx = o->vvec.x * o->size.y;
        double vy = o->vvec.y * o->size.y;
        coords_push2(g, o->pt0.x, o->pt0.y);
        coords_push(g, 0.0);
        coords_push2(g, o->pt0.x + ux, o->pt0.y + uy);
        coords_push(g, 0.0);
        coords_push2(g, o->pt0.x + ux + vx, o->pt0.y + uy + vy);
        coords_push(g, 0.0);
        coords_push2(g, o->pt0.x + vx, o->pt0.y + vy);
        coords_push(g, 0.0);
        box_add_coords(&bounds, g, 3);
      }
      if (g->length < 6) return 0;
      e.flags |= FCB_FLAG_CLOSED;
      attach_geometry(s, &e);
      commit(s, &e, &bounds, owner_block, FCB_TYPE_POLYLINE);
      return 1;
    }

    case DWG_TYPE_HELIX: {
      Dwg_Entity_HELIX *o = ent->tio.HELIX;
      uint32_t i;
      if (!o) return 0;
      if (o->fit_pts && o->num_fit_pts >= 2) {
        for (i = 0; i < o->num_fit_pts; i++) {
          coords_push2(g, o->fit_pts[i].x, o->fit_pts[i].y);
          coords_push(g, 0.0);
          box_add(&bounds, o->fit_pts[i].x, o->fit_pts[i].y);
        }
      } else if (o->ctrl_pts && o->num_ctrl_pts >= 2) {
        for (i = 0; i < o->num_ctrl_pts; i++) {
          coords_push2(g, o->ctrl_pts[i].x, o->ctrl_pts[i].y);
          coords_push(g, 0.0);
          box_add(&bounds, o->ctrl_pts[i].x, o->ctrl_pts[i].y);
        }
      }
      if (g->length < 6) return 0;
      attach_geometry(s, &e);
      commit(s, &e, &bounds, owner_block, FCB_TYPE_POLYLINE);
      return 1;
    }

    default: {
      const char *dimension_name = dimension_type_name(obj->fixedtype);
      if (dimension_name) {
        void *o = (void *)ent->tio.DIMENSION_LINEAR;
        Dwg_Object_Ref *block_ref;
        char *user_text;
        char *style_name = NULL;
        int owned_text;
        int owned_style = 0;
        int64_t ints[2];
        double text_x, text_y, measurement;
        const char *block_name = "";
        uint32_t block;

        if (!o) return 0;
        block_ref = dyn_handle(o, dimension_name, "block");
        block = block_index_from_ref(s, block_ref, obj);
        text_x = dyn_double(o, dimension_name, "text_midpt", 0.0);
        /* text_midpt is a 2RD, so reading it as a double yields only x; read
         * the pair explicitly. */
        {
          BITCODE_2RD midpoint;
          memset(&midpoint, 0, sizeof(midpoint));
          if (dwg_dynapi_entity_value(o, dimension_name, "text_midpt",
                                      &midpoint, NULL)) {
            text_x = midpoint.x;
            text_y = midpoint.y;
          } else {
            text_y = 0.0;
          }
        }
        if (block != 0xFFFFFFFFu && block < s->block_count) {
          uint32_t self = (uint32_t)(obj - s->dwg->object);
          uint32_t winner = hmap_get(&s->claimed_dimension_blocks,
                                     (uint64_t)block + 1u, 0xFFFFFFFFu);
          /* A colliding DIMENSION.block that points at another dim's
           * *D must not redraw those ticks. The fitting text_midpt
           * already claimed the block in preclaim; otherwise the
           * first remaining dimension keeps it so the *D is not
           * orphaned. */
          if (winner == 0xFFFFFFFFu) {
            hmap_put(&s->claimed_dimension_blocks, (uint64_t)block + 1u,
                     self);
            block_name = s->block_names[block];
          } else if (winner == self) {
            block_name = s->block_names[block];
          }
        }
        measurement = dyn_double(o, dimension_name, "act_measurement", 0.0);
        user_text = dyn_text(o, dimension_name, "user_text", &owned_text);

        coords_push2(g, text_x, text_y);
        coords_push(g, measurement);
        box_add(&bounds, text_x, text_y);

        ints[0] = 0;
        ints[1] = 0;
        e.int_offset = fcb_add_ints(s->b, ints, 2);
        e.int_count = 2;
        e.string_offset = fcb_append_string(s->b, block_name);
        fcb_append_string(s->b, user_text ? user_text : "");
        fcb_append_string(s->b, style_name ? style_name : "Standard");
        e.string_count = 3;
        attach_geometry(s, &e);
        commit(s, &e, &bounds, owner_block, FCB_TYPE_DIMENSION);
        dyn_text_free(user_text, owned_text);
        dyn_text_free(style_name, owned_style);
        return 1;
      }

      /* Anything else becomes a proxy so it stays visible in the drawing tree
       * and survives a save instead of silently disappearing. Prefer isoline
       * wires from ACIS bodies when LibreDWG decoded them. */
      {
        const char *type_name = obj->dxfname ? obj->dxfname : "UNKNOWN";
        int64_t runs[64];
        uint32_t run_count = 0;
        Dwg_Entity__3DSOLID *solid = NULL;
        if (obj->fixedtype == DWG_TYPE_REGION) solid = ent->tio.REGION;
        else if (obj->fixedtype == DWG_TYPE__3DSOLID) solid = ent->tio._3DSOLID;
        else if (obj->fixedtype == DWG_TYPE_BODY) solid = ent->tio.BODY;
        if (solid) {
          run_count = extract_acis_wires(g, &bounds, runs, 64, solid);
          if (run_count == 0) {
            run_count = extract_sat_points(g, &bounds, runs, 64, solid);
          }
        }
        if (run_count == 0) {
          note_proxy(s, type_name);
          coords_push2(g, 0.0, 0.0);
          coords_push2(g, 0.0, 0.0);
        } else {
          uint32_t stroke_len = g->length;
          uint32_t i;
          for (i = 0; i < 4; i++) coords_push(g, 0.0);
          memmove(g->data + 4, g->data, stroke_len * sizeof(double));
          g->data[0] = bounds.min_x;
          g->data[1] = bounds.min_y;
          g->data[2] = bounds.max_x;
          g->data[3] = bounds.max_y;
          e.int_offset = fcb_add_ints(s->b, runs, run_count);
          e.int_count = run_count;
        }
        e.string_offset = fcb_append_string(s->b, type_name);
        e.string_count = 1;
        attach_geometry(s, &e);
        commit(s, &e, &bounds, owner_block, FCB_TYPE_UNKNOWN);
        return 1;
      }
    }
  }
}

/* The interned layer name stored on a previously written layer record. */
static uint32_t interned_layer_name(import_state *s, const Dwg_Object *obj) {
  uint32_t idx;
  const uint8_t *p;
  if (!obj->tio.entity) return fcb_intern(s->b, "0");
  idx = hmap_get(&s->layer_index, ref_handle(obj->tio.entity->layer), 0);
  if (idx >= s->b->layer_count) return fcb_intern(s->b, "0");
  p = s->b->layers.data + (size_t)idx * FCB_RECORD_LAYER;
  return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) |
         ((uint32_t)p[3] << 24);
}

static int name_is_model(const char *name) {
  const char *want = "model";
  if (!name) return 0;
  while (*name && *want) {
    unsigned char a = (unsigned char)*name++;
    unsigned char b = (unsigned char)*want++;
    if (a >= 'A' && a <= 'Z') a = (unsigned char)(a + 32);
    if (a != b) return 0;
  }
  return *name == 0 && *want == 0;
}

typedef struct {
  char *name;
  uint32_t block;
  uint32_t tab_order;
  uint32_t sequence;
  int is_model;
  double paper_width;
  double paper_height;
} layout_item;

static int layout_item_cmp(const void *a, const void *b) {
  const layout_item *la = (const layout_item *)a;
  const layout_item *lb = (const layout_item *)b;
  if (la->is_model != lb->is_model) return lb->is_model - la->is_model;
  if (la->tab_order != lb->tab_order) {
    return la->tab_order < lb->tab_order ? -1 : 1;
  }
  if (la->sequence == lb->sequence) return 0;
  return la->sequence < lb->sequence ? -1 : 1;
}

static void layout_paper_size(const Dwg_Object_LAYOUT *lo, double *width,
                              double *height) {
  *width = lo->plotsettings.paper_width;
  *height = lo->plotsettings.paper_height;
  if (*width <= 0.0 || *height <= 0.0) {
    *width = lo->LIMMAX.x - lo->LIMMIN.x;
    *height = lo->LIMMAX.y - lo->LIMMIN.y;
  }
  if (*width <= 0.0 || *height <= 0.0) {
    *width = 297.0;
    *height = 210.0;
  }
}

static void emit_layout_item(import_state *s, const layout_item *item) {
  fcb_layout layout;
  const char *name = item->name && item->name[0] ? item->name
                                                 : (item->is_model ? "Model" : "Layout");
  memset(&layout, 0, sizeof(layout));
  layout.name = fcb_intern(s->b, name);
  layout.block_index = item->block;
  layout.tab_order = item->tab_order;
  layout.paper_width = item->paper_width;
  layout.paper_height = item->paper_height;
  if (item->is_model) layout.flags |= FCB_LAYOUT_MODEL_SPACE;
  fcb_add_layout(s->b, &layout);
}

/* LAYOUT objects carry the tab name and plotted sheet size. Drawings that
 * predate them still get one tab per *Paper_Space* block. */
static int import_layouts(import_state *s, uint32_t **layout_blocks_out,
                          uint32_t *layout_count_out) {
  uint32_t i;
  uint32_t found = 0;
  uint32_t count = 0;
  uint32_t paper_count = 0;
  int has_model = 0;
  layout_item *items = NULL;
  uint32_t *blocks = NULL;

  *layout_blocks_out = NULL;
  *layout_count_out = 0;

  for (i = 0; i < s->dwg->num_objects; i++) {
    if (s->dwg->object[i].supertype == DWG_SUPERTYPE_OBJECT &&
        s->dwg->object[i].fixedtype == DWG_TYPE_LAYOUT) {
      found++;
    }
  }

  if (found > 0) {
    items = (layout_item *)calloc(found + 1, sizeof(layout_item));
    if (!items) return 0;
    for (i = 0; i < s->dwg->num_objects; i++) {
      Dwg_Object *obj = &s->dwg->object[i];
      Dwg_Object_LAYOUT *lo;
      Dwg_Object_Ref *block_ref;
      uint32_t block;
      char *name;
      int owned;
      layout_item *item;

      if (obj->supertype != DWG_SUPERTYPE_OBJECT) continue;
      if (obj->fixedtype != DWG_TYPE_LAYOUT) continue;
      if (!obj->tio.object || !obj->tio.object->tio.LAYOUT) continue;
      lo = obj->tio.object->tio.LAYOUT;

      name = dyn_text(lo, "LAYOUT", "layout_name", &owned);
      block_ref = lo->block_header;
      block = hmap_get(&s->block_index, ref_handle(block_ref), 0xFFFFFFFFu);
      item = &items[count];
      item->is_model = name_is_model(name) || block == s->model_space_block;
      if (block == 0xFFFFFFFFu) {
        if (!item->is_model) {
          dyn_text_free(name, owned);
          continue;
        }
        block = s->model_space_block;
      }
      item->name = name && name[0] ? strdup(name) : NULL;
      item->block = block;
      item->tab_order = (uint32_t)lo->tab_order;
      item->sequence = count;
      layout_paper_size(lo, &item->paper_width, &item->paper_height);
      if (item->is_model) has_model = 1;
      count++;
      dyn_text_free(name, owned);
    }
    if (!has_model && count < found + 1) {
      items[count].name = strdup("Model");
      items[count].block = s->model_space_block;
      items[count].is_model = 1;
      items[count].tab_order = 0;
      items[count].sequence = 0;
      items[count].paper_width = 297.0;
      items[count].paper_height = 210.0;
      count++;
    }
    qsort(items, count, sizeof(layout_item), layout_item_cmp);
  } else {
    for (i = 0; i < s->block_count; i++) {
      if (i == s->model_space_block) continue;
      if (strncmp(s->block_names[i], "*Paper_Space", 12) == 0) paper_count++;
    }
    items = (layout_item *)calloc(paper_count + 1, sizeof(layout_item));
    if (!items) return 0;
    items[0].name = strdup("Model");
    items[0].block = s->model_space_block;
    items[0].is_model = 1;
    items[0].tab_order = 0;
    items[0].paper_width = 297.0;
    items[0].paper_height = 210.0;
    count = 1;
    for (i = 0; i < s->block_count; i++) {
      char name[64];
      if (i == s->model_space_block) continue;
      if (strncmp(s->block_names[i], "*Paper_Space", 12) != 0) continue;
      snprintf(name, sizeof(name), "Layout%u", count);
      items[count].name = strdup(name);
      items[count].block = i;
      items[count].tab_order = count;
      items[count].sequence = count;
      items[count].paper_width = 297.0;
      items[count].paper_height = 210.0;
      count++;
    }
  }

  blocks = (uint32_t *)calloc(count ? count : 1, sizeof(uint32_t));
  if (!blocks) {
    for (i = 0; i < count; i++) free(items[i].name);
    free(items);
    return 0;
  }
  for (i = 0; i < count; i++) {
    emit_layout_item(s, &items[i]);
    blocks[i] = items[i].block;
    free(items[i].name);
  }
  free(items);
  *layout_blocks_out = blocks;
  *layout_count_out = count;
  return 1;
}

/* VIEWPORT entities become paper windows on a layout, not drawable proxies. */
static void import_paper_viewports(import_state *s,
                                   const uint32_t *layout_blocks,
                                   uint32_t layout_count) {
  uint32_t i;
  uint32_t j;
  if (!layout_blocks || layout_count == 0) return;

  for (i = 0; i < s->dwg->num_objects; i++) {
    Dwg_Object *obj = &s->dwg->object[i];
    Dwg_Entity_VIEWPORT *vp;
    uint32_t owner;
    uint32_t layout_index;
    fcb_viewport rec;
    double scale;

    if (obj->fixedtype != DWG_TYPE_VIEWPORT) continue;
    if (!obj->tio.entity || !obj->tio.entity->tio.VIEWPORT) continue;
    vp = obj->tio.entity->tio.VIEWPORT;

    /* Viewport 1 is paper space's own sheet window, not a model-space hole. */
    if (vp->id == 1) continue;
    if (vp->width <= 0.0 || vp->height <= 0.0) continue;

    owner = owner_block(s, obj);

    layout_index = UINT32_MAX;
    for (j = 0; j < layout_count; j++) {
      if (layout_blocks[j] == owner) {
        layout_index = j;
        break;
      }
    }
    /* Model space does not host paper viewports. */
    if (owner == s->model_space_block) continue;
    if (layout_index == UINT32_MAX) continue;

    scale = vp->VIEWSIZE > 0.0 ? vp->height / vp->VIEWSIZE : 1.0;

    memset(&rec, 0, sizeof(rec));
    rec.layout_index = layout_index;
    if (vp->on_off > 0 && (vp->status_flag & 131072u) == 0) {
      rec.flags |= FCB_VIEWPORT_ON;
    }
    if (vp->status_flag & 16384u) rec.flags |= FCB_VIEWPORT_LOCKED;
    rec.paper_min_x = vp->center.x - vp->width * 0.5;
    rec.paper_min_y = vp->center.y - vp->height * 0.5;
    rec.paper_max_x = vp->center.x + vp->width * 0.5;
    rec.paper_max_y = vp->center.y + vp->height * 0.5;
    rec.model_center_x = vp->VIEWCTR.x;
    rec.model_center_y = vp->VIEWCTR.y;
    rec.scale = scale;
    rec.rotation = vp->twist_angle;
    rec.layer = interned_layer_name(s, obj);
    fcb_add_viewport(s->b, &rec);
  }
}

/* -------------------------------------------------------------------------
 * Driver
 * ------------------------------------------------------------------------- */

int fcdwg_import(const char *path, fcb_builder *b, char *error_out,
                 size_t error_capacity) {
  Dwg_Data dwg;
  import_state state;
  int result;
  uint32_t i;
  uint32_t *bucket_counts = NULL;
  uint32_t *bucket_cursors = NULL;
  uint32_t *ordered = NULL;
  uint32_t *candidates = NULL;
  uint32_t *layout_blocks = NULL;
  uint32_t entity_total = 0;
  uint32_t candidate_count = 0;
  uint32_t status = FC_STATUS_OK;
  char message[256];

  memset(&dwg, 0, sizeof(dwg));
  memset(&state, 0, sizeof(state));
  result = dwg_read_file((char *)path, &dwg);
  /* LibreDWG returns a bitmask of severities; anything up to
   * DWG_ERR_CRITICAL still yields a usable drawing, which matters because a
   * large share of real-world files have minor defects. */
  if (result >= DWG_ERR_CRITICAL) {
    snprintf(error_out, error_capacity,
             "LibreDWG could not read the file (error 0x%x)", result);
    dwg_free(&dwg);
    return FC_STATUS_PARSE_ERROR;
  }
  if (dwg.num_objects == 0) {
    snprintf(error_out, error_capacity, "The drawing contains no objects");
    dwg_free(&dwg);
    return FC_STATUS_PARSE_ERROR;
  }

  state.dwg = &dwg;
  state.b = b;
  coords_init(&state.staging);
  if (!hmap_init(&state.layer_index, 64) ||
      !hmap_init(&state.linetype_index, 32) ||
      !hmap_init(&state.block_index, 256) ||
      !hmap_init(&state.used_entity_ids, dwg.num_objects)) {
    status = FC_STATUS_OUT_OF_MEMORY;
    goto cleanup;
  }

  /* Line types first: layers reference them by index. */
  import_linetypes(&state);
  import_layers(&state);
  import_textstyles(&state);
  if (!import_block_headers(&state)) {
    status = FC_STATUS_OUT_OF_MEMORY;
    goto cleanup;
  }
  if (!hmap_init(&state.claimed_dimension_blocks, state.block_count)) {
    status = FC_STATUS_OUT_OF_MEMORY;
    goto cleanup;
  }
  if (!index_referenced_dimension_blocks(&state)) {
    status = FC_STATUS_OUT_OF_MEMORY;
    goto cleanup;
  }
  if (!index_first_entities(&state)) {
    status = FC_STATUS_OUT_OF_MEMORY;
    goto cleanup;
  }
  if (!index_owned_entities(&state)) {
    status = FC_STATUS_OUT_OF_MEMORY;
    goto cleanup;
  }
  if (!index_block_member_boxes(&state)) {
    status = FC_STATUS_OUT_OF_MEMORY;
    goto cleanup;
  }

  /* Entities are grouped by owning block with a counting sort so that the
   * output is in block order and, within a block, in file order, which is the
   * draw order. One pass to count, one to place. */
  bucket_counts = (uint32_t *)calloc(state.block_count + 1, sizeof(uint32_t));
  bucket_cursors = (uint32_t *)calloc(state.block_count + 1, sizeof(uint32_t));
  if (!bucket_counts || !bucket_cursors) {
    status = FC_STATUS_OUT_OF_MEMORY;
    goto cleanup;
  }

  /* First row keeps the handle. A later non-POINT row on the same
   * handle is another object LibreDWG listed after a *D arrow; drop
   * a later POINT. */
  candidates = (uint32_t *)calloc(dwg.num_objects ? dwg.num_objects : 1,
                                  sizeof(uint32_t));
  if (!candidates) {
    status = FC_STATUS_OUT_OF_MEMORY;
    goto cleanup;
  }
  for (i = 0; i < dwg.num_objects; i++) {
    Dwg_Object *obj = &dwg.object[i];
    uint64_t handle;
    uint32_t first;
    if (obj->supertype != DWG_SUPERTYPE_ENTITY || !obj->tio.entity) continue;
    /* Vertices and sequence-end markers belong to their parent polyline.
     * BLOCK/ENDBLK are the old entity-stream brackets; the block table is
     * BLOCK_HEADER. VIEWPORTs are paper windows, written after the layout
     * table. */
    if (is_structural_entity(obj->fixedtype)) continue;
    handle = (uint64_t)obj->handle.value;
    first = handle
                ? hmap_get(&state.first_entity, handle, 0xFFFFFFFFu)
                : 0xFFFFFFFFu;
    if (handle && first != i) {
      /* LibreDWG repeats vertices as POINT on a reused handle. A later
       * LINE / INSERT / MTEXT is a different object (plate edge, title
       * frame, sheet number). */
      if (obj->fixedtype == DWG_TYPE_POINT) continue;
    }
    candidates[candidate_count++] = i;
  }

  if (!reindex_live_dimension_blocks(&state, candidates, candidate_count)) {
    status = FC_STATUS_OUT_OF_MEMORY;
    goto cleanup;
  }
  if (!preclaim_fitting_dimension_blocks(&state, candidates,
                                         candidate_count)) {
    status = FC_STATUS_OUT_OF_MEMORY;
    goto cleanup;
  }

  for (i = 0; i < candidate_count; i++) {
    uint32_t owner = owner_block(&state, &dwg.object[candidates[i]]);
    bucket_counts[owner]++;
  }
  entity_total = candidate_count;

  ordered = (uint32_t *)calloc(entity_total ? entity_total : 1,
                               sizeof(uint32_t));
  if (!ordered) {
    status = FC_STATUS_OUT_OF_MEMORY;
    goto cleanup;
  }
  {
    uint32_t running = 0;
    for (i = 0; i < state.block_count; i++) {
      bucket_cursors[i] = running;
      running += bucket_counts[i];
    }
  }
  for (i = 0; i < candidate_count; i++) {
    uint32_t owner = owner_block(&state, &dwg.object[candidates[i]]);
    ordered[bucket_cursors[owner]++] = candidates[i];
  }

  /* Emit entities block by block, recording each block's contiguous range. */
  {
    uint32_t cursor = 0;
    uint32_t block;
    for (block = 0; block < state.block_count; block++) {
      uint32_t first = b->entity_count;
      uint32_t count = bucket_counts[block];
      uint32_t k;
      for (k = 0; k < count; k++) {
        import_entity(&state, &dwg.object[ordered[cursor + k]], block);
      }
      cursor += count;

      {
        fcb_block record;
        memset(&record, 0, sizeof(record));
        record.name = fcb_intern(b, state.block_names[block]);
        record.base_x = state.block_base_x[block];
        record.base_y = state.block_base_y[block];
        record.entity_first = first;
        record.entity_count = b->entity_count - first;
        if (block == state.model_space_block) {
          record.flags |= FCB_BLOCK_LAYOUT;
        }
        if (state.block_names[block][0] == '*') {
          if (strncmp(state.block_names[block], "*Paper_Space", 12) == 0) {
            record.flags |= FCB_BLOCK_LAYOUT;
          } else if (block != state.model_space_block) {
            record.flags |= FCB_BLOCK_ANONYMOUS;
          }
        }
        fcb_add_block(b, &record);
      }
    }
  }

  {
    uint32_t layout_count = 0;
    if (!import_layouts(&state, &layout_blocks, &layout_count)) {
      status = FC_STATUS_OUT_OF_MEMORY;
      goto cleanup;
    }
    import_paper_viewports(&state, layout_blocks, layout_count);
  }

  /* A handful of header variables that affect rendering. */
  {
    char buffer[64];
    snprintf(buffer, sizeof(buffer), "%g", dwg.header_vars.LTSCALE);
    fcb_add_header_variable(b, "$LTSCALE", buffer);
    snprintf(buffer, sizeof(buffer), "%d", (int)dwg.header_vars.INSUNITS);
    fcb_add_header_variable(b, "$INSUNITS", buffer);
    snprintf(buffer, sizeof(buffer), "%d", (int)dwg.header_vars.PDMODE);
    fcb_add_header_variable(b, "$PDMODE", buffer);
    snprintf(buffer, sizeof(buffer), "%g", dwg.header_vars.PDSIZE);
    fcb_add_header_variable(b, "$PDSIZE", buffer);
    snprintf(buffer, sizeof(buffer), "%g", dwg.header_vars.DIMSCALE);
    fcb_add_header_variable(b, "$DIMSCALE", buffer);
    fcb_add_header_variable(b, "$ACADVER",
                           dwg_version_type(dwg.header.version));
    snprintf(buffer, sizeof(buffer), "%u", (unsigned)dwg.header.codepage);
    fcb_add_header_variable(b, "$DWGCODEPAGE", buffer);
  }

  if (state.skipped > 0) {
    uint32_t t;
    snprintf(message, sizeof(message),
             "%u object(s) were imported as proxies because their type is not "
             "supported yet",
             state.skipped);
    fcb_diagnose(b, message);
    for (t = 0; t < state.proxy_tally_count; t++) {
      snprintf(message, sizeof(message), "%u %s object(s) have no drawable geometry",
               state.proxies[t].count, state.proxies[t].name);
      fcb_diagnose(b, message);
    }
  }
  if (state.unsupported_hatch_segments > 0) {
    snprintf(message, sizeof(message),
             "%u curved hatch boundary edge(s) were approximated by chords",
             state.unsupported_hatch_segments);
    fcb_diagnose(b, message);
  }

cleanup:
  free(bucket_counts);
  free(bucket_cursors);
  free(ordered);
  free(candidates);
  free(layout_blocks);
  hmap_dispose(&state.used_entity_ids);
  hmap_dispose(&state.entity_block);
  hmap_dispose(&state.first_entity);
  hmap_dispose(&state.referenced_dimension_blocks);
  hmap_dispose(&state.claimed_dimension_blocks);
  free(state.block_member_box);
  free(state.block_base_x);
  free(state.block_base_y);
  if (state.block_names) {
    for (i = 0; i < state.block_count; i++) free(state.block_names[i]);
    free(state.block_names);
  }
  coords_dispose(&state.staging);
  hmap_dispose(&state.layer_index);
  hmap_dispose(&state.linetype_index);
  hmap_dispose(&state.block_index);
  dwg_free(&dwg);

  if (status != FC_STATUS_OK && error_out && error_capacity > 0) {
    snprintf(error_out, error_capacity, "Out of memory while importing");
  }
  return (int)status;
}

#endif /* FANCAD_HAVE_LIBREDWG */
