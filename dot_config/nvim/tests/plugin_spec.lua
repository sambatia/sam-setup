local h = dofile(vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), "helpers.lua"))
local phase = vim.env.NVIM_SPEC_PHASE or "all"
package.path = vim.fs.joinpath(h.root, "lua", "?.lua") .. ";" .. package.path
local specs = h.specs()

local function core()
  local expected_extras = {
    "lazyvim.plugins.extras.ai.claudecode",
    "lazyvim.plugins.extras.ai.copilot",
    "lazyvim.plugins.extras.coding.yanky",
    "lazyvim.plugins.extras.editor.aerial",
    "lazyvim.plugins.extras.editor.dial",
    "lazyvim.plugins.extras.editor.inc-rename",
    "lazyvim.plugins.extras.editor.overseer",
    "lazyvim.plugins.extras.editor.snacks_picker",
    "lazyvim.plugins.extras.lang.json",
    "lazyvim.plugins.extras.lang.markdown",
    "lazyvim.plugins.extras.test.core",
    "lazyvim.plugins.extras.util.dot",
    "lazyvim.plugins.extras.util.mini-hipatterns",
    "lazyvim.plugins.extras.util.octo",
  }
  h.same_list(h.json("lazyvim.json").extras, expected_extras, "LazyVim extras must be authoritative and sorted")

  local lazy_source = h.read("lua/config/lazy.lua")
  assert(
    not lazy_source:find('import = "lazyvim.plugins.extras.editor.telescope"', 1, true),
    "manual Telescope import remains"
  )
  assert(lazy_source:find("missing = true", 1, true), "missing-plugin installation is not explicit")
  assert(lazy_source:find("frequency = 86400", 1, true), "daily checker frequency is not configured")
  assert(lazy_source:find("notify = true", 1, true), "update notification is not enabled")

  local ai_source = h.read("lua/plugins/ai.lua")
  assert(ai_source:find("interactions%s*="), "CodeCompanion interactions config is missing")
  assert(not ai_source:find("strategies%s*="), "deprecated CodeCompanion strategies config remains")
  assert(
    not ai_source:find("-w '<token>'", 1, true),
    "CodeCompanion credential guidance must not place a token in shell history"
  )
  local codecompanion = assert(h.find_plugin(specs, "olimorris/codecompanion.nvim"), "CodeCompanion is missing")
  assert(codecompanion.version == "^19.0.0", "CodeCompanion must stay within the compatible v19 release line")

  local claude = assert(h.find_plugin(specs, "coder/claudecode.nvim"), "Claude mapping override is missing")
  local claude_keys = claude.keys({}, {
    { "<leader>ac", "<cmd>ClaudeCode<cr>" },
    { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>" },
    { "<leader>ar", "<cmd>ClaudeCode --resume<cr>" },
  })
  assert(h.find_key({ keys = claude_keys }, "<leader>ai"), "Claude toggle must not shadow CodeCompanion chat")
  assert(h.find_key({ keys = claude_keys }, "<leader>ay"), "Claude accept must not shadow CodeCompanion actions")
  assert(not h.find_key({ keys = claude_keys }, "<leader>ac"), "Claude shadows CodeCompanion chat")
  assert(not h.find_key({ keys = claude_keys }, "<leader>aa"), "Claude shadows CodeCompanion actions")

  local telescope
  for _, spec in ipairs(specs) do
    if spec[1] == "nvim-telescope/telescope.nvim" and spec.keys then
      telescope = spec
    end
  end
  assert(telescope, "standalone Telescope picker specification is missing")
  assert(h.find_key(telescope, "<leader>uC"), "persistent theme picker must still use Telescope")
  assert(telescope.lazy == true, "secondary Telescope picker must load on demand")
  assert(h.contains(telescope.dependencies, "nvim-lua/plenary.nvim"), "standalone Telescope dependency is missing")
  local snacks = assert(h.find_plugin(specs, "folke/snacks.nvim"), "Snacks theme-key override is missing")
  local snack_keys = snacks.keys({}, {
    { "<leader>uC", function() end },
    { "<leader>ff", function() end },
  })
  assert(not h.find_key({ keys = snack_keys }, "<leader>uC"), "Snacks shadows the persistent Telescope theme picker")
  assert(h.find_key({ keys = snack_keys }, "<leader>ff"), "general Snacks navigation must stay available")

  local overrides_source = h.read("lua/plugins/overrides.lua")
  assert(not overrides_source:find("jsonls%s*="), "manual jsonls config duplicates the JSON extra")
  assert(
    overrides_source:find('require%("config%.treesitter_languages"%)'),
    "Treesitter parser declarations must come from the shared validation list"
  )
  local languages = dofile(vim.fs.joinpath(h.root, "lua", "config", "treesitter_languages.lua"))
  for _, language in ipairs({ "lua", "typescript", "tsx", "json", "markdown", "python", "go", "rust" }) do
    assert(h.contains(languages, language), "required Treesitter language is missing: " .. language)
  end

  local update_source = h.read("lua/plugins/updates.lua")
  assert(update_source:find("<leader>pu", 1, true), "safe plugin update key is missing")
  assert(update_source:find("<leader>ps", 1, true), "safe plugin update status key is missing")
  local manager_source = h.read("lua/config/safe_updates.lua")
  assert(manager_source:find("LazySafeUpdate", 1, true), "safe plugin update command is missing")
  assert(manager_source:find("VimLeavePre", 1, true), "updates are not deferred until exit")
  assert(manager_source:find("detach = true", 1, true), "updater process is not detached")
  assert(
    manager_source:find("NVIM_SAFE_UPDATE_PARENT_PID", 1, true),
    "safe updater does not receive the initiating Neovim PID"
  )
  local updater_source = h.read("scripts/safe-plugin-update.sh")
  assert(
    updater_source:find("verify%-treesitter%.lua"),
    "safe updates must synchronously install and verify required Treesitter parsers"
  )
  local treesitter_verifier = h.read("scripts/verify-treesitter.lua")
  assert(treesitter_verifier:find("treesitter.update", 1, true), "required parsers are not updated with plugins")
  assert(
    treesitter_verifier:find("vim.treesitter.query.get", 1, true),
    "Treesitter query compatibility is not validated"
  )
  assert(updater_source:find("vim%.treesitter"), "safe updater uses an obsolete Treesitter health-check name")
  assert(updater_source:find("assert_no_errors", 1, true), "safe updater does not inspect health report errors")
  assert(updater_source:find("tests/runtime_smoke.lua", 1, true), "safe updater does not run runtime smoke tests")
  assert(
    not updater_source:find('--headless -l "$config_dir/tests/runtime_smoke.lua"', 1, true),
    "runtime smoke must load the actual Neovim configuration"
  )
  assert(updater_source:find("checkhealth codecompanion", 1, true), "CodeCompanion health is not validated")
  h.pass("core LazyVim and CodeCompanion configuration")
end

local function tools()
  local csv = assert(h.find_plugin(specs, "hat0uma/csvview.nvim"), "csvview.nvim is missing")
  for _, command in ipairs({ "CsvViewEnable", "CsvViewDisable", "CsvViewToggle", "CsvViewInfo" }) do
    assert(h.contains(csv.cmd, command), command .. " is not a lazy command")
  end
  assert(h.contains(csv.ft, "csv") and h.contains(csv.ft, "tsv"), "CSV/TSV lazy filetypes are incomplete")
  assert(h.find_key(csv, "<leader>cv"), "CSV toggle key is missing")
  assert(csv.opts.parser.async_chunksize == 25, "CSV async chunk limit is not conservative")
  assert(csv.opts.parser.max_lookahead == 50, "CSV lookahead limit is missing")
  assert(h.contains(csv.opts.parser.delimiter.fallbacks, ";"), "semicolon detection is missing")
  assert(csv.opts.parser.delimiter.ft.csv == nil, "CSV delimiter must be sniffed instead of forced to comma")
  assert(csv.opts.parser.delimiter.ft.tsv == "\t", "TSV delimiter must remain explicit")

  local treesj = assert(h.find_plugin(specs, "Wansmer/treesj"), "TreeSJ is missing")
  assert(treesj.opts.use_default_keymaps == false, "TreeSJ default mappings must be disabled")
  assert(h.find_key(treesj, "<leader>cj"), "TreeSJ toggle key is missing")

  local undotree = assert(h.find_plugin(specs, "mbbill/undotree"), "Undotree is missing")
  assert(h.find_key(undotree, "<leader>uu"), "Undotree toggle key is missing")

  local splits = assert(h.find_plugin(specs, "mrjones2014/smart-splits.nvim"), "smart-splits is missing")
  for _, lhs in ipairs({ "<C-h>", "<C-j>", "<C-k>", "<C-l>", "<M-h>", "<M-j>", "<M-k>", "<M-l>" }) do
    assert(h.find_key(splits, lhs), "smart-splits mapping missing: " .. lhs)
  end

  local aerial = assert(h.find_plugin(specs, "stevearc/aerial.nvim"), "Aerial override is missing")
  assert(h.find_key(aerial, "[a") and h.find_key(aerial, "]a"), "Aerial navigation mappings are missing")

  local yanky = assert(h.find_plugin(specs, "gbprod/yanky.nvim"), "Yanky override is missing")
  assert(h.find_key(yanky, "<leader>sy"), "Yanky history key is missing")
  local old_yanky_key = h.find_key(yanky, "<leader>p")
  assert(old_yanky_key and old_yanky_key[2] == false, "Yanky's conflicting <leader>p key is not disabled")

  local colorizer = assert(h.find_plugin(specs, "catgoose/nvim-colorizer.lua"), "canonical colorizer is missing")
  assert(h.find_key(colorizer, "<leader>uH"), "Colorizer toggle key is missing")
  assert(colorizer.opts.lazy_load == true, "Colorizer should schedule highlighting lazily")
  assert(
    colorizer.opts.options.display.disable_document_color == true,
    "Colorizer must suppress duplicate Neovim LSP document colors"
  )
  local hipatterns =
    assert(h.find_plugin(specs, "nvim-mini/mini.hipatterns"), "Tailwind highlighting override is missing")
  local highlights = { highlighters = { hex_color = {}, shorthand = {} }, tailwind = { enabled = true } }
  hipatterns.opts({}, highlights)
  assert(
    not highlights.highlighters.hex_color and not highlights.highlighters.shorthand,
    "hex highlighting has duplicate owners"
  )
  assert(highlights.tailwind.enabled, "distinct Tailwind highlighting must remain enabled")

  for _, rejected in ipairs({
    "RRethy/vim-illuminate",
    "j-hui/fidget.nvim",
    "kevinhwang91/nvim-bqf",
    "NeogitOrg/neogit",
  }) do
    assert(not h.find_plugin(specs, rejected), rejected .. " must remain excluded")
  end
  h.pass("data, editing, navigation, and UI plugin specifications")
end

local function git()
  local diffview = assert(h.find_plugin(specs, "dlyongemallo/diffview-plus.nvim"), "diffview+ is missing")
  assert(diffview.version == "*", "diffview+ must track stable releases")
  for _, lhs in ipairs({ "<leader>gvo", "<leader>gvf", "<leader>gvh", "<leader>gvx" }) do
    assert(h.find_key(diffview, lhs), "Diffview mapping missing: " .. lhs)
  end
  assert(not h.find_plugin(specs, "sindrets/diffview.nvim"), "dormant Diffview upstream must not be installed")

  local octo = assert(h.find_plugin(specs, "pwntester/octo.nvim"), "Octo override is missing")
  assert(octo.opts.default_to_projects_v2 == false, "Octo Projects v2 must stay disabled without its gh scope")
  local old_search = h.find_key(octo, "<leader>gS")
  assert(old_search and old_search[2] == false, "Octo must preserve the Git stash key")
  assert(h.find_key(octo, "<leader>go"), "Octo search key is missing")
  h.pass("Git and GitHub plugin specifications")
end

local function workflows()
  local obsidian = assert(h.find_plugin(specs, "obsidian-nvim/obsidian.nvim"), "maintained Obsidian plugin is missing")
  assert(obsidian.version == "*", "Obsidian must track stable releases")
  assert(obsidian.opts.legacy_commands == false, "Obsidian legacy commands must be disabled")
  assert(obsidian.opts.templates.folder == "templates", "note templates must have one owner")
  assert(obsidian.opts.picker.name == "snacks.picker", "notes should use the existing Snacks picker")
  assert(obsidian.opts.daily_notes.enabled == true, "daily notes are not configured")
  assert(obsidian.opts.ui.enable == false, "Obsidian UI duplicates the existing Markdown renderer")
  local markdown_source = h.read("lua/plugins/markdown.lua")
  for _, lhs in ipairs({ "<leader>on", "<leader>od", "<leader>of", "<leader>os", "<leader>ob", "<leader>ol" }) do
    assert(markdown_source:find(lhs, 1, true), "Obsidian vault-local mapping missing: " .. lhs)
  end

  local kulala = assert(h.find_plugin(specs, "mistweaverco/kulala.nvim"), "Kulala is missing")
  assert(kulala.opts.global_keymaps == false, "Kulala global defaults must remain disabled")
  assert(kulala.opts.session.restore == false, "Kulala response history must not be persisted in sessions")
  assert(
    kulala.version == "6.22.0",
    "Kulala must match the installed kulala-core 0.29.1; newer releases need a license"
  )
  for _, lhs in ipairs({ "<leader>rr", "<leader>ra", "<leader>ri", "<leader>rc" }) do
    assert(h.find_key(kulala, lhs), "Kulala mapping missing: " .. lhs)
  end

  local overseer = assert(h.find_plugin(specs, "stevearc/overseer.nvim"), "Overseer override is missing")
  assert(overseer.lazy == true, "Overseer must remain outside the startup path")
  for _, lhs in ipairs({ "<leader>rr", "<leader>ra", "<leader>rt" }) do
    assert(h.find_key(overseer, lhs), "Overseer mapping missing: " .. lhs)
  end
  for _, lhs in ipairs({ "<leader>ow", "<leader>oo", "<leader>ot" }) do
    local old_key = h.find_key(overseer, lhs)
    assert(old_key and old_key[2] == false, "legacy Overseer namespace remains: " .. lhs)
  end
  assert(
    h.read("lua/overseer/template/user/project_tasks.lua"):find("go test", 1, true),
    "project task provider is missing"
  )
  h.pass("Obsidian, request, and task workflow specifications")
end

local phases = {
  core = core,
  tools = tools,
  git = git,
  workflows = workflows,
}

if phase == "all" then
  for _, name in ipairs({ "core", "tools", "git", "workflows" }) do
    phases[name]()
  end
else
  assert(phases[phase], "unknown NVIM_SPEC_PHASE: " .. phase)()
end
