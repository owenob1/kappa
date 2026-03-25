use kappa_parser::parse;
use std::fs;

fn main() {
    let dir = "../../examples/dense";
    let mut ok = 0;
    let mut total = 0;
    let mut entries: Vec<_> = fs::read_dir(dir).unwrap()
        .filter_map(|e| e.ok())
        .filter(|e| e.path().extension().map_or(false, |ext| ext == "kappa"))
        .collect();
    entries.sort_by_key(|e| e.file_name());
    
    for entry in &entries {
        total += 1;
        let src = fs::read_to_string(entry.path()).unwrap();
        let result = parse(&src);
        let fields: usize = result.entities.iter().map(|e| e.fields.len()).sum();
        if result.diagnostics.is_empty() {
            println!("PASS {}: {} entities, {} fields",
                entry.file_name().to_string_lossy(),
                result.entities.len(), fields);
            ok += 1;
        } else {
            println!("FAIL {}: {}", entry.file_name().to_string_lossy(),
                result.diagnostics[0].message);
        }
    }
    println!("{}/{} passed", ok, total);
    if ok != total { std::process::exit(1); }
}
