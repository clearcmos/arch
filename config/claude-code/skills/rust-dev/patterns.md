# Rust Advanced Patterns Reference

Detailed patterns and idioms for Rust development.

## Trait Patterns

### Extension Traits

```rust
// Extend existing types with new methods
pub trait StringExt {
    fn truncate_ellipsis(&self, max_len: usize) -> String;
}

impl StringExt for str {
    fn truncate_ellipsis(&self, max_len: usize) -> String {
        if self.len() <= max_len {
            self.to_string()
        } else {
            format!("{}...", &self[..max_len.saturating_sub(3)])
        }
    }
}

// Usage
use crate::StringExt;
let s = "hello world".truncate_ellipsis(8);
```

### Sealed Traits

```rust
// Prevent external implementations
mod private {
    pub trait Sealed {}
}

pub trait MyTrait: private::Sealed {
    fn method(&self);
}

impl private::Sealed for MyType {}
impl MyTrait for MyType {
    fn method(&self) { /* ... */ }
}
```

### Trait Objects vs Generics

```rust
// Static dispatch (generics) - faster, monomorphized
fn process<T: Display>(item: T) {
    println!("{}", item);
}

// Dynamic dispatch (trait objects) - smaller binary, runtime dispatch
fn process_dyn(item: &dyn Display) {
    println!("{}", item);
}

// Object-safe traits can be used as trait objects
// NOT object-safe: generic methods, Self in return type, associated types without bounds
```

## Concurrency Patterns

### Shared State with Mutex

```rust
use std::sync::{Arc, Mutex};
use std::thread;

let counter = Arc::new(Mutex::new(0));
let mut handles = vec![];

for _ in 0..10 {
    let counter = Arc::clone(&counter);
    let handle = thread::spawn(move || {
        let mut num = counter.lock().unwrap();
        *num += 1;
    });
    handles.push(handle);
}

for handle in handles {
    handle.join().unwrap();
}
```

### RwLock for Read-Heavy Workloads

```rust
use std::sync::{Arc, RwLock};

let data = Arc::new(RwLock::new(vec![1, 2, 3]));

// Multiple readers
let read_guard = data.read().unwrap();

// Exclusive writer
let mut write_guard = data.write().unwrap();
write_guard.push(4);
```

### Scoped Threads (std::thread::scope)

```rust
let mut data = vec![1, 2, 3];

std::thread::scope(|s| {
    s.spawn(|| {
        // Can borrow data directly - no Arc needed
        println!("{:?}", data);
    });

    s.spawn(|| {
        // Another thread
        println!("len: {}", data.len());
    });
}); // Threads are joined here

// data is still usable
data.push(4);
```

### Async Mutex (Tokio)

```rust
use tokio::sync::Mutex;
use std::sync::Arc;

let data = Arc::new(Mutex::new(0));

let data_clone = data.clone();
tokio::spawn(async move {
    let mut lock = data_clone.lock().await;
    *lock += 1;
});
```

## Type System Patterns

### Typestate Pattern

```rust
// Compile-time state machine
struct Unvalidated;
struct Validated;

struct Form<State> {
    data: String,
    _state: std::marker::PhantomData<State>,
}

impl Form<Unvalidated> {
    fn new(data: String) -> Self {
        Form {
            data,
            _state: std::marker::PhantomData,
        }
    }

    fn validate(self) -> Result<Form<Validated>, Error> {
        if self.data.is_empty() {
            return Err(Error::Empty);
        }
        Ok(Form {
            data: self.data,
            _state: std::marker::PhantomData,
        })
    }
}

impl Form<Validated> {
    fn submit(self) -> Result<(), Error> {
        // Only validated forms can be submitted
        Ok(())
    }
}
```

### Phantom Data

```rust
use std::marker::PhantomData;

// Type parameter not used in fields
struct Handle<T> {
    id: u64,
    _marker: PhantomData<T>,
}

// Indicates ownership semantics
struct Ref<'a, T> {
    ptr: *const T,
    _marker: PhantomData<&'a T>,
}
```

### Const Generics

```rust
// Array-like with compile-time size
struct Buffer<const N: usize> {
    data: [u8; N],
}

impl<const N: usize> Buffer<N> {
    fn new() -> Self {
        Self { data: [0; N] }
    }

    fn len(&self) -> usize {
        N
    }
}

let small: Buffer<64> = Buffer::new();
let large: Buffer<1024> = Buffer::new();
```

## Memory Patterns

### Cow (Clone on Write)

```rust
use std::borrow::Cow;

fn process(input: &str) -> Cow<str> {
    if input.contains(' ') {
        // Only allocate if needed
        Cow::Owned(input.replace(' ', "_"))
    } else {
        Cow::Borrowed(input)
    }
}
```

### MaybeUninit for Uninitialized Memory

```rust
use std::mem::MaybeUninit;

// Safe uninitialized array
let mut arr: [MaybeUninit<u32>; 10] = unsafe {
    MaybeUninit::uninit().assume_init()
};

for (i, elem) in arr.iter_mut().enumerate() {
    elem.write(i as u32);
}

// Now safe to transmute
let arr: [u32; 10] = unsafe {
    std::mem::transmute(arr)
};
```

### Pin for Self-Referential Structs

```rust
use std::pin::Pin;
use std::future::Future;

// Futures must be pinned to poll
fn poll_future(future: Pin<&mut impl Future>) {
    // ...
}

// Pin to heap
let pinned = Box::pin(my_future);
```

## Macro Patterns

### Declarative Macros

```rust
// Simple macro
macro_rules! vec_of_strings {
    ($($x:expr),*) => {
        vec![$($x.to_string()),*]
    };
}

// With different patterns
macro_rules! hashmap {
    () => { std::collections::HashMap::new() };
    ($($key:expr => $value:expr),+ $(,)?) => {{
        let mut map = std::collections::HashMap::new();
        $(map.insert($key, $value);)+
        map
    }};
}

let map = hashmap! {
    "a" => 1,
    "b" => 2,
};
```

### Derive Macros

```rust
// Using derive
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
struct Point {
    x: i32,
    y: i32,
}

// Serde
#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct Config {
    #[serde(default)]
    enabled: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    value: Option<u32>,
}
```

## FFI Patterns

### C Interop

```rust
// Calling C from Rust
extern "C" {
    fn strlen(s: *const c_char) -> usize;
}

// Exposing Rust to C
#[no_mangle]
pub extern "C" fn rust_function(x: i32) -> i32 {
    x * 2
}

// C-compatible types
#[repr(C)]
struct CStruct {
    field1: c_int,
    field2: *const c_char,
}
```

### CString Handling

```rust
use std::ffi::{CString, CStr};
use std::os::raw::c_char;

// Rust to C
let c_string = CString::new("hello").unwrap();
let ptr: *const c_char = c_string.as_ptr();

// C to Rust
unsafe {
    let c_str = CStr::from_ptr(ptr);
    let rust_str: &str = c_str.to_str().unwrap();
}
```

## Performance Patterns

### Avoiding Allocations

```rust
// Reuse buffers
let mut buffer = String::new();
for item in items {
    buffer.clear();
    write!(&mut buffer, "{}", item).unwrap();
    process(&buffer);
}

// Use references instead of cloning
fn process(s: &str) { /* ... */ }

// Use iterators instead of collecting
let sum: i32 = items.iter().map(|x| x * 2).sum();
```

### SIMD with std::simd (nightly)

```rust
#![feature(portable_simd)]
use std::simd::*;

fn add_arrays(a: &[f32; 4], b: &[f32; 4]) -> [f32; 4] {
    let va = f32x4::from_array(*a);
    let vb = f32x4::from_array(*b);
    (va + vb).to_array()
}
```

### Benchmarking with Criterion

```rust
// benches/my_benchmark.rs
use criterion::{black_box, criterion_group, criterion_main, Criterion};

fn fibonacci(n: u64) -> u64 {
    match n {
        0 => 1,
        1 => 1,
        n => fibonacci(n-1) + fibonacci(n-2),
    }
}

fn criterion_benchmark(c: &mut Criterion) {
    c.bench_function("fib 20", |b| b.iter(|| fibonacci(black_box(20))));
}

criterion_group!(benches, criterion_benchmark);
criterion_main!(benches);
```

## Unsafe Patterns

### Unsafe Guidelines

```rust
// Document safety invariants
/// # Safety
///
/// `ptr` must be valid and properly aligned.
/// The memory must be initialized.
unsafe fn read_value(ptr: *const u32) -> u32 {
    *ptr
}

// Minimize unsafe scope
fn safe_wrapper(data: &[u8]) -> u32 {
    assert!(data.len() >= 4);
    // Only the actual unsafe operation
    unsafe {
        std::ptr::read(data.as_ptr() as *const u32)
    }
}
```

### Raw Pointers

```rust
let mut x = 5;
let raw_ptr: *mut i32 = &mut x;

unsafe {
    *raw_ptr = 10;
}

// Pointer arithmetic
let arr = [1, 2, 3, 4, 5];
let ptr = arr.as_ptr();
unsafe {
    let third = *ptr.add(2);
}
```

## Common Gotchas

### String vs &str

```rust
// &str - borrowed, immutable view
let s: &str = "hello";

// String - owned, growable
let mut owned = String::from("hello");
owned.push_str(" world");

// Conversion
let owned: String = s.to_string();
let borrowed: &str = &owned;
```

### Deref Coercion

```rust
// These work automatically:
// &String -> &str
// &Vec<T> -> &[T]
// &Box<T> -> &T

fn takes_str(s: &str) {}
let string = String::from("hello");
takes_str(&string);  // Deref coercion
```

### Move vs Copy

```rust
// Copy types: i32, f64, bool, char, (i32, i32), [i32; 3]
let x = 5;
let y = x;  // Copy
println!("{}", x);  // Still valid

// Move types: String, Vec, Box, etc.
let s = String::from("hello");
let t = s;  // Move
// println!("{}", s);  // Error: s moved

// Clone explicitly
let s = String::from("hello");
let t = s.clone();
println!("{}", s);  // Valid
```

### Iterator Invalidation Prevention

```rust
// Can't modify while iterating
let mut vec = vec![1, 2, 3];

// Error: can't borrow as mutable while borrowed as immutable
// for x in &vec {
//     vec.push(x * 2);
// }

// Solution 1: Collect first
let to_add: Vec<_> = vec.iter().map(|x| x * 2).collect();
vec.extend(to_add);

// Solution 2: Index-based iteration
for i in 0..vec.len() {
    let new_val = vec[i] * 2;
    vec.push(new_val);
}
```
