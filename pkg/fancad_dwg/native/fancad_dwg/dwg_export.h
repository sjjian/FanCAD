#ifndef FANCAD_DWG_EXPORT_H
#define FANCAD_DWG_EXPORT_H

#include <stddef.h>
#include <stdint.h>

/* Converts an ASCII DXF file into a DWG file.
 * target_version is 2000 or 2004; 0 means 2000.
 * Returns an FC_STATUS_* code. */
int fcdwg_export_dxf_to_dwg(const char *dxf_path, const char *dwg_path,
                            int32_t target_version, char *error_out,
                            size_t error_capacity);

#endif
