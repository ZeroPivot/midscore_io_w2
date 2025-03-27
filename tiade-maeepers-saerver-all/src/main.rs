use std::thread;
use async_std::task;
use tide::{Request, Response, StatusCode};
use tide_rustls::TlsListener;
use tide::utils::After;
use serde::Deserialize;
use tide::http::Method;
use tide::http::Request as TideRequest;
use tide::http::Response as TideResponse;
use tide::http::StatusCode as TideStatusCode;
use std::sync::{Arc, Mutex};
use magnus::{eval, Error, RString};
/// Evaluates Ruby code and always returns a String.
fn call_rustby_eval(code: &str) -> Result<String, Error> {
    let result = eval::<RString>(code)?;
    Ok(result.to_string()?)
}


#[derive(Clone)]
struct AppState;

// Removed RubySender and related functionality

#[async_std::main]
async fn main() -> tide::Result<()> {
    // Main HTTPS server
    let mut app = tide::with_state(AppState {});
    app.with(After(|res: tide::Response| async {
        println!("Main server request handled");
        Ok(res)
    }));
    // Initialize the Ruby interpreter
    let _ruby = unsafe { magnus::embed::init() };
    // Several GET endpoints
    //app.at("/").get(|_| async { Ok("Main server") });
   let rustby_eval_title: String = call_rustby_eval("puts 'Hello from Ruby!'; 'RustbySpace'").unwrap();
    
 

    app.at("/").get(move |_| {
        let title = rustby_eval_title.clone();
        async move {
            let html_content = format!(r######"
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>{}</title>
                <meta name="description" content="A simple HTML page with an embedded iFrame, wip">
                <meta name="author" content="TIADE-MAEPPERS">
                <meta name="keywords" content="HTML, iFrame, example">
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
                    .iframe-container {{
                        position: relative;
                        width: 100%;
                        height: 100vh;
                        border: 3px solid black;
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
                </style>
            </head>
            <body>
                <div class="iframe-container">
                    <iframe src="https://miaedscore.online:8080" title="miaedscore.online"></iframe>
                </div>
            </body>
            </html>
            "######, title);
            Ok(Response::builder(StatusCode::Ok)
                .content_type("text/html")
                .body(html_content)
                .build())
        }
    });
    app.at("/health").get(|_| async { Ok("Health check OK") });
    app.at("/hello/:name").get(|req: Request<AppState>| async move {
        let name = match req.param("name") {
            Ok(name) => name,
            Err(_) => "world",
        };
        Ok(format!("Hello, {}!", name))
    });

    // A simple POST endpoint
    app.at("/echo").post(|mut req: Request<AppState>| async move {
        let body = req.body_string().await.unwrap_or_default();
        Ok(format!("You sent: {}", body))
    });

    // Removed Ruby eval endpoint

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
