#include "dwg_export.h"

#include <math.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "fancad_io.h"
#include "fcb_view.h"

#ifndef FANCAD_HAVE_LIBREDWG

int fcdwg_export_fcb_to_dwg(const uint8_t *fcb, uint64_t length,
                            const char *dwg_path, int32_t target_version,
                            char *error_out, size_t error_capacity) {
  (void)fcb;
  (void)length;
  (void)dwg_path;
  (void)target_version;
  if (error_out && error_capacity > 0) {
    snprintf(error_out, error_capacity,
             "This build has no DWG backend, so it cannot write DWG files.");
  }
  return FC_STATUS_NO_BACKEND;
}

int fcdwg_export_dxf_to_dwg(const char *dxf_path, const char *dwg_path,
                            int32_t target_version, char *error_out,
                            size_t error_capacity) {
  (void)dxf_path;
  (void)dwg_path;
  (void)target_version;
  if (error_out && error_capacity > 0) {
    snprintf(error_out, error_capacity,
             "This build has no DWG backend, so it cannot write DWG files.");
  }
  return FC_STATUS_NO_BACKEND;
}

#else

#include <dwg.h>
#include <dwg_api.h>
#if defined(__APPLE__) || defined(__linux__)
#include <iconv.h>
#define FANCAD_HAVE_ICONV 1
#endif

/* Not in the public headers; the static LibreDWG we link still exports it. */
void dwg_set_next_objhandle(Dwg_Object *obj);

#define NAME_CAP 256
#define TEXT_CAP 4096

static void set_error(char *error_out, size_t error_capacity, const char *msg) {
  if (error_out && error_capacity > 0) {
    snprintf(error_out, error_capacity, "%s", msg);
  }
}

static int streq(const char *a, const char *b) {
  if (!a || !b) return 0;
  return strcmp(a, b) == 0;
}

static int ascii_ieq(const char *a, const char *b) {
  if (!a || !b) return a == b;
  while (*a && *b) {
    unsigned char ca = (unsigned char)*a++;
    unsigned char cb = (unsigned char)*b++;
    if (ca >= 'A' && ca <= 'Z') ca = (unsigned char)(ca + 32);
    if (cb >= 'A' && cb <= 'Z') cb = (unsigned char)(cb + 32);
    if (ca != cb) return 0;
  }
  return *a == 0 && *b == 0;
}

/* R2000/R2004 table names store non-ASCII as AutoCAD MIF (`\U+XXXX`).
 * dwg_add_LAYER writes that encoding; dwg_find_tablehandle compares the
 * raw TV bytes, so a UTF-8 lookup never hits the row and the entity
 * falls onto layer 0. Encode both sides the same way. */
#define MIF_CAP 2048

static int utf8_next(const unsigned char **pp, unsigned *cp) {
  const unsigned char *p = *pp;
  unsigned char c;
  if (!p || !*p) return 0;
  c = p[0];
  if (c < 0x80) {
    *cp = c;
    *pp = p + 1;
    return 1;
  }
  if ((c & 0xE0) == 0xC0 && (p[1] & 0xC0) == 0x80) {
    *cp = ((unsigned)(c & 0x1F) << 6) | (unsigned)(p[1] & 0x3F);
    *pp = p + 2;
    return 1;
  }
  if ((c & 0xF0) == 0xE0 && (p[1] & 0xC0) == 0x80 && (p[2] & 0xC0) == 0x80) {
    *cp = ((unsigned)(c & 0x0F) << 12) | ((unsigned)(p[1] & 0x3F) << 6) |
          (unsigned)(p[2] & 0x3F);
    *pp = p + 3;
    return 1;
  }
  if ((c & 0xF8) == 0xF0 && (p[1] & 0xC0) == 0x80 && (p[2] & 0xC0) == 0x80 &&
      (p[3] & 0xC0) == 0x80) {
    *cp = ((unsigned)(c & 0x07) << 18) | ((unsigned)(p[1] & 0x3F) << 12) |
          ((unsigned)(p[2] & 0x3F) << 6) | (unsigned)(p[3] & 0x3F);
    *pp = p + 4;
    return 1;
  }
  return 0;
}

static void utf8_to_mif(const char *src, char *dst, size_t cap) {
  const unsigned char *p = (const unsigned char *)src;
  size_t o = 0;
  if (!dst || cap == 0) return;
  dst[0] = '\0';
  if (!src) return;
  if (strstr(src, "\\U+")) {
    strncpy(dst, src, cap - 1);
    dst[cap - 1] = '\0';
    return;
  }
  while (*p && o + 1 < cap) {
    unsigned cp = 0;
    if (!utf8_next(&p, &cp)) break;
    if (cp >= 0x20 && cp <= 0x7E) {
      dst[o++] = (char)cp;
      continue;
    }
    if (cp < 0x10000) {
      if (o + 7 >= cap) break;
      snprintf(dst + o, cap - o, "\\U+%04X", cp);
      o += 7;
      continue;
    }
    {
      unsigned hi = 0xD800u + ((cp - 0x10000u) >> 10);
      unsigned lo = 0xDC00u + ((cp - 0x10000u) & 0x3FFu);
      if (o + 14 >= cap) break;
      snprintf(dst + o, cap - o, "\\U+%04X\\U+%04X", hi, lo);
      o += 14;
    }
  }
  dst[o] = '\0';
}

static const char *mif_name(const char *utf8, char *buf, size_t cap) {
  if (!utf8 || !utf8[0]) return utf8;
  utf8_to_mif(utf8, buf, cap);
  return buf[0] ? buf : utf8;
}

static int tv_is_ascii(const unsigned char *s) {
  if (!s) return 1;
  for (; *s; s++) {
    if (*s & 0x80) return 0;
  }
  return 1;
}

#ifdef FANCAD_HAVE_ICONV
static char *iconv_from_utf8(const char *src, const char *to) {
  iconv_t cd;
  char *in;
  char *out;
  char *result;
  size_t inleft;
  size_t outleft;
  size_t outcap;
  if (!src || !to) return NULL;
  cd = iconv_open(to, "UTF-8");
  if (cd == (iconv_t)-1) return NULL;
  inleft = strlen(src);
  outcap = inleft * 2 + 8;
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

static const char *iconv_name_for_codepage(unsigned codepage) {
  switch (codepage) {
    case 2:
      return "ISO-8859-1";
    case 24:
      return "BIG5";
    case 30:
      return "WINDOWS-1252";
    case 31:
      return "GB2312";
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

/* R2000/R2004 TEXT/MTEXT still live in the drawing codepage. FanCAD holds
 * UTF-8; GstarCAD reads those TV bytes as GBK on a Chinese sheet and shows
 * `?` when we leave UTF-8 in the file. Convert, and fall back to MIF when
 * iconv cannot. */
static void encode_tv(Dwg_Data *dwg, char *dst, size_t cap, const char *utf8) {
  if (!dst || cap == 0) return;
  dst[0] = '\0';
  if (!utf8) return;
  if (tv_is_ascii((const unsigned char *)utf8)) {
    strncpy(dst, utf8, cap - 1);
    dst[cap - 1] = '\0';
    return;
  }
#ifdef FANCAD_HAVE_ICONV
  {
    char *converted = NULL;
    const char *to =
        dwg ? iconv_name_for_codepage((unsigned)dwg->header.codepage) : NULL;
    if (to) converted = iconv_from_utf8(utf8, to);
    if (!converted) {
      converted = iconv_from_utf8(utf8, "GB18030");
      if (!converted) converted = iconv_from_utf8(utf8, "GBK");
      if (!converted) converted = iconv_from_utf8(utf8, "CP936");
      if (converted && dwg) dwg->header.codepage = 39;
    }
    if (converted) {
      strncpy(dst, converted, cap - 1);
      dst[cap - 1] = '\0';
      free(converted);
      return;
    }
  }
#endif
  utf8_to_mif(utf8, dst, cap);
}

/* dwg_add_TEXT / MTEXT treat the argument as UTF-8. 0.13.3 then strdup's it;
 * 0.14's bit_utf8_to_TV skips invalid UTF-8, which would drop a GBK payload.
 * Pass ASCII through the API and write the encoded TV ourselves. */
static const char *tv_api_arg(const char *stored) {
  return tv_is_ascii((const unsigned char *)stored) ? stored : "x";
}

static void assign_tv(BITCODE_T *slot, const char *stored) {
  char *copy;
  if (!slot) return;
  copy = strdup(stored ? stored : "");
  if (!copy) return;
  if (*slot) free(*slot);
  *slot = copy;
}

static const char *dwgcodepage_name(unsigned codepage) {
  switch (codepage) {
    case 24:
    case 41:
      return "ANSI_950";
    case 31:
    case 39:
      return "ANSI_936";
    case 38:
      return "ANSI_932";
    case 40:
      return "ANSI_949";
    case 30:
      return "ANSI_1252";
    default:
      return NULL;
  }
}

static void sync_codepage_name(Dwg_Data *dwg) {
  const char *name;
  if (!dwg) return;
  name = dwgcodepage_name((unsigned)dwg->header.codepage);
  if (!name) return;
  dwg->header_vars.codepage = (BITCODE_RS)dwg->header.codepage;
  assign_tv(&dwg->header_vars.DWGCODEPAGE, name);
}

static BITCODE_H find_named(Dwg_Data *dwg, const char *utf8, const char *table) {
  char mif[MIF_CAP];
  BITCODE_H href;
  if (!dwg || !utf8 || !utf8[0] || !table) return NULL;
  href = dwg_find_tablehandle(dwg, utf8, table);
  if (href) return href;
  utf8_to_mif(utf8, mif, sizeof(mif));
  if (mif[0] && !streq(mif, utf8)) {
    href = dwg_find_tablehandle(dwg, mif, table);
  }
  return href;
}

static Dwg_Object_STYLE *style_of_handle(Dwg_Data *dwg, BITCODE_H href) {
  Dwg_Object *obj;
  if (!dwg || !href) return NULL;
  obj = dwg_resolve_handle_silent(dwg, href->absolute_ref);
  if (!obj || obj->fixedtype != DWG_TYPE_STYLE || !obj->tio.object) return NULL;
  return obj->tio.object->tio.STYLE;
}

/* FanCAD lays out hugging MTEXT (rect_width 0) from the insertion as the
 * left of the column, even when attachment is a right corner: shifting by a
 * guessed glyph width walked title notes off the sheet. GstarCAD still
 * honours the right attachment, so write the left column instead. */
static BITCODE_BS hugging_attachment(BITCODE_BS attachment, double rect_width) {
  if (rect_width > 0) return attachment;
  switch (attachment) {
    case 3:
      return 1;
    case 6:
      return 4;
    case 9:
      return 7;
    default:
      return attachment;
  }
}

static int is_model_space(const char *name) {
  return streq(name, "*Model_Space") || streq(name, "*MODEL_SPACE");
}

static int is_primary_paper_space(const char *name) {
  return ascii_ieq(name, "*Paper_Space");
}

static Dwg_Object_BLOCK_HEADER *header_of(Dwg_Object *obj) {
  if (!obj || obj->supertype != DWG_SUPERTYPE_OBJECT) return NULL;
  return obj->tio.object->tio.BLOCK_HEADER;
}

static void bind_entity(Dwg_Data *dwg, Dwg_Object_BLOCK_HEADER *hdr, void *ent,
                        const fcb_view *v, const uint8_t *rec) {
  int err = 0;
  Dwg_Object *obj;
  Dwg_Object_Entity *common;
  uint32_t layer_index;
  uint32_t packed;
  uint32_t kind;
  uint32_t value;
  uint16_t flags;
  char layer[NAME_CAP];
  BITCODE_H href;

  if (!ent) return;
  obj = dwg_obj_generic_to_object(ent, &err);
  if (!obj || obj->supertype != DWG_SUPERTYPE_ENTITY) return;
  common = obj->tio.entity;
  if (!common) return;

  layer_index = fcb_u32(rec + FCB_ENT_LAYER_INDEX);
  if (layer_index < v->layer_count) {
    const uint8_t *layer_rec = fcb_view_layer(v, layer_index);
    if (layer_rec) {
      fcb_view_str(v, fcb_u32(layer_rec + FCB_LAYER_NAME), layer, sizeof(layer));
      if (layer[0]) {
        href = find_named(dwg, layer, "LAYER");
        if (href) common->layer = href;
      }
    }
  }

  packed = fcb_u32(rec + FCB_ENT_COLOR);
  kind = (packed >> 24) & 0xFFu;
  value = packed & 0xFFFFFFu;
  if (kind == FCB_COLOR_INDEXED && value >= 1 && value <= 255) {
    common->color.index = (BITCODE_BS)value;
    common->color.rgb = (BITCODE_BL)(0xC3000000u | value);
  } else if (kind == FCB_COLOR_TRUE) {
    common->color.method = 0xc3;
    common->color.rgb = (BITCODE_BL)(0xC3000000u | value);
    common->color.flag = (BITCODE_BS)(common->color.flag | 0x80);
  } else if (kind == FCB_COLOR_BY_BLOCK) {
    common->color.index = 0;
  }

  {
    uint32_t lt_index = fcb_u32(rec + FCB_ENT_LINETYPE_INDEX);
    char ltype[NAME_CAP];
    common->ltype_flags = 0;
    common->isbylayerlt = 1;
    if (lt_index < v->linetype_count) {
      const uint8_t *lt_rec = fcb_view_linetype(v, lt_index);
      if (lt_rec) {
        fcb_view_str(v, fcb_u32(lt_rec + FCB_LTYPE_NAME), ltype, sizeof(ltype));
        if (streq(ltype, "ByBlock")) {
          common->ltype_flags = 1;
          common->isbylayerlt = 0;
        } else if (streq(ltype, "Continuous")) {
          common->ltype_flags = 2;
          common->isbylayerlt = 0;
        } else if (ltype[0] && !streq(ltype, "ByLayer")) {
          href = find_named(dwg, ltype, "LTYPE");
          if (href) {
            common->ltype = href;
            /* 11 = named LTYPE handle; 00 leaves the entity ByLayer. */
            common->ltype_flags = 3;
            common->isbylayerlt = 0;
          }
        }
      }
    }
  }
  {
    int32_t weight = fcb_i32(rec + FCB_ENT_LINE_WEIGHT);
    if (weight != -1 && weight != -3) common->linewt = (BITCODE_RC)weight;
  }

  flags = fcb_u16(rec + FCB_ENT_FLAGS);
  if (flags & FCB_FLAG_INVISIBLE) common->invisible = 1;
  {
    Dwg_Object_BLOCK_HEADER *model = header_of(dwg_model_space_object(dwg));
    Dwg_Object_BLOCK_HEADER *paper = header_of(dwg_paper_space_object(dwg));
    if (hdr == paper) {
      common->entmode = 1;
    } else if (hdr && hdr != model) {
      /* Named blocks and extra *Paper_SpaceN tabs. Only entmode 0 writes the
       * ownerhandle into the file; 1 and 2 mean paper and model space, and
       * anything else leaves the member with no owner on reread. */
      common->entmode = 0;
    }
  }
}

static int geom_ok(const fcb_view *v, uint64_t offset, uint32_t count) {
  return count == 0 || (offset + count <= v->double_count);
}

static const double *geom_at(const fcb_view *v, uint64_t offset) {
  return v->doubles + offset;
}

static dwg_point_3d pt3(double x, double y) {
  dwg_point_3d p;
  p.x = x;
  p.y = y;
  p.z = 0;
  return p;
}

static dwg_point_2d pt2(double x, double y) {
  dwg_point_2d p;
  p.x = x;
  p.y = y;
  return p;
}

static int ints_ok(const fcb_view *v, uint64_t offset, uint32_t count) {
  return count == 0 || (offset + count <= v->int_count);
}

static const int64_t *ints_at(const fcb_view *v, uint64_t offset) {
  return v->ints + offset;
}

static void bind_style(Dwg_Data *dwg, BITCODE_H *slot, const fcb_view *v,
                       uint32_t str_off, uint32_t str_count) {
  char name[NAME_CAP];
  BITCODE_H href;
  if (!slot || str_count < 2) return;
  fcb_view_str(v, str_off + 1, name, sizeof(name));
  if (!name[0] || streq(name, "Standard")) return;
  href = find_named(dwg, name, "STYLE");
  if (href) *slot = href;
}

static void apply_packed_color(BITCODE_CMC *color, uint32_t packed) {
  uint32_t kind = (packed >> 24) & 0xFFu;
  uint32_t value = packed & 0xFFFFFFu;
  if (!color) return;
  if (kind == FCB_COLOR_INDEXED && value >= 1 && value <= 255) {
    color->index = (BITCODE_BS)value;
    /* R2004 persists ACI in the CMC dword; index alone is dropped. */
    color->rgb = (BITCODE_BL)(0xC3000000u | value);
  } else if (kind == FCB_COLOR_TRUE) {
    color->method = 0xc3;
    color->rgb = (BITCODE_BL)(0xC3000000u | value);
    color->flag = (BITCODE_BS)(color->flag | 0x80);
  }
}

static void *export_hatch(Dwg_Data *dwg, Dwg_Object_BLOCK_HEADER *hdr,
                          const fcb_view *v, const uint8_t *rec,
                          const double *g, uint32_t geom_count) {
  char name[NAME_CAP];
  uint64_t int_off = fcb_u64(rec + FCB_ENT_INT_OFFSET);
  uint32_t int_count = fcb_u32(rec + FCB_ENT_INT_COUNT);
  uint16_t flags = fcb_u16(rec + FCB_ENT_FLAGS);
  const int64_t *ints;
  const Dwg_Object *dummy = NULL;
  Dwg_Entity_HATCH *hatch;
  int64_t loop_count;
  uint32_t cursor;
  uint32_t i;
  uint32_t p;
  if (!g || geom_count < 2 || !ints_ok(v, int_off, int_count) || int_count < 1) {
    return NULL;
  }
  ints = ints_at(v, int_off);
  fcb_view_str(v, fcb_u32(rec + FCB_ENT_STRING_OFFSET), name, sizeof(name));
  hatch = dwg_add_HATCH(hdr, 1, name[0] ? name : "SOLID", 0, 0, &dummy);
  if (!hatch) return NULL;
  hatch->is_solid_fill = (flags & FCB_FLAG_SOLID_FILL) ? 1 : 0;
  hatch->angle = g[0];
  hatch->scale_spacing = g[1] == 0 ? 1 : g[1];
  loop_count = ints[0];
  if (loop_count < 0) loop_count = 0;
  cursor = 2;
  hatch->num_paths = (BITCODE_BL)loop_count;
  if (loop_count > 0) {
    hatch->paths =
        (Dwg_HATCH_Path *)calloc((size_t)loop_count, sizeof(Dwg_HATCH_Path));
  }
  for (p = 0; p < (uint32_t)loop_count && hatch->paths; p++) {
    uint32_t meta = 1 + p * 2;
    int64_t npts;
    Dwg_HATCH_Path *path = &hatch->paths[p];
    uint32_t k;
    if (meta + 1 >= int_count) break;
    npts = ints[meta + 1];
    if (npts < 0) npts = 0;
    path->parent = hatch;
    /* DXF 92: bit 1 = polyline, bit 4 = outermost. */
    path->flag = 2u | (ints[meta] ? 16u : 0u);
    path->closed = 1;
    path->num_segs_or_paths = (BITCODE_BL)npts;
    if (npts > 0) {
      path->polyline_paths = (Dwg_HATCH_PolylinePath *)calloc(
          (size_t)npts, sizeof(Dwg_HATCH_PolylinePath));
    }
    for (k = 0; k < (uint32_t)npts && path->polyline_paths; k++) {
      if (cursor + 1 >= geom_count) break;
      path->polyline_paths[k].parent = path;
      path->polyline_paths[k].point.x = g[cursor++];
      path->polyline_paths[k].point.y = g[cursor++];
    }
  }
  {
    uint32_t line_at = 1 + (uint32_t)loop_count * 2;
    int64_t nlines = 0;
    if (line_at < int_count) nlines = ints[line_at++];
    if (nlines > 0) {
      hatch->num_deflines = (BITCODE_BS)nlines;
      hatch->deflines = (Dwg_HATCH_DefLine *)calloc((size_t)nlines,
                                                    sizeof(Dwg_HATCH_DefLine));
      for (i = 0; i < (uint32_t)nlines && hatch->deflines; i++) {
        int64_t dashes = 0;
        uint32_t d;
        if (line_at + i < int_count) dashes = ints[line_at + i];
        if (cursor + 4 >= geom_count) break;
        hatch->deflines[i].parent = hatch;
        hatch->deflines[i].angle = g[cursor++];
        hatch->deflines[i].pt0.x = g[cursor++];
        hatch->deflines[i].pt0.y = g[cursor++];
        hatch->deflines[i].offset.x = g[cursor++];
        hatch->deflines[i].offset.y = g[cursor++];
        if (dashes < 0) dashes = 0;
        hatch->deflines[i].num_dashes = (BITCODE_BS)dashes;
        if (dashes > 0) {
          hatch->deflines[i].dashes =
              (BITCODE_BD *)calloc((size_t)dashes, sizeof(BITCODE_BD));
          for (d = 0; d < (uint32_t)dashes && hatch->deflines[i].dashes; d++) {
            if (cursor >= geom_count) break;
            hatch->deflines[i].dashes[d] = g[cursor++];
          }
        }
      }
    }
  }
  (void)dwg;
  return hatch;
}

static void *export_spline(Dwg_Object_BLOCK_HEADER *hdr, const fcb_view *v,
                           const uint8_t *rec, const double *g,
                           uint32_t geom_count) {
  uint64_t int_off = fcb_u64(rec + FCB_ENT_INT_OFFSET);
  uint32_t int_count = fcb_u32(rec + FCB_ENT_INT_COUNT);
  uint16_t flags = fcb_u16(rec + FCB_ENT_FLAGS);
  const int64_t *ints;
  int64_t degree, knot_n, ctrl_n, weight_n, fit_n;
  uint32_t cursor = 0;
  int i;
  dwg_point_3d *fits;
  dwg_point_3d tan0;
  dwg_point_3d tan1;
  Dwg_Entity_SPLINE *sp;
  int nfit;
  if (!g || !ints_ok(v, int_off, int_count) || int_count < 5) return NULL;
  ints = ints_at(v, int_off);
  degree = ints[0];
  knot_n = ints[1];
  ctrl_n = ints[2];
  weight_n = ints[3];
  fit_n = ints[4];
  if (knot_n < 0) knot_n = 0;
  if (ctrl_n < 0) ctrl_n = 0;
  if (weight_n < 0) weight_n = 0;
  if (fit_n < 0) fit_n = 0;
  nfit = (int)fit_n;
  if (nfit < 2) nfit = (int)(ctrl_n >= 2 ? ctrl_n : 0);
  if (nfit < 2) return NULL;
  fits = (dwg_point_3d *)calloc((size_t)nfit, sizeof(dwg_point_3d));
  if (!fits) return NULL;
  cursor = (uint32_t)knot_n + (uint32_t)ctrl_n * 2 + (uint32_t)weight_n;
  if (fit_n >= 2) {
    for (i = 0; i < (int)fit_n; i++) {
      uint32_t at = cursor + (uint32_t)i * 2;
      if (at + 1 >= geom_count) break;
      fits[i] = pt3(g[at], g[at + 1]);
    }
  } else {
    for (i = 0; i < (int)ctrl_n && i < nfit; i++) {
      uint32_t at = (uint32_t)knot_n + (uint32_t)i * 2;
      if (at + 1 >= geom_count) break;
      fits[i] = pt3(g[at], g[at + 1]);
    }
  }
  tan0 = pt3(1, 0);
  tan1 = pt3(1, 0);
  sp = dwg_add_SPLINE(hdr, nfit, fits, &tan0, &tan1);
  free(fits);
  if (!sp) return NULL;
  sp->degree = (BITCODE_BS)degree;
  sp->scenario = 1;
  sp->closed_b = (flags & FCB_FLAG_CLOSED) ? 1 : 0;
  cursor = 0;
  if (knot_n > 0) {
    sp->num_knots = (BITCODE_BL)knot_n;
    sp->knots = (BITCODE_BD *)malloc((size_t)knot_n * sizeof(BITCODE_BD));
    for (i = 0; i < (int)knot_n && sp->knots; i++) {
      sp->knots[i] = cursor < geom_count ? g[cursor++] : 0;
    }
  } else {
    cursor = 0;
  }
  if (ctrl_n > 0) {
    sp->num_ctrl_pts = (BITCODE_BL)ctrl_n;
    sp->ctrl_pts = (Dwg_SPLINE_control_point *)calloc(
        (size_t)ctrl_n, sizeof(Dwg_SPLINE_control_point));
    for (i = 0; i < (int)ctrl_n && sp->ctrl_pts; i++) {
      if (cursor + 1 >= geom_count) break;
      sp->ctrl_pts[i].parent = sp;
      sp->ctrl_pts[i].x = g[cursor++];
      sp->ctrl_pts[i].y = g[cursor++];
      sp->ctrl_pts[i].z = 0;
      sp->ctrl_pts[i].w = 1;
    }
    if (knot_n == 0 && ctrl_n > 0) {
      /* Clamped uniform knots so the encoder has a legal NURBS. */
      int d = (int)degree;
      int nknots = (int)ctrl_n + d + 1;
      int k;
      if (d < 1) d = 1;
      if (nknots < 2) nknots = 2;
      sp->num_knots = (BITCODE_BL)nknots;
      sp->knots = (BITCODE_BD *)malloc((size_t)nknots * sizeof(BITCODE_BD));
      if (sp->knots) {
        for (k = 0; k < nknots; k++) {
          if (k < d + 1) sp->knots[k] = 0;
          else if (k >= nknots - d - 1) sp->knots[k] = 1;
          else {
            int inner = nknots - 2 * (d + 1);
            sp->knots[k] = inner > 0 ? (double)(k - d) / (double)(inner + 1) : 0;
          }
        }
      }
    }
  }
  if (weight_n > 0 && sp->ctrl_pts) {
    sp->weighted = 1;
    for (i = 0; i < (int)weight_n && i < (int)ctrl_n; i++) {
      if (cursor >= geom_count) break;
      sp->ctrl_pts[i].w = g[cursor++];
    }
  }
  return sp;
}

static BITCODE_H find_block_header(Dwg_Data *dwg, const char *name) {
  char mif[MIF_CAP];
  BITCODE_BL k;
  if (!dwg || !name || !name[0]) return NULL;
  utf8_to_mif(name, mif, sizeof(mif));
  for (k = 0; k < dwg->num_objects; k++) {
    Dwg_Object *obj = &dwg->object[k];
    Dwg_Object_BLOCK_HEADER *bh;
    if (obj->fixedtype != DWG_TYPE_BLOCK_HEADER || !obj->tio.object) continue;
    bh = obj->tio.object->tio.BLOCK_HEADER;
    if (!bh || !bh->name) continue;
    if (streq(bh->name, name) || ascii_ieq(bh->name, name) ||
        (mif[0] && streq(bh->name, mif))) {
      return dwg_add_handleref(dwg, 5, obj->handle.value, obj);
    }
  }
  return NULL;
}

static Dwg_Object_BLOCK_HEADER *header_named(
    const fcb_view *v, Dwg_Object_BLOCK_HEADER **headers, const char *name) {
  uint64_t i;
  if (!v || !headers || !name || !name[0]) return NULL;
  for (i = 0; i < v->block_count; i++) {
    char bn[NAME_CAP];
    const uint8_t *rec = fcb_view_block(v, i);
    if (!rec || !headers[i]) continue;
    fcb_view_str(v, fcb_u32(rec + FCB_BLOCK_NAME), bn, sizeof(bn));
    if (streq(bn, name)) return headers[i];
  }
  return NULL;
}

/* dwg_add_INSERT looks up the definition by name. R2000 stores CJK / × as
 * \U+XXXX (sometimes mangled), so the UTF-8 FCB name never matches and the
 * INSERT is dropped. Point the lookup at a temporary ASCII alias; the
 * handle on the INSERT is what GstarCAD actually uses. */
static void *export_insert_ref(Dwg_Data *dwg, Dwg_Object_BLOCK_HEADER *owner,
                               Dwg_Object_BLOCK_HEADER *target,
                               const dwg_point_3d *ins, double xscale,
                               double yscale, double zscale, double rot,
                               int rows, int cols, double row_sp,
                               double col_sp) {
  char alias[32];
  char *saved;
  int err = 0;
  Dwg_Object *obj;
  void *ent;
  if (!owner || !target) return NULL;
  obj = dwg_obj_generic_to_object(target, &err);
  if (!obj) return NULL;
  snprintf(alias, sizeof(alias), "_FC%X", (unsigned)obj->handle.value);
  saved = target->name;
  target->name = alias;
  if (cols > 1 || rows > 1) {
    ent = dwg_add_MINSERT(owner, ins, alias, xscale, yscale, zscale, rot, rows,
                          cols, row_sp, col_sp);
  } else {
    ent = dwg_add_INSERT(owner, ins, alias, xscale, yscale, zscale, rot);
  }
  target->name = saved;
  return ent;
}

static void *export_dimension(Dwg_Data *dwg, Dwg_Object_BLOCK_HEADER *hdr,
                              const fcb_view *v, const uint8_t *rec,
                              const double *g, uint32_t geom_count) {
  uint64_t int_off = fcb_u64(rec + FCB_ENT_INT_OFFSET);
  uint32_t int_count = fcb_u32(rec + FCB_ENT_INT_COUNT);
  uint32_t str_off = fcb_u32(rec + FCB_ENT_STRING_OFFSET);
  uint32_t str_count = fcb_u32(rec + FCB_ENT_STRING_COUNT);
  const int64_t *ints;
  int dimtype = 0;
  int dimflags = 0;
  int npts = 0;
  dwg_point_3d text;
  dwg_point_3d p0;
  dwg_point_3d p1;
  dwg_point_3d p2;
  void *ent = NULL;
  char user[TEXT_CAP];
  char block[NAME_CAP];
  if (!g || geom_count < 3) return NULL;
  text = pt3(g[0], g[1]);
  /* Imported dimensions often have a *D block and no definition points.
   * Synthesizing a linear dim from the origin to (measurement, 0) draws
   * rays across the whole sheet in AutoCAD/GstarCAD. Keep the entity at
   * the text point until real origins exist; the *D block is the drawing. */
  p0 = text;
  p1 = text;
  p2 = text;
  if (ints_ok(v, int_off, int_count) && int_count >= 1) {
    ints = ints_at(v, int_off);
    dimflags = (int)ints[0];
    dimtype = dimflags & 0xF;
    if (int_count > 1) npts = (int)ints[1];
  }
  if (npts >= 1 && geom_count >= 5) p0 = pt3(g[3], g[4]);
  if (npts >= 2 && geom_count >= 7) p1 = pt3(g[5], g[6]);
  if (npts >= 3 && geom_count >= 9) p2 = pt3(g[7], g[8]);
  switch (dimtype) {
    case 1:
      ent = dwg_add_DIMENSION_ALIGNED(hdr, &p0, &p1, &text);
      break;
    case 3:
      ent = dwg_add_DIMENSION_DIAMETER(hdr, &p0, &p1, g[2]);
      break;
    case 4:
      ent = dwg_add_DIMENSION_RADIUS(hdr, &p0, &p1, g[2]);
      break;
    case 5:
      /* FanCAD stores [first, second, vertex]; the API wants the vertex first. */
      ent = dwg_add_DIMENSION_ANG3PT(hdr, &p2, &p0, &p1, &text);
      break;
    case 2:
      ent = dwg_add_DIMENSION_ANG2LN(hdr, &p0, &p1, &p2, &text);
      break;
    case 6:
      ent = dwg_add_DIMENSION_ORDINATE(hdr, &p0, &p1, (dimflags & 64) != 0);
      break;
    default:
      ent = dwg_add_DIMENSION_LINEAR(hdr, &p0, &p1, &p2, 0);
      break;
  }
  fcb_view_str(v, str_off, block, sizeof(block));
  fcb_view_str(v, str_off + 1, user, sizeof(user));
  if (ent) {
    Dwg_DIMENSION_common *d = (Dwg_DIMENSION_common *)ent;
    BITCODE_H href;
    d->act_measurement = g[2];
    d->text_midpt.x = g[0];
    d->text_midpt.y = g[1];
    if (user[0]) {
      char stored[TEXT_CAP];
      encode_tv(dwg, stored, sizeof(stored), user);
      assign_tv(&d->user_text, stored);
    }
    if (str_count > 2) {
      char style[NAME_CAP];
      fcb_view_str(v, str_off + 2, style, sizeof(style));
      if (style[0] && !streq(style, "Standard")) {
        href = find_named(dwg, style, "DIMSTYLE");
        if (href) d->dimstyle = href;
      }
    }
    href = find_block_header(dwg, block);
    if (href) {
      d->block = href;
      d->flag = (BITCODE_RC)((dimflags & ~0x0F) | dimtype | 32);
    }
  }
  return ent;
}

static int sat_put(char **buf, size_t *len, size_t *cap, const char *s) {
  size_t n;
  if (!buf || !len || !cap || !s) return 0;
  n = strlen(s);
  if (*len + n + 1 > *cap) {
    size_t next = *cap ? *cap * 2 : 1024;
    char *tmp;
    while (next < *len + n + 1) next *= 2;
    tmp = (char *)realloc(*buf, next);
    if (!tmp) return 0;
    *buf = tmp;
    *cap = next;
  }
  memcpy(*buf + *len, s, n + 1);
  *len += n;
  return 1;
}

static int sat_fmt(char **buf, size_t *len, size_t *cap, const char *fmt, ...) {
  char line[512];
  va_list ap;
  va_start(ap, fmt);
  vsnprintf(line, sizeof(line), fmt, ap);
  va_end(ap);
  return sat_put(buf, len, cap, line);
}

static int xy_close(double ax, double ay, double bx, double by) {
  double dx = ax - bx;
  double dy = ay - by;
  return dx * dx + dy * dy < 1e-16;
}

/* Planar SAT v1 that extract_sat_loops can walk: one loop record per stroke. */
static char *sat_from_strokes(const double *g, uint32_t geom_count,
                              const int64_t *runs, uint32_t run_count) {
  char *buf = NULL;
  size_t len = 0;
  size_t cap = 0;
  uint32_t cursor = 4;
  uint32_t r;
  int rec = 0;
  int64_t fallback_run = 0;
  if (!g || geom_count < 8) return NULL;
  if (!sat_put(&buf, &len, &cap, "700 0 1 0 \n")) goto fail;
  if (!sat_put(&buf, &len, &cap,
               "8 FanCAD 8 ACIS 1.7.0 24 Thu Jan 01 00:00:00 1998 \n")) {
    goto fail;
  }
  if (!sat_put(&buf, &len, &cap, "18 1e-6 1e-10 \n")) goto fail;
  if (!runs || run_count == 0) {
    fallback_run = (int64_t)((geom_count - 4) / 2);
    runs = &fallback_run;
    run_count = 1;
  }
  for (r = 0; r < run_count; r++) {
    int n = (int)runs[r];
    int i;
    int body, lump, shell, face, loop, co0, ed0, v0, p0;
    if (n < 2) {
      cursor += (uint32_t)n * 2;
      continue;
    }
    if (cursor + (uint32_t)n * 2 > geom_count) break;
    if (n >= 3 &&
        xy_close(g[cursor], g[cursor + 1], g[cursor + (uint32_t)(n - 1) * 2],
                 g[cursor + (uint32_t)(n - 1) * 2 + 1])) {
      n -= 1;
    }
    if (n < 3) {
      cursor += (uint32_t)runs[r] * 2;
      continue;
    }
    body = rec++;
    lump = rec++;
    shell = rec++;
    face = rec++;
    loop = rec++;
    co0 = rec;
    rec += n;
    ed0 = rec;
    rec += n;
    v0 = rec;
    rec += n;
    p0 = rec;
    rec += n;
    if (!sat_fmt(&buf, &len, &cap, "body $-1 $%d $-1 $-1 #\n", lump)) goto fail;
    if (!sat_fmt(&buf, &len, &cap, "lump $-1 $-1 $%d $%d #\n", shell, body)) {
      goto fail;
    }
    if (!sat_fmt(&buf, &len, &cap, "shell $-1 $-1 $-1 $%d $-1 $%d #\n", face,
                 lump)) {
      goto fail;
    }
    if (!sat_fmt(&buf, &len, &cap,
                 "face $-1 $-1 $%d $-1 $%d $-1 $-1 forward single #\n", loop,
                 shell)) {
      goto fail;
    }
    if (!sat_fmt(&buf, &len, &cap, "loop $-1 $-1 $-1 $%d $%d #\n", co0, face)) {
      goto fail;
    }
    for (i = 0; i < n; i++) {
      int next = co0 + ((i + 1) % n);
      int edge = ed0 + i;
      if (!sat_fmt(&buf, &len, &cap,
                   "coedge $-1 $-1 $-1 $%d $-1 $-1 $%d forward #\n", next,
                   edge)) {
        goto fail;
      }
    }
    for (i = 0; i < n; i++) {
      int start_v = v0 + i;
      int end_v = v0 + ((i + 1) % n);
      if (!sat_fmt(&buf, &len, &cap,
                   "edge $-1 $-1 $%d $%d $%d $-1 $-1 $%d 0 1 #\n", co0 + i,
                   start_v, end_v, co0 + i)) {
        goto fail;
      }
    }
    for (i = 0; i < n; i++) {
      if (!sat_fmt(&buf, &len, &cap, "vertex $-1 $-1 $-1 $%d #\n", p0 + i)) {
        goto fail;
      }
    }
    for (i = 0; i < n; i++) {
      double x = g[cursor + (uint32_t)i * 2];
      double y = g[cursor + (uint32_t)i * 2 + 1];
      if (!sat_fmt(&buf, &len, &cap, "point $-1 $-1 %.17g %.17g 0 #\n", x, y)) {
        goto fail;
      }
    }
    cursor += (uint32_t)runs[r] * 2;
  }
  if (!buf || len == 0) goto fail;
  if (!sat_put(&buf, &len, &cap, "End-of-ACIS-data \n")) goto fail;
  return buf;
fail:
  free(buf);
  return NULL;
}

static void *export_unknown_solid(Dwg_Object_BLOCK_HEADER *hdr,
                                  const fcb_view *v, const uint8_t *rec,
                                  const double *g, uint32_t geom_count) {
  uint64_t int_off = fcb_u64(rec + FCB_ENT_INT_OFFSET);
  uint32_t int_count = fcb_u32(rec + FCB_ENT_INT_COUNT);
  uint32_t str_off = fcb_u32(rec + FCB_ENT_STRING_OFFSET);
  uint32_t str_count = fcb_u32(rec + FCB_ENT_STRING_COUNT);
  const int64_t *runs = NULL;
  char kind[NAME_CAP];
  char *sat;
  void *ent = NULL;
  kind[0] = '\0';
  if (str_count > 0) fcb_view_str(v, str_off, kind, sizeof(kind));
  if (ints_ok(v, int_off, int_count) && int_count > 0) runs = ints_at(v, int_off);
  sat = sat_from_strokes(g, geom_count, runs, runs ? int_count : 0);
  if (!sat) return NULL;
  if (ascii_ieq(kind, "3DSOLID")) ent = dwg_add_3DSOLID(hdr, sat);
  else if (ascii_ieq(kind, "BODY")) ent = dwg_add_BODY(hdr, sat);
  else ent = dwg_add_REGION(hdr, sat);
  free(sat);
  return ent;
}

static Dwg_Entity_MULTILEADER *export_multileader(
    Dwg_Data *dwg, Dwg_Object_BLOCK_HEADER *hdr, const fcb_view *v,
    const uint8_t *rec, const double *g, uint32_t geom_count, uint16_t flags) {
  uint64_t int_off = fcb_u64(rec + FCB_ENT_INT_OFFSET);
  uint32_t int_count = fcb_u32(rec + FCB_ENT_INT_COUNT);
  uint32_t str_off = fcb_u32(rec + FCB_ENT_STRING_OFFSET);
  uint32_t str_count = fcb_u32(rec + FCB_ENT_STRING_COUNT);
  char content[TEXT_CAP];
  unsigned nvert;
  unsigned npath = 1;
  const int64_t *paths = NULL;
  BITCODE_BL idx;
  int realloced;
  int err = 0;
  int klass;
  unsigned i;
  unsigned cursor = 0;
  Dwg_Object *blkobj;
  Dwg_Object *obj;
  Dwg_Entity_MULTILEADER *ml;
  Dwg_MLEADER_AnnotContext *ctx;
  if (!dwg || !hdr || !g || geom_count < 6) return NULL;
  nvert = (unsigned)((geom_count - 4) / 2);
  if (nvert < 2) return NULL;
  if (ints_ok(v, int_off, int_count) && int_count > 0) {
    paths = ints_at(v, int_off);
    npath = int_count;
  }
  content[0] = '\0';
  if (str_count > 0) fcb_view_str(v, str_off, content, sizeof(content));
  blkobj = dwg_obj_generic_to_object(hdr, &err);
  if (!blkobj) return NULL;
  idx = dwg->num_objects;
  realloced = dwg_add_object(dwg);
  if (realloced > 0) return NULL;
  if (realloced == -1) {
    blkobj = dwg_obj_generic_to_object(hdr, &err);
    if (!blkobj) return NULL;
  }
  obj = &dwg->object[idx];
  if (dwg_setup_MULTILEADER(obj) != 0) return NULL;
  klass = dwg_require_class(dwg, "MULTILEADER", 11);
  if (klass >= 500) obj->type = (Dwg_Object_Type)klass;
  dwg_add_entity_defaults(dwg, obj->tio.entity);
  dwg_set_next_objhandle(obj);
  obj->tio.entity->ownerhandle =
      dwg_add_handleref(dwg, 5, blkobj->handle.value, obj);
  dwg_insert_entity(hdr, obj);
  ml = obj->tio.entity->tio.MULTILEADER;
  if (!ml) return NULL;
  ml->type = 1;
  ml->has_landing = 1;
  ml->has_dogleg = 0;
  ml->style_content = 2;
  ml->arrow_size = 2.5;
  ml->scale_factor = 1.0;
  ctx = &ml->ctx;
  ctx->scale_factor = 1.0;
  ctx->text_height = g[geom_count - 2];
  if (ctx->text_height <= 0.0) ctx->text_height = 2.5;
  ctx->arrow_size = ctx->text_height;
  ctx->has_content_txt = 1;
  ctx->content.txt.type = 2;
  ctx->content.txt.location.x = g[geom_count - 4];
  ctx->content.txt.location.y = g[geom_count - 3];
  ctx->content.txt.location.z = 0.0;
  ctx->content.txt.height = ctx->text_height;
  ctx->content.txt.rotation = g[geom_count - 1];
  {
    char stored[TEXT_CAP];
    encode_tv(dwg, stored, sizeof(stored), content);
    assign_tv(&ctx->content.txt.default_text, stored);
  }
  ctx->content.txt.direction.x = cos(ctx->content.txt.rotation);
  ctx->content.txt.direction.y = sin(ctx->content.txt.rotation);
  ctx->content.txt.normal.z = 1.0;
  ctx->content_base = ctx->content.txt.location;
  ctx->base = ctx->content.txt.location;
  ctx->base_dir.x = 1.0;
  ctx->base_vert.z = 1.0;
  ctx->num_leaders = npath;
  ctx->leaders = (Dwg_LEADER_Node *)calloc(npath, sizeof(Dwg_LEADER_Node));
  if (!ctx->leaders) return ml;
  for (i = 0; i < npath; i++) {
    Dwg_LEADER_Node *node = &ctx->leaders[i];
    Dwg_LEADER_Line *line;
    unsigned npts = paths ? (unsigned)paths[i] : nvert;
    unsigned p;
    if (npts < 2) npts = 2;
    if (cursor + npts > nvert) npts = nvert - cursor;
    if (npts < 2) break;
    node->parent = ml;
    node->has_lastleaderlinepoint = 1;
    node->lastleaderlinepoint.x = g[(cursor + npts - 1) * 2];
    node->lastleaderlinepoint.y = g[(cursor + npts - 1) * 2 + 1];
    node->num_lines = 1;
    node->lines = (Dwg_LEADER_Line *)calloc(1, sizeof(Dwg_LEADER_Line));
    if (!node->lines) break;
    line = &node->lines[0];
    line->parent = node;
    line->type = 1;
    line->num_points = npts;
    line->points = (BITCODE_3DPOINT *)calloc(npts, sizeof(BITCODE_3DPOINT));
    if (!line->points) break;
    for (p = 0; p < npts; p++) {
      line->points[p].x = g[(cursor + p) * 2];
      line->points[p].y = g[(cursor + p) * 2 + 1];
    }
    cursor += npts;
  }
  bind_style(dwg, &ctx->content.txt.style, v, str_off, str_count);
  bind_style(dwg, &ml->text_style, v, str_off, str_count);
  (void)flags;
  return ml;
}

static void export_entity(Dwg_Data *dwg, Dwg_Object_BLOCK_HEADER *hdr,
                          const fcb_view *v, const uint8_t *rec,
                          Dwg_Object_BLOCK_HEADER **headers) {
  uint16_t type;
  uint16_t flags;
  uint64_t geom_off;
  uint32_t geom_count;
  uint32_t str_off;
  uint32_t str_count;
  const double *g;
  dwg_point_3d a;
  dwg_point_3d b;
  void *ent = NULL;

  if (!hdr) return;
  type = fcb_u16(rec + FCB_ENT_TYPE);
  flags = fcb_u16(rec + FCB_ENT_FLAGS);
  geom_off = fcb_u64(rec + FCB_ENT_GEOM_OFFSET);
  geom_count = fcb_u32(rec + FCB_ENT_GEOM_COUNT);
  str_off = fcb_u32(rec + FCB_ENT_STRING_OFFSET);
  str_count = fcb_u32(rec + FCB_ENT_STRING_COUNT);
  if (!geom_ok(v, geom_off, geom_count)) return;
  g = geom_count ? geom_at(v, geom_off) : NULL;

  switch (type) {
    case FCB_TYPE_LINE:
      if (geom_count < 4 || !g) return;
      a = pt3(g[0], g[1]);
      b = pt3(g[2], g[3]);
      ent = dwg_add_LINE(hdr, &a, &b);
      break;
    case FCB_TYPE_POINT:
      if (geom_count < 2 || !g) return;
      a = pt3(g[0], g[1]);
      ent = dwg_add_POINT(hdr, &a);
      break;
    case FCB_TYPE_CIRCLE:
      if (geom_count < 3 || !g) return;
      a = pt3(g[0], g[1]);
      ent = dwg_add_CIRCLE(hdr, &a, g[2]);
      break;
    case FCB_TYPE_ARC:
      if (geom_count < 5 || !g) return;
      a = pt3(g[0], g[1]);
      ent = dwg_add_ARC(hdr, &a, g[2], g[3], g[4]);
      break;
    case FCB_TYPE_POLYLINE: {
      int n;
      int i;
      int has_bulge = 0;
      dwg_point_2d *pts;
      Dwg_Entity_LWPOLYLINE *pline;
      /* FCB polyline geom is [x, y, bulge] * n, optionally followed by
       * constantWidth when geom_count % 3 == 1. */
      if (!g || geom_count < 6) return;
      n = (int)(geom_count / 3);
      if (n < 2) return;
      pts = (dwg_point_2d *)malloc((size_t)n * sizeof(dwg_point_2d));
      if (!pts) return;
      for (i = 0; i < n; i++) {
        pts[i].x = g[i * 3];
        pts[i].y = g[i * 3 + 1];
        if (g[i * 3 + 2] != 0.0) has_bulge = 1;
      }
      pline = dwg_add_LWPOLYLINE(hdr, n, pts);
      free(pts);
      if (pline) {
        if (flags & FCB_FLAG_CLOSED) pline->flag |= 512;
        if (geom_count == (uint32_t)n * 3 + 1 && g[n * 3] != 0.0) {
          pline->const_width = g[n * 3];
          pline->flag |= 4;
        }
        if (has_bulge) {
          if (!pline->bulges) {
            pline->bulges =
                (BITCODE_BD *)malloc((size_t)n * sizeof(BITCODE_BD));
          }
          if (pline->bulges) {
            pline->num_bulges = (BITCODE_BL)n;
            pline->flag |= 16;
            for (i = 0; i < n; i++) pline->bulges[i] = g[i * 3 + 2];
          }
        }
      }
      ent = pline;
      break;
    }
    case FCB_TYPE_TEXT: {
      char content[TEXT_CAP];
      char stored[TEXT_CAP];
      Dwg_Entity_TEXT *text;
      if (geom_count < 6 || !g) return;
      fcb_view_str(v, str_count > 0 ? str_off : 0, content, sizeof(content));
      encode_tv(dwg, stored, sizeof(stored), content);
      a = pt3(g[0], g[1]);
      text = dwg_add_TEXT(hdr, tv_api_arg(stored), &a, g[2]);
      if (text) {
        uint64_t int_off = fcb_u64(rec + FCB_ENT_INT_OFFSET);
        uint32_t int_count = fcb_u32(rec + FCB_ENT_INT_COUNT);
        assign_tv(&text->text_value, stored);
        text->rotation = g[3];
        text->width_factor = g[4] == 0 ? 1 : g[4];
        text->oblique_angle = g[5];
        if (ints_ok(v, int_off, int_count) && int_count >= 2) {
          const int64_t *ints = ints_at(v, int_off);
          text->horiz_alignment = (BITCODE_BS)ints[0];
          text->vert_alignment = (BITCODE_BS)ints[1];
        }
        /* Justified text paints from alignment_pt, and FanCAD keeps a single
         * position per string. Leaving alignment_pt at its zero default drags
         * every justified string to the origin. */
        text->alignment_pt.x = geom_count >= 8 ? g[6] : g[0];
        text->alignment_pt.y = geom_count >= 8 ? g[7] : g[1];
        bind_style(dwg, &text->style, v, str_off, str_count);
      }
      ent = text;
      break;
    }
    case FCB_TYPE_INSERT: {
      char block[NAME_CAP];
      uint64_t int_off = fcb_u64(rec + FCB_ENT_INT_OFFSET);
      uint32_t int_count = fcb_u32(rec + FCB_ENT_INT_COUNT);
      int64_t cols = 1;
      int64_t rows = 1;
      if (geom_count < 5 || !g) return;
      fcb_view_str(v, str_count > 0 ? str_off : 0, block, sizeof(block));
      if (!block[0]) return;
      a = pt3(g[0], g[1]);
      if (int_count >= 2 && int_off + 2 <= v->int_count) {
        cols = v->ints[int_off];
        rows = v->ints[int_off + 1];
      }
      if (cols < 1) cols = 1;
      if (rows < 1) rows = 1;
      {
        Dwg_Object_BLOCK_HEADER *target = header_named(v, headers, block);
        if (cols > 1 || rows > 1) {
          ent = export_insert_ref(dwg, hdr, target, &a, g[2], g[3], 1.0, g[4],
                                  (int)rows, (int)cols,
                                  geom_count > 6 ? g[6] : 0,
                                  geom_count > 5 ? g[5] : 0);
        } else {
          Dwg_Entity_INSERT *insert = (Dwg_Entity_INSERT *)export_insert_ref(
              dwg, hdr, target, &a, g[2], g[3], 1.0, g[4], 1, 1, 0, 0);
          if (insert && str_count >= 3) {
            /* dwg_add_ATTRIB overwrites insert->block_header with the block
             * that owns the INSERT, so a model space INSERT with attributes
             * ends up referencing *MODEL_SPACE and recurses forever. Keep the
             * definition we bound. */
            BITCODE_H definition = insert->block_header;
            uint32_t s;
            for (s = 1; s + 1 < str_count; s += 2) {
              char tag[NAME_CAP];
              char value[TEXT_CAP];
              char stored[TEXT_CAP];
              Dwg_Entity_ATTRIB *attrib;
              fcb_view_str(v, str_off + s, tag, sizeof(tag));
              fcb_view_str(v, str_off + s + 1, value, sizeof(value));
              if (!tag[0]) continue;
              encode_tv(dwg, stored, sizeof(stored), value);
              /* Same placeholder as ATTDEF: dwg_add_ATTRIB refuses a space,
               * '!', or lowercase letter and UNADDs the ATTRIB. */
              attrib = dwg_add_ATTRIB(insert, 2.5, 0, &a, "TAG",
                                      tv_api_arg(stored));
              if (attrib) assign_tv(&attrib->text_value, stored);
              if (attrib && tag[0]) {
                free(attrib->tag);
                attrib->tag = dwg_add_u8_input(dwg, tag);
              }
            }
            insert->block_header = definition;
          }
          ent = insert;
        }
      }
      break;
    }
    case FCB_TYPE_ELLIPSE: {
      Dwg_Entity_ELLIPSE *el;
      if (geom_count < 5 || !g) return;
      a = pt3(g[0], g[1]);
      el = dwg_add_ELLIPSE(hdr, &a, sqrt(g[2] * g[2] + g[3] * g[3]), g[4]);
      if (el) {
        el->sm_axis.x = g[2];
        el->sm_axis.y = g[3];
        el->sm_axis.z = 0;
        if (geom_count >= 7) {
          el->start_angle = g[5];
          el->end_angle = g[6];
        }
      }
      ent = el;
      break;
    }
    case FCB_TYPE_MTEXT: {
      char content[TEXT_CAP];
      char stored[TEXT_CAP];
      Dwg_Entity_MTEXT *mtext;
      uint64_t int_off = fcb_u64(rec + FCB_ENT_INT_OFFSET);
      uint32_t int_count = fcb_u32(rec + FCB_ENT_INT_COUNT);
      if (geom_count < 5 || !g) return;
      fcb_view_str(v, str_count > 0 ? str_off : 0, content, sizeof(content));
      encode_tv(dwg, stored, sizeof(stored), content);
      a = pt3(g[0], g[1]);
      mtext = dwg_add_MTEXT(hdr, &a, g[4], tv_api_arg(stored));
      if (mtext) {
        assign_tv(&mtext->text, stored);
        mtext->text_height = g[2];
        mtext->x_axis_dir.x = cos(g[3]);
        mtext->x_axis_dir.y = sin(g[3]);
        mtext->x_axis_dir.z = 0;
        if (ints_ok(v, int_off, int_count) && int_count >= 1) {
          mtext->attachment = hugging_attachment(
              (BITCODE_BS)ints_at(v, int_off)[0], g[4]);
        }
        bind_style(dwg, &mtext->style, v, str_off, str_count);
      }
      ent = mtext;
      break;
    }
    case FCB_TYPE_SPLINE:
      ent = export_spline(hdr, v, rec, g, geom_count);
      break;
    case FCB_TYPE_HATCH:
      ent = export_hatch(dwg, hdr, v, rec, g, geom_count);
      break;
    case FCB_TYPE_DIMENSION:
      ent = export_dimension(dwg, hdr, v, rec, g, geom_count);
      break;
    case FCB_TYPE_LEADER: {
      unsigned n;
      unsigned i;
      dwg_point_3d *pts;
      Dwg_Entity_LEADER *leader;
      if (!g || geom_count < 4) return;
      n = (unsigned)(geom_count / 2);
      pts = (dwg_point_3d *)malloc((size_t)n * sizeof(dwg_point_3d));
      if (!pts) return;
      for (i = 0; i < n; i++) pts[i] = pt3(g[i * 2], g[i * 2 + 1]);
      leader = dwg_add_LEADER(hdr, n, pts, NULL, 1);
      free(pts);
      if (leader) leader->arrowhead_on = (flags & FCB_FLAG_ARROW_HEAD) ? 1 : 0;
      ent = leader;
      break;
    }
    case FCB_TYPE_MLEADER: {
      Dwg_Entity_MULTILEADER *ml = NULL;
      /* MULTILEADER is an AutoCAD 2008 class. Writing it into r2000/r2004
       * makes GstarCAD report a corrupt drawing and drop the callouts. */
      if (dwg->header.version >= R_2007) {
        ml = export_multileader(dwg, hdr, v, rec, g, geom_count, flags);
      }
      if (ml) {
        ent = ml;
        break;
      }
      /* If the class entity cannot be built, keep the callout visible. */
      {
        char content[TEXT_CAP];
        char stored[TEXT_CAP];
        unsigned nvert;
        unsigned i;
        dwg_point_3d *pts;
        Dwg_Entity_MTEXT *mtext;
        Dwg_Entity_LEADER *leader;
        if (!g || geom_count < 6) return;
        nvert = (unsigned)((geom_count - 4) / 2);
        if (nvert < 2) return;
        fcb_view_str(v, str_count > 0 ? str_off : 0, content, sizeof(content));
        encode_tv(dwg, stored, sizeof(stored), content);
        a = pt3(g[geom_count - 4], g[geom_count - 3]);
        mtext = dwg_add_MTEXT(hdr, &a, 0, tv_api_arg(stored));
        if (mtext) {
          assign_tv(&mtext->text, stored);
          mtext->text_height = g[geom_count - 2];
          mtext->x_axis_dir.x = cos(g[geom_count - 1]);
          mtext->x_axis_dir.y = sin(g[geom_count - 1]);
          bind_style(dwg, &mtext->style, v, str_off, str_count);
        }
        pts = (dwg_point_3d *)malloc((size_t)nvert * sizeof(dwg_point_3d));
        if (!pts) {
          ent = mtext;
          break;
        }
        for (i = 0; i < nvert; i++) pts[i] = pt3(g[i * 2], g[i * 2 + 1]);
        leader = dwg_add_LEADER(hdr, nvert, pts, mtext, 0);
        free(pts);
        if (leader) leader->arrowhead_on = (flags & FCB_FLAG_ARROW_HEAD) ? 1 : 0;
        if (mtext) bind_entity(dwg, hdr, mtext, v, rec);
        ent = leader ? (void *)leader : (void *)mtext;
      }
      break;
    }
    case FCB_TYPE_SOLID: {
      dwg_point_3d c1;
      dwg_point_2d c2;
      dwg_point_2d c3;
      dwg_point_2d c4;
      if (!g || geom_count < 6) return;
      c1 = pt3(g[0], g[1]);
      c2 = pt2(g[2], g[3]);
      if (geom_count >= 8) {
        /* FanCAD stores a boundary walk; DWG SOLID is Z-order. */
        c4 = pt2(g[4], g[5]);
        c3 = pt2(g[6], g[7]);
      } else {
        c3 = pt2(g[4], g[5]);
        c4 = c3;
      }
      ent = dwg_add_SOLID(hdr, &c1, &c2, &c3, &c4);
      break;
    }
    case FCB_TYPE_RAY:
    case FCB_TYPE_XLINE: {
      dwg_point_3d origin;
      dwg_point_3d dir;
      if (!g || geom_count < 4) return;
      origin = pt3(g[0], g[1]);
      dir = pt3(g[2], g[3]);
      ent = (type == FCB_TYPE_RAY) ? (void *)dwg_add_RAY(hdr, &origin, &dir)
                                   : (void *)dwg_add_XLINE(hdr, &origin, &dir);
      break;
    }
    case FCB_TYPE_IMAGE: {
      char path[TEXT_CAP];
      double scale;
      double rot;
      Dwg_Entity_IMAGE *img;
      if (!g || geom_count < 6) return;
      fcb_view_str(v, str_count > 0 ? str_off : 0, path, sizeof(path));
      a = pt3(g[0], g[1]);
      scale = sqrt(g[2] * g[2] + g[3] * g[3]);
      if (scale == 0) scale = 1;
      rot = atan2(g[3], g[2]);
      img = dwg_add_IMAGE(hdr, path[0] ? path : "image.png", &a, scale, rot);
      if (img) {
        double ulen = sqrt(g[2] * g[2] + g[3] * g[3]);
        double vlen = sqrt(g[4] * g[4] + g[5] * g[5]);
        if (ulen == 0) ulen = 1;
        if (vlen == 0) vlen = 1;
        img->uvec.x = g[2] / ulen;
        img->uvec.y = g[3] / ulen;
        img->uvec.z = 0;
        img->vvec.x = g[4] / vlen;
        img->vvec.y = g[5] / vlen;
        img->vvec.z = 0;
        img->image_size.x = ulen;
        img->image_size.y = vlen;
      }
      ent = img;
      break;
    }
    case FCB_TYPE_ATTDEF: {
      char value[TEXT_CAP];
      char tag[NAME_CAP];
      char prompt[TEXT_CAP];
      uint64_t int_off = fcb_u64(rec + FCB_ENT_INT_OFFSET);
      uint32_t int_count = fcb_u32(rec + FCB_ENT_INT_COUNT);
      int mode = 0;
      if (geom_count < 6 || !g) return;
      fcb_view_str(v, str_count > 0 ? str_off : 0, value, sizeof(value));
      fcb_view_str(v, str_count > 2 ? str_off + 2 : 0, tag, sizeof(tag));
      fcb_view_str(v, str_count > 3 ? str_off + 3 : 0, prompt, sizeof(prompt));
      {
        char stored_value[TEXT_CAP];
        char stored_prompt[TEXT_CAP];
        encode_tv(dwg, stored_value, sizeof(stored_value), value);
        encode_tv(dwg, stored_prompt, sizeof(stored_prompt), prompt);
        strncpy(value, stored_value, sizeof(value) - 1);
        value[sizeof(value) - 1] = '\0';
        strncpy(prompt, stored_prompt, sizeof(prompt) - 1);
        prompt[sizeof(prompt) - 1] = '\0';
      }
      if (ints_ok(v, int_off, int_count) && int_count >= 3) {
        mode = (int)ints_at(v, int_off)[2];
      }
      a = pt3(g[0], g[1]);
      {
        /* dwg_add_ATTDEF refuses a tag holding a space, '!' or a lowercase
         * letter, and drops the whole ATTDEF with it. Real drawings carry
         * those tags, so build it under a placeholder and put the file's own
         * tag back. */
        Dwg_Entity_ATTDEF *ad =
            dwg_add_ATTDEF(hdr, g[2], mode, tv_api_arg(prompt), &a, "TAG",
                           tv_api_arg(value));
        if (ad) {
          assign_tv(&ad->default_value, value);
          assign_tv(&ad->prompt, prompt);
          if (tag[0]) {
            free(ad->tag);
            ad->tag = dwg_add_u8_input(dwg, tag);
          }
          ad->rotation = g[3];
          ad->width_factor = g[4] == 0 ? 1 : g[4];
          ad->oblique_angle = g[5];
          if (ints_ok(v, int_off, int_count) && int_count >= 2) {
            const int64_t *ints = ints_at(v, int_off);
            ad->horiz_alignment = (BITCODE_BS)ints[0];
            ad->vert_alignment = (BITCODE_BS)ints[1];
          }
          ad->alignment_pt.x = geom_count >= 8 ? g[6] : g[0];
          ad->alignment_pt.y = geom_count >= 8 ? g[7] : g[1];
        }
        ent = ad;
      }
      break;
    }
    case FCB_TYPE_ATTRIB: {
      char value[TEXT_CAP];
      char stored[TEXT_CAP];
      if (geom_count < 6 || !g) return;
      fcb_view_str(v, str_count > 0 ? str_off : 0, value, sizeof(value));
      encode_tv(dwg, stored, sizeof(stored), value);
      a = pt3(g[0], g[1]);
      {
        Dwg_Entity_TEXT *text = dwg_add_TEXT(hdr, tv_api_arg(stored), &a, g[2]);
        if (text) assign_tv(&text->text_value, stored);
        ent = text;
      }
      break;
    }
    case FCB_TYPE_UNKNOWN: {
      if (!g || geom_count < 6) return;
      ent = export_unknown_solid(hdr, v, rec, g, geom_count);
      if (ent) break;
      /* Strokes that cannot form a REGION stay visible as polylines. */
      {
        uint64_t int_off = fcb_u64(rec + FCB_ENT_INT_OFFSET);
        uint32_t int_count = fcb_u32(rec + FCB_ENT_INT_COUNT);
        uint32_t cursor = 4;
        if (ints_ok(v, int_off, int_count) && int_count > 0) {
          const int64_t *ints = ints_at(v, int_off);
          uint32_t r;
          for (r = 0; r < int_count; r++) {
            int n = (int)ints[r];
            int i;
            dwg_point_2d *pts;
            if (n < 2) {
              cursor += (uint32_t)n * 2;
              continue;
            }
            pts = (dwg_point_2d *)malloc((size_t)n * sizeof(dwg_point_2d));
            if (!pts) continue;
            for (i = 0; i < n; i++) {
              if (cursor + 1 >= geom_count) break;
              pts[i].x = g[cursor++];
              pts[i].y = g[cursor++];
            }
            ent = dwg_add_LWPOLYLINE(hdr, n, pts);
            bind_entity(dwg, hdr, ent, v, rec);
            free(pts);
          }
        } else {
          int n = (int)((geom_count - 4) / 2);
          int i;
          dwg_point_2d *pts;
          if (n < 2) return;
          pts = (dwg_point_2d *)malloc((size_t)n * sizeof(dwg_point_2d));
          if (!pts) return;
          for (i = 0; i < n; i++) {
            pts[i].x = g[4 + i * 2];
            pts[i].y = g[5 + i * 2];
          }
          ent = dwg_add_LWPOLYLINE(hdr, n, pts);
          free(pts);
        }
      }
      break;
    }
    default:
      return;
  }

  bind_entity(dwg, hdr, ent, v, rec);
}

static int is_default_layer(const char *name) { return streq(name, "0"); }

static int is_default_ltype(const char *name) {
  return streq(name, "Continuous") || streq(name, "ByLayer") ||
         streq(name, "ByBlock");
}

static int is_default_style(const char *name) { return streq(name, "Standard"); }

static int is_default_dimstyle(const char *name) {
  return streq(name, "Standard");
}

static void fill_ltype_dashes(Dwg_Data *dwg, Dwg_Object_LTYPE *lt,
                              const fcb_view *v, const uint8_t *rec) {
  uint32_t offset;
  uint32_t count;
  uint32_t n;
  uint32_t i;
  double length;
  char desc[TEXT_CAP];
  if (!lt || !rec) return;
  fcb_view_str(v, fcb_u32(rec + FCB_LTYPE_DESCRIPTION), desc, sizeof(desc));
  if (desc[0]) {
    char stored[TEXT_CAP];
    encode_tv(dwg, stored, sizeof(stored), desc);
    assign_tv(&lt->description, stored);
  }
  offset = fcb_u32(rec + FCB_LTYPE_PATTERN_OFFSET);
  count = fcb_u32(rec + FCB_LTYPE_PATTERN_COUNT);
  length = fcb_f64(rec + FCB_LTYPE_PATTERN_LENGTH);
  if (count == 0 || !v->doubles) return;
  if ((uint64_t)offset + count > v->double_count) return;
  n = count > 255 ? 255 : count;
  lt->dashes = (Dwg_LTYPE_dash *)calloc((size_t)n, sizeof(Dwg_LTYPE_dash));
  if (!lt->dashes) return;
  lt->numdashes = (BITCODE_RC)n;
  for (i = 0; i < n; i++) {
    double dash = v->doubles[offset + i];
    lt->dashes[i].parent = lt;
    lt->dashes[i].length = dash;
    lt->dashes[i].scale = 1.0;
    if (i < 12) lt->dashes_r11[i] = dash;
    if (length == 0.0) length += dash < 0 ? -dash : dash;
  }
  lt->pattern_len = length;
}

static void fill_style_metrics(Dwg_Data *dwg, Dwg_Object_STYLE *style,
                               const fcb_view *v, const uint8_t *rec) {
  char font[NAME_CAP];
  char bigfont[NAME_CAP];
  uint32_t flags;
  if (!style || !rec) return;
  fcb_view_str(v, fcb_u32(rec + FCB_STYLE_FONT), font, sizeof(font));
  fcb_view_str(v, fcb_u32(rec + FCB_STYLE_BIGFONT), bigfont, sizeof(bigfont));
  /* dwg_add_STYLE plants txt. An empty font in the source means FONTALT
   * (Chinese bigfont). Leaving txt makes GstarCAD stroke CJK TEXT as `?`. */
  {
    char stored[NAME_CAP];
    encode_tv(dwg, stored, sizeof(stored), font);
    assign_tv(&style->font_file, stored);
    encode_tv(dwg, stored, sizeof(stored), bigfont);
    assign_tv(&style->bigfont_file, stored);
  }
  style->text_size = fcb_f64(rec + FCB_STYLE_HEIGHT);
  style->width_factor = fcb_f64(rec + FCB_STYLE_WIDTH);
  if (style->width_factor == 0.0) style->width_factor = 1.0;
  style->oblique_angle = fcb_f64(rec + FCB_STYLE_OBLIQUE);
  flags = fcb_u32(rec + FCB_STYLE_FLAGS);
  if (flags & 1) style->generation = (BITCODE_RC)(style->generation | 2);
  if (flags & 2) style->generation = (BITCODE_RC)(style->generation | 4);
}

static void apply_header_vars(Dwg_Data *dwg, const fcb_view *v) {
  uint64_t i;
  char key[NAME_CAP];
  char value[NAME_CAP];
  for (i = 0; i < v->headervar_count; i++) {
    const uint8_t *rec = fcb_view_header_var(v, i);
    if (!rec) continue;
    fcb_view_str(v, fcb_u32(rec + FCB_HEADERVAR_KEY), key, sizeof(key));
    fcb_view_str(v, fcb_u32(rec + FCB_HEADERVAR_VALUE), value, sizeof(value));
    if (streq(key, "$LTSCALE")) {
      dwg->header_vars.LTSCALE = strtod(value, NULL);
    } else if (streq(key, "$INSUNITS")) {
      dwg->header_vars.INSUNITS = (BITCODE_BS)atoi(value);
    } else if (streq(key, "$PDMODE")) {
      dwg->header_vars.PDMODE = (BITCODE_BS)atoi(value);
    } else if (streq(key, "$PDSIZE")) {
      dwg->header_vars.PDSIZE = strtod(value, NULL);
    } else if (streq(key, "$DWGCODEPAGE")) {
      dwg->header.codepage = (BITCODE_RS)atoi(value);
    }
  }
}

static int layout_is_model_name(const char *name) {
  return streq(name, "Model") || streq(name, "MODEL");
}

static unsigned fcb_paper_layout_count(const fcb_view *view) {
  uint64_t i;
  unsigned n = 0;
  if (!view) return 0;
  for (i = 0; i < view->layout_count; i++) {
    const uint8_t *rec = fcb_view_layout(view, i);
    if (!rec) continue;
    if (fcb_u32(rec + FCB_LAYOUT_FLAGS) & FCB_LAYOUT_MODEL_SPACE) continue;
    n++;
  }
  return n;
}

static void apply_model_paper_size(Dwg_Data *dwg, const fcb_view *view) {
  uint64_t i;
  double width = 0;
  double height = 0;
  BITCODE_BL k;
  if (!dwg || !view) return;
  for (i = 0; i < view->layout_count; i++) {
    const uint8_t *rec = fcb_view_layout(view, i);
    if (!rec) continue;
    if (!(fcb_u32(rec + FCB_LAYOUT_FLAGS) & FCB_LAYOUT_MODEL_SPACE)) continue;
    width = fcb_f64(rec + FCB_LAYOUT_WIDTH);
    height = fcb_f64(rec + FCB_LAYOUT_HEIGHT);
    break;
  }
  if (width <= 0.0 || height <= 0.0) return;
  for (k = 0; k < dwg->num_objects; k++) {
    Dwg_Object *obj = &dwg->object[k];
    Dwg_Object_LAYOUT *lo;
    if (obj->supertype != DWG_SUPERTYPE_OBJECT) continue;
    if (obj->fixedtype != DWG_TYPE_LAYOUT || !obj->tio.object) continue;
    lo = obj->tio.object->tio.LAYOUT;
    if (!lo || !layout_is_model_name(lo->layout_name)) continue;
    lo->plotsettings.paper_width = width;
    lo->plotsettings.paper_height = height;
    lo->LIMMAX.x = width;
    lo->LIMMAX.y = height;
  }
}

/* dwg_new_Document always creates Layout1 at A3. Drop it when the source
 * drawing has no paper tab, so save-reopen does not grow a blank sheet. */
static void drop_default_paper_layout(Dwg_Data *dwg) {
  BITCODE_H dictref;
  Dwg_Object *dictobj = NULL;
  Dwg_Object_DICTIONARY *dict = NULL;
  Dwg_Object_BLOCK_HEADER *pspace;
  BITCODE_BL k;
  BITCODE_BL i;
  BITCODE_BL w;
  if (!dwg) return;
  for (k = 0; k < dwg->num_objects; k++) {
    Dwg_Object *obj = &dwg->object[k];
    Dwg_Object_LAYOUT *lo;
    if (obj->supertype != DWG_SUPERTYPE_OBJECT) continue;
    if (obj->fixedtype != DWG_TYPE_LAYOUT || !obj->tio.object) continue;
    lo = obj->tio.object->tio.LAYOUT;
    if (!lo || layout_is_model_name(lo->layout_name)) continue;
    obj->type = DWG_TYPE_UNUSED;
    obj->fixedtype = DWG_TYPE_UNUSED;
  }
  dictref = dwg_find_dictionary(dwg, "ACAD_LAYOUT");
  if (dictref) {
    BITCODE_RLL abs = dictref->absolute_ref;
    for (k = 0; k < dwg->num_objects; k++) {
      if (dwg->object[k].handle.value == abs) {
        dictobj = &dwg->object[k];
        break;
      }
    }
  }
  if (dictobj && dictobj->tio.object) dict = dictobj->tio.object->tio.DICTIONARY;
  if (dict && dict->texts && dict->itemhandles) {
    w = 0;
    for (i = 0; i < dict->numitems; i++) {
      const char *text = dict->texts[i];
      if (text && !layout_is_model_name(text)) continue;
      if (w != i) {
        dict->texts[w] = dict->texts[i];
        dict->itemhandles[w] = dict->itemhandles[i];
      }
      w++;
    }
    dict->numitems = w;
  }
  pspace = header_of(dwg_paper_space_object(dwg));
  if (pspace) pspace->layout = dwg_add_handleref(dwg, 5, 0, NULL);
}

/* dwg_add_* calls API_UNADD_ENTITY on failure (INSERT name miss, bad hatch,
 * ...). That leaves type=UNUSED in the object map while first/last/next still
 * point at it. The encoder then skips UNUSED, so GstarCAD follows a handle
 * that is not in the file and offers to recover a "corrupted" drawing. */
static int is_live_owned_entity(const Dwg_Object *obj) {
  if (!obj || obj->supertype != DWG_SUPERTYPE_ENTITY || !obj->tio.entity) {
    return 0;
  }
  if (obj->type == DWG_TYPE_UNUSED || obj->type == DWG_TYPE_FREED) return 0;
  if (obj->fixedtype == DWG_TYPE_BLOCK || obj->fixedtype == DWG_TYPE_ENDBLK ||
      obj->fixedtype == DWG_TYPE_SEQEND) {
    return 0;
  }
  if (dwg_obj_is_subentity(obj)) return 0;
  return 1;
}

static void bind_viewport_entity(Dwg_Data *dwg, Dwg_Object_BLOCK_HEADER *hdr,
                                 Dwg_Entity_VIEWPORT *vp, const char *layer) {
  int err = 0;
  Dwg_Object *obj;
  Dwg_Object_Entity *common;
  BITCODE_H href;
  Dwg_Object_BLOCK_HEADER *model;
  Dwg_Object_BLOCK_HEADER *paper;

  if (!vp) return;
  obj = dwg_obj_generic_to_object(vp, &err);
  if (!obj || obj->supertype != DWG_SUPERTYPE_ENTITY) return;
  common = obj->tio.entity;
  if (!common) return;

  if (layer && layer[0]) {
    href = find_named(dwg, layer, "LAYER");
    if (href) common->layer = href;
  }

  model = header_of(dwg_model_space_object(dwg));
  paper = header_of(dwg_paper_space_object(dwg));
  if (hdr == paper) {
    common->entmode = 1;
  } else if (hdr && hdr != model) {
    common->entmode = 0;
  }
}

/* R2000 stores VPLAYER as hard pointers (code 5); R2004+ as soft (code 4). */
static void bind_frozen_layers(Dwg_Data *dwg, Dwg_Entity_VIEWPORT *vp,
                               const char *csv) {
  const char *p = csv;
  BITCODE_BL n = 0;
  BITCODE_BL cap = 0;
  BITCODE_H *hs = NULL;
  unsigned hcode;

  if (!dwg || !vp || !csv || !csv[0]) return;
  hcode = (dwg->header.version >= R_2004) ? 4u : 5u;
  while (*p) {
    char name[NAME_CAP];
    size_t len = 0;
    BITCODE_H found;
    while (*p == ',' || *p == ' ') p++;
    if (!*p) break;
    while (p[len] && p[len] != ',') len++;
    if (len >= sizeof(name)) len = sizeof(name) - 1;
    memcpy(name, p, len);
    name[len] = '\0';
    while (len > 0 && name[len - 1] == ' ') name[--len] = '\0';
    p += len;
    if (*p == ',') p++;
    if (!name[0]) continue;
    found = find_named(dwg, name, "LAYER");
    if (!found) continue;
    if (n == cap) {
      BITCODE_BL next = cap ? cap * 2 : 4;
      BITCODE_H *tmp = (BITCODE_H *)realloc(hs, (size_t)next * sizeof(*hs));
      if (!tmp) {
        free(hs);
        return;
      }
      hs = tmp;
      cap = next;
    }
    hs[n++] = dwg_add_handleref(dwg, hcode, found->absolute_ref, NULL);
  }
  if (n == 0) {
    free(hs);
    return;
  }
  vp->frozen_layers = hs;
  vp->num_frozen_layers = n;
}

/* R2000 does not store VIEWPORT.id. LibreDWG numbers them on read: first
 * paper-space window becomes 1 (the sheet itself). Write that window first
 * so model holes come back as 2, 3, … and FanCAD's importer still drops 1. */
static void export_sheet_viewport(Dwg_Data *dwg, Dwg_Object_BLOCK_HEADER *hdr,
                                  double paper_width, double paper_height) {
  Dwg_Entity_VIEWPORT *vp;
  if (!hdr || paper_width <= 0.0 || paper_height <= 0.0) return;
  vp = dwg_add_VIEWPORT(hdr, "");
  if (!vp) return;
  vp->center.x = paper_width * 0.5;
  vp->center.y = paper_height * 0.5;
  vp->center.z = 0.0;
  vp->width = paper_width;
  vp->height = paper_height;
  vp->VIEWCTR.x = vp->center.x;
  vp->VIEWCTR.y = vp->center.y;
  vp->VIEWSIZE = paper_height;
  vp->VIEWTWIST = 0.0;
  vp->id = 1;
  vp->on_off = 1;
  bind_viewport_entity(dwg, hdr, vp, "0");
}

static void export_model_viewport(Dwg_Data *dwg, Dwg_Object_BLOCK_HEADER *hdr,
                                  const fcb_view *view, const uint8_t *rec,
                                  uint16_t id) {
  Dwg_Entity_VIEWPORT *vp;
  uint32_t flags;
  double min_x;
  double min_y;
  double max_x;
  double max_y;
  double width;
  double height;
  double scale;
  char layer[NAME_CAP];
  char frozen[TEXT_CAP];

  min_x = fcb_f64(rec + FCB_VP_PAPER_MIN_X);
  min_y = fcb_f64(rec + FCB_VP_PAPER_MIN_Y);
  max_x = fcb_f64(rec + FCB_VP_PAPER_MAX_X);
  max_y = fcb_f64(rec + FCB_VP_PAPER_MAX_Y);
  width = max_x - min_x;
  height = max_y - min_y;
  if (width <= 0.0 || height <= 0.0) return;

  vp = dwg_add_VIEWPORT(hdr, "");
  if (!vp) return;
  flags = fcb_u32(rec + FCB_VP_FLAGS);
  scale = fcb_f64(rec + FCB_VP_SCALE);
  vp->center.x = (min_x + max_x) * 0.5;
  vp->center.y = (min_y + max_y) * 0.5;
  vp->center.z = 0.0;
  vp->width = width;
  vp->height = height;
  vp->VIEWCTR.x = fcb_f64(rec + FCB_VP_MODEL_X);
  vp->VIEWCTR.y = fcb_f64(rec + FCB_VP_MODEL_Y);
  vp->VIEWSIZE = scale > 0.0 ? height / scale : height;
  vp->VIEWTWIST = fcb_f64(rec + FCB_VP_ROTATION);
  vp->id = id;
  vp->on_off = (flags & FCB_VIEWPORT_ON) ? 1 : 0;
  if (flags & FCB_VIEWPORT_LOCKED) vp->status_flag |= 16384u;
  if (!(flags & FCB_VIEWPORT_ON)) vp->status_flag |= 131072u;
  fcb_view_str(view, fcb_u32(rec + FCB_VP_LAYER), layer, sizeof(layer));
  bind_viewport_entity(dwg, hdr, vp, layer[0] ? layer : "0");
  fcb_view_str(view, fcb_u32(rec + FCB_VP_FROZEN), frozen, sizeof(frozen));
  bind_frozen_layers(dwg, vp, frozen);
}

static void export_paper_viewports(Dwg_Data *dwg, const fcb_view *view,
                                   Dwg_Object_BLOCK_HEADER **headers) {
  uint64_t li;
  if (!dwg || !view) return;
  for (li = 0; li < view->layout_count; li++) {
    const uint8_t *layout = fcb_view_layout(view, li);
    Dwg_Object_BLOCK_HEADER *hdr = NULL;
    uint32_t block;
    uint16_t id = 2;
    uint64_t i;
    if (!layout) continue;
    if (fcb_u32(layout + FCB_LAYOUT_FLAGS) & FCB_LAYOUT_MODEL_SPACE) continue;
    block = fcb_u32(layout + FCB_LAYOUT_BLOCK);
    if (headers && block < view->block_count) hdr = headers[block];
    if (!hdr) continue;
    export_sheet_viewport(dwg, hdr, fcb_f64(layout + FCB_LAYOUT_WIDTH),
                          fcb_f64(layout + FCB_LAYOUT_HEIGHT));
    for (i = 0; i < view->viewport_count; i++) {
      const uint8_t *rec = fcb_view_viewport(view, i);
      if (!rec || fcb_u32(rec + FCB_VP_LAYOUT) != (uint32_t)li) continue;
      export_model_viewport(dwg, hdr, view, rec, id++);
    }
  }
}

static void relink_block_entities(Dwg_Data *dwg) {
  BITCODE_BL b;
  BITCODE_BL i;
  if (!dwg) return;
  for (b = 0; b < dwg->num_objects; b++) {
    Dwg_Object *hdr_obj = &dwg->object[b];
    Dwg_Object_BLOCK_HEADER *hdr;
    Dwg_Object **owned = NULL;
    BITCODE_BL n = 0;
    BITCODE_BL cap = 0;
    BITCODE_RLL hv;
    BITCODE_BL k;
    if (hdr_obj->type == DWG_TYPE_UNUSED || hdr_obj->type == DWG_TYPE_FREED) {
      continue;
    }
    if (hdr_obj->fixedtype != DWG_TYPE_BLOCK_HEADER || !hdr_obj->tio.object) {
      continue;
    }
    hdr = hdr_obj->tio.object->tio.BLOCK_HEADER;
    if (!hdr) continue;
    hv = hdr_obj->handle.value;
    for (i = 0; i < dwg->num_objects; i++) {
      Dwg_Object *obj = &dwg->object[i];
      BITCODE_H own;
      if (!is_live_owned_entity(obj)) continue;
      own = obj->tio.entity->ownerhandle;
      if (!own || own->absolute_ref != hv) continue;
      if (n == cap) {
        BITCODE_BL next = cap ? cap * 2 : 32;
        Dwg_Object **tmp =
            (Dwg_Object **)realloc(owned, (size_t)next * sizeof(*owned));
        if (!tmp) {
          free(owned);
          return;
        }
        owned = tmp;
        cap = next;
      }
      owned[n++] = obj;
    }
    if (hdr->entities) {
      free(hdr->entities);
      hdr->entities = NULL;
    }
    hdr->num_owned = n;
    if (n == 0) {
      hdr->first_entity = dwg_add_handleref(dwg, 4, 0, NULL);
      hdr->last_entity = dwg_add_handleref(dwg, 4, 0, NULL);
      free(owned);
      continue;
    }
    hdr->entities = (BITCODE_H *)calloc((size_t)n, sizeof(BITCODE_H));
    for (k = 0; k < n; k++) {
      Dwg_Object_Entity *ent = owned[k]->tio.entity;
      BITCODE_RLL prev_h = k ? owned[k - 1]->handle.value : 0;
      BITCODE_RLL next_h = (k + 1 < n) ? owned[k + 1]->handle.value : 0;
      ent->prev_entity = dwg_add_handleref(dwg, 4, prev_h, owned[k]);
      ent->next_entity = dwg_add_handleref(dwg, 4, next_h, owned[k]);
      ent->nolinks = 0;
      if (hdr->entities) {
        hdr->entities[k] =
            dwg_add_handleref(dwg, 3, owned[k]->handle.value, NULL);
      }
    }
    hdr->first_entity = dwg_add_handleref(dwg, 4, owned[0]->handle.value, NULL);
    hdr->last_entity =
        dwg_add_handleref(dwg, 4, owned[n - 1]->handle.value, NULL);
    free(owned);
  }
}

static int write_tmp_and_replace(const char *dwg_path, Dwg_Data *dwg,
                                 char *error_out, size_t error_capacity) {
  char tmp[4096];
  char bak[4096];
  int error;
  int had_dest = 0;
  size_t len = strlen(dwg_path);
  if (len + 5 >= sizeof(tmp)) {
    set_error(error_out, error_capacity, "DWG path is too long");
    return FC_STATUS_INVALID_ARGUMENT;
  }
  snprintf(tmp, sizeof(tmp), "%s.tmp", dwg_path);
  snprintf(bak, sizeof(bak), "%s.bak", dwg_path);
  remove(tmp);
  remove(bak);
  /* dwg_new_Document sets DWG_OPTS_IN, which includes INJSON. bit_write_TV
   * then runs bit_utf8_to_TV on every string. FanCAD already stored TV in
   * the drawing codepage; treating those bytes as UTF-8 turns 型材 into Ѝı
   * and GstarCAD shows `?`. */
  dwg->opts &= (unsigned)~DWG_OPTS_INJSON;
  error = dwg_write_file(tmp, dwg);
  if (error >= DWG_ERR_CRITICAL) {
    remove(tmp);
    if (error_out && error_capacity > 0) {
      snprintf(error_out, error_capacity,
               "LibreDWG could not write %s (status %d)", dwg_path, error);
    }
    return FC_STATUS_UNSUPPORTED;
  }
  /* Move the existing file aside first. Deleting it before rename
   * succeeds would leave the user with neither file if replace fails.
   * LibreDWG refuses to overwrite the destination path. */
  if (rename(dwg_path, bak) == 0) had_dest = 1;
  if (rename(tmp, dwg_path) != 0) {
    if (had_dest) rename(bak, dwg_path);
    remove(tmp);
    set_error(error_out, error_capacity, "Could not replace the DWG file");
    return FC_STATUS_UNSUPPORTED;
  }
  if (had_dest) remove(bak);
  return FC_STATUS_OK;
}

int fcdwg_export_fcb_to_dwg(const uint8_t *fcb, uint64_t length,
                            const char *dwg_path, int32_t target_version,
                            char *error_out, size_t error_capacity) {
  fcb_view view;
  Dwg_Data *dwg = NULL;
  Dwg_Object_BLOCK_HEADER **headers = NULL;
  unsigned char *needs_endblk = NULL;
  Dwg_Version_Type version;
  uint64_t i;
  int status = FC_STATUS_OK;

  if (!fcb || !dwg_path) {
    set_error(error_out, error_capacity, "fcdwg_export: invalid argument");
    return FC_STATUS_INVALID_ARGUMENT;
  }
  if (fcb_view_open(&view, fcb, length) != 0) {
    set_error(error_out, error_capacity, "The FCB buffer is not a valid drawing");
    return FC_STATUS_PARSE_ERROR;
  }

  version = (target_version == 2004) ? R_2004 : R_2000;
  dwg = dwg_new_Document(version, 0, 0);
  if (!dwg) {
    set_error(error_out, error_capacity, "LibreDWG could not create a drawing");
    return FC_STATUS_OUT_OF_MEMORY;
  }
  dwg->header.version = version;
  apply_header_vars(dwg, &view);
  apply_model_paper_size(dwg, &view);

  for (i = 0; i < view.linetype_count; i++) {
    const uint8_t *rec = fcb_view_linetype(&view, i);
    char name[NAME_CAP];
    if (!rec) continue;
    fcb_view_str(&view, fcb_u32(rec + FCB_LTYPE_NAME), name, sizeof(name));
    if (!name[0] || is_default_ltype(name)) continue;
    if (!find_named(dwg, name, "LTYPE")) {
      char stored[MIF_CAP];
      Dwg_Object_LTYPE *lt =
          dwg_add_LTYPE(dwg, mif_name(name, stored, sizeof(stored)));
      if (lt) fill_ltype_dashes(dwg, lt, &view, rec);
    }
  }

  for (i = 0; i < view.textstyle_count; i++) {
    const uint8_t *rec = fcb_view_textstyle(&view, i);
    char name[NAME_CAP];
    if (!rec) continue;
    fcb_view_str(&view, fcb_u32(rec + FCB_STYLE_NAME), name, sizeof(name));
    if (!name[0]) continue;
    if (is_default_style(name)) {
      Dwg_Object_STYLE *style =
          style_of_handle(dwg, find_named(dwg, name, "STYLE"));
      if (style) fill_style_metrics(dwg, style, &view, rec);
      continue;
    }
    if (!find_named(dwg, name, "STYLE")) {
      char stored[MIF_CAP];
      Dwg_Object_STYLE *style =
          dwg_add_STYLE(dwg, mif_name(name, stored, sizeof(stored)));
      if (style) fill_style_metrics(dwg, style, &view, rec);
    }
  }

  for (i = 0; i < view.dimstyle_count; i++) {
    const uint8_t *rec = fcb_view_dimstyle(&view, i);
    char name[NAME_CAP];
    char style[NAME_CAP];
    Dwg_Object_DIMSTYLE *ds;
    BITCODE_H href;
    if (!rec) continue;
    fcb_view_str(&view, fcb_u32(rec + FCB_DIMSTYLE_NAME), name, sizeof(name));
    if (!name[0] || is_default_dimstyle(name)) continue;
    if (find_named(dwg, name, "DIMSTYLE")) continue;
    {
      char stored[MIF_CAP];
      ds = dwg_add_DIMSTYLE(dwg, mif_name(name, stored, sizeof(stored)));
    }
    if (!ds) continue;
    ds->DIMDEC = (BITCODE_BS)fcb_u32(rec + FCB_DIMSTYLE_DECIMALS);
    ds->DIMTXT = fcb_f64(rec + FCB_DIMSTYLE_TEXT_HEIGHT);
    ds->DIMASZ = fcb_f64(rec + FCB_DIMSTYLE_ARROW);
    ds->DIMEXO = fcb_f64(rec + FCB_DIMSTYLE_EXO);
    ds->DIMEXE = fcb_f64(rec + FCB_DIMSTYLE_EXE);
    ds->DIMGAP = fcb_f64(rec + FCB_DIMSTYLE_GAP);
    ds->DIMSCALE = fcb_f64(rec + FCB_DIMSTYLE_SCALE);
    fcb_view_str(&view, fcb_u32(rec + FCB_DIMSTYLE_TEXTSTYLE), style,
                 sizeof(style));
    if (style[0] && !is_default_style(style)) {
      href = find_named(dwg, style, "STYLE");
      if (href) ds->DIMTXSTY = href;
    }
  }

  for (i = 0; i < view.layer_count; i++) {
    const uint8_t *rec = fcb_view_layer(&view, i);
    char name[NAME_CAP];
    if (!rec) continue;
    fcb_view_str(&view, fcb_u32(rec + FCB_LAYER_NAME), name, sizeof(name));
    if (!name[0] || is_default_layer(name)) continue;
    if (!find_named(dwg, name, "LAYER")) {
      char stored[MIF_CAP];
      Dwg_Object_LAYER *layer =
          dwg_add_LAYER(dwg, mif_name(name, stored, sizeof(stored)));
      if (layer) {
        uint32_t lf = fcb_u32(rec + FCB_LAYER_FLAGS);
        char ltype[NAME_CAP];
        BITCODE_H href;
        apply_packed_color(&layer->color, fcb_u32(rec + FCB_LAYER_COLOR));
        {
          int32_t weight = fcb_i32(rec + FCB_LAYER_WEIGHT);
          BITCODE_BSd coded = dxf_revcvt_lweight((int)weight);
          layer->linewt = (BITCODE_RC)coded;
        }
        if (lf & FCB_LAYER_HIDDEN) layer->off = 1;
        if (lf & FCB_LAYER_FROZEN) layer->frozen = 1;
        if (lf & FCB_LAYER_LOCKED) layer->locked = 1;
        if (lf & FCB_LAYER_NOPLOT) layer->plotflag = 0;
        layer->flag0 = (BITCODE_BS)((layer->frozen ? 1 : 0) |
                                    (layer->off ? 2 : 0) |
                                    (layer->frozen_in_new ? 4 : 0) |
                                    (layer->locked ? 8 : 0) |
                                    (layer->plotflag ? 16 : 0) |
                                    ((layer->linewt & 0x1F) << 5));
        {
          uint32_t lt_index = fcb_u32(rec + FCB_LAYER_LINETYPE);
          if (lt_index < view.linetype_count) {
            const uint8_t *lt_rec = fcb_view_linetype(&view, lt_index);
            if (lt_rec) {
              fcb_view_str(&view, fcb_u32(lt_rec + FCB_LTYPE_NAME), ltype,
                           sizeof(ltype));
              if (ltype[0] && !is_default_ltype(ltype)) {
                href = find_named(dwg, ltype, "LTYPE");
                if (href) layer->ltype = href;
              }
            }
          }
        }
      }
    }
  }

  if (view.block_count > 0) {
    headers = (Dwg_Object_BLOCK_HEADER **)calloc((size_t)view.block_count,
                                                 sizeof(*headers));
    needs_endblk = (unsigned char *)calloc((size_t)view.block_count, 1);
    if (!headers || !needs_endblk) {
      free(headers);
      free(needs_endblk);
      dwg_free(dwg);
      free(dwg);
      set_error(error_out, error_capacity, "Out of memory");
      return FC_STATUS_OUT_OF_MEMORY;
    }
  }

  for (i = 0; i < view.block_count; i++) {
    const uint8_t *rec = fcb_view_block(&view, i);
    char name[NAME_CAP];
    if (!rec) continue;
    fcb_view_str(&view, fcb_u32(rec + FCB_BLOCK_NAME), name, sizeof(name));
    if (is_model_space(name) || i == 0) {
      headers[i] = header_of(dwg_model_space_object(dwg));
    } else if (is_primary_paper_space(name)) {
      headers[i] = header_of(dwg_paper_space_object(dwg));
    } else {
      /* Named blocks and extra paper tabs (*Paper_Space0, ...). */
      {
        char stored[MIF_CAP];
        const char *stored_name = mif_name(name, stored, sizeof(stored));
        headers[i] = dwg_add_BLOCK_HEADER(dwg, stored_name);
        if (headers[i]) {
          dwg_add_BLOCK(headers[i], stored_name);
          headers[i]->base_pt.x = fcb_f64(rec + FCB_BLOCK_BASE_X);
          headers[i]->base_pt.y = fcb_f64(rec + FCB_BLOCK_BASE_Y);
          headers[i]->base_pt.z = 0;
          needs_endblk[i] = 1;
        }
      }
    }
  }

  /* Close named / extra-sheet blocks before INSERT lands in model or paper. */
  for (i = 0; i < view.entity_count; i++) {
    const uint8_t *rec = fcb_view_entity(&view, i);
    uint32_t owner;
    if (!rec) continue;
    owner = fcb_u32(rec + FCB_ENT_OWNER_BLOCK);
    if (!needs_endblk || owner >= view.block_count || !needs_endblk[owner]) {
      continue;
    }
    export_entity(dwg, headers[owner], &view, rec, headers);
  }
  for (i = 0; i < view.block_count; i++) {
    if (needs_endblk && needs_endblk[i] && headers && headers[i]) {
      dwg_add_ENDBLK(headers[i]);
    }
  }
  for (i = 0; i < view.entity_count; i++) {
    const uint8_t *rec = fcb_view_entity(&view, i);
    uint32_t owner;
    Dwg_Object_BLOCK_HEADER *hdr;
    if (!rec) continue;
    owner = fcb_u32(rec + FCB_ENT_OWNER_BLOCK);
    if (needs_endblk && owner < view.block_count && needs_endblk[owner]) {
      continue;
    }
    hdr = (headers && owner < view.block_count) ? headers[owner] : NULL;
    if (!hdr) hdr = header_of(dwg_model_space_object(dwg));
    export_entity(dwg, hdr, &view, rec, headers);
  }

  {
    uint64_t li;
    unsigned paper = 0;
    if (fcb_paper_layout_count(&view) == 0) drop_default_paper_layout(dwg);
    for (li = 0; li < view.layout_count; li++) {
      const uint8_t *rec = fcb_view_layout(&view, li);
      char name[NAME_CAP];
      uint32_t flags;
      uint32_t block;
      double width;
      double height;
      unsigned seen = 0;
      BITCODE_BL k;
      Dwg_Object_LAYOUT *lo = NULL;
      Dwg_Object *hdr_obj = NULL;
      int err = 0;
      if (!rec) continue;
      flags = fcb_u32(rec + FCB_LAYOUT_FLAGS);
      if (flags & FCB_LAYOUT_MODEL_SPACE) continue;
      fcb_view_str(&view, fcb_u32(rec + FCB_LAYOUT_NAME), name, sizeof(name));
      width = fcb_f64(rec + FCB_LAYOUT_WIDTH);
      height = fcb_f64(rec + FCB_LAYOUT_HEIGHT);
      block = fcb_u32(rec + FCB_LAYOUT_BLOCK);
      if (headers && block < view.block_count && headers[block]) {
        hdr_obj = dwg_obj_generic_to_object(headers[block], &err);
      }
      for (k = 0; k < dwg->num_objects; k++) {
        Dwg_Object *obj = &dwg->object[k];
        Dwg_Object_LAYOUT *candidate;
        if (obj->supertype != DWG_SUPERTYPE_OBJECT) continue;
        if (obj->fixedtype != DWG_TYPE_LAYOUT || !obj->tio.object) continue;
        candidate = obj->tio.object->tio.LAYOUT;
        if (!candidate) continue;
        if (candidate->layout_name && (streq(candidate->layout_name, "Model") ||
                                       streq(candidate->layout_name, "MODEL"))) {
          continue;
        }
        if (seen == paper) {
          lo = candidate;
          break;
        }
        seen++;
      }
      if (!lo && hdr_obj) {
        lo = dwg_add_LAYOUT(hdr_obj, name[0] ? name : "Layout",
                            "ISO_A3_(420.00_x_297.00_MM)");
      }
      if (lo) {
        if (name[0]) lo->layout_name = strdup(name);
        if (width > 0) lo->plotsettings.paper_width = width;
        if (height > 0) lo->plotsettings.paper_height = height;
      }
      paper++;
    }
  }

  export_paper_viewports(dwg, &view, headers);
  relink_block_entities(dwg);
  sync_codepage_name(dwg);
  status = write_tmp_and_replace(dwg_path, dwg, error_out, error_capacity);
  free(headers);
  free(needs_endblk);
  dwg_free(dwg);
  free(dwg);
  return status;
}

int fcdwg_export_dxf_to_dwg(const char *dxf_path, const char *dwg_path,
                            int32_t target_version, char *error_out,
                            size_t error_capacity) {
  (void)dxf_path;
  (void)dwg_path;
  (void)target_version;
  set_error(error_out, error_capacity,
            "DWG save writes FCB through fc_write_file, not DXF");
  return FC_STATUS_UNSUPPORTED;
}

#endif
