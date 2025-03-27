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


use serde_json::{json, Value};

//implement a partitioned array/linedb database in rustby that encapsulates all partitioned array functions and is capable of storing files if possible; tide will perform surf calls to it

#[derive(Clone)]
struct AppState {}

#[async_std::main]
async fn main() -> tide::Result<()> {
    // Main HTTPS server
    let mut app = tide::with_state(AppState {});
    app.with(After(|res: tide::Response| async {
        println!("Main server request handled");
        Ok(res)
    }));
    // Several GET endpoints
    app.at("/").get(|_| async { Ok("Main server") });
    app.at("/health").get(|_| async { Ok("Health check OK") });
    app.at("/hello/:name").get(|req: Request<AppState>| async move {
        let name = req.param("name").unwrap_or("world");
        Ok(format!("Hello, {}!", name))
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