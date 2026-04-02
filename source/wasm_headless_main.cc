/* SPDX-FileCopyrightText: 2026 Blender Web Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later */

/** \file
 * \ingroup wasm
 *
 * Custom headless WASM entry point for Blender Web (Phase 1).
 *
 * This bypasses Blender's full initialization (no Python, no GPU, no window
 * manager) and provides exported C functions that JavaScript can call to
 * initialize the engine, load .blend files, query scene data, and check
 * memory usage.
 *
 * The goal is to prove the data pipeline works:
 *   DNA -> RNA -> BKE -> blenloader
 *
 * Exported functions (EMSCRIPTEN_KEEPALIVE):
 *   - wasm_init()          : Initialize Blender core subsystems
 *   - wasm_load_blend()    : Load a .blend file from Emscripten MEMFS
 *   - wasm_query_scene()   : Return JSON with scene/object info
 *   - wasm_memory_usage()  : Return current MEM_guarded_alloc usage
 */

#include "MEM_guardedalloc.h"

#include "BLF_api.hh"

#include "BKE_blendfile.hh"
#include "BKE_blender.hh"
#include "BKE_callbacks.hh"
#include "BKE_global.hh"
#include "BKE_appdir.hh"
#include "BKE_idtype.hh"
#include "BKE_layer.hh"
#include "BKE_lib_id.hh"
#include "BKE_main.hh"
#include "BKE_modifier.hh"
#include "BKE_node.hh"
#include "BKE_vfont.hh"
#include "BKE_wm_runtime.hh"

#include "BLI_listbase.h"
#include "BLI_threads.h"

#include "DEG_depsgraph.hh"

#include "DNA_genfile.h"
#include "DNA_scene_types.h"
#include "DNA_object_types.h"
#include "DNA_ID.h"
#include "DNA_windowmanager_types.h"

#include "BLO_readfile.hh"

#include "CLG_log.h"

#include "ED_datafiles.h"

#include "IMB_imbuf.hh"

#include "RNA_define.hh"

#include "SEQ_modifier.hh"

#include "wm.hh"

#ifdef __EMSCRIPTEN__
#  include <emscripten.h>
#  include <emscripten/threading.h>
#endif

#include <cstdio>
#include <cstring>
#include <cstddef>

using namespace blender;

/* -------------------------------------------------------------------- */
/** \name Internal State
 * \{ */

static bool g_initialized = false;

/** \} */

/* -------------------------------------------------------------------- */
/** \name Object Type String Helpers
 * \{ */

/**
 * Return a short string label for the given #ObjectType enum value.
 * Used when building the JSON scene query response.
 */
static const char *object_type_to_string(short type)
{
  switch (type) {
    case OB_MESH:
      return "MESH";
    case OB_CURVES_LEGACY:
      return "CURVE";
    case OB_SURF:
      return "SURFACE";
    case OB_FONT:
      return "FONT";
    case OB_EMPTY:
      return "EMPTY";
    case OB_LAMP:
      return "LIGHT";
    case OB_CAMERA:
      return "CAMERA";
    case OB_ARMATURE:
      return "ARMATURE";
    default:
      return "OTHER";
  }
}

/** \} */

/* -------------------------------------------------------------------- */
/** \name Exported WASM Functions
 * \{ */

extern "C" {

/**
 * Initialize Blender's core subsystems in headless mode.
 *
 * Mirrors Blender's own blendfile-loading test bootstrap closely enough
 * to safely parse real .blend files in a headless runtime.
 *
 * \return 0 on success, -1 on failure.
 */
#ifdef __EMSCRIPTEN__
EMSCRIPTEN_KEEPALIVE
#endif
int wasm_init()
{
  if (g_initialized) {
    printf("[wasm] Already initialized, skipping.\n");
    return 0;
  }

  printf("[wasm] Initializing Blender WASM engine...\n");

  /* Mirror Blender's blendfile-loading test bootstrap to avoid loader-time crashes. */
  CLG_init();
  BLI_threadapi_init();
  DNA_sdna_current_init();
  BKE_blender_globals_init();
  BKE_idtype_init();
  BKE_appdir_init();
  IMB_init();
  BKE_modifier_init();
  seq::modifiers_init();
  DEG_register_node_types();
  RNA_init();
  bke::node_system_init();
  BKE_callback_global_init();
  BKE_vfont_builtin_register(datatoc_bfont_pfb, datatoc_bfont_pfb_size);
  BLF_init();

  BKE_blender_globals_main_replace(BKE_main_new());

  G.background = true;
  G.factory_startup = true;

  if (G.main->wm.first == nullptr) {
    wmWindowManager *wm = BKE_id_new<wmWindowManager>(G.main, "WMdummy");
    wm->runtime = MEM_new<bke::WindowManagerRuntime>(__func__);
  }

  g_initialized = true;

  size_t mem_usage = MEM_get_memory_in_use();
  printf("[wasm] Blender WASM engine initialized (mem: %zu bytes)\n", mem_usage);

  return 0;
}

/**
 * Load a .blend file from the given path (typically on Emscripten MEMFS).
 *
 * Uses BLO_read_from_file() to parse the blend-file and replaces G_MAIN
 * with the loaded data. Counts objects in the resulting Main database.
 *
 * \param path: Path to the .blend file (e.g. "/data/scene.blend").
 * \return Number of objects loaded on success, -1 on failure.
 */
#ifdef __EMSCRIPTEN__
EMSCRIPTEN_KEEPALIVE
#endif
int wasm_load_blend(const char *path)
{
  if (!g_initialized) {
    printf("[wasm] ERROR: Engine not initialized. Call wasm_init() first.\n");
    return -1;
  }

  if (!path || path[0] == '\0') {
    printf("[wasm] ERROR: Invalid path (null or empty).\n");
    return -1;
  }

  printf("[wasm] Loading blend file: %s\n", path);

  BlendFileReadReport bf_reports = {};
  BlendFileData *bfd = BLO_read_from_file(path, BLO_READ_SKIP_USERDEF, &bf_reports);

  if (!bfd) {
    printf("[wasm] ERROR: Failed to load blend file: %s\n", path);
    return -1;
  }

  if (bfd->curscene) {
    for (ViewLayer &view_layer : bfd->curscene->view_layers) {
      BKE_view_layer_synced_ensure(*bfd->main, bfd->curscene, &view_layer);
    }
  }

  /* Replace current G_MAIN with the loaded data. */
  if (bfd->main) {
    BKE_blender_globals_main_replace(bfd->main);
    bfd->main = nullptr; /* Ownership transferred to G_MAIN. */
  }

  /* Count objects in the loaded Main. */
  int object_count = 0;
  for (const Object &ob : G_MAIN->objects) {
    (void)ob;
    object_count++;
  }

  printf("[wasm] Loaded %d objects from %s\n", object_count, path);

  /* Free the BlendFileData wrapper (Main ownership already transferred). */
  BLO_blendfiledata_free(bfd);

  return object_count;
}

/**
 * Query the current scene and return a JSON string describing it.
 *
 * Builds a simple JSON object containing the scene name, object count,
 * and an array of objects with their names and types.
 *
 * \return Pointer to a static JSON buffer (valid until next call).
 *         Returns "{}" if no data is loaded.
 */
#ifdef __EMSCRIPTEN__
EMSCRIPTEN_KEEPALIVE
#endif
const char *wasm_query_scene()
{
  static char json_buf[4096];

  if (!g_initialized || !G_MAIN) {
    snprintf(json_buf, sizeof(json_buf), "{}");
    return json_buf;
  }

  /* Find the first scene. */
  Scene *scene = nullptr;
  for (Scene &sc : G_MAIN->scenes) {
    scene = &sc;
    break;
  }

  if (!scene) {
    snprintf(json_buf, sizeof(json_buf), "{\"scene\":null,\"objects\":[]}");
    return json_buf;
  }

  /* Build JSON response. */
  int offset = 0;
  const char *scene_name = scene->id.name + 2; /* Skip the 2-byte type prefix. */

  offset += snprintf(json_buf + offset,
                     sizeof(json_buf) - offset,
                     "{\"scene\":\"%s\",\"objects\":[",
                     scene_name);

  bool first = true;
  for (const Object &ob : G_MAIN->objects) {
    const char *ob_name = ob.id.name + 2;
    const char *ob_type = object_type_to_string(ob.type);

    if (!first) {
      offset += snprintf(json_buf + offset, sizeof(json_buf) - offset, ",");
    }
    offset += snprintf(json_buf + offset,
                       sizeof(json_buf) - offset,
                       "{\"name\":\"%s\",\"type\":\"%s\"}",
                       ob_name,
                       ob_type);
    first = false;

    /* Safety: stop if we are running out of buffer space. */
    if (offset >= (int)(sizeof(json_buf) - 128)) {
      break;
    }
  }

  snprintf(json_buf + offset, sizeof(json_buf) - offset, "]}");

  return json_buf;
}

/**
 * Return the current memory usage as tracked by MEM_guarded_alloc.
 *
 * \return Bytes of memory currently allocated.
 */
#ifdef __EMSCRIPTEN__
EMSCRIPTEN_KEEPALIVE
#endif
size_t wasm_memory_usage()
{
  return MEM_get_memory_in_use();
}

} /* extern "C" */

/** \} */

/* -------------------------------------------------------------------- */
/** \name Main Entry Point
 * \{ */

/**
 * Headless main entry point for the WASM build.
 *
 * Initializes the engine and optionally loads a .blend file if one is
 * passed as the first command-line argument. Does NOT enter WM_main --
 * this is headless mode, and control returns to the JavaScript host.
 */
int main(int argc, char **argv)
{
  printf("[wasm] Blender Web -- Headless WASM Build\n");

  int rc = wasm_init();
  if (rc != 0) {
    printf("[wasm] ERROR: Initialization failed.\n");
    return 1;
  }

  printf("[wasm] Headless WASM build ready. Awaiting commands.\n");

  /* If a .blend file path was provided, load it. */
  if (argc > 1 && argv[1] != nullptr) {
    const char *blend_path = argv[1];
    size_t len = strlen(blend_path);
    if (len > 6 && strcmp(blend_path + len - 6, ".blend") == 0) {
      printf("[wasm] Auto-loading blend file: %s\n", blend_path);
      int result = wasm_load_blend(blend_path);
      if (result < 0) {
        printf("[wasm] WARNING: Failed to load %s\n", blend_path);
      }
      else {
        printf("[wasm] Loaded %d objects.\n", result);
        printf("[wasm] Scene query: %s\n", wasm_query_scene());
      }
    }
  }

  printf("[wasm] Memory usage: %zu bytes\n", wasm_memory_usage());

  return 0;
}

/** \} */
