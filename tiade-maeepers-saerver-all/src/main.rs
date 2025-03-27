use std::thread;
use async_std::task;
use tide::{Request, Response, StatusCode};
use tide_rustls::TlsListener;
use tide::utils::After;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use magnus::{embed, eval, Error};
pub fn spawn_ruby_eval_thread() -> std::thread::JoinHandle<Result<(), Error>> {
    std::thread::spawn(|| {
        let _ruby = unsafe { embed::init() };
        eval::<()>("puts 'Hello from Ruby via Magnus'")?;
        Ok(())
    })
}

pub fn eval_ruby_expression(expr: &str) -> Result<String, Error> {
    let _ruby = unsafe { embed::init() };
    let result: String = eval(expr)?;
    Ok(result)
}


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
        .addrs("0.0.0.0:443")
        .cert(cert_path)
        .key(key_path);

    // Spawn a separate thread for port forwarding
    thread::spawn(move || {
        task::block_on(async move {
            let mut proxy_app = tide::with_state(AppState {});
            proxy_app.at("/*").all(|mut req: Request<AppState>| async move {
                let body = req.body_bytes().await.unwrap_or_default();
                let url = format!("https://127.0.0.1:8080{}", req.url().path());
                let client = surf::Client::new();
                let mut forward = client.request(req.method(), &url).body_bytes(body);
                for (name, value) in req.iter() {
                    forward = forward.header(name, value);
                }
                match forward.send().await {
                    Ok(mut r) => {
                        let status = r.status();
                        let resp_body = r.body_bytes().await.unwrap_or_default();
                        let mut resp = Response::new(status);
                        resp.set_body(resp_body);
                        Ok(resp)
                    }
                    Err(_) => Ok(Response::new(StatusCode::BadGateway)),
                }
            });

            let proxy_listener = TlsListener::build()
                .addrs("127.0.0.1:80")
                .cert(cert_path)
                .key(key_path);
            proxy_app.listen(proxy_listener).await.unwrap();
        });
    });

    app.listen(main_listener).await?;
    Ok(())
}