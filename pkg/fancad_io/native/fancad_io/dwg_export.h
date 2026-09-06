#ifndef FANCAD_DWG_EXPORT_H
#define FANCAD_DWG_EXPORT_H

#include <stddef.h>
#include <stdint.h>

/* Converts an FCB buffer into a DWG file.
 * target_version is 2000 or 2004; 0 means 2000.
 * Returns an FC_STATUS_* code. */
int fcdwg_export_fcb_to_dwg(const uint8_t *fcb, uint64_t length,
                            const char *dwg_path, int32_t target_version,
                            char *error_out, size_t error_capacity);

/* Converts an ASCII DXF file into a DWG file. Kept for the FFI symbol;
 * drawing save no longer uses this path. */
int fcdwg_export_dxf_to_dwg(const char *dxf_path, const char *dwg_path,
                            int32_t target_version, char *error_out,
                            size_t error_capacity);

#endif
