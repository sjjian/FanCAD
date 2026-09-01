/* FanCAD native DWG shim.
 *
 * This is the entire surface that Dart binds to. Deliberately tiny: five
 * functions and no structs by value, so the FFI bindings are hand-written and
 * reviewable, and so that dwg.h never has to be parsed by a binding generator.
 *
 * The shim compiles with or without GNU LibreDWG. Without it, every reader
 * returns FC_STATUS_NO_BACKEND and fc_capabilities() reports zero, which lets
 * the application build and run on a machine that has no DWG library while
 * still reporting the situation clearly instead of failing to link.
 */
#ifndef FANCAD_IO_H
#define FANCAD_IO_H

#include <stdint.h>

#if defined(_WIN32)
#define FC_EXPORT __declspec(dllexport)
#else
#define FC_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* Status codes returned by every entry point. */
#define FC_STATUS_OK 0
#define FC_STATUS_NO_BACKEND (-1)
#define FC_STATUS_FILE_NOT_FOUND (-2)
#define FC_STATUS_PARSE_ERROR (-3)
#define FC_STATUS_OUT_OF_MEMORY (-4)
#define FC_STATUS_UNSUPPORTED (-5)
#define FC_STATUS_INVALID_ARGUMENT (-6)

/* Capability bits reported by fc_capabilities(). */
#define FC_CAP_READ_DWG (1u << 0)
#define FC_CAP_WRITE_DWG (1u << 1)
#define FC_CAP_READ_DXF (1u << 2)
#define FC_CAP_WRITE_DXF (1u << 3)

/* Which formats this build can handle. */
FC_EXPORT uint32_t fc_capabilities(void);

/* The FCB format version this build emits, so Dart can reject a mismatch. */
FC_EXPORT uint32_t fc_fcb_version(void);

/* A human-readable backend description, for example
 * "LibreDWG 0.14" or "no backend". Statically allocated. */
FC_EXPORT const char *fc_backend_version(void);

/* Reads a DWG or DXF file and serializes it as an FCB buffer.
 *
 * On FC_STATUS_OK, *out_data points at a buffer the caller must release with
 * fc_free(), *out_length holds its size, and *out_entity_count the number of
 * entities written. On failure the outputs are left untouched and
 * fc_last_error() describes the problem.
 */
FC_EXPORT int32_t fc_read_file(const char *path, uint8_t **out_data,
                               uint64_t *out_length,
                               uint32_t *out_entity_count);

/* Releases a buffer produced by fc_read_file(). Safe to call with NULL. */
FC_EXPORT void fc_free(uint8_t *data);

/* Copies the last error message into out, NUL-terminated, and returns the
 * number of bytes written excluding the terminator. */
FC_EXPORT int32_t fc_last_error(char *out, int32_t capacity);

/* Writes an FCB buffer back out as a DWG or DXF file.
 *
 * target_version is a DWG release code (for example 2000 or 2004); 0 selects
 * the backend default. Returns FC_STATUS_UNSUPPORTED until the exporter is
 * implemented.
 */
FC_EXPORT int32_t fc_write_file(const char *path, const uint8_t *fcb,
                                uint64_t length, int32_t target_version);

/* Converts an ASCII DXF file to DWG r2000 or r2004. */
FC_EXPORT int32_t fc_dxf_to_dwg(const char *dxf_path, const char *dwg_path,
                                int32_t target_version);

#ifdef __cplusplus
}
#endif

#endif /* FANCAD_IO_H */
