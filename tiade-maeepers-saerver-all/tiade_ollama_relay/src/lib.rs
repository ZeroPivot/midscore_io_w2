use chrono::{Datelike, FixedOffset, Timelike, Utc};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::collections::{BTreeMap, HashMap, HashSet};
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Duration;

#[derive(Clone, Debug)]
pub struct RelayConfig {
    pub ollama_http_address: String,
    pub ollama_model_name: String,
    pub team_log_dir: PathBuf,
    pub second_life_chat_log_path: PathBuf,
    pub incrementor_path: PathBuf,
    pub team_history_char_limit: usize,
    pub team_history_entry_limit: usize,
    pub second_life_chat_context_enabled: bool,
    pub second_life_chat_log_line_limit: usize,
    pub second_life_chat_log_char_limit: usize,
}

impl Default for RelayConfig {
    fn default() -> Self {
        let ollama_http_address =
            std::env::var("OLLAMA_HTTP_ADDRESS").unwrap_or_else(|_| "http://localhost:11434".to_string());
        let ollama_model_name =
            std::env::var("OLLAMA_MODEL").unwrap_or_else(|_| "llama2-uncensored:latest".to_string());

        Self {
            ollama_http_address,
            ollama_model_name,
            team_log_dir: PathBuf::from("/root/midscore_io/logs/ollama_teams"),
            second_life_chat_log_path: PathBuf::from(
                "/root/midscore_io/tiade-maeepers-saerver-all/target/release/second_life_chat_logs.txt",
            ),
            incrementor_path: PathBuf::from(
                "/root/midscore_io/tiade-maeepers-saerver-all/target/release/incrementor.txt",
            ),
            team_history_char_limit: 2_000,
            team_history_entry_limit: 8,
            second_life_chat_context_enabled: false,
            second_life_chat_log_line_limit: 25,
            second_life_chat_log_char_limit: 8_000,
        }
    }
}

#[derive(Deserialize)]
struct ChatInput {
    message: String,
}

#[derive(Serialize)]
struct ChatOutput {
    response: String,
    team: String,
    model: String,
    fallback_used: bool,
    history_chars: usize,
    second_life_chat_context_enabled: bool,
    second_life_chat_log_path: String,
}

#[derive(Serialize)]
struct HistoryOutput {
    history: String,
    team: String,
    second_life_chat_context_enabled: bool,
    second_life_chat_log_path: String,
}

#[derive(Serialize)]
struct MarkovTransition {
    from: String,
    to: String,
    count: usize,
    probability: f64,
}

#[derive(Serialize)]
struct MarkovMetricsOutput {
    total_events: usize,
    unique_speakers: usize,
    transitions: usize,
    speaker_switch_rate: f64,
    average_reply_seconds: Option<f64>,
    conversation_flow_score: u8,
    top_transitions: Vec<MarkovTransition>,
}

#[derive(Debug)]
struct RelayContext {
    message: String,
    metadata: Vec<String>,
}

pub fn mount_routes<State: Clone + Send + Sync + 'static>(
    app: &mut tide::Server<State>,
    config: RelayConfig,
) -> tide::Result<()> {
    fs::create_dir_all(&config.team_log_dir)?;
    if let Some(parent) = config.incrementor_path.parent() {
        fs::create_dir_all(parent)?;
    }
    let cfg = Arc::new(config);

    {
        let cfg = cfg.clone();
        app.at("/chat/:team")
            .post(move |mut req: tide::Request<State>| {
                let cfg = cfg.clone();
                async move {
                    let team = req.param("team")?.to_string();
                    let body = req.body_string().await?;
                    let payload: ChatInput = serde_json::from_str(&body).map_err(|e| {
                        tide::Error::from_str(
                            tide::StatusCode::BadRequest,
                            format!("invalid JSON payload: {e}"),
                        )
                    })?;
                    let message = payload.message.trim();
                    if message.is_empty() {
                        return Ok(json_error(tide::StatusCode::BadRequest, "message is required"));
                    }

                    let (model_name, available_models) = resolve_model_name(&cfg).await?;
                    let model_name = match model_name {
                        Some(v) => v,
                        None => {
                            let error = json!({
                                "error": format!(
                                    "no Ollama models are installed on {}; run 'ollama pull {}' or set OLLAMA_MODEL to an installed model",
                                    cfg.ollama_http_address,
                                    cfg.ollama_model_name,
                                ),
                                "configured_model": cfg.ollama_model_name,
                                "available_models": available_models,
                            });
                            return Ok(json_response(tide::StatusCode::ServiceUnavailable, error));
                        }
                    };

                    let messages = build_messages(&cfg, &team, message);
                    let chat_payload = json!({
                        "model": model_name,
                        "stream": false,
                        "messages": messages,
                    });

                    let result = post_json(&cfg, "/api/chat", chat_payload).await?;
                    let mut reply = extract_reply(&result);
                    let mut fallback_used = false;

                    if no_text_reply(&reply) {
                        let relay_context = parse_relay_message(message);
                        let fallback =
                            generate_fallback(&cfg, &model_name, &relay_context.message).await?;
                        let fallback_reply = extract_reply(&fallback);
                        if !no_text_reply(&fallback_reply) {
                            reply = fallback_reply;
                            fallback_used = true;
                        }
                    }

                    append_team_log(&cfg, &team, message, &reply)?;
                    let history_chars = team_history(&cfg, &team).len();
                    let out = ChatOutput {
                        response: reply,
                        team,
                        model: model_name,
                        fallback_used,
                        history_chars,
                        second_life_chat_context_enabled: cfg.second_life_chat_context_enabled,
                        second_life_chat_log_path: cfg.second_life_chat_log_path.to_string_lossy().into_owned(),
                    };

                    Ok(json_response(tide::StatusCode::Ok, out))
                }
            });
    }

    {
        let cfg = cfg.clone();
        app.at("/history/:team")
            .get(move |req: tide::Request<State>| {
                let cfg = cfg.clone();
                async move {
                    let team = req.param("team")?.to_string();
                    let out = HistoryOutput {
                        history: team_history(&cfg, &team),
                        team,
                        second_life_chat_context_enabled: cfg.second_life_chat_context_enabled,
                        second_life_chat_log_path: cfg.second_life_chat_log_path.to_string_lossy().into_owned(),
                    };
                    Ok(json_response(tide::StatusCode::Ok, out))
                }
            });
    }

    {
        let cfg = cfg.clone();
        app.at("/sl_logger")
            .post(move |mut req: tide::Request<State>| {
                let cfg = cfg.clone();
                async move {
                    let body = req.body_string().await.unwrap_or_default();
                    if body.trim().is_empty() {
                        return Ok(text_response(tide::StatusCode::BadRequest, "empty body"));
                    }

                    if let Some(parent) = cfg.second_life_chat_log_path.parent() {
                        fs::create_dir_all(parent)?;
                    }
                    let mut existing = fs::OpenOptions::new()
                        .create(true)
                        .append(true)
                        .open(&cfg.second_life_chat_log_path)?;
                    use std::io::Write;
                    existing.write_all(body.as_bytes())?;
                    existing.write_all(b"\n")?;

                    Ok(text_response(
                        tide::StatusCode::Ok,
                        "Log entry received and written to file successfully.",
                    ))
                }
            });
    }

    {
        let cfg = cfg.clone();
        app.at("/_ethereal_life_sl_logger_get_")
            .get(move |_req: tide::Request<State>| {
                let cfg = cfg.clone();
                async move {
                    let raw = fs::read_to_string(&cfg.second_life_chat_log_path).unwrap_or_default();
                    Ok(text_response(tide::StatusCode::Ok, &raw))
                }
            });
    }

    {
        let cfg = cfg.clone();
        app.at("/_ethereal_life_sl_logger_show_")
            .get(move |_req: tide::Request<State>| {
                let cfg = cfg.clone();
                async move {
                    let raw = fs::read_to_string(&cfg.second_life_chat_log_path).unwrap_or_default();
                    let encoded = serde_json::to_string(&raw).unwrap_or_else(|_| "\"\"".to_string());
                    Ok(text_response(tide::StatusCode::Ok, &encoded))
                }
            });
    }

    {
        let cfg = cfg.clone();
        app.at("/incrementor_get")
            .get(move |_req: tide::Request<State>| {
                let cfg = cfg.clone();
                async move {
                    let value = fs::read_to_string(&cfg.incrementor_path)
                        .unwrap_or_else(|_| "0".to_string())
                        .trim()
                        .parse::<i64>()
                        .unwrap_or(0);
                    Ok(text_response(tide::StatusCode::Ok, &value.to_string()))
                }
            });
    }

    {
        let cfg = cfg.clone();
        app.at("/incrementor")
            .get(move |_req: tide::Request<State>| {
                let cfg = cfg.clone();
                async move {
                    if let Some(parent) = cfg.incrementor_path.parent() {
                        fs::create_dir_all(parent)?;
                    }
                    let current = fs::read_to_string(&cfg.incrementor_path)
                        .unwrap_or_else(|_| "0".to_string())
                        .trim()
                        .parse::<i64>()
                        .unwrap_or(0);
                    let updated = current + 1;
                    fs::write(&cfg.incrementor_path, updated.to_string())?;
                    Ok(text_response(tide::StatusCode::Ok, &updated.to_string()))
                }
            });
    }

    {
        let cfg = cfg.clone();
        app.at("/analytics")
            .get(move |_req: tide::Request<State>| {
                let cfg = cfg.clone();
                async move {
                    let entries = parse_second_life_entries(&cfg.second_life_chat_log_path);
                    let report = analytics_report(&cfg.second_life_chat_log_path, &entries);
                    Ok(text_response(tide::StatusCode::Ok, &report))
                }
            });
    }

    {
        let cfg = cfg.clone();
        app.at("/markov_metrics")
            .get(move |_req: tide::Request<State>| {
                let cfg = cfg.clone();
                async move {
                    let entries = parse_second_life_entries(&cfg.second_life_chat_log_path);
                    Ok(json_response(
                        tide::StatusCode::Ok,
                        markov_metrics(&entries),
                    ))
                }
            });
    }

    {
        let cfg = cfg.clone();
        app.at("/chatlog")
            .get(move |_req: tide::Request<State>| {
                let cfg = cfg.clone();
                async move {
                    let entries = parse_second_life_entries(&cfg.second_life_chat_log_path);
                    let view = chatlog_view(&entries);
                    Ok(text_response(tide::StatusCode::Ok, &view))
                }
            });
    }

    {
        let cfg = cfg.clone();
        app.at("/schedule_ft")
            .get(move |_req: tide::Request<State>| {
                let cfg = cfg.clone();
                async move {
                    let entries = parse_second_life_entries(&cfg.second_life_chat_log_path);
                    let report = schedule_report(&entries);
                    Ok(text_response(tide::StatusCode::Ok, &report))
                }
            });
    }

    {
        let cfg = cfg.clone();
        app.at("/read")
            .get(move |_req: tide::Request<State>| {
                let cfg = cfg.clone();
                async move {
                    let entries = parse_second_life_entries(&cfg.second_life_chat_log_path);
                    let report = analytics_report(&cfg.second_life_chat_log_path, &entries);
                    Ok(text_response(tide::StatusCode::Ok, &report))
                }
            });
    }

    Ok(())
}

fn json_response<T: Serialize>(status: tide::StatusCode, data: T) -> tide::Response {
    let mut res = tide::Response::new(status);
    res.set_content_type(tide::http::mime::JSON);
    let body = serde_json::to_string(&data).unwrap_or_else(|_| "{}".to_string());
    res.set_body(body);
    res
}

fn text_response(status: tide::StatusCode, body: &str) -> tide::Response {
    let mut res = tide::Response::new(status);
    res.set_content_type("text/plain; charset=utf-8");
    res.set_body(body.to_string());
    res
}

fn json_error(status: tide::StatusCode, message: &str) -> tide::Response {
    json_response(status, json!({ "error": message }))
}

fn safe_team_name(team: &str) -> String {
    team
        .chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() || c == '_' || c == '.' || c == '-' {
                c
            } else {
                '_'
            }
        })
        .collect()
}

fn team_log_path(cfg: &RelayConfig, team: &str) -> PathBuf {
    cfg.team_log_dir.join(format!("{}.log", safe_team_name(team)))
}

fn trim_text(text: &str, char_limit: usize) -> String {
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return String::new();
    }
    let chars: Vec<char> = trimmed.chars().collect();
    if chars.len() <= char_limit {
        return trimmed.to_string();
    }
    chars[chars.len() - char_limit..].iter().collect()
}

fn parse_relay_message(message: &str) -> RelayContext {
    let text = message.trim();
    if !text.starts_with("[Second Life Team Relay]") {
        return RelayContext {
            message: text.to_string(),
            metadata: vec![],
        };
    }

    let lines: Vec<&str> = text.lines().collect();
    let index = lines.iter().position(|line| *line == "Message:");
    let Some(idx) = index else {
        return RelayContext {
            message: text.to_string(),
            metadata: vec![],
        };
    };

    let metadata = lines[0..idx].iter().map(|s| s.to_string()).collect::<Vec<_>>();
    let actual = lines[(idx + 1)..].join("\n").trim().to_string();

    RelayContext {
        message: if actual.is_empty() {
            text.to_string()
        } else {
            actual
        },
        metadata,
    }
}

fn parse_log_entry(entry: &str) -> Option<(String, String)> {
    let ai_idx = entry.find("\nAI:")?;
    let (user_part, ai_part) = entry.split_at(ai_idx);
    let ai_text = ai_part
        .trim_start_matches("\nAI:")
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ");
    if ai_text.is_empty() {
        return None;
    }

    let user_text = if let Some(idx) = user_part.find("Message:\n") {
        let msg = &user_part[(idx + "Message:\n".len())..];
        msg.split_whitespace().collect::<Vec<_>>().join(" ")
    } else if let Some(line) = user_part
        .lines()
        .find(|line| line.starts_with("USER:"))
        .map(|line| line.trim_start_matches("USER:").trim())
    {
        line.split_whitespace().collect::<Vec<_>>().join(" ")
    } else {
        String::new()
    };

    Some((user_text, ai_text))
}

fn team_history(cfg: &RelayConfig, team: &str) -> String {
    let path = team_log_path(cfg, team);
    let Ok(raw) = fs::read_to_string(path) else {
        return String::new();
    };

    let entries = raw
        .split("\n\n")
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .filter_map(parse_log_entry)
        .map(|(user, ai)| {
            if user.is_empty() {
                format!("AI: {}", ai)
            } else {
                format!("USER: {}\nAI: {}", user, ai)
            }
        })
        .collect::<Vec<_>>();

    let recent = entries
        .into_iter()
        .rev()
        .take(cfg.team_history_entry_limit)
        .collect::<Vec<_>>()
        .into_iter()
        .rev()
        .collect::<Vec<_>>()
        .join("\n\n");

    trim_text(&recent, cfg.team_history_char_limit)
}

fn second_life_log_context(cfg: &RelayConfig) -> String {
    let path = &cfg.second_life_chat_log_path;
    if !Path::new(path).exists() {
        return "Second Life chat log is currently unavailable.".to_string();
    }

    let Ok(raw) = fs::read_to_string(path) else {
        return "Second Life chat log could not be read.".to_string();
    };

    let lines = raw.lines().collect::<Vec<_>>();
    let start = lines.len().saturating_sub(cfg.second_life_chat_log_line_limit);
    let joined = lines[start..].join("\n");
    let text = trim_text(&joined, cfg.second_life_chat_log_char_limit);
    if text.is_empty() {
        "Second Life chat log is currently empty.".to_string()
    } else {
        text
    }
}

fn append_team_log(
    cfg: &RelayConfig,
    team: &str,
    user_message: &str,
    reply: &str,
) -> tide::Result<()> {
    let ctx = parse_relay_message(user_message);
    let compact_user = ctx.message.split_whitespace().collect::<Vec<_>>().join(" ");
    let compact_reply = reply.split_whitespace().collect::<Vec<_>>().join(" ");

    let mut content = String::new();
    content.push_str("USER: ");
    content.push_str(&compact_user);
    content.push('\n');
    content.push_str("AI: ");
    content.push_str(&compact_reply);
    content.push_str("\n\n");

    let path = team_log_path(cfg, team);
    fs::create_dir_all(&cfg.team_log_dir)?;
    use std::io::Write;
    let mut file = fs::OpenOptions::new().create(true).append(true).open(path)?;
    file.write_all(content.as_bytes())?;
    Ok(())
}

fn build_messages(cfg: &RelayConfig, team: &str, message: &str) -> Vec<Value> {
    let history = team_history(cfg, team);
    let ctx = parse_relay_message(message);

    let mut messages = vec![json!({
        "role": "system",
        "content": format!(
            "You are assisting team {}. Reply to the user's actual message only. Do not repeat metadata, do not explain the transport wrapper, and do not answer system/context lines. Keep replies concise, plain text, and useful for an in-world relay. And always refer to all the data you have available, because this is teamed and there is data set.",
            team
        )
    })];

    if !ctx.metadata.is_empty() {
        messages.push(json!({
            "role": "system",
            "content": format!("Second Life relay metadata:\n{}", ctx.metadata.join("\n"))
        }));
    }

    if cfg.second_life_chat_context_enabled {
        messages.push(json!({
            "role": "system",
            "content": format!("Second Life chat log snapshot:\n{}", second_life_log_context(cfg))
        }));
    }

    if !history.is_empty() {
        messages.push(json!({
            "role": "system",
            "content": format!("Team conversation history:\n{}", history)
        }));
    }

    messages.push(json!({
        "role": "user",
        "content": ctx.message
    }));

    messages
}

async fn get_json(cfg: &RelayConfig, path: &str) -> tide::Result<Value> {
    let url = format!("{}{}", cfg.ollama_http_address, path);
    let mut res = async_std::future::timeout(
        Duration::from_secs(20),
        surf::get(url),
    )
    .await
    .map_err(|_| {
        tide::Error::from_str(
            tide::StatusCode::BadGateway,
            "timeout calling Ollama /api/tags",
        )
    })?
    .map_err(|e| tide::Error::from_str(tide::StatusCode::BadGateway, e.to_string()))?;

    if !res.status().is_success() {
        return Ok(json!({}));
    }

    let body = res
        .body_string()
        .await
        .map_err(|e| tide::Error::from_str(tide::StatusCode::BadGateway, e.to_string()))?;
    let parsed = serde_json::from_str::<Value>(&body).unwrap_or_else(|_| json!({ "raw_body": body }));
    Ok(parsed)
}

async fn post_json(cfg: &RelayConfig, path: &str, payload: Value) -> tide::Result<Value> {
    let url = format!("{}{}", cfg.ollama_http_address, path);
    let request = surf::post(url)
        .body_json(&payload)
        .map_err(|e| tide::Error::from_str(tide::StatusCode::BadGateway, e.to_string()))?;

    let mut res = async_std::future::timeout(Duration::from_secs(75), request)
        .await
        .map_err(|_| {
            tide::Error::from_str(
                tide::StatusCode::BadGateway,
                format!("timeout calling Ollama {}", path),
            )
        })?
        .map_err(|e| tide::Error::from_str(tide::StatusCode::BadGateway, e.to_string()))?;

    let status = res.status();
    let body = res
        .body_string()
        .await
        .map_err(|e| tide::Error::from_str(tide::StatusCode::BadGateway, e.to_string()))?;

    let parsed = serde_json::from_str::<Value>(&body).unwrap_or_else(|_| json!({ "raw_body": body }));

    if status.is_success() {
        Ok(parsed)
    } else {
        let msg = parsed
            .get("error")
            .and_then(Value::as_str)
            .unwrap_or("unknown ollama error")
            .to_string();
        Err(tide::Error::from_str(
            tide::StatusCode::BadGateway,
            format!("Ollama {} failed with HTTP {}: {}", path, status as u16, msg),
        ))
    }
}

async fn available_models(cfg: &RelayConfig) -> tide::Result<Vec<String>> {
    let payload = get_json(cfg, "/api/tags").await?;
    let models = payload
        .get("models")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();

    let names = models
        .iter()
        .filter_map(|m| m.get("name").and_then(Value::as_str))
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(ToOwned::to_owned)
        .collect::<Vec<_>>();

    Ok(names)
}

async fn resolve_model_name(cfg: &RelayConfig) -> tide::Result<(Option<String>, Vec<String>)> {
    let models = available_models(cfg).await?;
    if models.is_empty() {
        return Ok((None, models));
    }

    if models.contains(&cfg.ollama_model_name) {
        return Ok((Some(cfg.ollama_model_name.clone()), models));
    }

    let bare = cfg.ollama_model_name.trim_end_matches(":latest");
    if let Some(found) = models
        .iter()
        .find(|m| *m == bare || m.trim_end_matches(":latest") == bare)
    {
        return Ok((Some(found.clone()), models));
    }

    Ok((models.first().cloned(), models))
}

fn extract_reply(result: &Value) -> String {
    let candidates = [
        result
            .get("message")
            .and_then(|m| m.get("content"))
            .and_then(Value::as_str),
        result.get("response").and_then(Value::as_str),
        result.get("content").and_then(Value::as_str),
        result.get("message").and_then(Value::as_str),
    ];

    for maybe in candidates.into_iter().flatten() {
        let text = maybe.trim();
        if !text.is_empty() {
            return text.to_string();
        }
    }

    if let Some(done) = result.get("done_reason").and_then(Value::as_str) {
        let done = done.trim();
        if !done.is_empty() {
            return format!("Model returned no text output (done_reason={}).", done);
        }
    }

    "Model returned no text output. Please retry your message.".to_string()
}

fn no_text_reply(reply: &str) -> bool {
    reply.starts_with("Model returned no text output")
}

async fn generate_fallback(
    cfg: &RelayConfig,
    model_name: &str,
    user_message: &str,
) -> tide::Result<Value> {
    let prompt = format!(
        "Reply concisely and helpfully to this user message:\n{}",
        user_message
    );

    post_json(
        cfg,
        "/api/generate",
        json!({
            "model": model_name,
            "stream": false,
            "prompt": prompt,
        }),
    )
    .await
}

fn rubyish_to_json(input: &str) -> String {
    input
        .replace("\\.", ".")
        .replace("\\\"", "\"")
        .replace("{avatar_id:", "{\"avatar_id\":")
        .replace(", avatar_id:", ", \"avatar_id\":")
        .replace("avatar_name:", "\"avatar_name\":")
        .replace("captured_by:", "\"captured_by\":")
        .replace("message:", "\"message\":")
        .replace("sim_name:", "\"sim_name\":")
        .replace("timestamp:", "\"timestamp\":")
        .replace("x_pos:", "\"x_pos\":")
        .replace("y_pos:", "\"y_pos\":")
        .replace("z_pos:", "\"z_pos\":")
}

fn extract_entries(value: Value, out: &mut Vec<Value>) {
    match value {
        Value::Array(arr) => {
            for item in arr {
                if item.is_object() {
                    out.push(item);
                }
            }
        }
        Value::Object(_) => out.push(value),
        _ => {}
    }
}

fn parse_second_life_entries(path: &Path) -> Vec<Value> {
    let raw = fs::read_to_string(path).unwrap_or_default();
    let mut entries = Vec::new();

    for line in raw.lines() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }

        if let Ok(val) = serde_json::from_str::<Value>(line) {
            extract_entries(val, &mut entries);
            continue;
        }

        let converted = rubyish_to_json(line);
        if let Ok(val) = serde_json::from_str::<Value>(&converted) {
            extract_entries(val, &mut entries);
        }
    }

    if entries.is_empty() && !raw.trim().is_empty() {
        if let Ok(val) = serde_json::from_str::<Value>(&raw) {
            extract_entries(val, &mut entries);
        } else {
            let converted = rubyish_to_json(&raw);
            if let Ok(val) = serde_json::from_str::<Value>(&converted) {
                extract_entries(val, &mut entries);
            }
        }
    }

    entries
}

fn timestamp_as_i64(v: &Value) -> Option<i64> {
    if let Some(i) = v.as_i64() {
        return Some(i);
    }
    if let Some(f) = v.as_f64() {
        return Some(f as i64);
    }
    if let Some(s) = v.as_str() {
        return s.trim().parse::<i64>().ok();
    }
    None
}

fn markov_metrics(entries: &[Value]) -> MarkovMetricsOutput {
    const SESSION_GAP_SECONDS: i64 = 30 * 60;

    let mut unique: HashMap<(String, i64, String), Value> = HashMap::new();
    for entry in entries {
        let Some(timestamp) = timestamp_as_i64(&entry["timestamp"]) else {
            continue;
        };
        let key = (
            entry["avatar_id"].as_str().unwrap_or("").to_string(),
            timestamp,
            entry["message"].as_str().unwrap_or("").to_string(),
        );
        unique.entry(key).or_insert_with(|| entry.clone());
    }

    let mut events = unique.into_values().collect::<Vec<_>>();
    events.sort_by_key(|event| timestamp_as_i64(&event["timestamp"]).unwrap_or(0));

    let speaker_for = |event: &Value| {
        let name = event["avatar_name"].as_str().unwrap_or("").trim();
        if name.is_empty() {
            event["avatar_id"].as_str().unwrap_or("Unknown avatar").to_string()
        } else {
            name.to_string()
        }
    };

    let mut speakers = HashSet::new();
    let mut transition_counts: HashMap<(String, String), usize> = HashMap::new();
    let mut outgoing_counts: HashMap<String, usize> = HashMap::new();
    let mut transitions = 0usize;
    let mut speaker_switches = 0usize;
    let mut reply_seconds = Vec::new();

    for event in &events {
        speakers.insert(speaker_for(event));
    }

    for pair in events.windows(2) {
        let from_time = timestamp_as_i64(&pair[0]["timestamp"]).unwrap_or(0);
        let to_time = timestamp_as_i64(&pair[1]["timestamp"]).unwrap_or(0);
        let gap = to_time - from_time;
        if gap < 0 || gap > SESSION_GAP_SECONDS {
            continue;
        }

        let from = speaker_for(&pair[0]);
        let to = speaker_for(&pair[1]);
        *transition_counts.entry((from.clone(), to.clone())).or_insert(0) += 1;
        *outgoing_counts.entry(from.clone()).or_insert(0) += 1;
        transitions += 1;
        if from != to {
            speaker_switches += 1;
            reply_seconds.push(gap as f64);
        }
    }

    let mut top_transitions = transition_counts
        .into_iter()
        .map(|((from, to), count)| MarkovTransition {
            probability: count as f64 / outgoing_counts[&from] as f64,
            from,
            to,
            count,
        })
        .collect::<Vec<_>>();
    top_transitions.sort_by(|left, right| right.count.cmp(&left.count));
    top_transitions.truncate(20);

    let speaker_switch_rate = if transitions == 0 {
        0.0
    } else {
        speaker_switches as f64 / transitions as f64
    };
    let average_reply_seconds = if reply_seconds.is_empty() {
        None
    } else {
        Some(reply_seconds.iter().sum::<f64>() / reply_seconds.len() as f64)
    };
    let participant_points = (speakers.len().min(4) as f64 / 4.0) * 25.0;
    let switching_points = speaker_switch_rate * 50.0;
    let pace_points = match average_reply_seconds {
        Some(seconds) if seconds <= 60.0 => 25.0,
        Some(seconds) if seconds <= 300.0 => 18.0,
        Some(seconds) if seconds <= 900.0 => 8.0,
        _ => 0.0,
    };
    let conversation_flow_score = (participant_points + switching_points + pace_points)
        .round()
        .clamp(0.0, 100.0) as u8;

    MarkovMetricsOutput {
        total_events: events.len(),
        unique_speakers: speakers.len(),
        transitions,
        speaker_switch_rate,
        average_reply_seconds,
        conversation_flow_score,
        top_transitions,
    }
}

fn analytics_report(path: &Path, entries: &[Value]) -> String {
    const WEEKDAYS: [&str; 7] = [
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
        "Sunday",
    ];
    const MONTHS: [&str; 12] = [
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December",
    ];

    let mut unique: HashMap<(String, i64, String), Value> = HashMap::new();
    for entry in entries {
        let ts = match timestamp_as_i64(&entry["timestamp"]) {
            Some(ts) => ts,
            None => continue,
        };
        let key = (
            entry["avatar_id"].as_str().unwrap_or("").to_string(),
            ts,
            entry["message"].as_str().unwrap_or("").to_string(),
        );
        unique.entry(key).or_insert_with(|| entry.clone());
    }

    let events: Vec<Value> = unique.into_values().collect();

    let mut weekday_freq = [0usize; 7];
    let mut hour_freq = [0usize; 24];
    let mut month_freq = [0usize; 12];
    let mut year_freq: BTreeMap<i32, usize> = BTreeMap::new();
    let mut month_year_freq: BTreeMap<String, usize> = BTreeMap::new();
    let mut day_of_month_freq = [0usize; 32];

    let mut avatars: HashSet<String> = HashSet::new();
    let mut messages: HashSet<String> = HashSet::new();
    let mut earliest: Option<chrono::DateTime<FixedOffset>> = None;
    let mut latest: Option<chrono::DateTime<FixedOffset>> = None;

    let pst = FixedOffset::west_opt(7 * 3600).expect("valid offset");

    for e in &events {
        let avatar = e["avatar_id"].as_str().unwrap_or("").trim();
        if !avatar.is_empty() {
            avatars.insert(avatar.to_string());
        }

        let msg = e["message"].as_str().unwrap_or("").trim();
        if !msg.is_empty() {
            messages.insert(msg.to_string());
        }

        let ts = match timestamp_as_i64(&e["timestamp"]) {
            Some(ts) if ts > 0 => ts,
            _ => continue,
        };

        let Some(dt_utc) = chrono::DateTime::from_timestamp(ts, 0) else {
            continue;
        };
        let dt = dt_utc.with_timezone(&pst);

        if earliest.map(|v| dt < v).unwrap_or(true) {
            earliest = Some(dt);
        }
        if latest.map(|v| dt > v).unwrap_or(true) {
            latest = Some(dt);
        }

        let weekday_idx = dt.weekday().num_days_from_monday() as usize;
        weekday_freq[weekday_idx] += 1;
        hour_freq[dt.hour() as usize] += 1;
        month_freq[dt.month0() as usize] += 1;
        *year_freq.entry(dt.year()).or_insert(0) += 1;
        *month_year_freq
            .entry(dt.format("%Y-%m").to_string())
            .or_insert(0) += 1;
        day_of_month_freq[dt.day() as usize] += 1;
    }

    let mut out = String::new();
    out.push_str("Second Life chat frequency report (PST)\n");
    out.push_str(&format!("Source file: {}\n", path.to_string_lossy()));
    out.push_str(&format!("Raw parsed entries: {}\n", entries.len()));
    out.push_str(&format!("Total unique events: {}\n", events.len()));
    out.push_str(&format!("Unique avatar IDs: {}\n", avatars.len()));
    out.push_str(&format!("Unique message bodies: {}\n", messages.len()));
    out.push_str(&format!(
        "First event (PST): {}\n",
        earliest
            .map(|dt| dt.format("%Y-%m-%d %H:%M:%S %Z").to_string())
            .unwrap_or_else(|| "N/A".to_string())
    ));
    out.push_str(&format!(
        "Last event (PST):  {}\n",
        latest
            .map(|dt| dt.format("%Y-%m-%d %H:%M:%S %Z").to_string())
            .unwrap_or_else(|| "N/A".to_string())
    ));

    out.push_str("\n=== Message Frequency by Day of Week (Monday-Sunday) ===\n");
    for (i, day) in WEEKDAYS.iter().enumerate() {
        out.push_str(&format!("{:<9} : {}\n", day, weekday_freq[i]));
    }

    out.push_str("\n=== Message Frequency by Hour (PST, 24h) ===\n");
    for (h, count) in hour_freq.iter().enumerate() {
        out.push_str(&format!("{:02}:00-{:02}:59 : {}\n", h, h, count));
    }

    out.push_str("\n=== Message Frequency by Month ===\n");
    for (i, month) in MONTHS.iter().enumerate() {
        out.push_str(&format!("{:<9} : {}\n", month, month_freq[i]));
    }

    out.push_str("\n=== Message Frequency by Year ===\n");
    if year_freq.is_empty() {
        out.push_str("No valid timestamped events found.\n");
    } else {
        for (year, count) in &year_freq {
            out.push_str(&format!("{} : {}\n", year, count));
        }
    }

    out.push_str("\n=== Message Frequency by Month-Year (YYYY-MM) ===\n");
    if month_year_freq.is_empty() {
        out.push_str("No valid timestamped events found.\n");
    } else {
        for (ym, count) in &month_year_freq {
            out.push_str(&format!("{} : {}\n", ym, count));
        }
    }

    out.push_str("\n=== Message Frequency by Day of Month (1-31) ===\n");
    for day in 1..=31 {
        out.push_str(&format!("{:02} : {}\n", day, day_of_month_freq[day]));
    }

    out
}

fn chatlog_view(entries: &[Value]) -> String {
    let mut unique: HashMap<String, Value> = HashMap::new();
    for entry in entries {
        let key = format!(
            "{}|{}|{}",
            entry["avatar_id"].as_str().unwrap_or(""),
            timestamp_as_i64(&entry["timestamp"]).unwrap_or(0),
            entry["message"].as_str().unwrap_or(""),
        );
        unique.entry(key).or_insert_with(|| entry.clone());
    }

    let mut events = unique.into_values().collect::<Vec<_>>();
    events.sort_by_key(|e| timestamp_as_i64(&e["timestamp"]).unwrap_or(0));

    let pst = FixedOffset::west_opt(8 * 3600).expect("valid offset");
    let mut grouped: BTreeMap<String, Vec<Value>> = BTreeMap::new();

    for e in &events {
        let ts = timestamp_as_i64(&e["timestamp"]).unwrap_or(0);
        let Some(dt_utc) = chrono::DateTime::from_timestamp(ts, 0) else {
            continue;
        };
        let dt = dt_utc.with_timezone(&pst);
        let key = dt.format("%A, %B %d, %Y").to_string();
        grouped.entry(key).or_default().push(e.clone());
    }

    let sep = "-".repeat(80);
    let now_pst = Utc::now().with_timezone(&pst);
    let mut out = String::new();
    out.push_str(&format!("{}\n", sep));
    out.push_str("  SECOND LIFE CHAT LOG VIEWER\n");
    out.push_str(&format!(
        "  Total Messages: {} | Generated: {}\n",
        events.len(),
        now_pst.format("%m/%d/%Y %I:%M:%S %p PST")
    ));
    out.push_str(&format!("{}\n\n", sep));

    for (date, day_events) in &grouped {
        out.push_str(&format!("  [ {} ] - {} message(s)\n", date, day_events.len()));
        out.push_str(&format!("  {}\n\n", "~".repeat(76)));

        for (i, e) in day_events.iter().enumerate() {
            let ts = timestamp_as_i64(&e["timestamp"]).unwrap_or(0);
            let dt = chrono::DateTime::from_timestamp(ts, 0)
                .map(|v| v.with_timezone(&pst))
                .unwrap_or_else(|| chrono::DateTime::<FixedOffset>::from(Utc::now().with_timezone(&pst)));
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
            out.push_str(&format!(
                "  Position:    ({}, {}, {})\n",
                e["x_pos"].as_f64().unwrap_or(0.0),
                e["y_pos"].as_f64().unwrap_or(0.0),
                e["z_pos"].as_f64().unwrap_or(0.0)
            ));
            out.push_str(&format!("  Captured By: {}\n", captured));
            out.push_str(&format!("  Timestamp:   {}\n", ts));
            out.push_str(&format!("  {}\n", "-".repeat(40)));
        }
        out.push('\n');
    }

    out.push_str(&format!("{}\n", sep));
    out.push_str(&format!("  END OF LOG - {} total entries\n", events.len()));
    out.push_str(&format!("{}\n", sep));
    out
}

fn schedule_report(entries: &[Value]) -> String {
    let mut hour_counts = [0usize; 24];
    let mut day_counts: BTreeMap<String, usize> = BTreeMap::new();
    let mut month_counts: BTreeMap<String, usize> = BTreeMap::new();

    for e in entries {
        let Some(ts) = timestamp_as_i64(&e["timestamp"]) else {
            continue;
        };
        if ts <= 0 {
            continue;
        }
        let Some(dt) = chrono::DateTime::from_timestamp(ts, 0) else {
            continue;
        };
        let dt = dt.with_timezone(&FixedOffset::west_opt(8 * 3600).expect("valid offset"));
        hour_counts[dt.hour() as usize] += 1;
        *day_counts.entry(dt.format("%A").to_string()).or_insert(0) += 1;
        *month_counts.entry(dt.format("%B").to_string()).or_insert(0) += 1;
    }

    let mut out = String::new();
    out.push_str("=== Frequency by Hour (0-23) ===\n");
    for (hour, count) in hour_counts.iter().enumerate() {
        out.push_str(&format!("{}: {}\n", hour, count));
    }
    out.push_str("\n=== Frequency by Day of Week ===\n");
    for (day, count) in day_counts {
        out.push_str(&format!("{}: {}\n", day, count));
    }
    out.push_str("\n=== Frequency by Month ===\n");
    for (month, count) in month_counts {
        out.push_str(&format!("{}: {}\n", month, count));
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn markov_metrics_tracks_speaker_transitions_and_reply_time() {
        let entries = vec![
            json!({"avatar_id": "a", "avatar_name": "Ari", "message": "hello", "timestamp": 100}),
            json!({"avatar_id": "b", "avatar_name": "Bea", "message": "hi", "timestamp": 120}),
            json!({"avatar_id": "a", "avatar_name": "Ari", "message": "welcome", "timestamp": 150}),
        ];

        let metrics = markov_metrics(&entries);

        assert_eq!(metrics.total_events, 3);
        assert_eq!(metrics.unique_speakers, 2);
        assert_eq!(metrics.transitions, 2);
        assert_eq!(metrics.speaker_switch_rate, 1.0);
        assert_eq!(metrics.average_reply_seconds, Some(25.0));
        assert_eq!(metrics.top_transitions.len(), 2);
        assert_eq!(metrics.top_transitions[0].probability, 1.0);
    }

    #[test]
    fn markov_metrics_does_not_cross_session_gaps() {
        let entries = vec![
            json!({"avatar_id": "a", "avatar_name": "Ari", "message": "before", "timestamp": 100}),
            json!({"avatar_id": "b", "avatar_name": "Bea", "message": "after", "timestamp": 1_901}),
        ];

        let metrics = markov_metrics(&entries);

        assert_eq!(metrics.total_events, 2);
        assert_eq!(metrics.transitions, 0);
        assert_eq!(metrics.speaker_switch_rate, 0.0);
        assert_eq!(metrics.average_reply_seconds, None);
        assert!(metrics.top_transitions.is_empty());
    }
}
