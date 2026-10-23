local notes = require("config.notes")

local function set_note_keymaps(buffer)
  for lhs, mapping in pairs({
    ["<leader>ob"] = { "backlinks", "Note backlinks" },
    ["<leader>ol"] = { "links", "Note links" },
    ["<leader>op"] = { "paste_img", "Paste image into note" },
  }) do
    vim.keymap.set("n", lhs, "<cmd>Obsidian " .. mapping[1] .. "<cr>", { buffer = buffer, desc = mapping[2] })
  end
end

return {
  {
    "obsidian-nvim/obsidian.nvim",
    version = "*",
    cmd = "Obsidian",
    keys = {
      { "<leader>on", "<cmd>Obsidian new<cr>", desc = "New note" },
      { "<leader>od", "<cmd>Obsidian today<cr>", desc = "Today's note" },
      { "<leader>of", "<cmd>Obsidian quick_switch<cr>", desc = "Find note" },
      { "<leader>os", "<cmd>Obsidian search<cr>", desc = "Search notes" },
      { "<leader>ot", "<cmd>Obsidian new_from_template<cr>", desc = "New note from template" },
      { "<leader>o#", "<cmd>Obsidian tags<cr>", desc = "Note tags" },
    },
    init = function()
      local group = vim.api.nvim_create_augroup("notes_ux", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "markdown",
        callback = function(event)
          if notes.contains(event.file) then
            require("config.note_edit").attach(event.buf)
          end
        end,
      })
      vim.api.nvim_create_user_command("NotesLint", function()
        if vim.bo.filetype == "markdown" then
          require("lint").try_lint("markdownlint-cli2")
        end
      end, { desc = "Check Markdown style explicitly (including personal notes)" })
      vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
        group = vim.api.nvim_create_augroup("obsidian_vault_loader", { clear = true }),
        pattern = "*.md",
        callback = function(event)
          if notes.contains(event.file) then
            require("lazy").load({ plugins = { "obsidian.nvim" } })
            set_note_keymaps(event.buf)
            -- Capture logs and personal notes are formatted on request, not every save.
            vim.b[event.buf].autoformat = false
          end
        end,
      })
    end,
    opts = {
      legacy_commands = false,
      checkbox = { order = { " ", "x" }, create_new = false },
      workspaces = { { name = "notes", path = notes.root, strict = true } },
      notes_subdir = "00-inbox",
      new_notes_location = "notes_subdir",
      note_id_func = function(title, dir)
        return require("obsidian.builtin").title_id(title, dir)
      end,
      note = { template = "note.md" },
      templates = { folder = "templates", date_format = "YYYY-MM-DD", time_format = "HH:mm" },
      daily_notes = {
        enabled = true,
        folder = notes.daily,
        date_format = "YYYY-MM-DD",
        template = "daily.md",
        default_tags = { "daily-notes" },
        workdays_only = false,
      },
      link = { style = "wiki", format = "shortest", auto_update = false },
      picker = { name = "snacks.picker" },
      completion = { min_chars = 2, match_case = false, create_new = true },
      -- Templates own metadata; never rewrite existing notes' frontmatter on save.
      frontmatter = { enabled = false },
      attachments = {
        folder = notes.assets,
        confirm_img_paste = false,
        img_name_func = function()
          return "image-" .. os.date("%Y%m%d-%H%M%S") .. "-" .. tostring(vim.uv.hrtime()) .. ".png"
        end,
        img_text_func = notes.image_link,
      },
      ui = { enable = false }, -- render-markdown owns presentation.
      footer = { enabled = false },
    },
    config = function(_, opts)
      notes.prepare()
      require("obsidian").setup(opts)
    end,
  },
  {
    "iamcco/markdown-preview.nvim",
    build = function()
      require("lazy").load({ plugins = { "markdown-preview.nvim" } })
      -- The upstream async installer can exit with headless Neovim before download ends.
      vim.fn["mkdp#util#install_sync"]()
      assert(vim.fn["mkdp#util#pre_build_version"]() ~= "", "Markdown preview binary was not built")
    end,
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters = {
        ["markdownlint-cli2"] = {
          condition = function(ctx)
            return not notes.contains(ctx.filename)
          end,
        },
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      -- Homebrew owns these CLIs so update-all covers them without another updater.
      opts.ensure_installed = vim.tbl_filter(function(tool)
        return tool ~= "markdownlint-cli2" and tool ~= "markdown-toc"
      end, opts.ensure_installed or {})
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        marksman = {
          mason = false,
          root_dir = function(buffer, on_dir)
            local file = vim.api.nvim_buf_get_name(buffer)
            if not notes.contains(file) then
              on_dir(vim.fs.root(buffer, { ".marksman.toml", ".git" }) or vim.fs.dirname(file))
            end
          end,
        },
      },
    },
  },
  {
    "folke/snacks.nvim",
    keys = {
      {
        "<leader>oh",
        function()
          require("config.note_ui").home()
        end,
        desc = "Notes Home",
      },
      {
        "<leader>o?",
        function()
          require("config.note_ui").help()
        end,
        desc = "Beginner notes help",
      },
      {
        "<leader>oi",
        function()
          require("config.note_capture").prompt()
        end,
        desc = "Quick idea (save to inbox)",
      },
      {
        "<leader>or",
        function()
          Snacks.picker.recent({ cwd = notes.root, filter = { cwd = true } })
        end,
        desc = "Recent notes",
      },
    },
    opts = {
      -- Herdr passthrough is unverified; plain links and browser preview remain available.
      image = { enabled = vim.env.HERDR_ENV ~= "1", doc = { enabled = true }, math = { enabled = false } },
    },
  },
  {
    "folke/which-key.nvim",
    opts = { spec = { { "<leader>o", group = "notes", icon = "󰎞 " } } },
  },
}
