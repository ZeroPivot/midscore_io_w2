use magnus::embed::init;
use magnus::{
    Error, RArray, RClass, RFile, RFloat, RHash, RModule, RObject, RRegexp, RString, RStruct, Ruby,
    Value, eval, function, method, prelude::*, rb_assert, typed_data, value::Lazy, value::Opaque,
};
use std::io::{self, BufRead};
use tide::utils::After;
use tide_rustls::TlsListener;

use chrono::Utc;
use tiade_ollama_relay::{RelayConfig as OllamaRelayConfig, mount_routes as mount_ollama_routes};


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

const SIGIL_DECK_ROOT: &str = "/root/midscore_io/tiade-maeepers-saerver-all/sigil_deck_data";
const SIGIL_DECK_DB_PATH: &str = "/root/midscore_io/tiade-maeepers-saerver-all/sigil_deck_data/deck.json";
const SIGIL_DECK_UPLOAD_DIR: &str = "/root/midscore_io/tiade-maeepers-saerver-all/sigil_deck_data/uploads";
const SIGIL_DECK_MAX_IMAGE_SIDE: u32 = 1600;

#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
struct SigilDeckEntry {
    id: u64,
    title: String,
    description: String,
    image_file: String,
    mime_type: String,
    created_at: String,
}

#[derive(Default, serde::Serialize, serde::Deserialize)]
struct SigilDeckDb {
    entries: Vec<SigilDeckEntry>,
}

#[derive(Clone, Debug)]
struct MultipartFile {
    filename: String,
    content_type: Option<String>,
    data: Vec<u8>,
}

fn escape_html(input: &str) -> String {
    input
        .replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&#39;")
}

fn sigil_deck_now_string() -> String {
    Utc::now().to_rfc3339()
}

fn sigil_deck_ensure_storage() -> tide::Result<()> {
    std::fs::create_dir_all(SIGIL_DECK_UPLOAD_DIR)
        .map_err(|e| tide::Error::from_str(tide::StatusCode::InternalServerError, e.to_string()))?;
    Ok(())
}

fn sigil_deck_upload_path(filename: &str) -> tide::Result<std::path::PathBuf> {
  let safe_name = std::path::Path::new(filename)
    .file_name()
    .and_then(|part| part.to_str())
    .filter(|part| *part == filename)
    .ok_or_else(|| tide::Error::from_str(tide::StatusCode::BadRequest, "invalid sigil filename"))?;
  Ok(std::path::Path::new(SIGIL_DECK_UPLOAD_DIR).join(safe_name))
}

fn load_sigil_deck_entries() -> tide::Result<Vec<SigilDeckEntry>> {
    sigil_deck_ensure_storage()?;
    match std::fs::read_to_string(SIGIL_DECK_DB_PATH) {
        Ok(raw) => {
            let db: SigilDeckDb = serde_json::from_str(&raw)
                .map_err(|e| tide::Error::from_str(tide::StatusCode::InternalServerError, e.to_string()))?;
            Ok(db.entries)
        }
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => Ok(Vec::new()),
        Err(err) => Err(tide::Error::from_str(
            tide::StatusCode::InternalServerError,
            err.to_string(),
        )),
    }
}

fn render_flashcard_page(entries: &[SigilDeckEntry]) -> String {
    let cards = entries
        .iter()
        .map(|entry| {
            serde_json::json!({
                "id": entry.id,
                "front": entry.title,
                "back": entry.description,
                "image": format!("/sigil-deck/image/{}", entry.image_file),
                "source": "Sigil deck",
            })
        })
        .collect::<Vec<_>>();
    let cards_json = serde_json::to_string(&cards)
        .unwrap_or_else(|_| "[]".to_string())
        .replace("</", "<\\/");

    format!(
        r##"<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Recall Deck</title>
  <style>
    :root {{ --paper: #f4f0e6; --ink: #1c2631; --muted: #64707a; --line: #d5d2c9; --navy: #18354a; --teal: #007d79; --card: #fffdf8; --shadow: 0 18px 42px rgba(20, 43, 55, .14); }}
    * {{ box-sizing: border-box; }} body {{ min-height: 100vh; margin: 0; color: var(--ink); font-family: Georgia, 'Times New Roman', serif; background-color: var(--paper); background-image: linear-gradient(rgba(24,53,74,.035) 1px, transparent 1px), linear-gradient(90deg, rgba(24,53,74,.035) 1px, transparent 1px); background-size: 28px 28px; }} button, input, textarea {{ font: inherit; }} button {{ cursor: pointer; }}
    .shell {{ width: min(1100px, calc(100% - 32px)); margin: 0 auto; padding: 28px 0 44px; }} .topbar {{ display: flex; justify-content: space-between; align-items: center; gap: 16px; border-bottom: 1px solid var(--line); padding-bottom: 18px; }} .brand {{ display: flex; align-items: center; gap: 11px; color: var(--navy); text-decoration: none; font-size: 1.05rem; font-weight: bold; }} .brand-mark {{ display: grid; place-items: center; width: 34px; height: 34px; border: 2px solid var(--teal); color: var(--teal); font-size: 1.4rem; line-height: 1; }} .text-button {{ padding: 9px 12px; border: 1px solid var(--line); color: var(--navy); background: rgba(255,255,255,.5); border-radius: 4px; text-decoration: none; }}
    .study {{ display: grid; grid-template-columns: minmax(0, 1fr) 250px; gap: 38px; align-items: start; padding-top: 40px; }} .eyebrow {{ margin: 0 0 8px; color: var(--teal); font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: .75rem; font-weight: 700; letter-spacing: .08em; text-transform: uppercase; }} h1 {{ margin: 0; color: var(--navy); font-size: clamp(2rem, 4vw, 3.4rem); line-height: 1; }} .subtitle {{ margin: 12px 0 26px; max-width: 56ch; color: var(--muted); line-height: 1.55; }} .progress-row {{ display: flex; align-items: center; justify-content: space-between; gap: 15px; margin-bottom: 12px; color: var(--muted); font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: .8rem; }} .progress {{ height: 7px; overflow: hidden; background: #d7e1df; }} .progress > div {{ width: 0; height: 100%; background: var(--teal); transition: width .25s ease; }}
    .scene {{ perspective: 1200px; margin-top: 22px; }} .flashcard {{ position: relative; min-height: 390px; transform-style: preserve-3d; transition: transform .55s cubic-bezier(.2,.7,.2,1); outline: 0; }} .flashcard.is-flipped {{ transform: rotateY(180deg); }} .face {{ position: absolute; inset: 0; display: flex; flex-direction: column; justify-content: space-between; overflow: hidden; padding: 30px; border: 1px solid #c8c3b8; background: var(--card); box-shadow: var(--shadow); backface-visibility: hidden; }} .face.back {{ color: white; background: var(--navy); transform: rotateY(180deg); }} .card-top {{ display: flex; justify-content: space-between; gap: 16px; color: var(--muted); font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: .75rem; letter-spacing: .04em; text-transform: uppercase; }} .back .card-top {{ color: #bcd5d4; }} .card-content {{ display: grid; grid-template-columns: minmax(0, 1fr) 150px; gap: 24px; align-items: center; flex: 1; }} .card-content.solo {{ grid-template-columns: 1fr; }} .card-question {{ margin: 0; font-size: clamp(1.6rem, 3.2vw, 2.7rem); line-height: 1.08; overflow-wrap: anywhere; }} .card-answer {{ margin: 0; font-size: clamp(1.15rem, 2.25vw, 1.65rem); line-height: 1.45; overflow-wrap: anywhere; white-space: pre-wrap; }} .card-image {{ display: block; width: 150px; height: 150px; object-fit: cover; border: 5px solid #e1ece8; }} .hint {{ margin: 18px 0 0; color: var(--muted); font-size: .9rem; }} .back .hint {{ color: #c9d7dd; }}
    .main-controls, .rating-controls {{ display: flex; flex-wrap: wrap; gap: 10px; margin-top: 18px; }} .control {{ min-width: 44px; min-height: 44px; padding: 0 14px; border: 1px solid var(--line); border-radius: 4px; color: var(--navy); background: rgba(255,255,255,.72); font-weight: bold; }} .control:hover {{ border-color: var(--teal); color: var(--teal); }} .control.primary {{ border-color: var(--teal); color: white; background: var(--teal); }} .rate {{ min-width: 110px; min-height: 42px; padding: 0 12px; border: 0; border-radius: 4px; color: #17252d; font-weight: bold; }} .rate.again {{ background: #f4b2a7; }} .rate.hard {{ background: #f5d88c; }} .rate.got-it {{ background: #9bd8c6; }}
    .side {{ padding-top: 64px; }} .side h2 {{ margin: 0 0 11px; color: var(--navy); font-size: 1rem; }} .stat {{ display: flex; align-items: baseline; justify-content: space-between; padding: 11px 0; border-top: 1px solid var(--line); }} .stat strong {{ color: var(--teal); font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 1.25rem; }} .side-actions {{ display: grid; gap: 9px; margin-top: 28px; }} .side-actions button {{ width: 100%; text-align: left; }}
    dialog {{ width: min(560px, calc(100% - 28px)); padding: 0; border: 0; box-shadow: var(--shadow); background: var(--card); }} dialog::backdrop {{ background: rgba(24,53,74,.5); }} .modal {{ padding: 24px; }} .modal-header {{ display: flex; align-items: center; justify-content: space-between; gap: 12px; }} .modal h2 {{ margin: 0; color: var(--navy); }} .form-grid {{ display: grid; gap: 14px; margin-top: 20px; }} label {{ display: grid; gap: 6px; color: var(--navy); font-size: .9rem; font-weight: bold; }} input, textarea {{ width: 100%; padding: 10px; border: 1px solid var(--line); border-radius: 3px; background: white; color: var(--ink); }} textarea {{ min-height: 105px; resize: vertical; }} .modal-actions {{ display: flex; justify-content: flex-end; gap: 10px; margin-top: 20px; }} .empty {{ display: none; padding: 32px; border: 1px dashed var(--line); color: var(--muted); text-align: center; }}
    @media (max-width: 760px) {{ .shell {{ width: min(100% - 20px, 1100px); padding-top: 16px; }} .study {{ grid-template-columns: 1fr; gap: 25px; padding-top: 28px; }} .side {{ padding-top: 0; }} .side-actions {{ grid-template-columns: repeat(2, minmax(0, 1fr)); }} .flashcard {{ min-height: 430px; }} .face {{ padding: 22px; }} .card-content {{ grid-template-columns: 1fr; }} .card-image {{ width: min(150px, 45vw); height: min(150px, 45vw); }} }}
  </style>
</head>
<body>
  <main class="shell">
    <header class="topbar"><a class="brand" href="/flashcard"><span class="brand-mark">R</span>Recall Deck</a><a class="text-button" href="/sigil-deck">Open sigil deck</a></header>
    <section class="study"><div><p class="eyebrow">Active recall study session</p><h1>Learn it. Hide it. Recall it.</h1><p class="subtitle">A focused digital flashcard routine: read the prompt, reveal only after your attempt, then rate how well it came back to you.</p><div id="studyArea"><div class="progress-row"><span id="position">Card 1 of 1</span><span id="deckLabel">Sigil deck</span></div><div class="progress"><div id="progressFill"></div></div><div class="scene"><article id="flashcard" class="flashcard" tabindex="0" aria-label="Flashcard. Press space to flip."><section class="face front"><div class="card-top"><span>Prompt</span><span id="frontSource"></span></div><div id="frontContent" class="card-content"><h2 id="frontText" class="card-question"></h2><img id="frontImage" class="card-image" alt=""></div><p class="hint">Try to answer before you reveal it.</p></section><section class="face back"><div class="card-top"><span>Answer</span><span>Recall Deck</span></div><div id="backContent" class="card-content"><p id="backText" class="card-answer"></p><img id="backImage" class="card-image" alt=""></div><p class="hint">How did that feel? Rate it, then move on.</p></section></article></div><div class="main-controls"><button id="previous" class="control" type="button">Previous</button><button id="flip" class="control primary" type="button">Reveal answer</button><button id="next" class="control" type="button">Next</button><button id="shuffle" class="control" type="button">Shuffle</button></div><div id="ratings" class="rating-controls" hidden><button class="rate again" data-rating="again" type="button">Again</button><button class="rate hard" data-rating="hard" type="button">Hard</button><button class="rate got-it" data-rating="got-it" type="button">Got it</button></div></div><div id="emptyState" class="empty">No cards yet. Add a card to start a study session.</div></div><aside class="side"><h2>Session</h2><div class="stat"><span>Reviewed</span><strong id="reviewed">0</strong></div><div class="stat"><span>Got it</span><strong id="mastered">0</strong></div><div class="stat"><span>In this deck</span><strong id="deckCount">0</strong></div><div class="side-actions"><button id="editCard" class="control" type="button">Edit current card</button><button id="deleteCard" class="control" type="button">Delete current card</button><button id="answerFirst" class="control" type="button">Start with answer</button><button id="addCard" class="control primary" type="button">Add personal card</button><button id="resetProgress" class="control" type="button">Reset session</button></div></aside></section>
  </main>
  <dialog id="cardDialog"><form id="cardForm" class="modal" method="dialog"><div class="modal-header"><h2 id="dialogTitle">Add a flashcard</h2><button id="closeDialog" class="control" type="button">Close</button></div><div class="form-grid"><label>Prompt<input name="front" required placeholder="Question, term, or cue"></label><label>Answer<textarea name="back" required placeholder="Definition, explanation, or answer"></textarea></label><label>Image URL (optional)<input name="imageUrl" type="url" placeholder="https://example.com/image.jpg"></label><label>Or choose an image (optional)<input name="imageFile" type="file" accept="image/*"></label></div><div class="modal-actions"><button class="control" type="button" id="cancelDialog">Cancel</button><button id="saveCard" class="control primary" type="submit">Add card</button></div></form></dialog>
  <script id="seedCards" type="application/json">{cards_json}</script>
  <script>
    (() => {{
      const storageKey = 'recall-deck-custom-cards', stateKey = 'recall-deck-session';
      const seedCards = JSON.parse(document.getElementById('seedCards').textContent);
      const getCustomCards = () => {{ try {{ return JSON.parse(localStorage.getItem(storageKey)) || []; }} catch {{ return []; }} }};
      let cards = [...seedCards, ...getCustomCards()], index = 0, reviewed = 0, mastered = 0, answerFirst = false, editingId = null;
      const flashcard = document.getElementById('flashcard'), frontText = document.getElementById('frontText'), backText = document.getElementById('backText'), frontImage = document.getElementById('frontImage'), backImage = document.getElementById('backImage'), ratings = document.getElementById('ratings'), dialog = document.getElementById('cardDialog');
      const updateImage = (image, url, alt) => {{ image.hidden = !url; image.src = url || ''; image.alt = alt || ''; }};
      const saveSession = () => localStorage.setItem(stateKey, JSON.stringify({{ reviewed, mastered }}));
      const render = () => {{ const card = cards[index]; document.getElementById('deckCount').textContent = cards.length; document.getElementById('studyArea').hidden = !card; document.getElementById('emptyState').style.display = card ? 'none' : 'block'; if (!card) return; flashcard.classList.toggle('is-flipped', answerFirst); ratings.hidden = !answerFirst; document.getElementById('flip').textContent = answerFirst ? 'Show prompt' : 'Reveal answer'; frontText.textContent = card.front; backText.textContent = card.back; document.getElementById('frontSource').textContent = card.source || 'Personal card'; updateImage(frontImage, card.image, card.front); updateImage(backImage, card.image, card.front); document.getElementById('frontContent').classList.toggle('solo', !card.image); document.getElementById('backContent').classList.toggle('solo', !card.image); document.getElementById('position').textContent = `Card ${{index + 1}} of ${{cards.length}}`; document.getElementById('progressFill').style.width = `${{((index + 1) / cards.length) * 100}}%`; document.getElementById('deckLabel').textContent = card.source || 'Personal card'; }};
      const flip = () => {{ if (!cards.length) return; const showingAnswer = flashcard.classList.toggle('is-flipped'); document.getElementById('flip').textContent = showingAnswer ? 'Show prompt' : 'Reveal answer'; ratings.hidden = !showingAnswer; }};
      const move = amount => {{ if (!cards.length) return; index = (index + amount + cards.length) % cards.length; render(); document.getElementById('flip').textContent = 'Reveal answer'; }};
      const restore = () => {{ try {{ const saved = JSON.parse(localStorage.getItem(stateKey)); reviewed = saved?.reviewed || 0; mastered = saved?.mastered || 0; }} catch {{}} document.getElementById('reviewed').textContent = reviewed; document.getElementById('mastered').textContent = mastered; }};
      document.getElementById('flip').addEventListener('click', flip); flashcard.addEventListener('click', flip); document.getElementById('previous').addEventListener('click', () => move(-1)); document.getElementById('next').addEventListener('click', () => move(1)); document.getElementById('shuffle').addEventListener('click', () => {{ for (let cardIndex = cards.length - 1; cardIndex > 0; cardIndex--) {{ const pick = Math.floor(Math.random() * (cardIndex + 1)); [cards[cardIndex], cards[pick]] = [cards[pick], cards[cardIndex]]; }} index = 0; render(); }}); document.getElementById('answerFirst').addEventListener('click', () => {{ answerFirst = !answerFirst; document.getElementById('answerFirst').textContent = answerFirst ? 'Start with prompt' : 'Start with answer'; render(); }});
      ratings.addEventListener('click', event => {{ const rating = event.target.dataset.rating; if (!rating) return; reviewed++; if (rating === 'got-it') mastered++; document.getElementById('reviewed').textContent = reviewed; document.getElementById('mastered').textContent = mastered; saveSession(); move(1); }}); document.getElementById('resetProgress').addEventListener('click', () => {{ reviewed = 0; mastered = 0; saveSession(); restore(); }}); document.getElementById('addCard').addEventListener('click', () => {{ editingId = null; document.getElementById('dialogTitle').textContent = 'Add a flashcard'; document.getElementById('saveCard').textContent = 'Add card'; document.getElementById('cardForm').reset(); dialog.showModal(); }}); document.getElementById('editCard').addEventListener('click', () => {{ const card = cards[index]; if (!card) return; if (card.source === 'Sigil deck') {{ window.location.href = `/sigil-deck/card/${{card.id}}`; return; }} editingId = card.id; const form = document.getElementById('cardForm'); form.elements.front.value = card.front; form.elements.back.value = card.back; form.elements.imageUrl.value = card.image || ''; document.getElementById('dialogTitle').textContent = 'Edit personal card'; document.getElementById('saveCard').textContent = 'Save changes'; dialog.showModal(); }}); document.getElementById('deleteCard').addEventListener('click', () => {{ const card = cards[index]; if (!card) return; if (card.source === 'Sigil deck') {{ window.location.href = `/sigil-deck/card/${{card.id}}`; return; }} if (!confirm('Delete this personal card?')) return; const custom = getCustomCards().filter(customCard => customCard.id !== card.id); localStorage.setItem(storageKey, JSON.stringify(custom)); cards = [...seedCards, ...custom]; index = Math.max(0, Math.min(index, cards.length - 1)); render(); }}); document.getElementById('closeDialog').addEventListener('click', () => dialog.close()); document.getElementById('cancelDialog').addEventListener('click', () => dialog.close());
      document.getElementById('cardForm').addEventListener('submit', event => {{ event.preventDefault(); const form = new FormData(event.currentTarget), file = form.get('imageFile'); const save = image => {{ const custom = getCustomCards(), card = {{ id: editingId || `custom-${{Date.now()}}`, front: form.get('front').trim(), back: form.get('back').trim(), image, source: 'Personal card' }}; const cardIndex = custom.findIndex(customCard => customCard.id === editingId); if (cardIndex >= 0) custom[cardIndex] = card; else custom.push(card); localStorage.setItem(storageKey, JSON.stringify(custom)); cards = [...seedCards, ...custom]; index = cards.findIndex(currentCard => currentCard.id === card.id); editingId = null; dialog.close(); event.currentTarget.reset(); render(); }}; if (file?.size) {{ const reader = new FileReader(); reader.onload = () => save(reader.result); reader.readAsDataURL(file); }} else {{ save(form.get('imageUrl').trim()); }} }});
      document.addEventListener('keydown', event => {{ if (dialog.open || event.target.matches('input, textarea')) return; if (event.key === ' ' || event.key === 'Enter') {{ event.preventDefault(); flip(); }} if (event.key === 'ArrowRight') move(1); if (event.key === 'ArrowLeft') move(-1); }}); restore(); render();
    }})();
  </script>
</body>
</html>"##,
        cards_json = cards_json,
    )
}

fn save_sigil_deck_entries(entries: &[SigilDeckEntry]) -> tide::Result<()> {
    sigil_deck_ensure_storage()?;
    let db = SigilDeckDb {
        entries: entries.to_vec(),
    };
    let raw = serde_json::to_string_pretty(&db)
        .map_err(|e| tide::Error::from_str(tide::StatusCode::InternalServerError, e.to_string()))?;
    std::fs::write(SIGIL_DECK_DB_PATH, raw)
        .map_err(|e| tide::Error::from_str(tide::StatusCode::InternalServerError, e.to_string()))?;
    Ok(())
}

fn sigil_mime_from_ext(ext: &str) -> &'static str {
    match ext {
        "jpg" | "jpeg" => "image/jpeg",
        "png" => "image/png",
        "gif" => "image/gif",
        "webp" => "image/webp",
        "bmp" => "image/bmp",
        _ => "application/octet-stream",
    }
}

fn sigil_ext_from_format(format: image::ImageFormat) -> Option<&'static str> {
    match format {
        image::ImageFormat::Jpeg => Some("jpg"),
        image::ImageFormat::Png => Some("png"),
        image::ImageFormat::Gif => Some("gif"),
        image::ImageFormat::WebP => Some("webp"),
        image::ImageFormat::Bmp => Some("bmp"),
        _ => None,
    }
}

  fn sigil_normalize_image(data: &[u8]) -> tide::Result<(Vec<u8>, &'static str)> {
    if data.is_empty() {
      return Err(tide::Error::from_str(
        tide::StatusCode::BadRequest,
        "sigil image cannot be empty",
      ));
    }

    let image = image::load_from_memory(data)
      .map_err(|e| tide::Error::from_str(tide::StatusCode::BadRequest, e.to_string()))?;
    let format = image::guess_format(data)
      .map_err(|e| tide::Error::from_str(tide::StatusCode::BadRequest, e.to_string()))?;
    let ext = sigil_ext_from_format(format)
      .ok_or_else(|| tide::Error::from_str(tide::StatusCode::BadRequest, "unsupported image type"))?;
    let (width, height) = image.dimensions();

    if width <= SIGIL_DECK_MAX_IMAGE_SIDE && height <= SIGIL_DECK_MAX_IMAGE_SIDE {
      return Ok((data.to_vec(), ext));
    }

    let resized = image.resize(
      SIGIL_DECK_MAX_IMAGE_SIDE,
      SIGIL_DECK_MAX_IMAGE_SIDE,
      image::imageops::FilterType::Lanczos3,
    );
    let output_format = if format == image::ImageFormat::Gif {
      image::ImageFormat::Png
    } else {
      format
    };
    let output_ext = sigil_ext_from_format(output_format)
      .ok_or_else(|| tide::Error::from_str(tide::StatusCode::BadRequest, "unsupported image type"))?;
    let mut output = std::io::Cursor::new(Vec::new());
    resized
      .write_to(&mut output, output_format)
      .map_err(|e| tide::Error::from_str(tide::StatusCode::BadRequest, e.to_string()))?;
    Ok((output.into_inner(), output_ext))
  }

  async fn download_sigil_image(image_url: &str) -> tide::Result<Vec<u8>> {
    let parsed = url::Url::parse(image_url)
      .map_err(|_| tide::Error::from_str(tide::StatusCode::BadRequest, "invalid image URL"))?;
    if !matches!(parsed.scheme(), "http" | "https") || parsed.host_str().is_none() {
      return Err(tide::Error::from_str(
        tide::StatusCode::BadRequest,
        "image URL must use http or https",
      ));
    }

    let mut response = surf::get(parsed.as_str())
      .await
      .map_err(|e| tide::Error::from_str(tide::StatusCode::BadGateway, e.to_string()))?;
    if !response.status().is_success() {
      return Err(tide::Error::from_str(
        tide::StatusCode::BadGateway,
        format!("image URL returned {}", response.status()),
      ));
    }
    let data = response
      .body_bytes()
      .await
      .map_err(|e| tide::Error::from_str(tide::StatusCode::BadGateway, e.to_string()))?;
    Ok(data)
  }

fn find_subslice(haystack: &[u8], needle: &[u8]) -> Option<usize> {
    if needle.is_empty() || haystack.len() < needle.len() {
        return None;
    }
    haystack.windows(needle.len()).position(|window| window == needle)
}

fn split_by_slice<'a>(haystack: &'a [u8], sep: &[u8]) -> Vec<&'a [u8]> {
    let mut out = Vec::new();
    let mut start = 0usize;
    while let Some(pos) = find_subslice(&haystack[start..], sep) {
        let at = start + pos;
        out.push(&haystack[start..at]);
        start = at + sep.len();
    }
    out.push(&haystack[start..]);
    out
}

fn extract_disposition_attr(disposition: &str, key: &str) -> Option<String> {
    let pattern = format!("{}=\"", key);
    let start = disposition.find(&pattern)? + pattern.len();
    let rest = &disposition[start..];
    let end = rest.find('"')?;
    Some(rest[..end].to_string())
}

fn parse_multipart_form_data(
    content_type: &str,
    body: &[u8],
) -> (std::collections::HashMap<String, String>, std::collections::HashMap<String, MultipartFile>) {
    let mut fields = std::collections::HashMap::new();
    let mut files = std::collections::HashMap::new();

    let boundary = content_type
        .split(';')
        .find_map(|part| {
            let trimmed = part.trim();
            trimmed
                .strip_prefix("boundary=")
                .map(|value| value.trim_matches('"').to_string())
        })
        .unwrap_or_default();

    if boundary.is_empty() {
        return (fields, files);
    }

    let marker = format!("--{}", boundary);
    for mut part in split_by_slice(body, marker.as_bytes()) {
        if part.is_empty() {
            continue;
        }
        if part.starts_with(b"\r\n") {
            part = &part[2..];
        }
        if part == b"--" || part == b"--\r\n" {
            continue;
        }
        if part.ends_with(b"\r\n") {
            part = &part[..part.len().saturating_sub(2)];
        }
        if part.ends_with(b"--") {
            part = &part[..part.len().saturating_sub(2)];
        }

        let Some(header_end) = find_subslice(part, b"\r\n\r\n") else {
            continue;
        };
        let header_bytes = &part[..header_end];
        let mut data = part[header_end + 4..].to_vec();
        while data.ends_with(b"\r") || data.ends_with(b"\n") {
            data.pop();
        }

        let headers = String::from_utf8_lossy(header_bytes);
        let mut name = None::<String>;
        let mut filename = None::<String>;
        let mut part_content_type = None::<String>;

        for line in headers.lines() {
            let lower = line.to_ascii_lowercase();
            if lower.starts_with("content-disposition:") {
                name = extract_disposition_attr(line, "name");
                filename = extract_disposition_attr(line, "filename");
            } else if lower.starts_with("content-type:") {
                part_content_type = line
                    .split_once(':')
                    .map(|(_, value)| value.trim().to_string())
                    .filter(|value| !value.is_empty());
            }
        }

        let Some(name) = name else {
            continue;
        };

        if let Some(filename) = filename {
            files.insert(
                name,
                MultipartFile {
                    filename,
                    content_type: part_content_type,
                    data,
                },
            );
        } else {
            fields.insert(name, String::from_utf8_lossy(&data).trim().to_string());
        }
    }

    (fields, files)
}

fn render_sigil_deck_page(entries: &[SigilDeckEntry]) -> String {
    let mut cards = String::new();
    if entries.is_empty() {
        cards.push_str(
            r#"<section class="empty-state"><h2>No sigils in the deck yet.</h2><p>Upload the first image to seed the tarot deck.</p></section>"#,
        );
    } else {
        for entry in entries {
            let image_src = format!("/sigil-deck/image/{}", entry.image_file);
            let _ = std::fmt::Write::write_fmt(
                &mut cards,
                format_args!(
                    r#"<a class="card" href="/sigil-deck/card/{id}">
  <img src="{image_src}" alt="{title}">
  <div class="card-body">
    <h2>{title}</h2>
    <p>{description}</p>
    <span class="meta">Drawn {created_at}</span>
  </div>
</a>"#,
                    id = entry.id,
                    image_src = image_src,
                    title = escape_html(&entry.title),
                    description = escape_html(&entry.description),
                    created_at = escape_html(&entry.created_at),
                ),
            );
        }
    }

    format!(
      r##"<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Sigil Tarot Deck</title>
  <style>
    :root {{
      color-scheme: dark;
      --bg: #0e0c12;
      --panel: rgba(19, 17, 26, 0.86);
      --panel-strong: #1e1a29;
      --text: #f4efe6;
      --muted: #b7ad9e;
      --line: rgba(255, 241, 214, 0.12);
      --gold: #e8c06a;
      --gold-strong: #ffd98a;
      --teal: #7ed9c4;
      --shadow: 0 30px 80px rgba(0, 0, 0, 0.45);
    }}

    * {{ box-sizing: border-box; }}
    html {{ scroll-behavior: smooth; }}
    body {{
      margin: 0;
      min-height: 100vh;
      color: var(--text);
      background:
        radial-gradient(circle at top left, rgba(126, 217, 196, 0.16), transparent 28%),
        radial-gradient(circle at top right, rgba(232, 192, 106, 0.18), transparent 24%),
        linear-gradient(180deg, #17131d 0%, #0e0c12 42%, #09070b 100%);
      font-family: Georgia, 'Times New Roman', serif;
    }}

    .wrap {{
      width: min(1120px, calc(100% - 24px));
      margin: 0 auto;
      padding: 18px 0 48px;
    }}

    .hero {{
      position: relative;
      overflow: hidden;
      padding: 24px;
      border: 1px solid var(--line);
      border-radius: 28px;
      background: linear-gradient(180deg, rgba(25, 21, 32, 0.96), rgba(16, 14, 22, 0.92));
      box-shadow: var(--shadow);
    }}

    .hero::after {{
      content: '';
      position: absolute;
      inset: auto -10% -35% auto;
      width: 280px;
      height: 280px;
      border-radius: 50%;
      background: radial-gradient(circle, rgba(232, 192, 106, 0.24), transparent 68%);
      pointer-events: none;
    }}

    .eyebrow {{
      margin: 0 0 10px;
      color: var(--gold-strong);
      text-transform: uppercase;
      letter-spacing: 0.22em;
      font-size: 0.74rem;
    }}

    h1 {{
      margin: 0;
      font-size: clamp(2rem, 4vw, 4rem);
      line-height: 0.96;
      max-width: 12ch;
    }}

    .lede {{
      max-width: 62ch;
      color: var(--muted);
      font-size: 1.03rem;
      line-height: 1.6;
      margin: 14px 0 0;
    }}

    .actions {{
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
      margin-top: 20px;
    }}

    .button {{
      display: inline-flex;
      align-items: center;
      justify-content: center;
      min-height: 46px;
      padding: 0 18px;
      border-radius: 999px;
      border: 1px solid rgba(255, 241, 214, 0.18);
      color: var(--text);
      text-decoration: none;
      background: rgba(255, 255, 255, 0.03);
      transition: transform 0.18s ease, border-color 0.18s ease, background 0.18s ease;
    }}

    .button.primary {{
      background: linear-gradient(135deg, var(--gold), #a67528);
      color: #181106;
      font-weight: 700;
      border-color: transparent;
    }}

    .button:hover {{ transform: translateY(-1px); border-color: rgba(255, 217, 138, 0.5); }}

    .upload {{
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 14px;
      margin-top: 22px;
      padding-top: 22px;
      border-top: 1px solid var(--line);
    }}

    .field {{ display: grid; gap: 8px; }}
    .field.full {{ grid-column: 1 / -1; }}
    label {{ color: var(--muted); font-size: 0.92rem; }}
    input, textarea {{
      width: 100%;
      border-radius: 16px;
      border: 1px solid rgba(255, 241, 214, 0.12);
      background: rgba(255, 255, 255, 0.04);
      color: var(--text);
      padding: 14px 14px;
      font: inherit;
    }}
    textarea {{ min-height: 120px; resize: vertical; }}
    input[type="file"] {{ padding: 12px; }}

    .upload button {{
      grid-column: 1 / -1;
      min-height: 48px;
      border: 0;
      border-radius: 16px;
      background: linear-gradient(135deg, var(--teal), #4e8f86);
      color: #08110f;
      font: inherit;
      font-weight: 800;
    }}

    .section {{ margin-top: 20px; }}
    .section h2 {{ margin: 0 0 12px; font-size: 1.2rem; }}
    .section p {{ margin: 0 0 16px; color: var(--muted); }}

    .grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 14px;
    }}

    .card {{
      display: block;
      overflow: hidden;
      border-radius: 22px;
      border: 1px solid var(--line);
      background: var(--panel);
      color: var(--text);
      text-decoration: none;
      box-shadow: var(--shadow);
      min-height: 100%;
    }}

    .card img {{
      display: block;
      width: 100%;
      aspect-ratio: 4 / 5;
      object-fit: contain;
      background: var(--panel-strong);
    }}

    .card-body {{ padding: 14px; }}
    .card-body h2 {{ margin: 0 0 8px; font-size: 1.03rem; }}
    .card-body p {{ margin: 0 0 10px; color: var(--muted); line-height: 1.5; font-size: 0.96rem; }}
    .meta {{ color: rgba(244, 239, 230, 0.7); font-size: 0.82rem; letter-spacing: 0.03em; }}

    .empty-state {{
      padding: 22px;
      border-radius: 22px;
      border: 1px dashed rgba(255, 241, 214, 0.18);
      background: rgba(255, 255, 255, 0.03);
    }}

    @media (max-width: 720px) {{
      .wrap {{ width: min(100% - 16px, 1120px); padding-top: 10px; }}
      .hero {{ padding: 18px; border-radius: 22px; }}
      .upload {{ grid-template-columns: 1fr; }}
      .field.full {{ grid-column: auto; }}
      .grid {{ grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); }}
      h1 {{ max-width: 100%; }}
    }}
  </style>
</head>
<body>
  <div class="wrap">
    <section class="hero">
      <p class="eyebrow">Sigil Tarot Deck</p>
      <h1>Draw a sigil for the game.</h1>
      <p class="lede">Upload an image, write its meaning, and keep the deck in one scrollable gallery. Tap random to pull a card from the stack, or browse the collection below.</p>
      <div class="actions">
        <a class="button primary" href="/sigil-deck/random">Draw Random Card</a>
        <a class="button" href="#deck">Browse Deck</a>
      </div>
      <form class="upload" method="post" action="/sigil-deck/upload" enctype="multipart/form-data">
        <div class="field full">
          <label for="image">Image file</label>
          <input id="image" type="file" name="image" accept="image/*">
        </div>
        <div class="field full">
          <label for="image_url">Or image URL</label>
          <input id="image_url" type="url" name="image_url" placeholder="https://example.com/sigil.jpg">
        </div>
        <div class="field">
          <label for="title">Title</label>
          <input id="title" type="text" name="title" placeholder="Sigil name" required>
        </div>
        <div class="field">
          <label for="description">Description</label>
          <textarea id="description" name="description" placeholder="Meaning, effect, lore, or gameplay trigger."></textarea>
        </div>
        <button type="submit">Save to Deck</button>
      </form>
    </section>

    <section class="section" id="deck">
      <h2>Deck Selection</h2>
      <p>Scroll through the cards or draw one at random for play.</p>
      <div class="grid">
        {cards}
      </div>
    </section>
  </div>
</body>
</html>"##,
        cards = cards
    )
}

fn render_sigil_card_page(entry: &SigilDeckEntry, deck_size: usize) -> String {
    let image_src = format!("/sigil-deck/image/{}", entry.image_file);
    format!(
      r##"<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{title} - Sigil Tarot Deck</title>
  <style>
    :root {{
      color-scheme: dark;
      --panel: rgba(19, 17, 26, 0.86);
      --text: #f4efe6;
      --muted: #b7ad9e;
      --line: rgba(255, 241, 214, 0.12);
      --gold: #e8c06a;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      min-height: 100vh;
      padding: 16px;
      color: var(--text);
      background: linear-gradient(180deg, #17131d 0%, #0e0c12 100%);
      font-family: Georgia, 'Times New Roman', serif;
    }}
    .shell {{ width: min(920px, 100%); margin: 0 auto; }}
    .panel {{
      padding: 18px;
      border-radius: 26px;
      border: 1px solid var(--line);
      background: var(--panel);
      box-shadow: 0 30px 80px rgba(0, 0, 0, 0.45);
    }}
    img {{ width: 100%; display: block; border-radius: 20px; aspect-ratio: 4 / 5; object-fit: contain; background: #1a1621; }}
    h1 {{ margin: 16px 0 10px; font-size: clamp(1.8rem, 4vw, 3rem); }}
    p {{ color: var(--muted); line-height: 1.6; }}
    .meta {{ display: grid; gap: 10px; margin-top: 12px; }}
    .actions {{ display: flex; flex-wrap: wrap; gap: 12px; margin-top: 18px; }}
    .manage {{ display: grid; gap: 12px; margin-top: 24px; padding-top: 20px; border-top: 1px solid var(--line); }}
    .manage h2 {{ margin: 0; font-size: 1.2rem; }}
    .field {{ display: grid; gap: 7px; }}
    label {{ color: var(--muted); font-size: 0.92rem; }}
    input, textarea {{ width: 100%; border: 1px solid var(--line); border-radius: 10px; background: rgba(255, 255, 255, 0.05); color: var(--text); padding: 10px 12px; font: inherit; }}
    textarea {{ min-height: 110px; resize: vertical; }}
    button {{ min-height: 42px; border: 1px solid var(--line); border-radius: 10px; padding: 0 14px; background: var(--gold); color: #181106; font: inherit; font-weight: 700; cursor: pointer; }}
    .delete button {{ background: #a64c48; color: #fff7f4; }}
    a {{
      display: inline-flex;
      align-items: center;
      justify-content: center;
      min-height: 46px;
      padding: 0 18px;
      border-radius: 999px;
      border: 1px solid rgba(255, 241, 214, 0.18);
      color: var(--text);
      text-decoration: none;
      background: rgba(255, 255, 255, 0.03);
    }}
    .primary {{ background: linear-gradient(135deg, var(--gold), #a67528); color: #181106; font-weight: 700; border-color: transparent; }}
  </style>
</head>
<body>
  <div class="shell">
    <section class="panel">
      <img src="{image_src}" alt="{title}">
      <h1>{title}</h1>
      <p>{description}</p>
      <div class="meta">
        <p>Deck size: {deck_size}</p>
        <p>Created: {created_at}</p>
      </div>
      <div class="actions">
        <a class="primary" href="/sigil-deck/random">Draw Another</a>
        <a href="/sigil-deck">Back to Deck</a>
      </div>
      <form class="manage" method="post" action="/sigil-deck/card/{id}/update" enctype="multipart/form-data">
        <h2>Edit Sigil</h2>
        <div class="field">
          <label for="title">Title</label>
          <input id="title" type="text" name="title" value="{title}" required>
        </div>
        <div class="field">
          <label for="description">Description</label>
          <textarea id="description" name="description">{description}</textarea>
        </div>
        <div class="field">
          <label for="image">Replace image</label>
          <input id="image" type="file" name="image" accept="image/*">
        </div>
        <div class="field">
          <label for="image_url">Or replace from image URL</label>
          <input id="image_url" type="url" name="image_url" placeholder="https://example.com/sigil.jpg">
        </div>
        <button type="submit">Update Sigil</button>
      </form>
      <form class="delete" method="post" action="/sigil-deck/card/{id}/delete">
        <button type="submit">Delete Sigil</button>
      </form>
    </section>
  </div>
</body>
</html>"##,
        title = escape_html(&entry.title),
        description = escape_html(&entry.description),
        created_at = escape_html(&entry.created_at),
        image_src = image_src,
        id = entry.id,
        deck_size = deck_size,
    )
}

use anyhow::Result;
use image::{DynamicImage, GenericImageView};
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
    mount_ollama_routes(&mut app, OllamaRelayConfig::default())?;

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
            let escaped_target_url = target_url
              .replace('&', "&amp;")
              .replace('"', "&quot;")
              .replace('<', "&lt;")
              .replace('>', "&gt;");

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
                escaped_target_url
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



   app.at("/random").get(|mut req: tide::Request<AppState>| async move {


    let mut res = tide::Response::new(tide::StatusCode::Ok);
    use rand::Rng;
    let mut rng = rand::thread_rng();
    let random_value: u32 = rng.gen_range(0..2);
    let output = random_value.to_string();

     // Return the HTML response.
    let mut res = tide::Response::new(tide::StatusCode::Ok);
    res.set_body(output);
    res.insert_header("Content-Type", "text/plain; charset=utf-8");
    Ok(res)
    //Ok(output.into())
  });


     app.at("/random2").get(|mut req: tide::Request<AppState>| async move {


    use rand::Rng;
    let mut rng = rand::thread_rng();
    let output = match rng.gen_range(0..3) {
      0 => "1/2",
      1 => "1/1",
      _ => "3/2",
    };

     // Return the HTML response.
    let mut res = tide::Response::new(tide::StatusCode::Ok);
    res.set_body(output);
    res.insert_header("Content-Type", "text/plain; charset=utf-8");
    Ok(res)
    //Ok(output.into())
  });


    app.at("/sigil-deck").get(|_| async move {
      let entries = load_sigil_deck_entries()?;
      let mut res = tide::Response::new(tide::StatusCode::Ok);
      res.set_body(render_sigil_deck_page(&entries));
      res.insert_header("Content-Type", "text/html; charset=utf-8");
      Ok(res)
    });

    app.at("/flashcard").get(|_| async move {
      let entries = load_sigil_deck_entries()?;
      let mut res = tide::Response::new(tide::StatusCode::Ok);
      res.set_body(render_flashcard_page(&entries));
      res.insert_header("Content-Type", "text/html; charset=utf-8");
      Ok(res)
    });

    app.at("/sigil-deck/upload").post(|mut req: tide::Request<AppState>| async move {
      let content_type = req
        .header("content-type")
        .and_then(|values| values.get(0))
        .map(|value| value.as_str().to_string())
        .unwrap_or_default();

      if !content_type.contains("multipart/form-data") {
        return Ok(tide::Response::new(tide::StatusCode::BadRequest));
      }

      let raw = req.body_bytes().await?;
      let (fields, files) = parse_multipart_form_data(&content_type, &raw);
      let title = fields
        .get("title")
        .cloned()
        .unwrap_or_else(|| "Untitled Sigil".to_string());
      let description = fields
        .get("description")
        .cloned()
        .unwrap_or_else(|| "No description provided yet.".to_string());
      let image_data = match fields.get("image_url").map(String::as_str).map(str::trim) {
        Some(image_url) if !image_url.is_empty() => download_sigil_image(image_url).await?,
        _ => {
          let Some(upload) = files.get("image").cloned().or_else(|| files.values().next().cloned()) else {
            return Ok(tide::Response::new(tide::StatusCode::BadRequest));
          };
          upload.data
        }
      };
      let (image_data, ext) = sigil_normalize_image(&image_data)?;

      sigil_deck_ensure_storage()?;
      let mut entries = load_sigil_deck_entries()?;
      let next_id = entries
        .iter()
        .map(|entry| entry.id)
        .max()
        .unwrap_or(0)
        .saturating_add(1);
      let filename = format!("sigil_{}_{}.{}", next_id, Utc::now().timestamp_millis(), ext);
      let path = format!("{}/{}", SIGIL_DECK_UPLOAD_DIR, filename);
      std::fs::write(&path, &image_data)
        .map_err(|e| tide::Error::from_str(tide::StatusCode::InternalServerError, e.to_string()))?;

      entries.push(SigilDeckEntry {
        id: next_id,
        title,
        description,
        image_file: filename.clone(),
        mime_type: sigil_mime_from_ext(ext).to_string(),
        created_at: sigil_deck_now_string(),
      });
      save_sigil_deck_entries(&entries)?;

      Ok(redirect(&format!("/sigil-deck/card/{}", next_id)))
    });

    app.at("/sigil-deck/card/:id/update").post(|mut req: tide::Request<AppState>| async move {
      let id: u64 = req.param("id").unwrap_or("0").parse().unwrap_or(0);
      let content_type = req
        .header("content-type")
        .and_then(|values| values.get(0))
        .map(|value| value.as_str().to_string())
        .unwrap_or_default();
      if !content_type.contains("multipart/form-data") {
        return Ok(tide::Response::new(tide::StatusCode::BadRequest));
      }

      let raw = req.body_bytes().await?;
      let (fields, files) = parse_multipart_form_data(&content_type, &raw);
      let mut entries = load_sigil_deck_entries()?;
      let Some(entry_index) = entries.iter().position(|entry| entry.id == id) else {
        return Ok(tide::Response::new(tide::StatusCode::NotFound));
      };
      let entry = &mut entries[entry_index];
      entry.title = fields.get("title").cloned().unwrap_or_else(|| entry.title.clone());
      entry.description = fields
        .get("description")
        .cloned()
        .unwrap_or_else(|| entry.description.clone());

      let mut old_image_path = None;
      let replacement_data = match fields.get("image_url").map(String::as_str).map(str::trim) {
        Some(image_url) if !image_url.is_empty() => Some(download_sigil_image(image_url).await?),
        _ => files.get("image").filter(|file| !file.data.is_empty()).map(|file| file.data.clone()),
      };
      if let Some(replacement_data) = replacement_data {
        let (replacement_data, ext) = sigil_normalize_image(&replacement_data)?;
        let filename = format!("sigil_{}_{}.{}", id, Utc::now().timestamp_millis(), ext);
        let new_image_path = sigil_deck_upload_path(&filename)?;
        std::fs::write(&new_image_path, &replacement_data)
          .map_err(|e| tide::Error::from_str(tide::StatusCode::InternalServerError, e.to_string()))?;
        old_image_path = Some(sigil_deck_upload_path(&entry.image_file)?);
        entry.image_file = filename;
        entry.mime_type = sigil_mime_from_ext(ext).to_string();
      }

      save_sigil_deck_entries(&entries)?;
      if let Some(path) = old_image_path {
        std::fs::remove_file(path)
          .map_err(|e| tide::Error::from_str(tide::StatusCode::InternalServerError, e.to_string()))?;
      }
      Ok(redirect(&format!("/sigil-deck/card/{}", id)))
    });

    app.at("/sigil-deck/card/:id/delete").post(|req: tide::Request<AppState>| async move {
      let id: u64 = req.param("id").unwrap_or("0").parse().unwrap_or(0);
      let mut entries = load_sigil_deck_entries()?;
      let Some(entry_index) = entries.iter().position(|entry| entry.id == id) else {
        return Ok(tide::Response::new(tide::StatusCode::NotFound));
      };
      let entry = entries.remove(entry_index);
      let image_path = sigil_deck_upload_path(&entry.image_file)?;
      std::fs::remove_file(image_path).map_err(|err| match err.kind() {
        std::io::ErrorKind::NotFound => tide::Error::from_str(tide::StatusCode::NotFound, "sigil image not found"),
        _ => tide::Error::from_str(tide::StatusCode::InternalServerError, err.to_string()),
      })?;
      save_sigil_deck_entries(&entries)?;
      Ok(redirect("/sigil-deck"))
    });

    app.at("/sigil-deck/image/:filename").get(|req: tide::Request<AppState>| async move {
      let filename = req.param("filename").unwrap_or("");
      let safe_name = std::path::Path::new(filename)
        .file_name()
        .and_then(|part| part.to_str())
        .unwrap_or("");
      if safe_name.is_empty() {
        return Ok(tide::Response::new(tide::StatusCode::BadRequest));
      }

      let path = format!("{}/{}", SIGIL_DECK_UPLOAD_DIR, safe_name);
      let bytes = match std::fs::read(&path) {
        Ok(bytes) => bytes,
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => {
          return Ok(tide::Response::new(tide::StatusCode::NotFound));
        }
        Err(err) => {
          return Err(tide::Error::from_str(
            tide::StatusCode::InternalServerError,
            err.to_string(),
          ));
        }
      };

      let ext = std::path::Path::new(safe_name)
        .extension()
        .and_then(|value| value.to_str())
        .unwrap_or("bin");
      let mut res = tide::Response::new(tide::StatusCode::Ok);
      res.set_body(bytes);
      res.insert_header("Content-Type", sigil_mime_from_ext(ext));
      Ok(res)
    });

    app.at("/sigil-deck/card/:id").get(|req: tide::Request<AppState>| async move {
      let id: u64 = req.param("id").unwrap_or("0").parse().unwrap_or(0);
      let entries = load_sigil_deck_entries()?;
      let Some(entry) = entries.iter().find(|entry| entry.id == id).cloned() else {
        return Ok(tide::Response::new(tide::StatusCode::NotFound));
      };

      let mut res = tide::Response::new(tide::StatusCode::Ok);
      res.set_body(render_sigil_card_page(&entry, entries.len()));
      res.insert_header("Content-Type", "text/html; charset=utf-8");
      Ok(res)
    });

    app.at("/sigil-deck/random").get(|_| async move {
      let entries = load_sigil_deck_entries()?;
      if entries.is_empty() {
        let mut res = tide::Response::new(tide::StatusCode::Ok);
        res.set_body(render_sigil_deck_page(&entries));
        res.insert_header("Content-Type", "text/html; charset=utf-8");
        return Ok(res);
      }

      use rand::Rng;
      let index = rand::thread_rng().gen_range(0..entries.len());
      let entry = entries[index].clone();

      Ok(redirect(&format!("/sigil-deck/card/{}", entry.id)))
    });

    // Migrated endpoints are mounted by tiade_ollama_relay::mount_routes.

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

    app.at("/tiade/moon")
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

    app.at("/tiade/sun")
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

    app.at("/tiade/img/resize")
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
        let mut res = tide::Response::new(tide::StatusCode::Ok);        
        res.set_body("<!DOCTYPE html>\n<html>\n<head>\n  <title>Home</title>\n</head>\n<body>\n  <h1>Welcome</h1>\n</body>\n</html>".to_string());
      res.insert_header("Content-Type", "text/html; charset=utf-8");
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
