use tide_rustls::TlsListener;
use tide::utils::After;
use magnus::{eval, Error, RString};
use std::io::{self, BufRead};

/// Evaluates Ruby code and always returns a String.
fn call_rustby_eval(code: &str) -> Result<String, Error> {
    let result = eval::<RString>(code)?;
    Ok(result.to_string()?)
}

#[derive(Clone)]
struct AppState;

#[async_std::main]
async fn main() -> tide::Result<()> {
    // Spawn a background thread to listen for CLI input.
    std::thread::spawn(|| {
        let stdin = io::stdin();
        for line in stdin.lock().lines() {
            if let Ok(input) = line {
                if input.trim() == "exit" {
                    println!("Exiting server abruptly.");
                    std::process::exit(0);
                }
            }
        }
    });

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
    let _ruby = unsafe { magnus::embed::init() };

    use std::sync::Arc;
    let rustby_eval_title = Arc::new(call_rustby_eval("puts 'Hello from Ruby!'; 'RustbySpace'").unwrap());

    use std::collections::HashMap;
    use tide::{Request, Response, StatusCode};
    let rustby_eval_title = rustby_eval_title.clone();


    

    app.at("/").get(|_| async {
        let html = r#"<!DOCTYPE html>
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
          display: flex;
          align-items: center;
          justify-content: center;
          height: 100vh;
        }
        h1 {
          color: #333;
        }
      </style>
    </head>
    <body>
      <h1>Welcome to the Landing Page</h1>
    </body>
    </html>"#;
        let mut res = tide::Response::new(tide::StatusCode::Ok);
        res.set_body(html);
        res.set_content_type("text/html");
        Ok(res)
    });

    app.at("/rustby").get(move |req: Request<AppState>| {
        let rustby_eval_title = rustby_eval_title.clone();
        async move {
            let query: HashMap<String, String> = req.query().unwrap_or_default();
            let vlog = query
                .get("vlog")
                .cloned()
                .unwrap_or_else(|| "".to_string());

            let title = rustby_eval_title.to_string();
            let base_iframe_url = format!("https://miaedscore.online:8080{}", vlog);

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

    // New "ae" route that displays an iframe similar to /rustby.
    // It takes a query parameter "route" corresponding to the path on port 8080.
    // It displays a text link for the standard port 8080 route and embeds the /rustby iframe.
    app.at("/ae").get(|req: Request<AppState>| async move {
        let query: HashMap<String, String> = req.query().unwrap_or_default();
        let route = query.get("route").cloned().unwrap_or_else(|| "/".to_string());
        let standard_route = format!("https://miaedscore.online:8080{}", route);
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

    let cert_path = "/root/midscore_io/config/miaedscore.online_ssl_certificate.cer";
    let key_path = "/root/midscore_io/config/miaedscore.online_private_key.key";
    let main_listener = TlsListener::build()
        .addrs("209.46.120.242:443")
        .cert(cert_path)
        .key(key_path);

    app.listen(main_listener).await?;
    Ok(())
}
