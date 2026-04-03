use std::env;
use std::process;

const VERSION: &str = env!("CARGO_PKG_VERSION");

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() > 1 {
        match args[1].as_str() {
            "--version" | "-V" => {
                println!("sample-binary {VERSION}");
                process::exit(0);
            }
            "--help" | "-h" => {
                println!("sample-binary {VERSION}");
                println!();
                println!("A minimal test binary for rust-binary-build CI");
                println!();
                println!("Usage: sample-binary [OPTIONS]");
                println!();
                println!("Options:");
                println!("  -V, --version  Print version");
                println!("  -h, --help     Print help");
                process::exit(0);
            }
            other => {
                eprintln!("Unknown option: {other}");
                eprintln!("Run with --help for usage");
                process::exit(1);
            }
        }
    }

    println!("Hello from sample-binary v{VERSION}!");
}
