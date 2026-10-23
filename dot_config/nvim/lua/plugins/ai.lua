-- AI assistant.
--
-- CodeCompanion keeps its existing shortcuts and Keychain-backed adapter.
-- Claude Code and Copilot are enabled through the authoritative LazyVim extras.
--
-- Credentials: this machine keeps API keys in the macOS Keychain, never as
-- plaintext in a config or dotfile (same pattern as RESPONDIO_API_KEY, used by
-- the respond-io MCP server). ANTHROPIC_API_KEY is NOT set in the environment.
--
-- To enable this adapter, store the key once:
--
--   security add-generic-password -a "$(id -un)" -s ANTHROPIC_API_KEY -w
--
-- The `cmd:` prefix makes CodeCompanion execute the command at request time,
-- so the key never enters the environment of every shell.
--
-- `tr -d '\n'` is REQUIRED: `security ... -w` appends a trailing newline (0x0a),
-- which would be sent verbatim in the x-api-key header and rejected as a 401.

return {
  {
    "coder/claudecode.nvim",
    keys = function(_, keys)
      -- Avoid shadowing CodeCompanion's existing chat/actions shortcuts.
      for _, key in ipairs(keys) do
        if key[1] == "<leader>ac" then
          key[1] = "<leader>ai"
        elseif key[1] == "<leader>aa" then
          key[1] = "<leader>ay"
        end
      end
      return keys
    end,
  },
  {
    "olimorris/codecompanion.nvim",
    version = "^19.0.0",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions", "CodeCompanionCmd" },
    keys = {
      { "<leader>aa", "<cmd>CodeCompanionActions<cr>", mode = { "n", "v" }, desc = "CodeCompanion actions" },
      { "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", mode = { "n", "v" }, desc = "CodeCompanion chat" },
      { "<leader>ap", "<cmd>CodeCompanion<cr>", mode = { "n", "v" }, desc = "CodeCompanion inline" },
    },
    opts = {
      adapters = {
        http = {
          anthropic = function()
            return require("codecompanion.adapters").extend("anthropic", {
              env = {
                api_key = "cmd:security find-generic-password -a $(id -un) -s ANTHROPIC_API_KEY -w | tr -d '\\n'",
              },
            })
          end,
        },
      },
      interactions = {
        chat = { adapter = "anthropic" },
        inline = { adapter = "anthropic" },
        cmd = { adapter = "anthropic" },
      },
    },
  },

  -- Register <leader>a as an "ai" group so which-key labels it.
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>a", group = "ai" },
      },
    },
  },
}
