///|
struct Options {
  wasm_path : String
  host_dir : String
  threads : Int32
  entry : String
  repeat : Int32
  warmup : Int32
  inner_repeat : Int32
  file_limit : Int32
  use_cwasm : Bool
  inherit_stdio : Bool
}

///|
fn print_help() -> Unit {
  println("bench_wasi_io --wasm <path> --dir <path> [options]")
  println("")
  println("Options:")
  println("  --threads <n>       Number of parallel workers (default: 4)")
  println("  --entry <name>      Exported entry function (default: run)")
  println("  --repeat <n>        Repeat count (default: 1)")
  println("  --warmup <n>        Warmup rounds (default: 0)")
  println("  --inner-repeat <n>  Run entry N times per worker (default: 1)")
  println("  --limit <n>         Limit worklist size (default: 0 = all)")
  println("  --cwasm             Precompile to dist/*.cwasm and run from it")
  println("  --inherit-stdio     Inherit stdio for WASI")
  println("  -h, --help          Show this help")
}

///|
fn parse_int_or(value : String, fallback : Int32) -> Int32 {
  @string.parse_int(value) catch {
    _ => fallback
  }
}

///|
fn parse_args() -> Options? {
  let args = @env.args()
  let mut wasm_path = ""
  let mut host_dir = ""
  let mut threads = 4
  let mut entry = "run"
  let mut repeat = 1
  let mut warmup = 0
  let mut inner_repeat = 1
  let mut file_limit = 0
  let mut use_cwasm = false
  let mut inherit_stdio = false
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if arg == "-h" || arg == "--help" {
      print_help()
      return None
    } else if arg == "--wasm" {
      i = i + 1
      if i < args.length() {
        wasm_path = args[i]
      }
    } else if arg == "--dir" {
      i = i + 1
      if i < args.length() {
        host_dir = args[i]
      }
    } else if arg == "--threads" {
      i = i + 1
      if i < args.length() {
        threads = parse_int_or(args[i], threads)
      }
    } else if arg == "--entry" {
      i = i + 1
      if i < args.length() {
        entry = args[i]
      }
    } else if arg == "--repeat" {
      i = i + 1
      if i < args.length() {
        repeat = parse_int_or(args[i], repeat)
      }
    } else if arg == "--warmup" {
      i = i + 1
      if i < args.length() {
        warmup = parse_int_or(args[i], warmup)
      }
    } else if arg == "--inner-repeat" {
      i = i + 1
      if i < args.length() {
        inner_repeat = parse_int_or(args[i], inner_repeat)
      }
    } else if arg == "--limit" {
      i = i + 1
      if i < args.length() {
        file_limit = parse_int_or(args[i], file_limit)
      }
    } else if arg == "--cwasm" {
      use_cwasm = true
    } else if arg == "--inherit-stdio" {
      inherit_stdio = true
    }
    i = i + 1
  }
  if wasm_path.length() == 0 || host_dir.length() == 0 {
    print_help()
    None
  } else {
    Some(Options::{
      wasm_path,
      host_dir,
      threads,
      entry,
      repeat,
      warmup,
      inner_repeat,
      file_limit,
      use_cwasm,
      inherit_stdio,
    })
  }
}

///|
let ignore_dirs : Array[String] = [
  ".mooncakes", ".git", "_build", "target", "node_modules",
]

///|
let worklist_file = ".wasm_worklist.txt"

///|
fn is_ignored_dir(entry : String) -> Bool {
  for ignored in ignore_dirs {
    if entry == ignored {
      return true
    }
  }
  false
}

///|
fn join_path(base : String, part : String) -> String {
  if base.length() == 0 {
    part
  } else if part.length() == 0 {
    base
  } else if base.has_suffix("/") {
    "\{base}\{part}"
  } else {
    "\{base}/\{part}"
  }
}

///|
fn basename(path : String) -> String {
  match path.rev_find("/") {
    Some(idx) => path.unsafe_substring(start=idx + 1, end=path.length())
    None => path
  }
}

///|
fn strip_suffix(name : String, suffix : String) -> String {
  if name.has_suffix(suffix) && name.length() >= suffix.length() {
    name.unsafe_substring(start=0, end=name.length() - suffix.length())
  } else {
    name
  }
}

///|
fn ensure_dist_dir() -> Result[String, Error] {
  match @env.current_dir() {
    Some(root) => {
      let dist = join_path(root, "dist")
      if !@fs.path_exists(dist) {
        @fs.create_dir(dist) catch {
          err => return Err(err)
        }
      }
      Ok(dist)
    }
    None => Err(@builtin.Failure::Failure("current_dir unavailable"))
  }
}

///|
fn cwasm_output_path(wasm_path : String) -> Result[String, Error] {
  let base = strip_suffix(basename(wasm_path), ".wasm")
  match ensure_dist_dir() {
    Ok(dist) => Ok(join_path(dist, "\{base}.cwasm"))
    Err(err) => Err(err)
  }
}

///|
fn collect_mbt_files(
  root : String,
  rel : String,
  out : Array[String],
  limit : Int32,
) -> Unit {
  if limit > 0 && out.length() >= limit {
    return
  }
  let dir_path = if rel == "" { root } else { join_path(root, rel) }
  let entries = @fs.read_dir(dir_path) catch { _ => return }
  for entry in entries {
    if is_ignored_dir(entry) {
      continue
    }
    let rel_path = if rel == "" { entry } else { "\{rel}/\{entry}" }
    let full_path = join_path(root, rel_path)
    let is_dir = @fs.is_dir(full_path) catch { _ => false }
    if is_dir {
      collect_mbt_files(root, rel_path, out, limit)
      if limit > 0 && out.length() >= limit {
        return
      }
    } else if entry.has_suffix(".mbt") {
      out.push(rel_path)
      if limit > 0 && out.length() >= limit {
        return
      }
    }
  }
}

///|
fn build_worklist(host_dir : String, limit : Int32) -> Result[Unit, Error] {
  let files : Array[String] = []
  collect_mbt_files(host_dir, "", files, limit)
  if files.is_empty() {
    return Err(@builtin.Failure::Failure("worklist is empty"))
  }
  let content = files.join("\n") + "\n"
  let path = join_path(host_dir, worklist_file)
  @fs.write_string_to_file(path, content) catch {
    err => return Err(err)
  }
  Ok(())
}

///|
fn spawn_all(
  rt : @thread_runtime.ThreadRuntime,
  payload : Bytes,
  entry : String,
  threads : Int32,
  inner_repeat : Int32,
  use_cwasm : Bool,
) -> Result[@thread_runtime.JoinSet, Error] {
  if threads <= 0 {
    return Err(@builtin.Failure::Failure("threads must be > 0"))
  }
  if inner_repeat <= 0 {
    return Err(@builtin.Failure::Failure("inner_repeat must be > 0"))
  }
  let join_set = @thread_runtime.JoinSet::new()
  for id in 0..<threads {
    let args = @wasmtime.make_val_buffer(2)
    @wasmtime.val_buffer_set_i32(args, 0, id)
    @wasmtime.val_buffer_set_i32(args, 1, threads)
    let res = if use_cwasm {
      if inner_repeat == 1 {
        rt.spawn_cwasm(payload, entry, args)
      } else {
        rt.spawn_cwasm_repeat(payload, entry, args, inner_repeat)
      }
    } else if inner_repeat == 1 {
      rt.spawn_wasm(payload, entry, args)
    } else {
      rt.spawn_wasm_repeat(payload, entry, args, inner_repeat)
    }
    guard res is Ok(handle) else { return Err(res.unwrap_err()) }
    join_set.push(handle)
  }
  Ok(join_set)
}

///|
fn run_once(
  rt : @thread_runtime.ThreadRuntime,
  payload : Bytes,
  entry : String,
  threads : Int32,
  inner_repeat : Int32,
  use_cwasm : Bool,
) -> Result[UInt64, Error] {
  let start = @wasmtime.clock_now_ns()
  let join_set_res = spawn_all(
    rt, payload, entry, threads, inner_repeat, use_cwasm,
  )
  guard join_set_res is Ok(join_set) else {
    return Err(join_set_res.unwrap_err())
  }
  let join_res = join_set.join_all()
  guard join_res is Ok(_) else { return Err(join_res.unwrap_err()) }
  let end = @wasmtime.clock_now_ns()
  Ok(end - start)
}

///|
fn run_repeat(
  rt : @thread_runtime.ThreadRuntime,
  payload : Bytes,
  entry : String,
  threads : Int32,
  repeat : Int32,
  warmup : Int32,
  inner_repeat : Int32,
  use_cwasm : Bool,
) -> Result[UInt64, Error] {
  if repeat <= 0 {
    return Err(@builtin.Failure::Failure("repeat must be > 0"))
  }
  if warmup < 0 {
    return Err(@builtin.Failure::Failure("warmup must be >= 0"))
  }
  let mut total : UInt64 = 0
  for _ in 0..<warmup {
    let res = run_once(rt, payload, entry, threads, inner_repeat, use_cwasm)
    guard res is Ok(_) else { return Err(res.unwrap_err()) }
  }
  for _ in 0..<repeat {
    let res = run_once(rt, payload, entry, threads, inner_repeat, use_cwasm)
    guard res is Ok(elapsed) else { return Err(res.unwrap_err()) }
    total = total + elapsed
  }
  Ok(total)
}

///|
fn main {
  let opts = parse_args()
  guard opts is Some(options) else { return }
  let result : Result[UInt64, Error] = try
    @fs.read_file_to_bytes(options.wasm_path)
  catch {
    err => Err(err)
  } noraise {
    wasm =>
      @thread_runtime.ThreadRuntime::new(1).bind(rt => {
        let precompiled = if options.use_cwasm {
          rt
          .precompile_cwasm(wasm)
          .bind(cwasm => {
            cwasm_output_path(options.wasm_path).bind(path => {
              @fs.write_bytes_to_file(path, cwasm) catch {
                err => return Err(err)
              }
              Ok(cwasm)
            })
          })
        } else {
          Ok(wasm)
        }
        let outcome = precompiled.bind(payload => {
          build_worklist(options.host_dir, options.file_limit)
          .bind(_ => {
            if options.inherit_stdio {
              rt.wasi_inherit_stdio()
            } else {
              Ok(())
            }
          })
          .bind(_ => rt.wasi_preopen_dir(options.host_dir))
          .bind(_ => {
            run_repeat(
              rt,
              payload,
              options.entry,
              options.threads,
              options.repeat,
              options.warmup,
              options.inner_repeat,
              options.use_cwasm,
            )
          })
        })
        rt.delete()
        outcome
      })
  }
  match result {
    Ok(total_ns) => {
      let batch_den = Int32::to_uint64(options.repeat)
      let batch_avg = total_ns / batch_den
      let inner = if options.inner_repeat <= 0 {
        1
      } else {
        options.inner_repeat
      }
      let iter_den = Int32::to_uint64(options.repeat * inner)
      let iter_avg = total_ns / iter_den
      println(
        "wasi io: avg_batch_ns=\{batch_avg} avg_iter_ns=\{iter_avg} threads=\{options.threads} repeat=\{options.repeat} inner_repeat=\{options.inner_repeat} warmup=\{options.warmup} cwasm=\{options.use_cwasm}",
      )
    }
    Err(err) => println("wasi io failed: \{err}")
  }
}
