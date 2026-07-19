# YouTube Music support research

Research date: 2026-07-18

## Recommendation

Build the first release as **YouTube music-video search plus a first-party app
handoff**, not as a full playback-control provider:

1. Search public YouTube videos through the documented YouTube Data API v3,
   restricted to the region's Music video category.
2. Show video title, channel, duration, publication date, and YouTube thumbnail in
   Telescope, with the results clearly attributed to YouTube.
3. On selection, open the corresponding item in YouTube Music (with a regular
   YouTube watch URL as a configurable fallback).
4. Declare pause/resume/next/previous/queue/now-playing unsupported. Do not map
   those controls for this provider.

This is the narrowest slice that returns structured results inside Neovim while
remaining on documented Google surfaces. It is not a true YouTube Music catalog
API: the documented Data API models `video`, `channel`, and `playlist` search
results, not songs, albums, or YouTube Music playback sessions
([`search.list`](https://developers.google.com/youtube/v3/docs/search/list),
[Data API reference](https://developers.google.com/youtube/v3/docs)). The UI and
README should therefore say something precise such as **"search YouTube's music
video category and open results in YouTube Music"**, rather than claiming full
YouTube Music search or remote control.

If exact YouTube Music search quality matters more than displaying results in
Telescope, an even smaller alternative is to forward the query to the first-party
YouTube Music web app. Google documents that shared songs, albums, playlists, and
podcasts open in YouTube Music, but does not publish its web routes as a stable
developer API ([YouTube Music sharing help](https://support.google.com/youtubemusic/answer/9198182)).
That alternative should be treated as a web handoff, not an integration API.

## Official surface and its limits

### Structured discovery

The official public discovery surface is YouTube Data API v3. Every request needs
an API key or OAuth token; public-data requests can use an API key, while OAuth is
needed for private user data or modifying data
([API reference](https://developers.google.com/youtube/v3/docs),
[sample requests](https://developers.google.com/youtube/v3/sample_requests)). A
read-only first slice therefore needs only a user-supplied API key and no login.
The key should be sent in the `x-goog-api-key` header rather than the URL, limited
to the YouTube Data API, kept out of the repository, and never bundled as a shared
jam.nvim key ([Google Cloud API-key best practices](https://docs.cloud.google.com/docs/authentication/api-keys-best-practices)).

Suggested request flow:

1. Resolve and cache the region's category whose returned title is `Music` with
   `videoCategories.list`; category IDs are API data, so this avoids baking an
   undocumented assumption into the adapter
   ([video category reference](https://developers.google.com/youtube/v3/docs/videoCategories/list)).
2. Call `GET https://www.googleapis.com/youtube/v3/search` with
   `part=snippet`, `type=video`, `videoCategoryId=<music category>`, `q`,
   `maxResults`, and optional `regionCode`/`relevanceLanguage`. The API documents
   the category filter only for `type=video`; it can also restrict results to
   embeddable videos if a future embedded-player mode needs that
   ([`search.list`](https://developers.google.com/youtube/v3/docs/search/list)).
3. Batch the returned IDs into one `videos.list` request with
   `part=contentDetails,status` to obtain ISO-8601 duration, region restrictions,
   and embeddability. One call accepts a comma-separated ID list and costs one
   general quota unit
   ([`videos.list`](https://developers.google.com/youtube/v3/docs/videos/list),
   [`video` resource](https://developers.google.com/youtube/v3/docs/videos)).

The result remains a **music-category YouTube video**, which can include music
videos, art tracks, performances, and other music content. The public resource
does not expose a general song/album/artist entity model. It does expose useful
jam.nvim fields: ID, title, description, channel title, thumbnails, publication
time, duration, licensed-content flag, region restrictions, and embed status
([`video` resource](https://developers.google.com/youtube/v3/docs/videos)).

### Quota changes the picker design

As of this research date, `search.list` uses a separate Search Queries bucket:
each request costs one search-query unit and a default project receives **100
search calls per day**. `videos.list` remains a one-unit general read request
([`search.list`](https://developers.google.com/youtube/v3/docs/search/list),
[quota and compliance audits](https://developers.google.com/youtube/v3/guides/quota_and_compliance_audits)).

jam.nvim's current finder invokes search after a 250 ms pause on every prompt
change ([picker](../../lua/jam/ui/picker.lua#L69),
[default config](../../lua/jam/config.lua#L5)). That interaction can consume the
entire daily search allocation during ordinary typing. The YouTube provider must
use explicit submit (for example `<C-s>` or Enter when there is no selection),
plus an in-memory exact-query cache. A longer debounce is not a sufficient quota
control. Keep Spotify's existing live-search behavior by making search triggering
a provider capability/configuration, not a new global default.

### User playlists are possible later, but are not a playback queue

The Data API can list and modify YouTube playlists. `playlistItems.list` returns
the ordered videos in a playlist, up to 50 per page, and costs one general quota
unit ([`playlistItems.list`](https://developers.google.com/youtube/v3/docs/playlistItems/list)).
YouTube Music says playlists are shared between YouTube Music and YouTube, while
only music videos from a general YouTube playlist surface in YouTube Music
([YouTube Music playlist help](https://support.google.com/youtubemusic/answer/7205933)).

Private playlists and writes require Google OAuth. Google's installed-desktop flow
supports a system browser, loopback redirect, PKCE, refresh tokens, and explicit
revocation; it also warns that installed apps cannot keep a client secret
([YouTube installed-app OAuth guide](https://developers.google.com/youtube/v3/guides/auth/installed-apps)).
OAuth should be a later, user-driven feature using the minimum scope only when
the corresponding feature exists. YouTube policies prohibit requesting broader
scopes in anticipation of future features and require programmatic revocation
and deletion of authorized data after consent is revoked
([Developer Policies](https://developers.google.com/youtube/terms/developer-policies)).

Adding a video to a persistent playlist is not equivalent to jam.nvim's current
`add_to_queue`, which means the active playback queue. Keep `queue = false`; if
playlist writes are added, expose a separately named capability and action.

### Playback and metadata control

There is no playback-session resource in the documented Data API resource and
method index, so it cannot pause, resume, skip, inspect the YouTube Music queue,
or report the current track ([Data API reference](https://developers.google.com/youtube/v3/docs)).
The official programmable playback surface is instead the YouTube IFrame Player
API. An owned web page can load a video or playlist, play/pause, seek, move to the
next/previous playlist video, and read player state, duration, URL, and playlist
IDs ([IFrame Player API](https://developers.google.com/youtube/iframe_api_reference)).

That is not a hidden audio backend suitable for Neovim. YouTube requires an
embedded player viewport of at least 200 x 200 pixels, requires autoplay only
when more than half the player is visible, forbids obscuring the player, and
requires client identity through the referrer/origin
([Required Minimum Functionality](https://developers.google.com/youtube/terms/required-minimum-functionality)).
The Developer Policies also prohibit separating audio from video and prohibit a
background player that is not displayed in the page, tab, or screen the user is
viewing ([Developer Policies](https://developers.google.com/youtube/terms/developer-policies)).

Consequently, an IFrame-based second phase would need a visible browser companion
page and a small localhost control channel. It can be standards-compliant, but it
does not preserve jam.nvim's current "without leaving Neovim" experience and may
encounter browser autoplay blocking, which the Player API reports explicitly
([IFrame Player API](https://developers.google.com/youtube/iframe_api_reference)).
It should be opt-in rather than the default path.

Browser media controls are not a portable substitute. The W3C Media Session API
lets a playing document publish metadata and register handlers that the user agent
invokes for platform media actions; it does not define a Lua/native API for an
unrelated process to take over another site's session
([Media Session specification](https://www.w3.org/TR/2026/WD-mediasession-20260605/)).
Platform-specific media-key integrations could be a separate best-effort feature,
not a YouTube provider contract.

### Explicitly reject undocumented integrations

Do not use YouTube Music's private web endpoints (often called InnerTube), scrape
`music.youtube.com`, extract media streams, use `yt-dlp` as a playback backend, or
drive the site's DOM as the product integration. YouTube's policies explicitly
prohibit scraping, using undocumented APIs, reverse-engineering undocumented API
services, downloading/caching audiovisual content, separating audio from video,
and using non-YouTube technology to retrieve API data or audiovisual content
([Developer Policies](https://developers.google.com/youtube/terms/developer-policies)).
These approaches are also coupled to private response shapes and login cookies,
so they are a poor maintenance boundary even apart from policy.

Google's Data Portability API does name a `youtube.music` archive containing a
user's uploaded music and library songs, but it is an export/portability schema,
not an interactive catalog or player API
([YouTube and YouTube Music portability schema](https://developers.google.com/data-portability/schema-reference/youtube)).

## Fit with jam.nvim

The repository already has a useful normalized item shape and a provider object,
but the current abstraction is only partly provider-neutral:

- The factory rejects every name except Spotify and constructs Spotify auth
  directly ([provider factory](../../lua/jam/providers/init.lua#L5)).
- `auth`, `logout`, and their messages assume every provider has Spotify-style
  auth; `now_playing` calls the method without a support check
  ([command layer](../../lua/jam/init.lua#L32)).
- Health checks always require OpenSSL and inspect Spotify configuration, even
  when another provider is selected ([health](../../lua/jam/health.lua#L27)).
- Global search defaults contain Spotify-specific item types
  ([config](../../lua/jam/config.lua#L5)).
- The picker conditionally checks collection methods but unconditionally invokes
  `play`, and unconditionally maps queue and pause in both picker levels
  ([picker selection](../../lua/jam/ui/picker.lua#L480),
  [picker mappings](../../lua/jam/ui/picker.lua#L509),
  [collection mappings](../../lua/jam/ui/picker.lua#L389)).

The Spotify adapter declares capabilities, but the UI primarily detects methods
instead of consistently honoring those declarations. YouTube support should first
make capability behavior real, so partial providers are safe.

## Concrete implementation phases

### Phase 0: make partial providers first-class

This is a prerequisite, not unrelated cleanup:

1. Replace the Spotify-only factory branch with a registry mapping provider names
   to constructors. Let a provider omit `auth` entirely.
2. Define the contract centrally. For this first YouTube slice, use at least:
   `search`, `open`, `live_search`, `auth`, `playback_control`, `queue`,
   `now_playing`, `album_tracks`, `artist_top_tracks`, `show_episodes`, and
   `artwork`. Prefer `open(item)` as a distinct action from `play(item)` so the UI
   does not announce "Playing" when it only launched another app.
3. Build commands, completions, picker mappings, and help text from capabilities.
   Unsupported actions should not be mapped; direct command attempts should give
   a provider-specific explanation rather than call a missing method.
4. Move provider search options under `providers.<name>.search` or merge a
   provider's supported types and trigger mode into global defaults. Spotify can
   retain its existing types and live debounce; YouTube should use `video` only
   and explicit submit.
5. Let each provider contribute health checks. Keep generic Neovim/Telescope/curl
   checks in `jam.health`; check OpenSSL and Spotify client ID only for Spotify,
   and YouTube API-key/category configuration only for YouTube.
6. Replace provider names embedded in auth/logout notifications with provider
   display names and auth-returned messages.

### Phase 1: `youtube_music` search/open adapter

Add a provider with the following truthful contract:

```lua
capabilities = {
  search = true,
  open = true,
  live_search = false,
  auth = false,
  playback_control = false,
  queue = false,
  now_playing = false,
  playlists = false,
  artwork = true,
}
```

Suggested configuration:

```lua
providers = {
  youtube_music = {
    api_key = vim.env.YOUTUBE_API_KEY,
    region_code = nil,       -- optional ISO 3166-1 alpha-2
    relevance_language = nil,
    open_host = "music.youtube.com",
    search = { limit = 20, mode = "submit" },
  },
}
```

Normalize each result as `kind = "video"` (rather than pretending every result
is a Spotify-like track), `id = videoId`, `uri`/`external_url` for the handoff,
`name = snippet.title`, `subtitle = snippet.channelTitle`, `image_url` from the
best available thumbnail, `release_date = publishedAt`, and `duration_ms` parsed
from `contentDetails.duration`. Add `VIDEO` to the picker label table and preserve
`raw`/`service_kind` for provider-specific diagnostics.

Cache exact queries for the Neovim session, ignore stale async responses as the
current picker already does, and surface a distinct quota-exhausted error. The
search action and result title should explicitly name YouTube to satisfy the
policy that YouTube actions and mixed-provider data be clearly attributable and
user initiated ([Developer Policies](https://developers.google.com/youtube/terms/developer-policies)).

Before documenting the Music-host handoff as stable, verify representative public
video IDs, unavailable/region-blocked items, age-restricted items, and signed-out
behavior on each supported OS. Keep regular YouTube as a fallback because Google
documents share links opening content in YouTube Music but does not specify URL
construction as an API contract.

### Phase 2: optional breadth

- Add public playlist drill-down using `playlistItems.list`; keep it read-only at
  first.
- Add OAuth only if private playlists/library actions are explicitly in scope,
  using Google's desktop loopback + PKCE flow and true token revocation on logout.
- Consider a visible browser companion using the IFrame Player API only if users
  accept its visible-player and autoplay constraints. Its capabilities can then
  be playback-specific and should exist only while that companion is connected.

Do not make full YouTube Music library search, its personalized recommendations,
its live queue, or remote control of an already-open YouTube Music tab part of the
roadmap unless Google publishes a supported API for those features.

## Acceptance criteria for the first slice

- One submitted query causes at most one `search.list` call plus one batched
  `videos.list` call; repeated identical queries in the same session use cache.
- Typing without submitting consumes no YouTube search quota.
- The picker labels results and selection actions as YouTube/YouTube Music.
- Selecting an item says "Opened in YouTube Music," never "Playing," and failure
  to launch the URL is reported.
- Queue and pause mappings are absent, and playback/now-playing commands explain
  that the selected provider hands control to YouTube Music.
- No OAuth, cookies, private web endpoint, scraping, stream extraction, or bundled
  shared API key is present.
- Tests cover capability-gated mappings and commands, Data API normalization,
  ISO-8601 duration parsing, exact-query cache, stale responses, quota errors,
  category lookup/cache, and URL handoff fallback.
