#include "dwg_export.h"

#include <stdio.h>
#include <string.h>

#include "fancad_io.h"

#ifndef FANCAD_HAVE_LIBREDWG

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

int fcdwg_export_dxf_to_dwg(const char *dxf_path, const char *dwg_path,
                            int32_t target_version, char *error_out,
                            size_t error_capacity) {
  Dwg_Data dwg;
  int error;
  Dwg_Version_Type version;

  if (!dxf_path || !dwg_path) {
    if (error_out && error_capacity > 0) {
      snprintf(error_out, error_capacity, "fcdwg_export: invalid argument");
    }
    return FC_STATUS_INVALID_ARGUMENT;
  }

  memset(&dwg, 0, sizeof(dwg));
  version = (target_version == 2004) ? R_2004 : R_2000;
  dwg.header.version = version;

  error = dxf_read_file(dxf_path, &dwg);
  if (error) {
    if (error_out && error_capacity > 0) {
      snprintf(error_out, error_capacity,
               "LibreDWG could not read the intermediate DXF (status %d)",
               error);
    }
    dwg_free(&dwg);
    return FC_STATUS_PARSE_ERROR;
  }

  dwg.header.version = version;
  error = dwg_write_file(dwg_path, &dwg);
  dwg_free(&dwg);
  if (error) {
    if (error_out && error_capacity > 0) {
      snprintf(error_out, error_capacity,
               "LibreDWG could not write %s as r%d (status %d)", dwg_path,
               target_version == 0 ? 2000 : target_version, error);
    }
    return FC_STATUS_UNSUPPORTED;
  }
  return FC_STATUS_OK;
}

#endif
