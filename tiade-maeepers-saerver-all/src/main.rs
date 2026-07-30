use magnus::embed::init;
use magnus::{
    Error, RArray, RClass, RFile, RFloat, RHash, RModule, RObject, RRegexp, RString, RStruct, Ruby,
    Value, eval, function, method, prelude::*, rb_assert, typed_data, value::Lazy, value::Opaque,
};
use std::io::{self, BufRead};
use tide::utils::After;
use tide_rustls::TlsListener;

use chrono::Utc;

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
use image::DynamicImage;
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

use std::fs::File;
use std::io::BufReader;
use std::io::BufWriter;
use std::io::Read;
use std::path::Path;

struct LogRoute;
#[tide::utils::async_trait]
impl tide::Middleware<AppState> for LogRoute {
    async fn handle(
        &self,
        req: tide::Request<AppState>,
        next: tide::Next<'_, AppState>,
    ) -> tide::Result {
        println!("Incoming route: {}", req.url().path());
        let res = next.run(req).await;
        println!("Response status: {}", res.status());
        Ok(res)
    }
}

use std::sync::mpsc;
use std::sync::mpsc::{Sender, channel};
use std::thread::JoinHandle;
// use std::sync::Arc;
use std::sync::Mutex;
use std::sync::mpsc::Receiver;
use std::sync::mpsc::sync_channel;
use std::thread;

#[derive(Clone)]
struct AppState;

#[async_std::main]
async fn main() -> tide::Result<()> {
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
                        let filename = format!(
                            "{}/script_{}.rb",
                            script_dir,
                            Utc::now().timestamp_nanos_opt().unwrap_or(0)
                        );
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
                        if let Err(e) = std::fs::write(pipe_path, format!("load '{}'\n", filename))
                        {
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
                                Err(magnus::Error::new(
                                    magnus::exception::runtime_error(),
                                    format!("Error reading Ruby output: {}", e),
                                ))
                            }
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
        async fn handle(
            &self,
            req: tide::Request<AppState>,
            next: tide::Next<'_, AppState>,
        ) -> tide::Result {
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

    use std::fs::OpenOptions;
    use url::Url;
    //let rustby_eval_title = rustby_eval_title.clone();

    // Serve each directory. Tide will serve new files as they appear.
    // app.at("/css").serve_dir("./css/")?;
    // app.at("/js").serve_dir("./js/")?;
    // app.at("/img").serve_dir("./img/")?;
    // app.at("/fonts").serve_dir("./fonts/")?;
    // app.at("/public").serve_dir("./public/")?;

    #[derive(serde::Deserialize)]
    struct PraexyForm {
        content: String,
    }

    app.at("/praexy-saerver")
        .post(|mut req: tide::Request<AppState>| async move {
            let form_data: PraexyForm = req.body_form().await.unwrap_or(PraexyForm {
                content: String::new(),
            });
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

    app.at("/bridge/*rest")
        .get(|req: tide::Request<AppState>| async move {
            // Extract the wildcard part from the URL.
            let rest = req.param("rest").unwrap_or("");
            // Build the target URL for the 8080 server.
            let target_url = format!("https://miaedscore.online:8080/{}", rest);

            // Build an HTML page with an iframe loading the target URL.
            // A JavaScript snippet removes any query parameters from the browser URL.
            let html_content = format!(
                r#"<!DOCTYPE html>
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
  </html>"#,
                target_url
            );

            // Return the HTML response.
            let mut res = tide::Response::new(tide::StatusCode::Ok);
            res.set_body(html_content);
            res.set_content_type("text/html");
            Ok(res)
        });

    {
        std::fs::create_dir_all("/root/midscore_io/rustby/rustby-vm/target/release/scripts").ok();
        let ts = Utc::now().timestamp_nanos_opt().unwrap_or(0);
        let filename =
            format!("/root/midscore_io/rustby/rustby-vm/target/release/scripts/script_{ts}.rb");
        let contents = r######"
       require 'date'
       require 'fileutils'
       require 'time'
       require 'json'
       require 'oj'
       require 'date'
       require 'net/http'

      class ForecastByLongitude
    GRIDPOINT_FORECAST_URL = 'https://api.weather.gov/gridpoints/EKA/93,22/forecast'.freeze

    def initialize
    end

    def fetch_forecast(_lat = nil, _lon = nil)
      [
        '--- Miaedscore-Plateau, Califurnia :: Daily Forecast ---',
        print_forecast(GRIDPOINT_FORECAST_URL)
      ].compact.join("\n")
    end

    def print_forecast(url)
      return 'No forecast URL provided.' unless url

      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      return "Error fetching forecast: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      periods = data.dig('properties', 'periods')

      if periods && !periods.empty?
        periods.map do |period|
          name = period['name']
          temp = "#{period['temperature']} #{period['temperatureUnit']}"
          forecast = period['shortForecast']
          "#{name}: #{temp}, #{forecast}"
        end.join("\n")
      else
        'No forecast data available.'
      end
    end
  end


    # This Ruby code is designed to be evaluated by the Magnus Ruby interpreter.
      class AECalendar
    attr_reader :start_date, :year_length, :month_length

    def initialize(start_date = DateTime.new(2025, 6, 4, 0, 0, 0), month_length = 14, months_in_year = 12)
      @start_date = start_date
      @month_length = month_length
      @year_length = month_length * months_in_year
    end

    def ae_date(gregorian_date)
      days_since_start = (gregorian_date - @start_date).to_i
      ae_year = 1 + (days_since_start / @year_length)
      ae_month = 1 + ((days_since_start % @year_length) / @month_length)
      ae_day = 1 + ((days_since_start % @year_length) % @month_length)
      day_of_week = gregorian_date.strftime('%A') # Get the day name

      "AE #{ae_year}, Month #{ae_month}, Day #{ae_day} (#{day_of_week})"
    end
  end

  # Example usage
  ae_calendar = AECalendar.new
  gregorian_example = DateTime.new(2025, 7, 1)





    class MoonPhaseDetails2
      # === Constants and Definitions ===

        # Average length of a full lunar cycle (in days)
    MOON_CYCLE_DAYS = 29.53


# The 27 fabled moon rotations with emojis:
MOON_ROTATIONS = [
  'New Moon 🌑', # 1
  'Waxing Crescent 🌒',     # 2
  'First Quarter 🌓',       # 3
  'Waxing Gibbous 🌔',      # 4
  'Full Moon 🌕',           # 5
  'Waning Gibbous 🌖',      # 6
  'Last Quarter 🌗',        # 7
  'Waning Crescent 🌘',     # 8
  'Supermoon 🌝',           # 9
  'Blue Moon 🔵🌙',         # 10
  'Blood Moon 🩸🌙',        # 11
  'Harvest Moon 🍂🌕',      # 12
  "Hunter's Moon 🌙🔭",     # 13
  'Wolf Moon 🐺🌕',         # 14
  'Pink Moon 🌸🌕', # 15
  'Snow Moon 🌨️', # 16
  'Snow Moon Snow 🌨️❄️', # 17
  'Avian Moon 🦅', # 18
  'Avian Moon Snow 🦅❄️',    # 19
  'Skunk Moon 🦨',           # 20
  'Skunk Moon Snow 🦨❄️',    # 21
  'Cosmic Moon 🌌🌕', # 22
  'Celestial Moon 🌟🌕', # 23
  'Otter Moon 🐕🌌', # 24
  'Muskium Otter Muskium Stinky Stimky Otter Moon 🦨🌌', # 25
  'Light Elemental Moon 💡🌕', # 26
  'Dark Elemental Moon 🌑🌕' # 27

]
# Define 27 corresponding species with emojis.
SPECIES = [
  'Dogg 🐶', # New Moon
  'Folf 🦊🐺', # Waxing Crescent
  'Aardwolf 🐾',
  'Spotted Hyena 🐆',
  'Folf Hybrid 🦊✨',
  'Striped Hyena 🦓',
  'Dogg Prime 🐕⭐',
  'WolfFox 🐺🦊', # Waning Crescent
  'Brown Hyena 🦴',
  'Dogg Celestial 🐕🌟',
  'Folf Eclipse 🦊🌒',
  'Aardwolf Luminous 🐾✨',
  'Spotted Hyena Stellar 🐆⭐',
  'Folf Nova 🦊💥',
  'Brown Hyena Cosmic 🦴🌌',
  'Snow Leopard 🌨️', # New Moon
  'Snow Leopard Snow Snep 🌨️❄️',
  'Avian 🦅',
  'Avian Snow 🦅❄️',
  'Skunk 🦨',
  'Skunk Snow 🦨❄️',
  'Infini-Vaeria Graevity-Infini 🌌🐕',
  'Graevity-Infini Infini-Vaeria 🌟🐕',
  'Otter 🦦',
  'Muskium Otter Stinky Stimky 🦦🦨',
  'Light Elf 💡',
  'Light Elf Cosmic 🌑'

]

# Define 27 corresponding were-forms with emojis.
WERE_FORMS = [
  'WereDogg 🐶🌑',
  'WereFolf 🦊🌙',
  'WereAardwolf 🐾',
  'WereSpottedHyena 🐆',
  'WereFolfHybrid 🦊✨',
  'WereStripedHyena 🦓',
  'WereDoggPrime 🐕⭐',
  'WereWolfFox 🐺🦊', # Waning Crescent
  'WereBrownHyena 🦴',
  'WereDoggCelestial 🐕🌟',
  'WereFolfEclipse 🦊🌒',
  'WereAardwolfLuminous 🐾✨',
  'WereSpottedHyenaStellar 🐆⭐',
  'WereFolfNova 🦊💥', # Wolf Moon
  'WereBrownHyenaCosmic 🦴🌌', # Pink Moon
  'WereSnowLeopard 🐆❄️',
  'WereSnowLeopardSnow 🐆❄️❄️', # Pink Moon
  'WereAvian 🦅', # New Moon
  'WereAvianSnow 🦅❄️', # Pink Moon
  'WereSkunk 🦨', # New Moon
  'WereSkunkSnow 🦨❄️', # New Moon
  'WereInfiniVaeriaGraevity 🐕🌌',
  'WereGraevityInfiniInfiniVaeria 🌟🐕',
  'WereOtter 🦦',
  'WereMuskiumOtterStinkyStimky 🦦🦨',
  'WereLightElf 💡',
  'WereLightElfCosmic 🌑'
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
        SunPhase2.new('Cosmic Slumber', 24, '🌠'),
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

    let script_dir = "/root/midscore_io/rustby/rustby-vm/target/release/scripts";
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




    let result_path = format!("/root/midscore_io/rustby/rustby-vm/target/release/scripts/moon_{}.txt", ts);

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

    app.at("/analytics")
        .get(|mut req: tide::Request<AppState>| async move {
            let script_dir = "/root/midscore_io/rustby/rustby-vm/target/release/scripts";
            //td::fs::create_dir_all(script_dir).ok();
            let mut res = tide::Response::new(tide::StatusCode::Ok);
            //res.set_body("HTML content for /moon route");
            //res.set_content_type("text/html; charset=utf-8");
            //return Ok(res);
            // Grab Ruby code from request body.
            let ruby_source = r######"



require 'json'
require 'time'
require 'oj'
require 'yaml'

# Load and parse chat logs from file.
# Supports both strict JSON and Ruby-hash style lines.
path = '/root/midscore_io/tiade-maeepers-saerver-all/target/release/second_life_chat_logs.txt'
raw = File.exist?(path) ? File.read(path) : ''
entries = []

parse_any = lambda do |text|
  begin
    JSON.parse(text)
  rescue JSON::ParserError
    begin
      Oj.load(text)
    rescue StandardError
      begin
        YAML.safe_load(text, permitted_classes: [Time, Date, Symbol], aliases: true)
      rescue StandardError
        eval(text)
      end
    end
  end
end

raw.each_line do |line|
  line = line.strip
  next if line.empty?

  begin
    parsed = parse_any.call(line)
    if parsed.is_a?(Array)
      parsed.each { |item| entries << item if item.is_a?(Hash) }
    elsif parsed.is_a?(Hash)
      entries << parsed
    end
  rescue StandardError
    # Skip malformed lines and continue processing.
  end
end

# Fallback: try parsing whole file if line-by-line found nothing.
if entries.empty? && !raw.strip.empty?
  begin
    parsed = parse_any.call(raw)
    if parsed.is_a?(Array)
      parsed.each { |item| entries << item if item.is_a?(Hash) }
    elsif parsed.is_a?(Hash)
      entries << parsed
    end
  rescue StandardError
    entries = []
  end
end

# Normalize keys for mixed JSON/Ruby inputs.
entries.map! do |e|
  next e unless e.respond_to?(:transform_keys)
  e.transform_keys { |k| k.respond_to?(:to_s) ? k.to_s : k }
end

# Deduplicate observer captures.
unique = {}
entries.each do |e|
  next unless e.is_a?(Hash)
  next unless e['timestamp']

  key = [e['avatar_id'], e['timestamp'], e['message']]
  unique[key] ||= e
end

events = unique.values

# Frequency tables.
weekday_freq = Hash.new(0)
hour_freq = Hash.new(0)
month_freq = Hash.new(0)
year_freq = Hash.new(0)
month_year_freq = Hash.new(0)
day_of_month_freq = Hash.new(0)

WEEKDAYS = %w[Monday Tuesday Wednesday Thursday Friday Saturday Sunday]
MONTHS = %w[January February March April May June July August September October November December]

valid_times = []
events.each do |e|
  ts = e['timestamp'].to_i
  next if ts <= 0

  t = Time.at(ts).getlocal('-07:00')
  valid_times << t

  weekday_freq[t.strftime('%A')] += 1
  hour_freq[t.hour] += 1
  month_freq[t.strftime('%B')] += 1
  year_freq[t.year] += 1
  month_year_freq[t.strftime('%Y-%m')] += 1
  day_of_month_freq[t.day] += 1
end

avatars = events.map { |e| e['avatar_id'].to_s.strip }.reject(&:empty?).uniq
messages = events.map { |e| e['message'].to_s.strip }.reject(&:empty?).uniq

earliest = valid_times.min
latest = valid_times.max

out = ""
out << "Second Life chat frequency report (PST)\n"
out << "Source file: #{path}\n"
out << "Raw parsed entries: #{entries.length}\n"
out << "Total unique events: #{events.length}\n"
out << "Unique avatar IDs: #{avatars.length}\n"
out << "Unique message bodies: #{messages.length}\n"
out << "First event (PST): #{earliest ? earliest.strftime('%Y-%m-%d %H:%M:%S %Z') : 'N/A'}\n"
out << "Last event (PST):  #{latest ? latest.strftime('%Y-%m-%d %H:%M:%S %Z') : 'N/A'}\n"

out << "\n=== Message Frequency by Day of Week (Monday-Sunday) ===\n"
WEEKDAYS.each do |day|
  out << "%-9s : %d\n" % [day, weekday_freq[day]]
end

out << "\n=== Message Frequency by Hour (PST, 24h) ===\n"
(0..23).each do |h|
  out << "%02d:00-%02d:59 : %d\n" % [h, h, hour_freq[h]]
end

out << "\n=== Message Frequency by Month ===\n"
MONTHS.each do |month|
  out << "%-9s : %d\n" % [month, month_freq[month]]
end

out << "\n=== Message Frequency by Year ===\n"
if year_freq.empty?
  out << "No valid timestamped events found.\n"
else
  year_freq.keys.sort.each do |year|
    out << "%d : %d\n" % [year, year_freq[year]]
  end
end

out << "\n=== Message Frequency by Month-Year (YYYY-MM) ===\n"
if month_year_freq.empty?
  out << "No valid timestamped events found.\n"
else
  month_year_freq.keys.sort.each do |ym|
    out << "#{ym} : #{month_year_freq[ym]}\n"
  end
end

out << "\n=== Message Frequency by Day of Month (1-31) ===\n"
(1..31).each do |d|
  out << "%02d : %d\n" % [d, day_of_month_freq[d]]
end

put_and_return = out

#{{put_and_return}}
    "######;

            if ruby_source.trim().is_empty() {
                let mut resp = tide::Response::new(tide::StatusCode::Ok);
                resp.set_body("No Ruby code supplied");
                return Ok(resp);
            }

            // Create unique .rb filename.
            let ts = Utc::now().timestamp_nanos_opt().unwrap_or(0);
            let filename = format!("{}/lanalytics_second_life_{}.rb", script_dir, ts);
            std::fs::write(&filename, &ruby_source)
                .map_err(|e| tide::Error::new(tide::StatusCode::InternalServerError, e))?;

            let result_path = format!(
                "/root/midscore_io/rustby/rustby-vm/target/release/scripts/lanalytics_second_life_{}.txt",
                ts
            );

            // Block until the result file is available or until timeout
            let start = std::time::Instant::now();
            let timeout = std::time::Duration::from_secs(120);
            while !std::path::Path::new(&result_path).exists() {
                if start.elapsed() > timeout {
                    return Ok("Timed out waiting for result file".into());
                }
                std::thread::sleep(std::time::Duration::from_millis(1));
            }
            let output =
                std::fs::read_to_string(&result_path).unwrap_or_else(|_| "No output".to_string());

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

    app.at("/chatlog")
        .get(|_req: tide::Request<AppState>| async move {
            use std::collections::{HashMap, BTreeMap};

            let log_path = "/root/midscore_io/tiade-maeepers-saerver-all/target/release/second_life_chat_logs.txt";
            let raw = std::fs::read_to_string(log_path).unwrap_or_default();

            // Parse each line as a Ruby-hash-style array by converting to JSON
            let mut all_entries: Vec<serde_json::Value> = Vec::new();
            for line in raw.lines() {
                let line = line.trim();
                if line.is_empty() { continue; }
                // Convert Ruby hash syntax to JSON: symbol keys to strings
                let json_line = line
                    .replace("\\.", ".")
                    .replace("\\\"", "\"");
                // Try direct JSON parse first
                if let Ok(val) = serde_json::from_str::<serde_json::Value>(&json_line) {
                    if let Some(arr) = val.as_array() {
                        all_entries.extend(arr.iter().cloned());
                    } else {
                        all_entries.push(val);
                    }
                    continue;
                }
                // Convert Ruby symbol keys to JSON string keys
                let converted = json_line
                    .replace("{avatar_id:", "{\"avatar_id\":")
                    .replace(", avatar_id:", ", \"avatar_id\":")
                    .replace("avatar_name:", "\"avatar_name\":")
                    .replace("captured_by:", "\"captured_by\":")
                    .replace("message:", "\"message\":")
                    .replace("sim_name:", "\"sim_name\":")
                    .replace("timestamp:", "\"timestamp\":")
                    .replace("x_pos:", "\"x_pos\":")
                    .replace("y_pos:", "\"y_pos\":")
                    .replace("z_pos:", "\"z_pos\":");
                if let Ok(val) = serde_json::from_str::<serde_json::Value>(&converted) {
                    if let Some(arr) = val.as_array() {
                        all_entries.extend(arr.iter().cloned());
                    } else {
                        all_entries.push(val);
                    }
                }
            }

            // Deduplicate by (avatar_id, timestamp, message)
            let mut unique: HashMap<String, &serde_json::Value> = HashMap::new();
            for entry in &all_entries {
                let key = format!("{}|{}|{}",
                    entry["avatar_id"].as_str().unwrap_or(""),
                    entry["timestamp"].as_i64().or_else(|| entry["timestamp"].as_f64().map(|f| f as i64)).unwrap_or(0),
                    entry["message"].as_str().unwrap_or("")
                );
                unique.entry(key).or_insert(entry);
            }

            // Sort by timestamp
            let mut events: Vec<&serde_json::Value> = unique.into_values().collect();
            events.sort_by_key(|e| e["timestamp"].as_i64().or_else(|| e["timestamp"].as_f64().map(|f| f as i64)).unwrap_or(0));

            // Group by date (PST = UTC-8)
            let mut grouped: BTreeMap<String, Vec<&serde_json::Value>> = BTreeMap::new();
            for e in &events {
                let ts = e["timestamp"].as_i64().or_else(|| e["timestamp"].as_f64().map(|f| f as i64)).unwrap_or(0);
                let dt = chrono::DateTime::from_timestamp(ts, 0)
                    .unwrap_or_default()
                    .with_timezone(&chrono::FixedOffset::west_opt(8 * 3600).unwrap());
                let day_key = dt.format("%A, %B %d, %Y").to_string();
                grouped.entry(day_key).or_default().push(e);
            }

            let sep = "-".repeat(80);
            let now_pst = Utc::now().with_timezone(&chrono::FixedOffset::west_opt(8 * 3600).unwrap());
            let mut out = String::new();
            out.push_str(&format!("{}\n", sep));
            out.push_str(&format!("  SECOND LIFE CHAT LOG VIEWER\n"));
            out.push_str(&format!("  Total Messages: {} | Generated: {}\n", events.len(), now_pst.format("%m/%d/%Y %I:%M:%S %p PST")));
            out.push_str(&format!("{}\n\n", sep));

            for (date, day_events) in &grouped {
                out.push_str(&format!("  [ {} ] — {} message(s)\n", date, day_events.len()));
                out.push_str(&format!("  {}\n\n", "~".repeat(76)));

                for (i, e) in day_events.iter().enumerate() {
                    let ts = e["timestamp"].as_i64().or_else(|| e["timestamp"].as_f64().map(|f| f as i64)).unwrap_or(0);
                    let dt = chrono::DateTime::from_timestamp(ts, 0)
                        .unwrap_or_default()
                        .with_timezone(&chrono::FixedOffset::west_opt(8 * 3600).unwrap());
                    let time_str = dt.format("%I:%M:%S %p").to_string();
                    let name = e["avatar_name"].as_str().unwrap_or("(unknown)");
                    let name = if name.is_empty() { "(unknown)" } else { name };
                    let msg = e["message"].as_str().unwrap_or("");
                    let sim = e["sim_name"].as_str().unwrap_or("");
                    let captured = e["captured_by"].as_str().unwrap_or("");
                    let avatar_id = e["avatar_id"].as_str().unwrap_or("");

                    out.push_str(&format!("  #{}  {} PST\n", i + 1, time_str));
                    out.push_str(&format!("  From:        {}\n", name));
                    out.push_str(&format!("  Avatar ID:   {}\n", avatar_id));
                    out.push_str(&format!("  Message:     {}\n", msg));
                    out.push_str(&format!("  Region:      {}\n", sim));
                    out.push_str(&format!("  Position:    ({}, {}, {})\n",
                        e["x_pos"].as_f64().unwrap_or(0.0),
                        e["y_pos"].as_f64().unwrap_or(0.0),
                        e["z_pos"].as_f64().unwrap_or(0.0)));
                    out.push_str(&format!("  Captured By: {}\n", captured));
                    out.push_str(&format!("  Timestamp:   {}\n", ts));
                    out.push_str(&format!("  {}\n", "-".repeat(40)));
                }
                out.push('\n');
            }

            out.push_str(&format!("{}\n", sep));
            out.push_str(&format!("  END OF LOG — {} total entries\n", events.len()));
            out.push_str(&format!("{}\n", sep));

            let mut res = tide::Response::new(tide::StatusCode::Ok);
            res.set_body(out);
            res.insert_header("Content-Type", "text/plain; charset=utf-8");
            Ok(res)
        });

    app.at("/read")
        .get(|mut req: tide::Request<AppState>| async move {
            let script_dir = "/root/midscore_io/rustby/rustby-vm/target/release/scripts";
            //td::fs::create_dir_all(script_dir).ok();
            let mut res = tide::Response::new(tide::StatusCode::Ok);
            //res.set_body("HTML content for /moon route");
            //res.set_content_type("text/html; charset=utf-8");
            //return Ok(res);
            // Grab Ruby code from request body.
            let ruby_source = r######"



require 'json'
require 'time'

# Load and parse chat logs from file.
# This supports both strict JSON and Ruby-hash style lines like:
# [{avatar_id: "...", message: "..."}, {...}]
path = '/root/midscore_io/tiade-maeepers-saerver-all/target/release/second_life_chat_logs.txt'
raw = File.exist?(path) ? File.read(path) : ''
entries = []


    "######;

            if ruby_source.trim().is_empty() {
                let mut resp = tide::Response::new(tide::StatusCode::Ok);
                resp.set_body("No Ruby code supplied");
                return Ok(resp);
            }

            // Create unique .rb filename.
            let ts = Utc::now().timestamp_nanos_opt().unwrap_or(0);
            let filename = format!("{}/lanalytics_second_life_{}.rb", script_dir, ts);
            std::fs::write(&filename, &ruby_source)
                .map_err(|e| tide::Error::new(tide::StatusCode::InternalServerError, e))?;

            let result_path = format!(
                "/root/midscore_io/rustby/rustby-vm/target/release/scripts/lanalytics_second_life_{}.txt",
                ts
            );

            // Block until the result file is available or until timeout
            let start = std::time::Instant::now();
            let timeout = std::time::Duration::from_secs(120);
            while !std::path::Path::new(&result_path).exists() {
                if start.elapsed() > timeout {
                    return Ok("Timed out waiting for result file".into());
                }
                std::thread::sleep(std::time::Duration::from_millis(1));
            }
            let output =
                std::fs::read_to_string(&result_path).unwrap_or_else(|_| "No output".to_string());

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

    app.at("/incrementor_get").get(|mut req: tide::Request<AppState>| async move {
      // Catch all POST variables into a hashmap and print them
      let body = req.body_string().await.unwrap_or_default();
      println!("Received POST body: {}", body);

      let script_dir = "/root/midscore_io/rustby/rustby-vm/target/release/scripts";
      let file_name: String = "incrementor.txt".to_string();

      let ruby_source = format!(r######"
      incrementor = File.read('/root/midscore_io/tiade-maeepers-saerver-all/target/release/incrementor.txt').to_s

      #{{incrementor}}

    "######

    );


    if ruby_source.trim().is_empty() {
        let mut resp = tide::Response::new(tide::StatusCode::Ok);
        resp.set_body("No Ruby code supplied");
        return Ok(resp);
    }

    // Create unique .rb filename.
    let ts = Utc::now().timestamp_nanos_opt().unwrap_or(0);
    let filename = format!("{}/sl_log_get_{}.rb", script_dir,ts);
    std::fs::write(&filename, &ruby_source).map_err(|e| tide::Error::new(tide::StatusCode::InternalServerError, e))?;




    let result_path = format!("/root/midscore_io/rustby/rustby-vm/target/release/scripts/sl_log_get_{}.txt", ts);

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

      //let output = "Log entry received and written to file successfully.";

     // Return the HTML response.
    let mut res = tide::Response::new(tide::StatusCode::Ok);
    res.set_body(output);
    res.insert_header("Content-Type", "text/plain; charset=utf-8");
    Ok(res)
    //Ok(output.into())
  });

    app.at("/incrementor").get(|mut req: tide::Request<AppState>| async move {
      // Catch all POST variables into a hashmap and print them
      let body = req.body_string().await.unwrap_or_default();
      println!("Received POST body: {}", body);

      let script_dir = "/root/midscore_io/rustby/rustby-vm/target/release/scripts";
      let file_name: String = "incrementor.txt".to_string();

      let ruby_source = format!(r######"

        incrementor_path = '/root/midscore_io/tiade-maeepers-saerver-all/target/release/incrementor.txt'
        File.write(incrementor_path, '0') unless File.exist?(incrementor_path)

        incrementor = File.open(incrementor_path, 'r+') do |file|
          file.flock(File::LOCK_EX)
          current = file.read.to_i
          updated = current + 1
          file.rewind
          file.write(updated.to_s)
          file.truncate(file.pos)
          updated
        end

        #{{incrementor}}
        "######

    );


    if ruby_source.trim().is_empty() {
        let mut resp = tide::Response::new(tide::StatusCode::Ok);
        resp.set_body("No Ruby code supplied");
        return Ok(resp);
    }

    // Create unique .rb filename.
    let ts = Utc::now().timestamp_nanos_opt().unwrap_or(0);
    let filename = format!("{}/incrementor_{}.rb", script_dir,ts);
    std::fs::write(&filename, &ruby_source).map_err(|e| tide::Error::new(tide::StatusCode::InternalServerError, e))?;




    let result_path = format!("/root/midscore_io/rustby/rustby-vm/target/release/scripts/incrementor_{}.txt", ts);

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

      //let output = "Log entry received and written to file successfully.";

     // Return the HTML response.
    let mut res = tide::Response::new(tide::StatusCode::Ok);
    res.set_body(output);
    res.insert_header("Content-Type", "text/plain; charset=utf-8");
    Ok(res)
    //Ok(output.into())
  });

    app.at("/_ethereal_life_sl_logger_get_").get(|mut req: tide::Request<AppState>| async move {
      // Catch all POST variables into a hashmap and print them
      let body = req.body_string().await.unwrap_or_default();
      println!("Received POST body: {}", body);

      let script_dir = "/root/midscore_io/rustby/rustby-vm/target/release/scripts";
      let file_name: String = "second_life_chat_log.txt".to_string();

      let ruby_source = format!(r######"
    previous_contents = File.read('/root/midscore_io/tiade-maeepers-saerver-all/target/release/second_life_chat_logs.txt')

    "#{{previous_contents}}"

    "######

    );


    if ruby_source.trim().is_empty() {
        let mut resp = tide::Response::new(tide::StatusCode::Ok);
        resp.set_body("No Ruby code supplied");
        return Ok(resp);
    }

    // Create unique .rb filename.
    let ts = Utc::now().timestamp_nanos_opt().unwrap_or(0);
    let filename = format!("{}/sl_log_get_{}.rb", script_dir,ts);
    std::fs::write(&filename, &ruby_source).map_err(|e| tide::Error::new(tide::StatusCode::InternalServerError, e))?;




    let result_path = format!("/root/midscore_io/rustby/rustby-vm/target/release/scripts/sl_log_get_{}.txt", ts);

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

      //let output = "Log entry received and written to file successfully.";

     // Return the HTML response.
    let mut res = tide::Response::new(tide::StatusCode::Ok);
    res.set_body(output);
    res.insert_header("Content-Type", "text/plain; charset=utf-8");
    Ok(res)
    //Ok(output.into())
  });

    app.at("/schedule_ft").get(|mut req: tide::Request<AppState>| async move {
      // Catch all POST variables into a hashmap and print them
      let body = req.body_string().await.unwrap_or_default();
      println!("Received POST body: {}", body);

      let script_dir = "/root/midscore_io/rustby/rustby-vm/target/release/scripts";
      let file_name: String = "second_life_chat_log.txt".to_string();

  let ruby_source = format!(r######"
require 'json'
require 'time'

previous_contents = File.read('/root/midscore_io/tiade-maeepers-saerver-all/target/release/second_life_chat_logs.txt')

# Parse each line as JSON and keep only objects with a timestamp
entries = previous_contents.each_line.filter_map do |line|
  begin
    obj = JSON.parse(line)
    obj if obj.is_a?(Hash) && obj['timestamp']
  rescue JSON::ParserError
    nil
  end
end

# Initialize frequency tables
hour_counts   = Hash.new(0)
day_counts    = Hash.new(0)
month_counts  = Hash.new(0)

entries.each do |entry|
  # Ensure timestamp exists and is numeric
  ts = entry['timestamp'].to_i
  time = Time.at(ts)

  # Increment frequency tables
  hour_counts[time.hour] += 1
  day_counts[time.strftime('%A')] += 1
  month_counts[time.strftime('%B')] += 1
end

# Build results
results = ""
results << "=== Frequency by Hour (0–23) ===\n"
results << (hour_counts.sort_by {{ |hour, _| hour }}.map {{ |hour, count| "#{{hour}}: #{{count}}" }}.join("\n"))
results << "\n\n=== Frequency by Day of Week ===\n"
results << day_counts.map {{ |day, count| "#{{day}}: #{{count}}" }}.join("\n")
results << "\n\n=== Frequency by Month ===\n"
results << month_counts.map {{ |month, count| "#{{month}}: #{{count}}" }}.join("\n")
results << "\n\n\n\n\n"

results

"######

);


    if ruby_source.trim().is_empty() {
        let mut resp = tide::Response::new(tide::StatusCode::Ok);
        resp.set_body("No Ruby code supplied");
        return Ok(resp);
    }

    // Create unique .rb filename.
    let ts = Utc::now().timestamp_nanos_opt().unwrap_or(0);
    let filename = format!("{}/sl_schedule_get_{}.rb", script_dir,ts);
    std::fs::write(&filename, &ruby_source).map_err(|e| tide::Error::new(tide::StatusCode::InternalServerError, e))?;




    let result_path = format!("/root/midscore_io/rustby/rustby-vm/target/release/scripts/sl_schedule_get_{}.txt", ts);

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

      //let output = "Log entry received and written to file successfully.";

     // Return the HTML response.
    let mut res = tide::Response::new(tide::StatusCode::Ok);
    res.set_body(output);
    res.insert_header("Content-Type", "text/plain; charset=utf-8");
    Ok(res)
    //Ok(output.into())
  });

    app.at("/_ethereal_life_sl_logger_show_").get(|mut req: tide::Request<AppState>| async move {
      // Catch all POST variables into a hashmap and print them
      let body = req.body_string().await.unwrap_or_default();
      println!("Received POST body: {}", body);

      let script_dir = "/root/midscore_io/rustby/rustby-vm/target/release/scripts";
      let file_name: String = "second_life_chat_log.txt".to_string();

      let ruby_source = format!(r######"
    previous_contents = File.read('/root/midscore_io/tiade-maeepers-saerver-all/target/release/second_life_chat_logs.txt')

    log = "#{{previous_contents}}".to_json

    "#{{log}}"
    "######

    );


    if ruby_source.trim().is_empty() {
        let mut resp = tide::Response::new(tide::StatusCode::Ok);
        resp.set_body("No Ruby code supplied");
        return Ok(resp);
    }

    // Create unique .rb filename.
    let ts = Utc::now().timestamp_nanos_opt().unwrap_or(0);
    let filename = format!("{}/sl_log_get_{}.rb", script_dir,ts);
    std::fs::write(&filename, &ruby_source).map_err(|e| tide::Error::new(tide::StatusCode::InternalServerError, e))?;




    let result_path = format!("/root/midscore_io/rustby/rustby-vm/target/release/scripts/sl_log_get_{}.txt", ts);

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

      //let output = "Log entry received and written to file successfully.";

     // Return the HTML response.
    let mut res = tide::Response::new(tide::StatusCode::Ok);
    res.set_body(output);
    res.insert_header("Content-Type", "text/plain; charset=utf-8");
    Ok(res)
    //Ok(output.into())
  });

    app.at("/sl_logger").post(|mut req: tide::Request<AppState>| async move {
    // Catch all POST variables into a hashmap and print them
    let body = req.body_string().await.unwrap_or_default();
    println!("Received POST body: {}", body);

    let script_dir = "/root/midscore_io/rustby/rustby-vm/target/release/scripts";
    let file_name: String = "second_life_chat_log.txt".to_string();

    let ruby_source = format!(r######"
    body = {}
    puts Dir.pwd
    FileUtils.touch("/root/midscore_io/tiade-maeepers-saerver-all/target/release/second_life_chat_logs.txt")
    puts "logging chat message to file"
     File.open('/root/midscore_io/tiade-maeepers-saerver-all/target/release/second_life_chat_logs.txt', 'a+') do |file|
       file.write("#{{body}}\n")
     end
    puts "Chat message logged to file successfully"

    "message logged to file successfully"
    "######, body);


    if ruby_source.trim().is_empty() {
        let mut resp = tide::Response::new(tide::StatusCode::Ok);
        resp.set_body("No Ruby code supplied");
        return Ok(resp);
    }

    // Create unique .rb filename.
    let ts = Utc::now().timestamp_nanos_opt().unwrap_or(0);
    let filename = format!("{}/sl_log_{}.rb", script_dir,ts);
    std::fs::write(&filename, &ruby_source).map_err(|e| tide::Error::new(tide::StatusCode::InternalServerError, e))?;




    let result_path = format!("/root/midscore_io/rustby/rustby-vm/target/release/scripts/sl_log_{}.txt", ts);

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

      let output = "Log entry received and written to file successfully.";

     // Return the HTML response.
    let mut res = tide::Response::new(tide::StatusCode::Ok);
    res.set_body(output);
    res.insert_header("Content-Type", "text/plain; charset=utf-8");
    Ok(res)
    //Ok(output.into())
  });

    app.at("/ae")
        .get(|mut req: tide::Request<AppState>| async move {
            let script_dir = "/root/midscore_io/rustby/rustby-vm/target/release/scripts";
            //td::fs::create_dir_all(script_dir).ok();
            let mut res = tide::Response::new(tide::StatusCode::Ok);
            //res.set_body("HTML content for /moon route");
            //res.set_content_type("text/html; charset=utf-8");
            //return Ok(res);
            // Grab Ruby code from request body.
            let ruby_source = r######"

     # Example usage
  ae_calendar = AECalendar.new
  "AE Calendar: #{ae_calendar.ae_date(DateTime.now)}"

    "######;
            if ruby_source.trim().is_empty() {
                let mut resp = tide::Response::new(tide::StatusCode::Ok);
                resp.set_body("No Ruby code supplied");
                return Ok(resp);
            }

            // Create unique .rb filename.
            let ts = Utc::now().timestamp_nanos_opt().unwrap_or(0);
            let filename = format!("{}/ae_{}.rb", script_dir, ts);
            std::fs::write(&filename, &ruby_source)
                .map_err(|e| tide::Error::new(tide::StatusCode::InternalServerError, e))?;

            let result_path = format!(
                "/root/midscore_io/rustby/rustby-vm/target/release/scripts/ae_{}.txt",
                ts
            );

            // Block until the result file is available or until timeout
            let start = std::time::Instant::now();
            let timeout = std::time::Duration::from_secs(120);
            while !std::path::Path::new(&result_path).exists() {
                if start.elapsed() > timeout {
                    return Ok("Timed out waiting for result file".into());
                }
                std::thread::sleep(std::time::Duration::from_millis(1));
            }
            let output =
                std::fs::read_to_string(&result_path).unwrap_or_else(|_| "No output".to_string());

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

    app.at("/moon")
        .get(|mut req: tide::Request<AppState>| async move {
            let script_dir = "/root/midscore_io/rustby/rustby-vm/target/release/scripts";
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
            let filename = format!("{}/moon_{}.rb", script_dir, ts);
            std::fs::write(&filename, &ruby_source)
                .map_err(|e| tide::Error::new(tide::StatusCode::InternalServerError, e))?;

            let result_path = format!(
                "/root/midscore_io/rustby/rustby-vm/target/release/scripts/moon_{}.txt",
                ts
            );

            // Block until the result file is available or until timeout
            let start = std::time::Instant::now();
            let timeout = std::time::Duration::from_secs(120);
            while !std::path::Path::new(&result_path).exists() {
                if start.elapsed() > timeout {
                    return Ok("Timed out waiting for result file".into());
                }
                std::thread::sleep(std::time::Duration::from_millis(1));
            }
            let output =
                std::fs::read_to_string(&result_path).unwrap_or_else(|_| "No output".to_string());

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

    app.at("/weather")
        .get(|mut req: tide::Request<AppState>| async move {
            let script_dir = "/root/midscore_io/rustby/rustby-vm/target/release/scripts";
            //td::fs::create_dir_all(script_dir).ok();
            let mut res = tide::Response::new(tide::StatusCode::Ok);
            //res.set_body("HTML content for /moon route");
            //res.set_content_type("text/html; charset=utf-8");
            //return Ok(res);
            // Grab Ruby code from request body.
            let ruby_source = r######"

    "#{ForecastByLongitude.new.fetch_forecast(39.068684, -122.781375)}"

    "######;
            if ruby_source.trim().is_empty() {
                let mut resp = tide::Response::new(tide::StatusCode::Ok);
                resp.set_body("No Ruby code supplied");
                return Ok(resp);
            }

            // Create unique .rb filename.
            let ts = Utc::now().timestamp_nanos_opt().unwrap_or(0);
            let filename = format!("{}/weather_{}.rb", script_dir, ts);
            std::fs::write(&filename, &ruby_source)
                .map_err(|e| tide::Error::new(tide::StatusCode::InternalServerError, e))?;

            let result_path = format!(
                "/root/midscore_io/rustby/rustby-vm/target/release/scripts/weather_{}.txt",
                ts
            );

            // Block until the result file is available or until timeout
            let start = std::time::Instant::now();
            let timeout = std::time::Duration::from_secs(120);
            while !std::path::Path::new(&result_path).exists() {
                if start.elapsed() > timeout {
                    return Ok("Timed out waiting for result file".into());
                }
                std::thread::sleep(std::time::Duration::from_millis(1));
            }
            let output =
                std::fs::read_to_string(&result_path).unwrap_or_else(|_| "No output".to_string());

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

    //get neutri alg
    app.at("/rneutrialg")
        .get(|mut req: tide::Request<AppState>| async move {
            let script_dir = "/root/midscore_io/rustby/rustby-vm/target/release/scripts";
            //td::fs::create_dir_all(script_dir).ok();
            let mut res = tide::Response::new(tide::StatusCode::Ok);
            //res.set_body("HTML content for /moon route");
            //res.set_content_type("text/html; charset=utf-8");
            //return Ok(res);
            // Grab Ruby code from request body.
            let query: std::collections::HashMap<String, String> = req.query().unwrap_or_default();
            let file_contents = std::fs::read_to_string("rneutri.txt")
                .map_err(|e| tide::Error::new(tide::StatusCode::InternalServerError, e))?;

            // Return the HTML response.
            let mut res = tide::Response::new(tide::StatusCode::Ok);
            res.set_body(file_contents);
            res.insert_header("Content-Type", "text/plain; charset=utf-8");
            Ok(res)
            //Ok(output.into())
        });

    //neutri setter
    app.at("/rneutri")
        .get(|mut req: tide::Request<AppState>| async move {
            let script_dir = "/root/midscore_io/rustby/rustby-vm/target/release/scripts";
            //td::fs::create_dir_all(script_dir).ok();
            let mut res = tide::Response::new(tide::StatusCode::Ok);
            //res.set_body("HTML content for /moon route");
            //res.set_content_type("text/html; charset=utf-8");
            //return Ok(res);
            // Grab Ruby code from request body.
            let query: std::collections::HashMap<String, String> = req.query().unwrap_or_default();
            let value = query.get("value").unwrap_or(&String::new()).to_string();
            std::fs::write("rneutri.txt", &value)
                .map_err(|e| tide::Error::new(tide::StatusCode::InternalServerError, e))?;

            // Return the HTML response.
            let mut res = tide::Response::new(tide::StatusCode::Ok);
            res.set_body(value);
            res.insert_header("Content-Type", "text/plain; charset=utf-8");
            Ok(res)
            //Ok(output.into())
        });

    app.at("/sun")
        .get(|mut req: tide::Request<AppState>| async move {
            let script_dir = "/root/midscore_io/rustby/rustby-vm/target/release/scripts";
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
            let filename = format!("{}/sun_{}.rb", script_dir, ts);
            std::fs::write(&filename, &ruby_source)
                .map_err(|e| tide::Error::new(tide::StatusCode::InternalServerError, e))?;

            let result_path = format!(
                "/root/midscore_io/rustby/rustby-vm/target/release/scripts/sun_{}.txt",
                ts
            );

            // Block until the result file is available or until timeout
            let start = std::time::Instant::now();
            let timeout = std::time::Duration::from_secs(120);
            while !std::path::Path::new(&result_path).exists() {
                if start.elapsed() > timeout {
                    return Ok("Timed out waiting for result file".into());
                }
                std::thread::sleep(std::time::Duration::from_millis(1));
            }
            let output =
                std::fs::read_to_string(&result_path).unwrap_or_else(|_| "No output".to_string());

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

    app.at("/tiade-maepers/*rest")
        .get(|req: tide::Request<AppState>| async move {
            // Extract the wildcard part from the URL.
            let rest = req.param("rest").unwrap_or("");
            // Build the target URL for the 8080 server.
            let target_url = format!("https://miaedscore.online/{}", rest);

            // Build an HTML page with an iframe loading the target URL.
            // A JavaScript snippet removes any query parameters from the browser URL.
            let html_content = format!(
                r#"<!DOCTYPE html>
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
</html>"#,
                target_url
            );

            // Return the HTML response.
            let mut res = tide::Response::new(tide::StatusCode::Ok);
            res.set_body(html_content);
            res.set_content_type("text/html");
            Ok(res)
        });
    app.at("/parse_plink")
        .get(|req: tide::Request<AppState>| async move {
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

    // assuming the helper is in the module

    app.at("/img/resize")
        .post(|mut req: tide::Request<AppState>| async move {
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
            let width: u32 = query
                .get("width")
                .and_then(|s| s.parse().ok())
                .unwrap_or(800);
            let height: u32 = query
                .get("height")
                .and_then(|s| s.parse().ok())
                .unwrap_or(600);

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
      <meta name="msvalidate.01" content="AAA4058A3DABDECA9018AD89DD143C68" />
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

    // A simple POST endpoint
    app.at("/echo")
        .post(|mut req: Request<AppState>| async move {
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
    app.at("/file/add")
        .post(|mut req: Request<AppState>| async move {
            let contents = req.body_bytes().await.unwrap_or_default();
            std::fs::write("/tmp/new_file.txt", &contents)?;
            Ok("File added")
        });

    // Delete a file
    app.at("/file/delete").delete(|_| async {
        std::fs::remove_file("/tmp/new_file.txt")?;
        Ok("File deleted")
    });

    // Listen on all interfaces over standard HTTPS (TLS) port.
    let addresses = vec!["0.0.0.0:443"];
    let cert_path = "/etc/letsencrypt/live/stimky.info/fullchain.pem";
    let key_path = "/etc/letsencrypt/live/stimky.info/privkey.pem";

    let mut tasks = vec![];
    for addr in addresses {
        let app_clone = app.clone();
        let c = cert_path.to_string();
        let k = key_path.to_string();
        println!("Spawning server on address: {}", addr); // Debug message
        tasks.push(async_std::task::spawn(async move {
            let listener = TlsListener::build().addrs(addr).cert(c).key(k);
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
