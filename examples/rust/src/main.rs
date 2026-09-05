use rllvm_rust_lib::rllvm_rust_value;

fn main() {
    std::process::exit(if rllvm_rust_value() == 42 { 0 } else { 1 });
}
