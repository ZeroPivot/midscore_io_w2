# tiade-maeepers-saerver-all

Tide-based Rust server that ports the Roda-era behavior and now uses LineDB-backed persistence.

## Version

- 1.0.0

## Highlights

- Roda compatibility routes for blog, gallery, admin, moon/sun, and image resize.
- LineDB integrated as the primary persistence backend.
- Blog and gallery state load/save through LineDB table mapping.
- Gallery image processing pipeline with derivative generation (original, thumbnail, resized).

## Persistence

This server uses the `partitioned_array_rust` crate with `LineDb` as top-level manager.

Default LineDB root:
- `/root/midscore_io/logs/tiade_roda_compat/line_db`

Fallback LineDB root:
- `/tmp/tiade_line_db`

State table mapping uses file stem naming:
- Blog store path -> `blog_store`
- Gallery store path -> `gallery_store`

## Admin Endpoints

- `GET /admin/login?password=...`
- `POST /admin/add` with form field `db_name`
- `GET /admin/remove/:db_name`
- `POST /admin/delete` with form field `db_name`
- `GET /admin/reload`
- `GET /admin/list`
- `POST /admin/rehash/:db_name`

## Route Matrix

Integration note:
- `src/main.rs` mounts `roda_tide_rewrite::mount_roda_compat_routes(&mut app)` last, so overlapping paths resolve to the Roda-compat handlers.
- `/` redirects to `/gallery`.
- Legacy Tiade overlap routes were namespaced to `/tiade/*`.

### Core and Static (Roda Compat)

| Method | Path | Source | Auth | Notes |
|---|---|---|---|---|
| GET | `/` | `src/roda_tide_rewrite.rs` | public | Redirects to `/gallery` |
| GET | `/assets/*path` | `src/roda_tide_rewrite.rs` | public | Serves project assets |
| GET | `/public/*path` | `src/roda_tide_rewrite.rs` | public | Serves public files |
| GET | `/card` | `src/roda_tide_rewrite.rs` | public | JPEG banner |
| GET | `/moon` | `src/roda_tide_rewrite.rs` | public | Text response |
| GET | `/sun` | `src/roda_tide_rewrite.rs` | public | Text response |
| POST | `/img/resize` | `src/roda_tide_rewrite.rs` | public | Image bytes resize endpoint |

### Admin (Roda Compat)

| Method | Path | Source | Auth | Notes |
|---|---|---|---|---|
| GET | `/admin/login` | `src/roda_tide_rewrite.rs` | public | `?password=` sets admin cookie on success |
| GET | `/admin` | `src/roda_tide_rewrite.rs` | admin cookie | Admin HTML dashboard |
| POST | `/admin/add` | `src/roda_tide_rewrite.rs` | admin cookie | Form field `db_name` |
| GET | `/admin/remove/:db_name` | `src/roda_tide_rewrite.rs` | admin cookie | Redirects back to admin |
| POST | `/admin/delete` | `src/roda_tide_rewrite.rs` | admin cookie | Form field `db_name` |
| GET | `/admin/reload` | `src/roda_tide_rewrite.rs` | admin cookie | Reload LineDB state |
| GET | `/admin/list` | `src/roda_tide_rewrite.rs` | admin cookie | JSON database listing |
| POST | `/admin/rehash/:db_name` | `src/roda_tide_rewrite.rs` | admin cookie | JSON rehash result |

### Blog (Roda Compat)

| Method | Path | Source | Auth | Notes |
|---|---|---|---|---|
| GET | `/blog` | `src/roda_tide_rewrite.rs` | public | Redirects to `/blog/login` |
| GET | `/blog/login` | `src/roda_tide_rewrite.rs` | public | HTML login form |
| POST | `/blog/login` | `src/roda_tide_rewrite.rs` | public | Requires `blog_user_name`, `blog_password_name`, `super_password` |
| GET | `/blog/logout` | `src/roda_tide_rewrite.rs` | session | Clears blog session cookie |
| GET | `/blog/signup` | `src/roda_tide_rewrite.rs` | public | HTML signup form |
| POST | `/blog/signup` | `src/roda_tide_rewrite.rs` | public | Creates user |
| GET | `/blog/render` | `src/roda_tide_rewrite.rs` | public | Render by query (`user`, `id`) |
| GET | `/blog/:user` | `src/roda_tide_rewrite.rs` | public | Redirects to `/blog/:user/view` |
| GET, POST | `/blog/:user/pin` | `src/roda_tide_rewrite.rs` | owner session | View or set pinned post |
| GET | `/blog/:user/tag/:tag` | `src/roda_tide_rewrite.rs` | public/private by profile | Tag filtered listing |
| GET, POST | `/blog/:user/edit/:id` | `src/roda_tide_rewrite.rs` | owner session | Edit post page and save |
| GET | `/blog/:user/delete` | `src/roda_tide_rewrite.rs` | public/private by profile | Delete/lock listing page |
| GET | `/blog/:user/delete/:id` | `src/roda_tide_rewrite.rs` | owner session | Toggle lock then redirect |
| GET | `/blog/:user/list` | `src/roda_tide_rewrite.rs` | public/private by profile | Post list |
| GET, POST | `/blog/:user/new` | `src/roda_tide_rewrite.rs` | owner session | New post page and save |
| GET | `/blog/:user/private_toggle` | `src/roda_tide_rewrite.rs` | owner session | Toggle private view |
| GET | `/blog/:user/view` | `src/roda_tide_rewrite.rs` | public/private by profile | Main blog index |
| GET | `/blog/:user/view/:id` | `src/roda_tide_rewrite.rs` | public/private by profile | Post view (`?format=json` supported) |
| GET | `/blog/:user/view/:month/:day/:year/:time` | `src/roda_tide_rewrite.rs` | public/private by profile | Date-based post lookup |

### Gallery (Roda Compat)

| Method | Path | Source | Auth | Notes |
|---|---|---|---|---|
| GET | `/gallery` | `src/roda_tide_rewrite.rs` | public | Gallery home/user list |
| GET, POST | `/gallery/secondlifeapi` | `src/roda_tide_rewrite.rs` | public | GET HTML, POST JSON echo/status |
| GET, POST | `/gallery/upload/url` | `src/roda_tide_rewrite.rs` | public | URL upload page and submit |
| GET, POST | `/gallery/upload` | `src/roda_tide_rewrite.rs` | public | Raw body or multipart file/url upload |
| GET | `/gallery/view/:user/latest` | `src/roda_tide_rewrite.rs` | public | Redirects to latest page index |
| GET | `/gallery/reset_session/:user` | `src/roda_tide_rewrite.rs` | public | Clears gallery preference cookies |
| GET | `/gallery/view/:user` | `src/roda_tide_rewrite.rs` | public/private by profile | Gallery index with cookie-backed prefs |
| GET | `/gallery/view/:user/id/:id` | `src/roda_tide_rewrite.rs` | public/private by profile | Single gallery item |
| GET | `/gallery/view/:user/id/:id/attachments` | `src/roda_tide_rewrite.rs` | public/private by profile | Attachment list |
| GET | `/gallery/view/:user/id/:id/attachments/delete/:attachment_id` | `src/roda_tide_rewrite.rs` | public/private by profile | Deletes attachment entry |
| GET, POST | `/gallery/view/:user/id/:id/attachments/upload` | `src/roda_tide_rewrite.rs` | public/private by profile | Form + multipart/url/value upload |
| GET | `/gallery/delete/:user/id/:id` | `src/roda_tide_rewrite.rs` | public/private by profile | Deletes post and files |
| GET | `/gallery/view/:user/tags/search` | `src/roda_tide_rewrite.rs` | public/private by profile | Include/exclude search (`search_tags`, `--tag`) |
| GET | `/gallery/view/:user/tags` | `src/roda_tide_rewrite.rs` | public/private by profile | Tag list page |
| GET, POST | `/gallery/edit/:user/id/:id` | `src/roda_tide_rewrite.rs` | public/private by profile | Edit gallery metadata |

### Gallery UWU/OWO (Roda Compat)

| Method | Path | Source | Auth | Notes |
|---|---|---|---|---|
| GET | `/gallery/uwu/view/:user` | `src/roda_tide_rewrite.rs` | public/private by profile | List collections |
| GET | `/gallery/uwu/view/:user/id/:id` | `src/roda_tide_rewrite.rs` | public/private by profile | View collection |
| GET | `/gallery/uwu/delete/id/:id` | `src/roda_tide_rewrite.rs` | session-dependent | Delete collection |
| GET, POST | `/gallery/uwu/new` | `src/roda_tide_rewrite.rs` | session-dependent | Create collection |
| POST | `/gallery/uwu/edit/id/:id` | `src/roda_tide_rewrite.rs` | session-dependent | Replace collection items |
| GET | `/gallery/uwu/delete_image/uwu_id/:uwu_id/gallery_id/:gallery_id` | `src/roda_tide_rewrite.rs` | session-dependent | Remove image from collection |
| POST | `/gallery/uwu/add_image/uwu_id/:uwu_id` | `src/roda_tide_rewrite.rs` | session-dependent | Add image to collection |
| GET | `/gallery/owo/add` | `src/roda_tide_rewrite.rs` | public | Increment counter |
| GET | `/gallery/owo/rem` | `src/roda_tide_rewrite.rs` | public | Decrement counter |
| GET | `/gallery/owo/sub` | `src/roda_tide_rewrite.rs` | public | Read counter |

### Tiade Main Server Routes (Legacy/Utility)

| Method | Path | Source | Notes |
|---|---|---|---|
| POST | `/praexy-saerver` | `src/main.rs` | Form relay utility |
| GET | `/bridge/*rest` | `src/main.rs` | iframe bridge page |
| GET | `/time` | `src/main.rs` | Ruby script output |
| GET | `/ae` | `src/main.rs` | Ruby script output |
| GET | `/weather` | `src/main.rs` | Ruby script output |
| GET | `/rneutrialg` | `src/main.rs` | Text file read |
| GET | `/rneutri` | `src/main.rs` | Text file write |
| GET | `/tiade/moon` | `src/main.rs` | Namespaced legacy moon endpoint |
| GET | `/tiade/sun` | `src/main.rs` | Namespaced legacy sun endpoint |
| GET | `/tiade-maepers/*rest` | `src/main.rs` | iframe bridge page |
| GET | `/parse_plink` | `src/main.rs` | URL parser redirect |
| POST | `/tiade/img/resize` | `src/main.rs` | Namespaced legacy placeholder resize |
| GET | `/` | `src/main.rs` | Redirects to `/gallery` |
| POST | `/echo` | `src/main.rs` | Echo body |
| POST | `/restart-servers` | `src/main.rs` | Process HUP command |
| POST | `/file/add` | `src/main.rs` | Writes `/tmp/new_file.txt` |
| DELETE | `/file/delete` | `src/main.rs` | Deletes `/tmp/new_file.txt` |

### Mounted Relay Routes (tiade_ollama_relay)

These are mounted by `mount_ollama_routes(&mut app, OllamaRelayConfig::default())`:

- `/chat/:team`
- `/history/:team`
- `/sl_logger`
- `/_ethereal_life_sl_logger_get_`
- `/_ethereal_life_sl_logger_show_`
- `/incrementor_get`
- `/incrementor`
- `/analytics`
- `/chatlog`
- `/schedule_ft`
- `/read`

## Run

```bash
cargo run
```

## Verify

```bash
cargo check
```

## Notes

`src/main.rs` currently contains pre-existing warnings unrelated to the LineDB migration layer in `src/roda_tide_rewrite.rs`.
