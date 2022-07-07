# window-picker.nvim

Neovim plugin for switching between windows painlessly.

### Installation
```lua
Plug 'kowsmo7/window-picker.nvim'
```

### Configuration
```lua
local window_picker = require("window-picker")

window_picker.setup({
    -- Characters used to pick windows, in order of appearance.
    chars = "abcdefg",

    -- Background and text highlight groups.
    background_hl = "Normal",
    text_hl = "Bold",

    -- The border style to use for the floating window.
    border_style = "single",

    -- Floating window width/height.
    float_width = 11,
    float_height = 5,

    -- Whether or not to show letters in uppercase.
    show_uppercase = false,

    -- Just switch to the other window if only two are open.
    skip_if_two = true,
})

-- Use any mapping you wish.
vim.cmd("nnoremap <silent> <Space>w :lua require(\"window-picker\").pick()<CR>")
```

### Credits

This is a fork ok [nvim-window](https://gitlab.com/yorickpeterse/nvim-window/-/tree/main/), which is licensed under the MPL-2.0 License.

### License

See [LICENSE](LICENSE).

