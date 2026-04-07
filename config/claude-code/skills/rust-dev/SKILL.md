---
name: rust-dev
description: "Rust development reference - cargo, async patterns, error handling, testing, memory safety idioms"
user-invocable: true
disable-model-invocation: true
---

# Rust Development Reference

Reference for Rust development including cargo workflows, common patterns, error handling, testing, and ecosystem conventions.

## Development Workflow

### Project Setup

```bash
# New binary project
cargo new my-project
cargo new my-project --bin

# New library
cargo new my-lib --lib

# Initialize in existing directory
cargo init
cargo init --lib
```

### Building and Running

```bash
# Development build
cargo build

# Release build (optimized)
cargo build --release

# Run
cargo run
cargo run --release
cargo run -- arg1 arg2

# Check (fast, no codegen)
cargo check

# Build specific binary in workspace
cargo build --bin my-binary
cargo build -p my-crate
```

### Testing

```bash
# Run all tests
cargo test

# Run specific test
cargo test test_name
cargo test module::test_name

# Run tests with output
cargo test -- --nocapture

# Run ignored tests
cargo test -- --ignored

# Run doc tests only
cargo test --doc

# Run specific integration test
cargo test --test integration_test_name
```

### Linting and Formatting

```bash
# Format code
cargo fmt

# Check formatting without changes
cargo fmt -- --check

# Lint
cargo clippy

# Clippy with warnings as errors
cargo clippy -- -D warnings

# Fix lint warnings automatically
cargo clippy --fix
```

### Documentation

```bash
# Build docs
cargo doc

# Build and open docs
cargo doc --open

# Include private items
cargo doc --document-private-items
```

## Project Structure

```
my-project/
├── Cargo.toml           # Package manifest
├── Cargo.lock           # Dependency lock file
├── src/
│   ├── main.rs          # Binary entry point
│   ├── lib.rs           # Library root
│   ├── bin/             # Additional binaries
│   │   └── other.rs
│   └── module/          # Module with submodules
│       ├── mod.rs       # Module root (or use module.rs)
│       └── submod.rs
├── tests/               # Integration tests
│   └── integration.rs
├── benches/             # Benchmarks
│   └── benchmark.rs
├── examples/            # Example code
│   └── example.rs
└── build.rs             # Build script
```

## Cargo.toml Patterns

```toml
[package]
name = "my-crate"
version = "0.1.0"
edition = "2021"
rust-version = "1.70"
authors = ["Name <email@example.com>"]
description = "A brief description"
license = "MIT"
repository = "https://github.com/user/repo"
keywords = ["keyword1", "keyword2"]
categories = ["development-tools"]

[dependencies]
serde = { version = "1.0", features = ["derive"] }
tokio = { version = "1", features = ["full"] }

[dev-dependencies]
tempfile = "3"
criterion = "0.5"

[build-dependencies]
cc = "1.0"

[features]
default = ["feature1"]
feature1 = []
full = ["feature1", "feature2"]

[[bin]]
name = "my-binary"
path = "src/bin/my-binary.rs"

[[bench]]
name = "my_benchmark"
harness = false

[profile.release]
lto = true
codegen-units = 1
strip = true
```

## Error Handling

### Result and Option

```rust
// Result type alias pattern
pub type Result<T> = std::result::Result<T, Error>;

// Custom error type
#[derive(Debug)]
pub enum Error {
    Io(std::io::Error),
    Parse(std::num::ParseIntError),
    Custom(String),
}

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Error::Io(e) => write!(f, "IO error: {}", e),
            Error::Parse(e) => write!(f, "Parse error: {}", e),
            Error::Custom(s) => write!(f, "{}", s),
        }
    }
}

impl std::error::Error for Error {}

// From implementations for ? operator
impl From<std::io::Error> for Error {
    fn from(e: std::io::Error) -> Self {
        Error::Io(e)
    }
}
```

### thiserror Crate (Recommended)

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum Error {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Parse error at line {line}: {message}")]
    Parse { line: usize, message: String },

    #[error("Not found: {0}")]
    NotFound(String),
}
```

### anyhow for Applications

```rust
use anyhow::{Context, Result, bail, ensure};

fn main() -> Result<()> {
    let config = load_config()
        .context("Failed to load configuration")?;

    ensure!(config.is_valid(), "Invalid configuration");

    if config.value > 100 {
        bail!("Value {} exceeds maximum", config.value);
    }

    Ok(())
}
```

## Async Patterns (Tokio)

### Basic Async

```rust
use tokio;

#[tokio::main]
async fn main() {
    let result = async_operation().await;
}

// Or with runtime builder
fn main() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        async_operation().await;
    });
}
```

### Spawning Tasks

```rust
use tokio::task;

// Spawn concurrent task
let handle = tokio::spawn(async {
    // async work
    42
});
let result = handle.await?;

// Spawn blocking task (for CPU-bound or sync I/O)
let result = task::spawn_blocking(|| {
    // blocking work
    expensive_computation()
}).await?;
```

### Channels

```rust
use tokio::sync::{mpsc, oneshot, broadcast, watch};

// Multi-producer, single-consumer
let (tx, mut rx) = mpsc::channel(32);
tx.send(value).await?;
while let Some(msg) = rx.recv().await {
    // handle msg
}

// Oneshot (single value)
let (tx, rx) = oneshot::channel();
tx.send(value)?;
let result = rx.await?;

// Broadcast (multi-consumer)
let (tx, _) = broadcast::channel(16);
let mut rx = tx.subscribe();

// Watch (single value, latest only)
let (tx, rx) = watch::channel(initial_value);
```

### Select and Join

```rust
use tokio::{select, join};

// Select first to complete
select! {
    result = future1 => { /* handle */ },
    result = future2 => { /* handle */ },
}

// Join all (concurrent execution)
let (r1, r2, r3) = join!(future1, future2, future3);

// Try join (stops on first error)
let (r1, r2) = tokio::try_join!(future1, future2)?;
```

## Common Idioms

### Builder Pattern

```rust
#[derive(Default)]
pub struct ConfigBuilder {
    name: Option<String>,
    value: u32,
}

impl ConfigBuilder {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn name(mut self, name: impl Into<String>) -> Self {
        self.name = Some(name.into());
        self
    }

    pub fn value(mut self, value: u32) -> Self {
        self.value = value;
        self
    }

    pub fn build(self) -> Result<Config, Error> {
        Ok(Config {
            name: self.name.ok_or(Error::MissingField("name"))?,
            value: self.value,
        })
    }
}
```

### Newtype Pattern

```rust
// Type safety without runtime cost
pub struct UserId(u64);
pub struct PostId(u64);

impl UserId {
    pub fn new(id: u64) -> Self {
        Self(id)
    }

    pub fn inner(&self) -> u64 {
        self.0
    }
}
```

### Interior Mutability

```rust
use std::cell::{Cell, RefCell};
use std::sync::{Arc, Mutex, RwLock};

// Single-threaded
let cell = Cell::new(5);      // Copy types
let refcell = RefCell::new(vec![1, 2, 3]);  // Any type

// Thread-safe
let mutex = Arc::new(Mutex::new(data));
let rwlock = Arc::new(RwLock::new(data));

// Atomic types for primitives
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
```

### Iterator Patterns

```rust
// Collect with type annotation
let v: Vec<_> = iter.collect();
let map: HashMap<_, _> = pairs.collect();

// Common adapters
iter.filter(|x| x > &0)
    .map(|x| x * 2)
    .take(10)
    .enumerate()
    .collect::<Vec<_>>();

// Fallible iteration
let results: Result<Vec<_>, _> = iter.map(fallible_fn).collect();
```

## Testing Patterns

### Unit Tests

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_basic() {
        assert_eq!(add(2, 2), 4);
    }

    #[test]
    #[should_panic(expected = "divide by zero")]
    fn test_panic() {
        divide(1, 0);
    }

    #[test]
    fn test_result() -> Result<(), Error> {
        let result = fallible_operation()?;
        assert!(result > 0);
        Ok(())
    }

    #[test]
    #[ignore]
    fn slow_test() {
        // Only runs with --ignored
    }
}
```

### Async Tests

```rust
#[tokio::test]
async fn test_async() {
    let result = async_operation().await;
    assert!(result.is_ok());
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_multi_threaded() {
    // Runs with specific runtime config
}
```

### Test Fixtures

```rust
use std::sync::Once;

static INIT: Once = Once::new();

fn setup() {
    INIT.call_once(|| {
        // One-time setup
    });
}

#[test]
fn test_with_setup() {
    setup();
    // test code
}
```

## Memory Safety Patterns

### Lifetimes

```rust
// Struct with lifetime
struct Parser<'a> {
    input: &'a str,
}

// Multiple lifetimes
fn longest<'a, 'b>(x: &'a str, y: &'b str) -> &'a str
where
    'b: 'a,  // 'b outlives 'a
{
    if x.len() > y.len() { x } else { y }
}

// Static lifetime
const CONFIG: &'static str = "value";
```

### Smart Pointers

```rust
use std::rc::Rc;
use std::sync::Arc;

// Single-threaded reference counting
let rc = Rc::new(data);
let clone = Rc::clone(&rc);

// Thread-safe reference counting
let arc = Arc::new(data);
let clone = Arc::clone(&arc);

// Weak references (break cycles)
use std::rc::Weak;
let weak: Weak<_> = Rc::downgrade(&rc);
```

## Common Crates

| Crate | Purpose |
|-------|---------|
| `serde` + `serde_json` | Serialization |
| `tokio` | Async runtime |
| `anyhow` / `thiserror` | Error handling |
| `clap` | CLI argument parsing |
| `tracing` | Logging/diagnostics |
| `reqwest` | HTTP client |
| `sqlx` / `diesel` | Database |
| `regex` | Regular expressions |
| `chrono` / `time` | Date/time |
| `rayon` | Data parallelism |
| `crossbeam` | Concurrency primitives |

## NixOS-Specific

### Using nix develop

```bash
# Enter development shell
nix develop

# Run command in shell
nix develop --command cargo build
```

### flake.nix Pattern

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };
        rust = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" ];
        };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            rust
            pkg-config
            openssl
          ];
        };
      });
}
```

For detailed API patterns, common error types, and advanced topics, see `patterns.md` in this directory.


## Directive: update-skill
When the user says "update-skill", read [references/update-skill.md](references/update-skill.md) and follow those instructions.
