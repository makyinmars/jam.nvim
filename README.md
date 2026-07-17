# jam.nvim

Search Spotify and control playback from a Telescope picker without leaving Neovim.

> [!NOTE]
> jam.nvim is an early preview. Spotify is the first provider; its provider-neutral
> core is designed for future Apple Music and YouTube Music adapters.

## Features

- Live, debounced Spotify search for tracks, albums, artists, and playlists
- Play, pause, skip, go back, and add tracks to the queue
- OAuth Authorization Code flow with PKCE—no client secret in your config
- Album-art previews through `image.nvim` or `chafa`, with automatic detection
- `:Jam` and `:Telescope jam` entry points
- Health diagnostics with `:checkhealth jam`

## Requirements

- Neovim 0.10+
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- `curl` and `openssl`
- A Spotify account and application client ID
- Spotify Premium for Web API playback control

Album artwork is optional. Install
[image.nvim](https://github.com/3rd/image.nvim) in a compatible terminal or
[`chafa`](https://hpjansson.org/chafa/) for a portable symbol preview.

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

1. Create an application in the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard).
2. Add `http://127.0.0.1:8765/callback` as an exact redirect URI.
3. Put the application's client ID in `SPOTIFY_CLIENT_ID`, or pass it to `setup`.
4. Restart Neovim and run `:Jam auth spotify`.
5. Run `:Jam`, enter a search, and press `<CR>` to play a result.

Tokens are stored with `0600` permissions under Neovim's data directory. Run
`:Jam logout` to remove them.

## Usage

```vim
:Jam                    " Open search
:Jam search             " Open search
:Jam auth spotify       " Connect Spotify
:Jam pause
:Jam next
:Jam previous
:Jam now-playing
:Jam logout
:Jam health
:Telescope jam
```

Picker mappings:

| Mapping | Action |
| --- | --- |
| `<CR>` | Play selection |
| `<C-q>` | Add selection to queue |
| `<C-p>` | Pause playback |

## Configuration

```lua
require("jam").setup({
  provider = "spotify",
  search = {
    debounce_ms = 250,
    limit = 30,
    types = { "track", "album", "artist", "playlist" },
  },
  artwork = {
    enabled = true,
    backend = "auto", -- auto, image, chafa, text, or none
    width = 38,
    height = 16,
    cache = true,
  },
  picker = {
    layout_strategy = "horizontal",
  },
  providers = {
    spotify = {
      client_id = vim.env.SPOTIFY_CLIENT_ID,
      redirect_uri = "http://127.0.0.1:8765/callback",
    },
  },
})
```

## Provider design

Provider adapters declare capabilities and implement the common search and
playback interface. The Telescope UI does not call Spotify-specific endpoints,
so additional providers can expose only the capabilities their APIs support.

Apple Music and YouTube Music are not implemented yet. YouTube Music does not
offer an official public playback-control API, so that adapter will require a
carefully documented fallback rather than pretending all providers have equal
capabilities.
