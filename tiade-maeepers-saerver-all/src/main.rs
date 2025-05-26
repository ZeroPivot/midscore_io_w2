use tide_rustls::TlsListener;
use tide::utils::After;
use magnus::embed::init;
use magnus::{eval,
    Error, RArray, RClass, RFile, RFloat, RHash, RModule, RObject, RRegexp, RString, RStruct, Ruby,
    Value, function, method, prelude::*, rb_assert, typed_data, value::Lazy, value::Opaque,
};
use std::io::{self, BufRead};

// v1.0.0.0

/// Evaluates Ruby code and always returns a String.
pub fn call_rustby_eval(code: &str) -> Result<String, Error> {
    let result = eval::<RString>(code)?;
    Ok(result.to_string()?)
}

/// Evaluates Ruby code from a &str and prints the result.
/// This function initializes a Ruby VM, evaluates the code, and prints the output.
/// If evaluation fails, it prints the error.
fn execute_ruby_code(ruby_code: &str) {
  match eval::<magnus::Value>(ruby_code) {
    Ok(val) => println!("Ruby result: {:?}", val),
    Err(e) => eprintln!("Ruby error: {}", e),
  }
}

async fn init_ruby_vm() {
  Ruby::init(|_ruby| Ok(())).unwrap();
}

// Helper: Create a JSON response.
pub fn json_response<T: serde::Serialize>(data: T) -> tide::Response {
  tide::Response::builder(tide::StatusCode::Ok)
      .body(serde_json::to_string(&data).unwrap())
      .content_type(tide::http::mime::JSON)
      .build()
}

// Helper: Redirect to a given URL.
pub fn redirect(url: &str) -> tide::Response {
  let mut res = tide::Response::new(tide::StatusCode::Found);
  res.insert_header("Location", url);
  res
}

use anyhow::Result;
use image::{DynamicImage};
use std::io::Cursor;




// filepath: /path/to/helpers.rs

use serde::Serialize;




// filepath: /path/to/blog.rs

use std::fs::{self, OpenOptions};
use std::io::Write;

pub fn create_blog_post(title: &str, content: &str) -> Result<()> {
    // This is a simple example writing to a file.
    let filename = format!("posts/{}.md", title.replace(" ", "_"));
    let mut file = OpenOptions::new()
        .write(true)
        .create(true)
        .open(&filename)?;
    writeln!(file, "# {}\n\n{}", title, content)?;
    Ok(())
}

// Similar functions can be created for updating or deleting posts.
// filepath: /path/to/blog.rs


use std::path::Path;
use std::fs::File;
use std::io::Read;
use std::io::BufReader;
use std::io::BufWriter;



struct LogRoute;
#[tide::utils::async_trait]
impl tide::Middleware<AppState> for LogRoute {
    async fn handle(&self, req: tide::Request<AppState>, next: tide::Next<'_, AppState>) -> tide::Result {
        println!("Incoming route: {}", req.url().path());
        let res = next.run(req).await;
        println!("Response status: {}", res.status());
        Ok(res)
    }
}


use std::thread::JoinHandle;
use std::sync::mpsc;
use std::sync::mpsc::{channel, Sender};
use std::sync::Arc;
use std::sync::Mutex;
use std::thread;
use std::sync::mpsc::Receiver;
use std::sync::mpsc::sync_channel;
    


#[derive(Clone)]
struct AppState;

#[async_std::main]
async fn main() -> tide::Result<()> 
{
  // Spawn a background thread to listen for CLI input.
 std::thread::spawn(|| {
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
      if let Ok(input) = line {
       match input.trim() {
        "exit" => {
         println!("Exiting server abruptly.");
        std::process::exit(0);
      }

      // When the "rustby" command is input, write the Ruby code to a .rb file
      // in a shared directory ("./rustby_scripts"). Then, immediately load (evaluate)
      // the file using Magnus. The file is deleted after evaluation. The Ruby code in
      // the file is expected to return a string.
      "rustby" => {
        println!("Running Ruby code via named pipe sharing system...");
       let script_dir = "./rustby_scripts";
        if let Err(e) = std::fs::create_dir_all(script_dir) {
        eprintln!("Failed to create script directory: {}", e);
        continue;
        }
         let filename = format!("{}/script_{}.rb", script_dir, Utc::now().timestamp_nanos());
        // Replace the Ruby code below as needed. It must return a string value.
       let ruby_code = r#"nil        
       'RustbySpace'
      "#;
       if let Err(e) = std::fs::write(&filename, ruby_code) {
       eprintln!("Error writing script file: {}", e);
        continue;
       }
        println!("Script file written: {}", filename);

        // Instead of calling the Ruby evaluator directly (which cannot be done in a thread),
        // write the Ruby load command to a named pipe for external processing.
        let pipe_path = "/tmp/ruby_pipe";
        if let Err(e) = std::fs::write(pipe_path, format!("load '{}'\n", filename)) {
            eprintln!("Error writing to named pipe: {}", e);
        } else {
            println!("Command sent to Ruby evaluator via pipe: {}", pipe_path);
       }
     
        // Wait briefly for the external process to evaluate the script and write the result.
        std::thread::sleep(std::time::Duration::from_millis(100));
        
        // Read the evaluation result from an output file.
        let result_path = "/tmp/ruby_output.txt";
        let script_result = match std::fs::read_to_string(result_path) {
                    Ok(output) => Ok(output),
                    Err(e) => {
                  eprintln!("Error reading Ruby output: {}", e);
                  Err(magnus::Error::new(magnus::exception::runtime_error(), format!("Error reading Ruby output: {}", e)))
                    },
                };
        
        // Remove the script file after evaluation.
        if let Err(e) = std::fs::remove_file(&filename) {
        eprintln!("Failed to remove script file: {}", e);
        }
        
        match script_result {
        Ok(output) => println!("Ruby output: {}", output),
        Err(e) => eprintln!("Error running Ruby code: {}", e),
        }
      }

      "restart" => {
        println!("Restarting all servers...");
        std::process::Command::new("sh")
        .arg("-c")
        .arg("killall -HUP tiade-maeepers-saerver-all") // Replace with your server binary name
        .spawn()
        .expect("Failed to restart servers");
      }
      _ => {
        println!("Unknown command: {}", input.trim());
      }
      }
    }
    }
  });

  
  // ... rest of the main function (server setup, routes, etc.)
//  Ok(())


    //////
    /// 
    /// 
    /// 
    /// 
    /// 
  
  
  /*
    ///
     // Example: Spawn 3 independent Ruby interpreter threads.
     let mut handles: Vec<JoinHandle<Result<(), Error>>> = Vec::new();
      
 
     // Optionally, wait for the threads to complete.
     for handle in handles {
         match handle.join() {
             Ok(Ok(())) => println!("Ruby instance finished successfully."),
             Ok(Err(err)) => eprintln!("Ruby eval error: {}", err),
             Err(_) => eprintln!("A thread panicked."),
         }
     }
 */
     // Continue with the rest of your server setup…
     //Ok(())
     // 

    // Main HTTPS server - handling all defined routes
    let mut app = tide::with_state(AppState {});

    // Custom middleware to log which route is being handled
    struct LogRoute;
    #[tide::utils::async_trait]
    impl tide::Middleware<AppState> for LogRoute {
        async fn handle(&self, req: tide::Request<AppState>, next: tide::Next<'_, AppState>) -> tide::Result {
            let route = req.url().path().to_string();
            let res = next.run(req).await;
            println!("Route '{}' handled with status: {}", route, res.status());
            Ok(res)
        }
    }

    app.with(LogRoute);

    // Initialize the Ruby interpreter
    let _ruby = init_ruby_vm().await;

    use std::sync::Arc;
   

    use std::collections::HashMap;
    use tide::{Request, Response, StatusCode};

    use url::Url;
    //let rustby_eval_title = rustby_eval_title.clone();


    // Utility function to list files in a directory with a specific extension.
    fn list_files_with_ext(dir: &str, ext: &str) -> std::io::Result<Vec<String>> {
      let mut files = Vec::new();
      for entry in std::fs::read_dir(dir)? {
        let entry = entry?;
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()) == Some(ext) {
          if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
            files.push(name.to_string());
          }
        }
      }
      Ok(files)
    }

    // For CSS
    let css_files = list_files_with_ext("./css", "css")?;
    let css_list_index = css_files.join(", ");
    let css_html_index = format!(
      "<html><head>{}</head><body></body></html>",
      css_files
        .iter()
        .map(|f| format!("<link rel=\"stylesheet\" href=\"/css/{}\" />", f))
        .collect::<Vec<_>>()
        .join("\n")
    );

    // For JS
    let js_files = list_files_with_ext("./js", "js")?;
    let js_list_index = js_files.join(", ");
    let js_html_index = format!(
      "<html><head>{}</head><body></body></html>",
      js_files
        .iter()
        .map(|f| format!("<script src=\"/js/{}\"></script>", f))
        .collect::<Vec<_>>()
        .join("\n")
    );

    // For IMG (no specific extension check here, adjust as needed)
    let img_files: Vec<String> = std::fs::read_dir("./img")?
      .filter_map(|entry| {
        let p = entry.ok()?.path();
        p.file_name().and_then(|n| n.to_str()).map(String::from)
      })
      .collect();
    let img_list_index = img_files.join(", ");
    let img_html_index = format!(
      "<html><body>{}</body></html>",
      img_files
        .iter()
        .map(|f| format!("<img src=\"/img/{}\" alt=\"{}\" />", f, f))
        .collect::<Vec<_>>()
        .join("\n")
    );

    // For FONTS
    let fonts_files: Vec<String> = std::fs::read_dir("./fonts")?
      .filter_map(|entry| {
        let p = entry.ok()?.path();
        p.file_name().and_then(|n| n.to_str()).map(String::from)
      })
      .collect();
    let fonts_list_index = fonts_files.join(", ");
    let fonts_html_index = format!(
      "<html><body><ul>{}</ul></body></html>",
      fonts_files
        .iter()
        .map(|f| format!("<li>{}</li>", f))
        .collect::<Vec<_>>()
        .join("")
    );

    // For PUBLIC
    let public_files: Vec<String> = std::fs::read_dir("./public")?
      .filter_map(|entry| {
        let p = entry.ok()?.path();
        p.file_name().and_then(|n| n.to_str()).map(String::from)
      })
      .collect();
    let public_list_index = public_files.join(", ");
    let public_html_index = format!(
      "<html><body><ul>{}</ul></body></html>",
      public_files
        .iter()
        .map(|f| format!("<li>{}</li>", f))
        .collect::<Vec<_>>()
        .join("")
    );

    // Check all directories before serving; if any are missing, raise an error.
    for dir in &["./css", "./js", "./img", "./fonts", "./public"] {
      if std::fs::metadata(dir).is_err() {
        eprintln!("Error: directory {} not found", dir);
        panic!("Directory not found");
      }
    }

    // Serve each directory. Tide will serve new files as they appear.
    app.at("/css").serve_dir("./css/")?;
    app.at("/js").serve_dir("./js/")?;
    app.at("/img").serve_dir("./img/")?;
    app.at("/fonts").serve_dir("./fonts/")?;
    app.at("/public").serve_dir("./public/")?;

    #[derive(serde::Deserialize)]
    struct PraexyForm {
      content: String,
    }


    app.at("/praexy-saerver").post(|mut req: tide::Request<AppState>| async move {
      let form_data: PraexyForm = req.body_form().await.unwrap_or(PraexyForm { content: String::new() });
      Ok(format!("Received content:\n{}", form_data.content))
    });
  
  
  /* 
    app.at("/rustby").get(|req: tide::Request<AppState>| {
        let rustby_eval_title = rustby_eval_title.clone();
        async move {
            let query: HashMap<String, String> = req.query().unwrap_or_default();
            let vlog = query
                .get("vlog")
                .cloned()
                .unwrap_or_else(|| "".to_string());

            let title = rustby_eval_title.to_string();
            let base_iframe_url = format!("https://miaedscore.online:8080/{}", vlog);

            let html_content = format!(r######"<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{title}</title>
  <meta name="description" content="This page embeds an external webpage via an iFrame.">
  <meta name="author" content="TIADE-MAEPPERS">
  <meta name="keywords" content="HTML, iFrame, Embedded Page">
  <meta name="theme-color" content="#ffffff">
  <meta name="robots" content="index, follow">
  <meta name="googlebot" content="index, follow">
  <meta name="google" content="notranslate">
  <meta name="msapplication-TileColor" content="#ffffff">
  <meta name="msapplication-TileImage" content="https://example.com/favicon.png">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="default">
  <meta name="apple-mobile-web-app-title" content="Embedded iFrame">
  <meta name="application-name" content="Embedded iFrame">
  <meta name="format-detection" content="telephone=no">
  <link rel="icon" href="https://example.com/favicon.png">
  <style>
    body {{
      margin: 0;
      padding: 0;
      font-family: sans-serif;
      background-color: #f8f8f8;
    }}
    .header {{
      background-color: #333;
      color: #fff;
      padding: 10px 20px;
      text-align: center;
    }}
    .iframe-container {{
      position: relative;
      width: 100%;
      height: calc(100vh - 120px);
      overflow: hidden;
    }}
    .iframe-container iframe {{
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      border: none;
    }}
    .footer {{
      background-color: #333;
      color: #fff;
      text-align: center;
      padding: 10px 20px;
    }}
  </style>
  <script>
    document.addEventListener("DOMContentLoaded", function() {{
      document.body.addEventListener("click", function(event) {{
        var target = event.target.closest("a");
        if (target && target.href) {{
          event.preventDefault();
          var url = new URL(target.href);
          var newPath = url.pathname + url.search + url.hash;
          var iframe = document.getElementById("contentFrame");
          if (iframe) {{
            iframe.src = "{base_iframe_url}" + newPath;
            history.pushState(null, '', url.pathname);
          }}
        }}
      }});
    }});
  </script>
</head>
<body>
  <div class="header">
    <h1>{title}</h1>
    <nav>
      <a href="/page1">Page 1</a> |
      <a href="/page2?query=example">Page 2</a>
    </nav>
  </div>
  <div class="iframe-container">
    <iframe id="contentFrame" src="{base_iframe_url}"></iframe>
  </div>
  <div class="footer">
    <p>&copy; 2025 TIADE-MAEPPERS. All rights reserved.</p>
  </div>
</body>
</html>"######);

            let mut res = tide::Response::new(tide::StatusCode::Ok);
            res.set_body(html_content);
            res.set_content_type("text/html");
            Ok(res)
        }
    });
  */

  // Route to handle the "/bridge/*rest" path
  // This will serve an HTML page with an iframe loading the target URL.
  // The iframe will load the URL "https://miaedscore.online:8080/*rest"
  // The JavaScript snippet in the HTML will remove any query parameters from the browser URL.
  // The HTML page will be served with the content type "text/html".
  // The HTML page will be styled to take up the full width and height of the browser window.
  // The iframe will be styled to take up the full width and height of the browser window.
  // The HTML page will have a light gray background color.
  // The iframe will have no border.
  // The HTML page will have a title "Bridge Iframe".
  // The HTML page will have a meta tag for viewport settings.
  // The HTML page will have a meta tag for character set settings.
  // The HTML page will have a meta tag for theme color settings.
  // The HTML page will have a meta tag for robots settings.
  // The HTML page will have a meta tag for apple mobile web app settings.
  // The HTML page will have a meta tag for application name settings.
  // The HTML page will have a meta tag for format detection settings.
  // The HTML page will have a meta tag for ms application tile color settings.
  // The HTML page will have a meta tag for ms application tile image settings.
  // The HTML page will have a meta tag for google bot settings.
  // The HTML page will have a meta tag for google settings.
  // The HTML page will have a meta tag for favicon settings.
  // The HTML page will have a meta tag for author settings.
  // The HTML page will have a meta tag for description settings.


    app.at("/bridge/*rest").get(|req: tide::Request<AppState>| async move {
      // Extract the wildcard part from the URL.
      let rest = req.param("rest").unwrap_or("");
      // Build the target URL for the 8080 server.
      let target_url = format!("https://miaedscore.online:8080/{}", rest);
      
      // Build an HTML page with an iframe loading the target URL.
      // A JavaScript snippet removes any query parameters from the browser URL.
      let html_content = format!(r#"<!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bridge Iframe</title>
    <style>
      html, body {{
        margin: 0;
        padding: 0;
        width: 100%;
        height: 100%;
        background-color: #f8f8f8;
      }}
      iframe {{
        width: 100%;
        height: 100%;
        border: none;
      }}
    </style>
    <script>
      // Remove query parameters from address bar.
      if(window.location.search.length > 0) {{
        window.history.replaceState(null, null, window.location.pathname);
      }}
    </script>
  </head>
  <body>
    <iframe src="{0}" title="Bridge - Embedded 8080 Server"></iframe>
  </body>
  </html>"#, target_url);
  
      // Return the HTML response.
      let mut res = tide::Response::new(tide::StatusCode::Ok);
      res.set_body(html_content);
      res.set_content_type("text/html");
      Ok(res)
  });





  {
    std::fs::create_dir_all("./scripts").ok();
    let ts = Utc::now().timestamp_nanos_opt().unwrap_or(0);
    let filename = format!("./scripts/script_{ts}.rb");
    let contents = r######"
    
    require 'date'
    class MoonPhaseDetails2
      # === Constants and Definitions ===

      # Average length of a full lunar cycle (in days)
      MOON_CYCLE_DAYS = 29.53

       # The 17 fabled moon rotations with emojis:
        MOON_ROTATIONS = [
          'New Moon 🌑',            # 0
          'Waxing Crescent 🌒',     # 1
          'First Quarter 🌓',       # 2
          'Waxing Gibbous 🌔', # 3
          'Full Moon 🌕',           # 4
          'Waning Gibbous 🌖',      # 5
          'Last Quarter 🌗',        # 6
          'Waning Crescent 🌘',     # 7
          'Supermoon 🌝',           # 8
          'Blue Moon 🔵🌙',         # 9
          'Blood Moon 🩸🌙',        # 10
          'Harvest Moon 🍂🌕',      # 11
          "Hunter's Moon 🌙🔭",     # 12
          'Wolf Moon 🐺🌕',         # 13
          'Pink Moon 🌸🌕',
          'Snow Moon 🌨️',          # 14
          'Snow Moon Snow 🌨️❄️',    # 15
          'Avian Moon 🦅',          # 16
          'Avian Moon Snow 🦅❄️'    # 17
        ]

        # Define 15 corresponding species with emojis.
        SPECIES = [
          'Dogg 🐶', # New Moon
          'Folf 🦊🐺', # Waxing Crescent
          'Aardwolf 🐾',                 # First Quarter
          'Spotted Hyena 🐆',            # Waxing Gibbous
          'Folf Hybrid 🦊✨',             # Full Moon
          'Striped Hyena 🦓',            # Waning Gibbous
          'Dogg Prime 🐕⭐',              # Last Quarter
          'WolfFox 🐺🦊', # Waning Crescent
          'Brown Hyena 🦴',              # Supermoon
          'Dogg Celestial 🐕🌟',          # Blue Moon
          'Folf Eclipse 🦊🌒',            # Blood Moon
          'Aardwolf Luminous 🐾✨', # Harvest Moon
          'Spotted Hyena Stellar 🐆⭐', # Hunter's Moon
          'Folf Nova 🦊💥', # Wolf Moon
          'Brown Hyena Cosmic 🦴🌌', # Pink Moon
          'Snow Leopard 🌨️', # New Moon
          'Snow Leopard Snow Snep 🌨️❄️', # Pink Moon
          'Avian 🦅', # New Moon
          'Avian Snow 🦅❄️' # Pink Moon
        ]

        # Define 15 corresponding were-forms with emojis.
        WERE_FORMS = [
          'WereDogg 🐶🌑',                     # New Moon
          'WereFolf 🦊🌙',                     # Waxing Crescent
          'WereAardwolf 🐾',                   # First Quarter
          'WereSpottedHyena 🐆',               # Waxing Gibbous
          'WereFolfHybrid 🦊✨',                # Full Moon
          'WereStripedHyena 🦓',               # Waning Gibbous
          'WereDoggPrime 🐕⭐',                 # Last Quarter
          'WereWolfFox 🐺🦊', # Waning Crescent
          'WereBrownHyena 🦴',                 # Supermoon
          'WereDoggCelestial 🐕🌟',             # Blue Moon
          'WereFolfEclipse 🦊🌒',               # Blood Moon
          'WereAardwolfLuminous 🐾✨',          # Harvest Moon
          'WereSpottedHyenaStellar 🐆⭐',       # Hunter's Moon
          'WereFolfNova 🦊💥', # Wolf Moon
          'WereBrownHyenaCosmic 🦴🌌', # Pink Moon
          'WereSnowLeopard 🐆❄️',
          'WereSnowLeopardSnow 🐆❄️❄️', # Pink Moon
          'WereAvian 🦅', # New Moon
          'WereAvianSnow 🦅❄️' # Pink Moon

        ]
      # Each moon phase is assumed to share an equal slice of the lunar cycle.
      PHASE_COUNT  = MOON_ROTATIONS.size # 15 total phases
      PHASE_LENGTH = MOON_CYCLE_DAYS / PHASE_COUNT # Days per phase

      # === Core Function ===

      def self.current_moon_details(date)
        reference_date = Date.new(2000, 1, 6)
        days_since_reference = (date - reference_date).to_f
        lunar_position = days_since_reference % MOON_CYCLE_DAYS
        phase_index_raw = lunar_position / PHASE_LENGTH
        phase_index = phase_index_raw.floor
        conscious_percentage = (phase_index_raw / (PHASE_COUNT - 1).to_f) * 100
        current_phase     = MOON_ROTATIONS[phase_index % MOON_ROTATIONS.size]
        current_species   = SPECIES[phase_index % SPECIES.size]
        current_were_form = WERE_FORMS[phase_index % WERE_FORMS.size]
        consciousness_level = "#{phase_index_raw}/#{PHASE_COUNT - 1} (#{conscious_percentage}%)"
        [current_phase, current_species, current_were_form, consciousness_level, conscious_percentage, phase_index_raw]
      end

      # === HTML-Generating Functions ===

      def self.render_full_schedule_html
        rows = ''
        MOON_ROTATIONS.each_with_index do |phase_name, index|
          rows << <<~ROW
            <tr>
              <td>#{phase_name}</td>
              <td>#{SPECIES[index]}</td>
              <td>#{WERE_FORMS[index]}</td>
            </tr>
          ROW
        end

        <<~HTML
          <div class="container">
            <h1>Complete Moon Rotation Schedule</h1>
            <table>
              <thead>
                <tr>
                  <th>Moon Phase</th>
                  <th>Species</th>
                  <th>Were-Form</th>
                </tr>
              </thead>
              <tbody>
                #{rows}
              </tbody>
            </table>
          </div>
        HTML
      end

      def self.print_details_for_date(date)
        phase, species, were_form, consciousness, consciousness_percentage, phase_index_raw = current_moon_details(date)
        "<p>
            Moon Phase: #{phase}<br />
            Species: #{species}<br />
            Were-Form: #{were_form}<br />
            Consciousness: #{consciousness}<br />
            Miade-Score/Infini-Vaeria Consciousness: #{1 - (consciousness_percentage / 100)}% (#{1 - (phase_index_raw / PHASE_COUNT - 1)}%)<br />
          </p>"
      end

      def self.print_text_details_for_date(date)
        phase, species, were_form, consciousness, consciousness_percentage, phase_index_raw = current_moon_details(date)
        " Moon Phase: #{phase}\n
            Species: #{species}\n
            Were-Form: #{were_form}\n
            Consciousness: #{consciousness}\n"
      end
    end

    class SunPhase2
      attr_reader :name, :start_hour, :emoji

      def initialize(name, start_hour, emoji)
        @name = name
        @start_hour = start_hour
        @emoji = emoji
      end
    end

    class SolarDance2
      PHASES = [
        SunPhase2.new('Midnight Mystery', 0, '🌑'),
        SunPhase2.new('Dawn\'s Whisper', 3, '🌅'),
        SunPhase2.new('First Light’s Murmur', 5, '🔅'),
        SunPhase2.new('Golden Awakening', 6, '☀️'),
        SunPhase2.new('Morning Glow', 8, '🌞'),
        SunPhase2.new('High Noon Radiance', 12, '🔥'),
        SunPhase2.new('Afternoon Brilliance', 15, '🌇'),
        SunPhase2.new('Golden Hour Serenade', 17, '🌆'),
        SunPhase2.new('Twilight Poetry', 18, '🌒'),
        SunPhase2.new('Dusky Secrets', 19, '🌓'),
        SunPhase2.new('Crimson Horizon', 20, '🌔'),
        SunPhase2.new('Moon\'s Ascent', 21, '🌕'),
        SunPhase2.new('Nightfall\'s Caress', 22, '✨'),
        SunPhase2.new('Deep Celestial Silence', 23, '🌌'),
        SunPhase2.new('Cosmic Slumber', 24, '🌠')
      ]

      def self.current_phase
        pst_hour = Time.now.getlocal('-08:00').hour
        PHASES.reverse.find { |phase| pst_hour >= phase.start_hour }
      end

      def self.sun_dance_message
        phase = current_phase
        "The Sun is currently in \"#{phase.name}\" phase! #{phase.emoji}"
      end
    end

    class Calendar
      attr_reader :date

      def initialize
        @date = Date.today
      end

      def gregorian
        @date.strftime('%m/%d/%Y')
      end

      def julian
        jd = @date.jd
        julian_date = Date.jd(jd, Date::JULIAN)
        julian_date.strftime('%m/%d/%Y')
      end

      def julian_primitive
        @date.jd
      end

      def formatted_pst_time
        pst_time = Time.now.getlocal('-07:00')
        pst_time.strftime('%B, %d, %Y - %I:%M:%S %p SLT/PST')
      end
    end

         def formatted_pst_time
        pst_time = Time.now.getlocal('-07:00')
        pst_time.strftime('%B, %d, %Y - %I:%M:%S %p SLT/PST')
      end




    
    
    
    "######;
    std::fs::write(&filename, contents)?;
    println!("Created script file: {}", filename);
  }



  app.at("/time").get(|mut req: tide::Request<AppState>| async move {
    
    let script_dir = "./scripts";
    //td::fs::create_dir_all(script_dir).ok();
    let mut res = tide::Response::new(tide::StatusCode::Ok);
    //res.set_body("HTML content for /moon route");
    //res.set_content_type("text/html; charset=utf-8");
    //return Ok(res);
    // Grab Ruby code from request body.
    let ruby_source = r######"

    "Gregorian: #{Calendar.new.gregorian}\nJulian: #{Calendar.new.julian_primitive} -> #{Calendar.new.julian}\nPST+DST+SLT: #{formatted_pst_time}"

    "######;
    if ruby_source.trim().is_empty() {
        let mut resp = tide::Response::new(tide::StatusCode::Ok);
        resp.set_body("No Ruby code supplied");
        return Ok(resp);
    }

    // Create unique .rb filename.
    let ts = Utc::now().timestamp_nanos_opt().unwrap_or(0);
    let filename = format!("{}/moon_{}.rb", script_dir,ts);
    std::fs::write(&filename, &ruby_source).map_err(|e| tide::Error::new(tide::StatusCode::InternalServerError, e))?;



    
    let result_path = format!("./scripts/moon_{}.txt", ts);

    // Block until the result file is available or until timeout
    let start = std::time::Instant::now();
    let timeout = std::time::Duration::from_secs(120);
    while !std::path::Path::new(&result_path).exists() {
      if start.elapsed() > timeout {
        return Ok("Timed out waiting for result file".into());
      }
      std::thread::sleep(std::time::Duration::from_millis(1));
    }
    let output = std::fs::read_to_string(&result_path).unwrap_or_else(|_| "No output".to_string());


    // Remove script file after evaluation.
  
    let _ = std::fs::remove_file(&result_path);
    let _ = std::fs::remove_file(&filename);


     // Return the HTML response.
    let mut res = tide::Response::new(tide::StatusCode::Ok);
    res.set_body(output);
    res.insert_header("Content-Type", "text/plain; charset=utf-8");
    Ok(res)
    //Ok(output.into())
  });




  app.at("/moon").get(|mut req: tide::Request<AppState>| async move {
    
    let script_dir = "./scripts";
    //td::fs::create_dir_all(script_dir).ok();
    let mut res = tide::Response::new(tide::StatusCode::Ok);
    //res.set_body("HTML content for /moon route");
    //res.set_content_type("text/html; charset=utf-8");
    //return Ok(res);
    // Grab Ruby code from request body.
    let ruby_source = r######"

    "#{MoonPhaseDetails2.print_text_details_for_date(Date.today)}"

    "######;
    if ruby_source.trim().is_empty() {
        let mut resp = tide::Response::new(tide::StatusCode::Ok);
        resp.set_body("No Ruby code supplied");
        return Ok(resp);
    }

    // Create unique .rb filename.
    let ts = Utc::now().timestamp_nanos_opt().unwrap_or(0);
    let filename = format!("{}/moon_{}.rb", script_dir,ts);
    std::fs::write(&filename, &ruby_source).map_err(|e| tide::Error::new(tide::StatusCode::InternalServerError, e))?;



    
    let result_path = format!("./scripts/moon_{}.txt", ts);

    // Block until the result file is available or until timeout
    let start = std::time::Instant::now();
    let timeout = std::time::Duration::from_secs(120);
    while !std::path::Path::new(&result_path).exists() {
      if start.elapsed() > timeout {
        return Ok("Timed out waiting for result file".into());
      }
      std::thread::sleep(std::time::Duration::from_millis(1));
    }
    let output = std::fs::read_to_string(&result_path).unwrap_or_else(|_| "No output".to_string());


    // Remove script file after evaluation.
  
    let _ = std::fs::remove_file(&result_path);
    let _ = std::fs::remove_file(&filename);


     // Return the HTML response.
    let mut res = tide::Response::new(tide::StatusCode::Ok);
    res.set_body(output);
    res.insert_header("Content-Type", "text/plain; charset=utf-8");
    Ok(res)
    //Ok(output.into())
  });

    app.at("/sun").get(|mut req: tide::Request<AppState>| async move {
    let script_dir = "./scripts";
    //td::fs::create_dir_all(script_dir).ok();
    let mut res = tide::Response::new(tide::StatusCode::Ok);
    //res.set_body("HTML content for /moon route");
    res.set_content_type("text/html; charset=utf-8");
    //return Ok(res);
    // Grab Ruby code from request body.
    let ruby_source = r######"

    "#{SolarDance2.sun_dance_message}"

    "######;
    if ruby_source.trim().is_empty() {
        let mut resp = tide::Response::new(tide::StatusCode::Ok);
        resp.set_body("No Ruby code supplied");
        return Ok(resp);
    }

    // Create unique .rb filename.
    let ts = Utc::now().timestamp_nanos_opt().unwrap_or(0);
    let filename = format!("{}/sun_{}.rb", script_dir,ts);
    std::fs::write(&filename, &ruby_source).map_err(|e| tide::Error::new(tide::StatusCode::InternalServerError, e))?;

    let result_path = format!("./scripts/sun_{}.txt", ts);

    // Block until the result file is available or until timeout
    let start = std::time::Instant::now();
    let timeout = std::time::Duration::from_secs(120);
    while !std::path::Path::new(&result_path).exists() {
      if start.elapsed() > timeout {
        return Ok("Timed out waiting for result file".into());
      }
      std::thread::sleep(std::time::Duration::from_millis(1));
    }
    let output = std::fs::read_to_string(&result_path).unwrap_or_else(|_| "No output".to_string());


    // Remove script file after evaluation.
  
    let _ = std::fs::remove_file(&result_path);
    let _ = std::fs::remove_file(&filename);


     // Return the HTML response.
    let mut res = tide::Response::new(tide::StatusCode::Ok);
    res.set_body(output);
    res.insert_header("Content-Type", "text/plain; charset=utf-8");
    Ok(res)
    //Ok(output.into())
  });

  app.at("/tiade-maepers/*rest").get(|req: tide::Request<AppState>| async move {
    // Extract the wildcard part from the URL.
    let rest = req.param("rest").unwrap_or("");
    // Build the target URL for the 8080 server.
    let target_url = format!("https://miaedscore.online/{}", rest);
    
    // Build an HTML page with an iframe loading the target URL.
    // A JavaScript snippet removes any query parameters from the browser URL.
    let html_content = format!(r#"<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Bridge Iframe</title>
  <style>
  /* Include style.css from the CSS folder */
  @import url('/css/style.css');

  

  /* Additional styling specific to this page */
    html, body {{
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      background-color: #f8f8f8;
    }}
    iframe {{
      width: 100%;
      height: 100%;
      border: none;
    }}
  </style>
  <script>
    // Remove query parameters from address bar.
    if(window.location.search.length > 0) {{
      window.history.replaceState(null, null, window.location.pathname);
    }}
  </script>
</head>
<body>
  <iframe src="{0}" title="Stimky.info -> miadscore.online [B]log/Gallery"></iframe>
</body>
</html>"#, target_url);

    // Return the HTML response.
    let mut res = tide::Response::new(tide::StatusCode::Ok);
    res.set_body(html_content);
    res.set_content_type("text/html");
    Ok(res)
});
    app.at("/parse_plink").get(|req: tide::Request<AppState>| async move {
      
      // Expect a query parameter "text" that includes a full URL (e.g., "https://miaedscore.online:8080/some/path?query=val")
      let query: HashMap<String, String> = req.query().unwrap_or_default();
      let input_text = query.get("text").map(|s| s.as_str()).unwrap_or("");
      if input_text.is_empty() {
        return Ok(tide::Response::new(StatusCode::BadRequest));
      }

      // Parse the provided URL string.
      let parsed_url = match Url::parse(input_text) {
        Ok(url) => url,
        Err(_) => return Ok(tide::Response::new(StatusCode::BadRequest)),
      };

      // Extract the path and query parts to form the rustby GET parameter.
      let mut vlog = parsed_url.path().to_string();
      if let Some(q) = parsed_url.query() {
        vlog.push('?');
        vlog.push_str(q);
      }

      // Construct the redirection URL to /rustby with the extracted "vlog" parameter.
      let redirect_url = format!("/rustby?vlog={}", vlog);
      let mut res = tide::Response::new(StatusCode::Found);
      res.insert_header("Location", redirect_url);
      Ok(res)
    });
    
    use async_std::path::Path;
use chrono::Utc;
 // assuming the helper is in the module

app.at("/img/resize").post(|mut req: tide::Request<AppState>| async move {
    // Extract query parameters.
    let query: HashMap<String, String> = req.query().unwrap_or_default();
    let file_name = query.get("filename").cloned().unwrap_or_default();
    if file_name.is_empty() {
        let mut res = tide::Response::new(StatusCode::BadRequest);
        res.set_body("Missing filename query parameter".to_string());
        return Ok(res);
    }
    
    // Check for a file extension.
    let path = Path::new(&file_name);
    let ext = path.extension().and_then(|os_str| os_str.to_str());
    if ext.is_none() {
        let mut res = tide::Response::new(StatusCode::BadRequest);
        res.set_body("File extension missing".to_string());
        return Ok(res);
    }
    let ext = ext.unwrap();

    // Optional: get desired width and height (default to 800x600).
    let width: u32 = query.get("width").and_then(|s| s.parse().ok()).unwrap_or(800);
    let height: u32 = query.get("height").and_then(|s| s.parse().ok()).unwrap_or(600);

    // Read the image bytes from the request body.
      let data = req.body_bytes().await?;
  
      let mut res = tide::Response::new(tide::StatusCode::Ok);
      res.set_body("Image resized (placeholder)".to_string());
      Ok(res)
  });
  
  app.at("/").get(|_| async {
    let html = r######"<!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Landing Page</title>
      <style>
        body {
          margin: 0;
          padding: 0;
          font-family: sans-serif;
          background-color: #f0f0f0;        
        }
        h1 {
          color: #333;
        }
      </style>
    </head>
    <body>
      <h1>Landing page for the Infini-Vaerias</h1>
      <br />
      <center>
      <h3><a href="https://miaedscore.online/gallery/the-field-testers">ART PORTFOLIO</a><h3>
      <h3><a href="https://miaedscore.online/blog/the-field-testers/view">BLOG</h3>
      <h3><a href="https://docs.google.com/document/d/1pdNbmPgFyXkRmxRGQ7mKmTFIu7D50VnOnoTwY8k6KBs/edit?tab=t.0#heading=h.yhslfamnj34l">COMMISSION Sheet</a></h3>
      <h3><a href="https://github.com/ZeroPivot">CODING Portfolio</a></h3>
      <iframe src="https://github.com/sponsors/ZeroPivot/card" title="Sponsor ZeroPivot" height="225" width="600" style="border: 0;"></iframe><br />
      <h3>e-mail: midscore.io@gmail.com</h3>
      <h3><a href="https://docs.google.com/document/d/1OyPcoBelY0BwqSCUIFdzUIAUJRoaUcb05W3eEKjbIW4/edit?tab=t.0#heading=h.3c37zycm53bd">Spiritology's MindWeave Language and PhDs Dissertation</a></h3>
      This is a rust server with the TIDE/MEEPERs crate that is a work in progress, especially with the Ruby/Rustby-c Virtual Machine that is going to work on the command line and return nothing but strings.
      <br><br />
      <br />
      For now it will include links to most of my works, social media, e-mail, etc. Home of the stimky Infini-Vaeria beings. #muskium #illustration #art.
      <br />
      This Page :: <a href="https://stimky.info">Stimky.info</a><br />
      BlueSky :: ART ==> <a href="https://bsky.app/profile/stimky.info">Stimky.info</a><br />      
      Blog/Gallery :: MAIN ==> <a href="https://miaedscore.online">Miaedscore</a><br />
      <br />
      <h4>Instant Messaging/Gaming</h4>     
      DISCORD :: TheFieldTester<br />
      STEAM :: https://steamcommunity.com/id/midscore/ 
      <br /><br /><br />
      <hr>
      External Google Blog: <a href="https://infini-vaeria.blogspot.com">Infini-Vaeria</a>
      </center>
    </body>
    </html>"######;
    let mut res = tide::Response::new(tide::StatusCode::Ok);
    res.set_body(html);
    res.set_content_type("text/html");
    Ok(res)
});
/*
    app.at("/paema").get(move |req: Request<AppState>| {
        let rustby_eval_title = rustby_eval_title.clone();
        async move {
            let query: HashMap<String, String> = req.query().unwrap_or_default();
            let vlog = query
                .get("vlog")
                .cloned()
                .unwrap_or_else(|| "".to_string());

            let title = rustby_eval_title.to_string();
            let base_iframe_url = format!("https://miaedscore.online:8080/{}", vlog);

            let html_content = format!(r######"<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{title}</title>
  <meta name="description" content="This page embeds an external webpage via an iFrame.">
  <meta name="author" content="TIADE-MAEPPERS">
  <meta name="keywords" content="HTML, iFrame, Embedded Page">
  <meta name="theme-color" content="#ffffff">
  <meta name="robots" content="index, follow">
  <meta name="googlebot" content="index, follow">
  <meta name="google" content="notranslate">
  <meta name="msapplication-TileColor" content="#ffffff">
  <meta name="msapplication-TileImage" content="https://example.com/favicon.png">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="default">
  <meta name="apple-mobile-web-app-title" content="Embedded iFrame">
  <meta name="application-name" content="Embedded iFrame">
  <meta name="format-detection" content="telephone=no">
  <link rel="icon" href="https://example.com/favicon.png">
  <style>
    body {{
      margin: 0;
      padding: 0;
      font-family: sans-serif;
      background-color: #f8f8f8;
    }}
    .header {{
      background-color: #333;
      color: #fff;
      padding: 10px 20px;
      text-align: center;
    }}
    .iframe-container {{
      position: relative;
      width: 100%;
      height: calc(100vh - 120px);
      overflow: hidden;
    }}
    .iframe-container iframe {{
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      border: none;
    }}
    .footer {{
      background-color: #333;
      color: #fff;
      text-align: center;
      padding: 10px 20px;
    }}
  </style>

  <script>
    document.addEventListener("DOMContentLoaded", function() {{
      document.body.addEventListener("click", function(event) {{
        var target = event.target.closest("a");
        if (target && target.href) {{
          event.preventDefault();
          var url = new URL(target.href);
          var newPath = url.pathname + url.search + url.hash;
          var iframe = document.getElementById("contentFrame");
          if (iframe) {{
            iframe.src = "{base_iframe_url}" + newPath;
            history.pushState(null, '', url.pathname);
          }}
        }}
      }});
    }});
  </script>
</head>
<body>
  <div class="header">
    <h1>{title}</h1>
    <nav>
      <a href="/page1">Page 1</a> |
      <a href="/page2?query=example">Page 2</a>
    </nav>
  </div>
  <div class="iframe-container">
    <iframe id="contentFrame" src="{base_iframe_url}"></iframe>
  </div>
  <div class="footer">
    <p>&copy; 2025 TIADE-MAEPPERS. All rights reserved.</p>
  </div>
</body>
</html>"######);

            let mut res = tide::Response::new(tide::StatusCode::Ok);
            res.set_body(html_content);
            res.set_content_type("text/html");
            Ok(res)
        }
    });
*/
    // New "ae" route that displays an iframe similar to /rustby.
    // It takes a query parameter "route" corresponding to the path on port 8080.
    // It displays a text link for the standard port 8080 route and embeds the /rustby iframe.
    app.at("/ae").get(|req: Request<AppState>| async move {
        let query: HashMap<String, String> = req.query().unwrap_or_default();
        let route = query.get("route").cloned().unwrap_or_else(|| "/".to_string());
        let standard_route = format!("https://miaedscore.online{}", route);
        let rustby_route = format!("https://miaedscore.online/rustby?vlog={}", route);
        let html = format!(r#"<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AE Route</title>
  <style>
    body {{
      margin: 0;
      padding: 0;
      font-family: sans-serif;
    }}
    .header {{
      padding: 10px;
      background-color: #f0f0f0;
      text-align: center;
    }}
    .content {{
      height: calc(100vh - 50px);
    }}
    iframe {{
      width: 100%;
      height: 100%;
      border: none;
    }}
  </style>
</head>

<body>
  <div class="header">
    <p>Standard route: <a href="{standard_route}">{standard_route}</a></p>
  </div>
  <div class="content">
    <iframe src="{rustby_route}"></iframe>
  </div>
</body>
</html>"#,
            standard_route = standard_route,
            rustby_route = rustby_route
        );
        let mut res = tide::Response::new(tide::StatusCode::Ok);
        res.set_body(html);
        res.set_content_type("text/html");
        Ok(res)
    });

    // A simple POST endpoint
    app.at("/echo").post(|mut req: Request<AppState>| async move {
        let body = req.body_string().await.unwrap_or_default();
        Ok(format!("You sent: {}", body))
    });

    // Route to restart all spawned servers
    app.at("/restart-servers").post(|_| async move {
      println!("Restarting all servers...");
      std::process::Command::new("sh")
        .arg("-c")
        .arg("killall -HUP tiade-maeepers-saerver-all") // Replace with your server binary name
        .spawn()
        .expect("Failed to restart servers");
      Ok("Servers are restarting")
    });

    // Add a file
    app.at("/file/add").post(|mut req: Request<AppState>| async move {
        let contents = req.body_bytes().await.unwrap_or_default();
        std::fs::write("/tmp/new_file.txt", &contents)?;
        Ok("File added")
    });

    // Delete a file
    app.at("/file/delete").delete(|_| async {
        std::fs::remove_file("/tmp/new_file.txt")?;
        Ok("File deleted")
    });

    let addresses = vec!["65.38.99.230:443"];
    let cert_path = "/etc/letsencrypt/live/stimky.info/fullchain.pem";
    let key_path = "/etc/letsencrypt/live/stimky.info/privkey.pem";

    let mut tasks = vec![];
    for addr in addresses {
      let app_clone = app.clone();
      let c = cert_path.to_string();
      let k = key_path.to_string();
      println!("Spawning server on address: {}", addr); // Debug message
      tasks.push(async_std::task::spawn(async move {
        let listener = TlsListener::build()
          .addrs(addr)
          .cert(c)
          .key(k);
        println!("Server is starting on address: {}", addr); // Debug message
        app_clone.listen(listener).await
      }));
    }

    for t in tasks {
      if let Err(e) = t.await {
        eprintln!("Error while running server: {}", e); // Debug message
      }
    }
    println!("All servers have been spawned successfully."); // Debug message
    Ok(())
}
