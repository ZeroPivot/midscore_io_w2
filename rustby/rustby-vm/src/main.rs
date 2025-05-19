use notify::{Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use std::{fs, path::PathBuf, sync::mpsc::channel};
use tokio::runtime::Runtime;

// Cargo.toml:
// [package]
// name = "magnus_vm_async"
// version = "0.1.0"
// edition = "2021"
//
// [dependencies]
// magnus = "0.3"
// tokio = { version = "1", features = ["rt-multi-thread", "macros"] }
// notify = "5.0"

use magnus::{embed, eval, prelude::*, Error, Ruby, Value, Object, Module, RString, RHash, RArray, RModule, RClass };
use magnus::embed::init;
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let (tx, rx) = channel();
    let mut watcher = RecommendedWatcher::new(
        move |res: Result<Event, notify::Error>| {
            if let Ok(event) = res {
                tx.send(event).ok();
            }
        },
        notify::Config::default()
    )?;



    let folder = std::env::args()
        .skip_while(|arg| arg != "--folder")
        .skip(1)
        .next()
        .unwrap_or("scripts".to_string());

    std::fs::create_dir_all(&folder)?;

    watcher.watch(std::path::Path::new(&folder), RecursiveMode::Recursive)?;
    watcher.watch(std::path::Path::new("scripts"), RecursiveMode::Recursive)?;
    fs::write("scripts/pid.txt", std::process::id().to_string())?;

    let ruby = unsafe{ init() };
    println!("Watching for Ruby scripts in ./scripts...");
   

    loop {
        if let Ok(event) = rx.recv() {
            if let EventKind::Create(_) = event.kind {
                for path in event.paths {
                    if path.extension().and_then(|e| e.to_str()) == Some("rb") {
                        let code = fs::read_to_string(&path)?;
                        let result = match ruby.eval::<Value>(&code) {
                            Ok(val) => val.to_string(),
                            Err(e) => format!("Error: {}", e),
                        };
                        let txt_path = path.with_extension("txt");
                        fs::write(&txt_path, result.to_string())?;
                        //fs::remove_file(&path)?;
                        println!("Evaluated {:?} -> {:?}", path, txt_path);
                    }
                }
            }
        }
    }
} 
