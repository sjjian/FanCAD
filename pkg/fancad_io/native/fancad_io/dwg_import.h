/* The DWG to FCB translation step, kept separate from the exported entry
 * points so that the shim's public surface compiles even when no DWG backend
 * is available. */
#ifndef FANCAD_DWG_IMPORT_H
#define FANCAD_DWG_IMPORT_H

#include <stddef.h>
#include <stdint.h>

#include "fcb_builder.h"

/* Translates the drawing at path into b.
 * Returns one of the FC_STATUS_* codes from fancad_io.h and, on failure,
 * writes a NUL-terminated description into error_out. */
int fcdwg_import(const char *path, fcb_builder *b, char *error_out,
                 size_t error_capacity);

/* Non-zero when this build links a DWG backend. */
int fcdwg_has_backend(void);

/* A static description of the backend. */
const char *fcdwg_backend_version(void);

#endif /* FANCAD_DWG_IMPORT_H */
