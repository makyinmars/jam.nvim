# jam.nvim

Search Spotify or YouTube's music-video category from Telescope. Control Spotify
playback in Neovim, or open YouTube results in the first-party YouTube Music app.

> [!NOTE]
> jam.nvim is an early preview. Provider features differ according to the
> capabilities exposed by each service's official APIs.

## Features

- Live Spotify search for music, playlists, podcasts, and episodes
- Explicit-submit YouTube music-video search with exact-query caching
- YouTube-attributed results that open in YouTube Music, with a YouTube fallback
- Drill-down for album tracks, artist top tracks, and podcast episodes
- Play, pause, skip, go back, and add tracks or episodes to the queue
- OAuth Authorization Code flow with PKCE—no client secret in your config
- Album-art previews through `image.nvim` or `chafa`, with automatic detection
- Contextual metadata for artists, albums, tracks, podcasts, and episodes
- `:Jam` and `:Telescope jam` entry points
- Health diagnostics with `:checkhealth jam`

## Requirements

Required:

- Neovim 0.10+
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- `curl` for provider API requests

Spotify additionally requires `openssl` for PKCE authentication, a Spotify
account and [application client ID](#create-a-spotify-application), and Spotify
Premium with an active Spotify Connect device for playback control.

YouTube Music search requires a Google Cloud API key with the YouTube Data API
v3 enabled. It does not require Google login. The integration searches public
videos in YouTube's Music category; it is not a YouTube Music catalog, library,
queue, or playback-control API.

Run `:checkhealth jam` after installation to verify these dependencies and your
configuration.

### Album artwork dependencies

Album artwork requires an optional renderer. Without one, the preview shows the
image URL as text.

- Install [`chafa`](https://hpjansson.org/chafa/) for a portable, full-color
  character-art preview
  (`brew install chafa` on macOS or `sudo apt install chafa` on Debian/Ubuntu).
- Or install [image.nvim](https://github.com/3rd/image.nvim) and use a compatible
  terminal such as Kitty or WezTerm.

`chafa` is the simplest cross-terminal option. Run `:checkhealth jam` to see
which artwork backend jam.nvim detected.

## Installation

### lazy.nvim

```lua
{
  "bautistaaa/jam.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    -- Optional, for high-resolution artwork:
    -- { "3rd/image.nvim", opts = {} },
  },
  cmd = { "Jam" },
  opts = {
    providers = {
      spotify = {
        client_id = vim.env.SPOTIFY_CLIENT_ID,
      },
    },
  },
}
```

### Native `vim.pack`

```lua
vim.pack.add({
  "https://github.com/nvim-telescope/telescope.nvim",
  "https://github.com/bautistaaa/jam.nvim",
})

require("jam").setup({
  providers = {
    spotify = { client_id = vim.env.SPOTIFY_CLIENT_ID },
  },
})
```

### mini.deps

```lua
local add = MiniDeps.add
add({ source = "nvim-telescope/telescope.nvim" })
add({ source = "bautistaaa/jam.nvim" })
```

### packer.nvim

```lua
use({
  "bautistaaa/jam.nvim",
  requires = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("jam").setup({
      providers = {
        spotify = { client_id = vim.env.SPOTIFY_CLIENT_ID },
      },
    })
  end,
})
```

### vim-plug

```vim
Plug 'nvim-telescope/telescope.nvim'
Plug 'bautistaaa/jam.nvim'
```

Then call `require("jam").setup(...)` from your Lua config.

## Spotify setup

### Create a Spotify application

1. Sign in to the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard).
2. Select **Create app**.
3. Enter an app name and description. A website is not required for local use.
4. Add this exact redirect URI:

   ```text
   http://127.0.0.1:8765/callback
   ```

5. Select **Web API** when Spotify asks which APIs or SDKs the app will use,
   accept the terms, and save the app.
6. Open the app's settings and copy its **Client ID**. jam.nvim does not need
   the client secret; never put the secret in your Neovim configuration.

### Connect jam.nvim

1. Put the client ID in your shell environment:

   ```sh
   export SPOTIFY_CLIENT_ID="your-client-id"
   ```

   Add that line to `~/.zshrc`, `~/.bashrc`, or the equivalent for your shell,
   then start Neovim from a new terminal.
2. Run `:checkhealth jam` and resolve any reported errors.
3. Run `:Jam auth spotify` and finish authorization in the browser.
4. Open Spotify and play something once so Spotify Connect marks the selected
   device as active.
5. Run `:Jam`, enter a search, and press `<CR>` to play a result.

Tokens are stored with `0600` permissions under Neovim's data directory. Run
`:Jam logout` to remove them.

## YouTube Music setup

1. Create or select a project in Google Cloud and enable **YouTube Data API v3**.
2. Create an API key restricted to the YouTube Data API. Keep the key out of the
   repository and do not share it between jam.nvim users.
3. Put the key in your shell environment:

   ```sh
   export YOUTUBE_API_KEY="your-api-key"
   ```

4. Select the provider in your Neovim config:

   ```lua
   require("jam").setup({
     provider = "youtube_music",
     providers = {
       youtube_music = {
         api_key = vim.env.YOUTUBE_API_KEY,
         region_code = "US", -- optional ISO 3166-1 alpha-2 code
         relevance_language = "en", -- optional language hint
       },
     },
   })
   ```

5. Run `:checkhealth jam`, open `:Jam`, enter a query, and press `<C-s>` or
   `<CR>` when no result is selected. Selecting a result opens it in YouTube
   Music. Set `open_host = "www.youtube.com"` to always use regular YouTube.

The `music.youtube.com/watch` handoff is a best-effort web route, not a documented
Google integration API. Use regular YouTube if the Music host does not handle a
video reliably on your platform or in your region.

Search requests have a limited daily quota, so YouTube search never runs on
each keystroke. Repeating the exact query in the same Neovim session uses a
memory cache.

### Troubleshooting

- **`Device not found`**: jam.nvim opens the selected item in Spotify. Once the
  app is ready, select the item again. If needed, manually play a track once so
  the Web API considers the device active.
- **Artwork URL instead of an image**: Install `chafa`, or configure `image.nvim`
  in a compatible terminal, then reopen the picker.
- **Client ID is not configured**: Confirm `:echo $SPOTIFY_CLIENT_ID` prints your
  client ID. Restart Neovim from a new terminal after changing your shell
  configuration.
- **OAuth redirect errors**: Confirm the redirect URI in Spotify is exactly
  `http://127.0.0.1:8765/callback`.

## Usage

```vim
:Jam                    " Open search
:Jam search             " Open search
:Jam auth spotify       " Connect Spotify
:Jam play
:Jam pause
:Jam next
:Jam previous
:Jam now-playing
:Jam logout
:Jam health
:Telescope jam
```

Search filters:

| Prefix | Searches |
| --- | --- |
| `a:` | Albums |
| `t:` | Artists |
| `s:` | Songs/tracks |
| `p:` | Podcasts |
| `e:` | Podcast episodes |

For example, `a:Abbey Road`, `t:BTS`, `s:One More Night`, `p:Radiolab`, or
`e:Black Holes`. Queries without a prefix search all supported item types.

Picker mappings:

| Mapping | Action |
| --- | --- |
| `<CR>` | Open a collection or play the selected track/episode |
| `<C-q>` | Add selection to queue |
| `<C-p>` | Pause playback |
| `<Esc>` | Return from a collection to the original search |
| `<C-s>` | Submit a YouTube music-video search |

Selecting an album opens its tracks in disc and track order. Selecting an artist
opens their top tracks, and selecting a podcast opens its episodes. Press `<Esc>`
in any collection view to return to the same search query.

## Configuration

```lua
require("jam").setup({
  provider = "spotify",
  artwork = {
    enabled = true,
    backend = "auto", -- auto, image, chafa, text, or none
    width = 38,
    height = 16,
    cache = true,
  },
  picker = {
    layout_strategy = "flex",
  },
  providers = {
    spotify = {
      client_id = vim.env.SPOTIFY_CLIENT_ID,
      redirect_uri = "http://127.0.0.1:8765/callback",
      search = {
        debounce_ms = 250,
        limit = 30,
        mode = "live",
        types = { "track", "album", "artist", "playlist", "show", "episode" },
      },
    },
    youtube_music = {
      api_key = vim.env.YOUTUBE_API_KEY,
      region_code = nil,
      relevance_language = nil,
      open_host = "music.youtube.com",
      fallback_host = "www.youtube.com",
      search = { limit = 20, mode = "submit" },
    },
  },
})
```

## Provider roadmap

Provider adapters declare capabilities, and commands, completion, picker actions,
and health checks follow those declarations. Spotify supports authentication,
live search, collection drill-down, queueing, and playback control. The
`youtube_music` provider only searches YouTube's public Music video category and
opens a selected video; playback, queue, now-playing, authentication, and private
playlists are intentionally unsupported.

jam.nvim uses the documented YouTube Data API. It does not scrape YouTube Music,
call private endpoints, extract media streams, or control an existing browser
tab.
