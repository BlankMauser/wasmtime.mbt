// A small synchronous sandbox over the official Wasmtime C API (v42
// headers, linked against the prebuilt libwasmtime). Built for running
// untrusted guests that only compute and return data:
// - no imports are ever provided (a module that imports anything fails to
//   instantiate);
// - fuel (instruction budget) and an epoch deadline (wall clock) bound
//   execution; the caller sets both once per session, so they span calls;
// - a store limiter caps linear memory, table elements, instances, tables
//   and memories;
// - Wasm GC, threads, shared memory, stack switching, component model are
//   off.
#include <wasmtime.h>
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

// Statuses returned to MoonBit.
enum {
  LF_OK = 0,
  LF_TRAP = 1,
  LF_OUT_OF_FUEL = 2,
  LF_TIMEOUT = 3,
  LF_ERROR = 4,
  LF_BAD_RESULT = 5,
  LF_NO_EXPORT = 6,
};

static wasm_engine_t *g_engine = NULL;
static pthread_once_t g_once = PTHREAD_ONCE_INIT;

// One epoch per millisecond, forever, for the deadline.
static void *ticker(void *arg) {
  (void)arg;
  struct timespec ms = {0, 1000000};
  for (;;) {
    nanosleep(&ms, NULL);
    wasmtime_engine_increment_epoch(g_engine);
  }
  return NULL;
}

static void engine_init(void) {
  wasm_config_t *config = wasm_config_new();
  wasmtime_config_consume_fuel_set(config, true);
  wasmtime_config_epoch_interruption_set(config, true);
  wasmtime_config_wasm_gc_set(config, false);
  wasmtime_config_wasm_function_references_set(config, false);
  wasmtime_config_wasm_threads_set(config, false);
  wasmtime_config_shared_memory_set(config, false);
  wasmtime_config_wasm_stack_switching_set(config, false);
  wasmtime_config_wasm_memory64_set(config, false);
  wasmtime_config_wasm_multi_memory_set(config, false);
  wasmtime_config_max_wasm_stack_set(config, 1024 * 1024);
  wasmtime_config_parallel_compilation_set(config, false);
  g_engine = wasm_engine_new_with_config(config);
  pthread_t t;
  pthread_create(&t, NULL, ticker, NULL);
  pthread_detach(t);
}

typedef struct lf_sandbox {
  wasmtime_store_t *store;
  wasmtime_context_t *context;
  wasmtime_module_t *module;
  wasmtime_instance_t instance;
} lf_sandbox_t;

static void copy_message(const wasm_byte_vec_t *msg, uint8_t *out, int32_t cap) {
  if (cap <= 0) return;
  size_t n = msg->size < (size_t)(cap - 1) ? msg->size : (size_t)(cap - 1);
  memcpy(out, msg->data, n);
  out[n] = 0;
}

static void error_message(wasmtime_error_t *e, uint8_t *out, int32_t cap) {
  wasm_byte_vec_t msg;
  wasmtime_error_message(e, &msg);
  copy_message(&msg, out, cap);
  wasm_byte_vec_delete(&msg);
  wasmtime_error_delete(e);
}

static int trap_status(wasm_trap_t *trap, uint8_t *out, int32_t cap) {
  wasmtime_trap_code_t code;
  int status = LF_TRAP;
  if (wasmtime_trap_code(trap, &code)) {
    if (code == WASMTIME_TRAP_CODE_OUT_OF_FUEL) status = LF_OUT_OF_FUEL;
    if (code == WASMTIME_TRAP_CODE_INTERRUPT) status = LF_TIMEOUT;
  }
  wasm_message_t msg;
  wasm_trap_message(trap, &msg);
  copy_message(&msg, out, cap);
  wasm_byte_vec_delete(&msg);
  wasm_trap_delete(trap);
  return status;
}

// Instantiates `wasm` under the limits. Returns NULL and a message on
// failure. Instantiation itself runs under `fuel` and `timeout_ms` (a start
// function is guest code too).
lf_sandbox_t *lf_sandbox_new(const uint8_t *wasm, int32_t len,
                             int64_t memory_bytes, int64_t table_elements,
                             int64_t fuel, int64_t timeout_ms,
                             uint8_t *msg, int32_t cap) {
  pthread_once(&g_once, engine_init);
  if (msg && cap > 0) msg[0] = 0;
  lf_sandbox_t *s = calloc(1, sizeof(lf_sandbox_t));
  if (!s) return NULL;
  wasmtime_error_t *e = wasmtime_module_new(g_engine, wasm, (size_t)len, &s->module);
  if (e) {
    error_message(e, msg, cap);
    free(s);
    return NULL;
  }
  s->store = wasmtime_store_new(g_engine, NULL, NULL);
  s->context = wasmtime_store_context(s->store);
  // memory_size, table_elements, instances, tables, memories
  wasmtime_store_limiter(s->store, memory_bytes, table_elements, 1, 4, 1);
  wasmtime_context_set_fuel(s->context, (uint64_t)fuel);
  wasmtime_context_set_epoch_deadline(s->context, (uint64_t)timeout_ms);
  wasm_trap_t *trap = NULL;
  e = wasmtime_instance_new(s->context, s->module, NULL, 0, &s->instance, &trap);
  if (e || trap) {
    if (e) error_message(e, msg, cap);
    else trap_status(trap, msg, cap);
    wasmtime_store_delete(s->store);
    wasmtime_module_delete(s->module);
    free(s);
    return NULL;
  }
  return s;
}

int32_t lf_sandbox_is_null(lf_sandbox_t *s) { return s == NULL; }

void lf_sandbox_free(lf_sandbox_t *s) {
  if (!s) return;
  wasmtime_store_delete(s->store);
  wasmtime_module_delete(s->module);
  free(s);
}

// A session: `fuel` instructions and `timeout_ms` from now, for every call
// until the next session.
void lf_sandbox_session(lf_sandbox_t *s, int64_t fuel, int64_t timeout_ms) {
  wasmtime_context_set_fuel(s->context, (uint64_t)fuel);
  wasmtime_context_set_epoch_deadline(s->context, (uint64_t)timeout_ms);
}

// Fuel left in the session.
int64_t lf_sandbox_fuel(lf_sandbox_t *s) {
  uint64_t f = 0;
  wasmtime_error_t *e = wasmtime_context_get_fuel(s->context, &f);
  if (e) {
    wasmtime_error_delete(e);
    return -1;
  }
  return (int64_t)f;
}

// Calls export `name` with `nargs` i32 arguments; it must return one i32.
int32_t lf_sandbox_call_i32(lf_sandbox_t *s, const uint8_t *name, int32_t name_len,
                            const int32_t *args, int32_t nargs, int32_t *result,
                            uint8_t *msg, int32_t cap) {
  if (msg && cap > 0) msg[0] = 0;
  wasmtime_extern_t item;
  if (!wasmtime_instance_export_get(s->context, &s->instance, (const char *)name,
                                    (size_t)name_len, &item) ||
      item.kind != WASMTIME_EXTERN_FUNC) {
    return LF_NO_EXPORT;
  }
  if (nargs < 0 || nargs > 8) return LF_ERROR;
  wasmtime_val_t argv[8];
  for (int i = 0; i < nargs; i++) {
    argv[i].kind = WASMTIME_I32;
    argv[i].of.i32 = args[i];
  }
  wasmtime_val_t res;
  wasm_trap_t *trap = NULL;
  wasmtime_error_t *e =
      wasmtime_func_call(s->context, &item.of.func, argv, (size_t)nargs, &res, 1, &trap);
  if (e) {
    error_message(e, msg, cap);
    return LF_ERROR;
  }
  if (trap) return trap_status(trap, msg, cap);
  if (res.kind != WASMTIME_I32) return LF_BAD_RESULT;
  *result = res.of.i32;
  return LF_OK;
}

// Copies `len` bytes at `offset` of exported memory `memory` into `out`.
// Bounds-checked against the memory's current size.
int32_t lf_sandbox_read(lf_sandbox_t *s, const uint8_t *name, int32_t name_len,
                        int32_t offset, int32_t len, uint8_t *out) {
  wasmtime_extern_t item;
  if (!wasmtime_instance_export_get(s->context, &s->instance, (const char *)name,
                                    (size_t)name_len, &item) ||
      item.kind != WASMTIME_EXTERN_MEMORY) {
    return LF_NO_EXPORT;
  }
  size_t size = wasmtime_memory_data_size(s->context, &item.of.memory);
  if (offset < 0 || len < 0 || (size_t)offset + (size_t)len > size) return LF_ERROR;
  memcpy(out, wasmtime_memory_data(s->context, &item.of.memory) + offset, (size_t)len);
  return LF_OK;
}

const char *lf_sandbox_version(void) { return WASMTIME_VERSION; }
