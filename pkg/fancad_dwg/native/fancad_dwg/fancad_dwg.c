#include "fancad_dwg.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "dwg_export.h"
#include "dwg_import.h"
#include "fcb_builder.h"

/* Last error message. The reader is expected to be called from a dedicated
 * import isolate, one file at a time, so a single slot is sufficient; it is
 * thread-local where the compiler supports it so a concurrent read cannot
 * clobber another's message. */
#if defined(_MSC_VER)
#define FC_THREAD_LOCAL __declspec(thread)
#elif defined(__GNUC__) || defined(__clang__)
#define FC_THREAD_LOCAL __thread
#else
#define FC_THREAD_LOCAL
#endif

#define FC_ERROR_CAPACITY 512

static FC_THREAD_LOCAL char fc_error[FC_ERROR_CAPACITY];

static void fc_set_error(const char *message) {
  if (!message) {
    fc_error[0] = '\0';
    return;
  }
  snprintf(fc_error, sizeof(fc_error), "%s", message);
}

uint32_t fc_capabilities(void) {
  if (!fcdwg_has_backend()) return 0u;
  /* DXF stays on the Dart side. Advertising a native DXF reader would send
   * `.dxf` through dwg_read_file, which only understands DWG. */
  return FC_CAP_READ_DWG | FC_CAP_WRITE_DWG;
}

uint32_t fc_fcb_version(void) { return (uint32_t)FCB_VERSION; }

const char *fc_backend_version(void) { return fcdwg_backend_version(); }

int32_t fc_read_file(const char *path, uint8_t **out_data,
                     uint64_t *out_length, uint32_t *out_entity_count) {
  fcb_builder builder;
  uint8_t *data = NULL;
  uint64_t length = 0;
  int status;

  fc_set_error(NULL);

  if (!path || !*path || !out_data || !out_length) {
    fc_set_error("fc_read_file: invalid argument");
    return FC_STATUS_INVALID_ARGUMENT;
  }

  fcb_builder_init(&builder);
  status = fcdwg_import(path, &builder, fc_error, sizeof(fc_error));
  if (status != FC_STATUS_OK) {
    fcb_builder_dispose(&builder);
    return status;
  }

  if (fcb_builder_finish(&builder, &data, &length) != 0) {
    fcb_builder_dispose(&builder);
    fc_set_error("Out of memory while serializing the drawing");
    return FC_STATUS_OUT_OF_MEMORY;
  }

  if (out_entity_count) *out_entity_count = builder.entity_count;
  fcb_builder_dispose(&builder);

  *out_data = data;
  *out_length = length;
  return FC_STATUS_OK;
}

void fc_free(uint8_t *data) { free(data); }

int32_t fc_last_error(char *out, int32_t capacity) {
  size_t size;
  if (!out || capacity <= 0) return 0;
  size = strlen(fc_error);
  if (size >= (size_t)capacity) size = (size_t)capacity - 1;
  memcpy(out, fc_error, size);
  out[size] = '\0';
  return (int32_t)size;
}

int32_t fc_write_file(const char *path, const uint8_t *fcb, uint64_t length,
                      int32_t target_version) {
  (void)path;
  (void)fcb;
  (void)length;
  (void)target_version;
  fc_set_error(
      "FCB-to-DWG is not implemented; write DXF and call fc_dxf_to_dwg");
  return FC_STATUS_UNSUPPORTED;
}

int32_t fc_dxf_to_dwg(const char *dxf_path, const char *dwg_path,
                      int32_t target_version) {
  fc_set_error(NULL);
  if (!dxf_path || !dwg_path) {
    fc_set_error("fc_dxf_to_dwg: invalid argument");
    return FC_STATUS_INVALID_ARGUMENT;
  }
  return fcdwg_export_dxf_to_dwg(dxf_path, dwg_path, target_version, fc_error,
                                 sizeof(fc_error));
}
