local h = dofile(vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), "helpers.lua"))

for _, path in ipairs({
  "README.md",
  "docs/plugin-audit.md",
  "docs/keymaps.md",
  "docs/update-and-rollback.md",
}) do
  assert(#h.read(path) > 500, path .. " is missing or incomplete")
end

local readme = h.read("README.md")
assert(readme:find("/Users/sam/.config/nvim.backup.20260725%-023926"), "README backup location is missing")
assert(readme:find("tests/run.sh all", 1, true), "README validation command is missing")

local audit = h.read("docs/plugin-audit.md")
for _, classification in ipairs({
  "INSTALL",
  "KEEP EXISTING",
  "SKIP — DUPLICATE",
  "REPLACE WITH",
  "OPTIONAL / NOT CONFIGURED",
}) do
  assert(audit:find(classification, 1, true), "plugin audit classification missing: " .. classification)
end

local keymaps = h.read("docs/keymaps.md")
for _, mapping in ipairs({ "<leader>cv", "<leader>gvo", "<leader>on", "<leader>rr", "<leader>pu" }) do
  assert(keymaps:find(mapping, 1, true), "keymap documentation missing: " .. mapping)
end

local updates = h.read("docs/update-and-rollback.md")
for _, topic in ipairs({
  "last-result.json",
  "safe_plugin_updates_enabled",
  "Lazy! restore",
  "Full configuration recovery",
  "side-effect-free",
  "another Neovim session",
  "runtime smoke",
  "CodeCompanion health",
  "Tree-sitter parsers",
  "leaves `lazy-lock.json` modified",
}) do
  assert(updates:find(topic, 1, true), "update documentation missing: " .. topic)
end

print("PASS production documentation coverage")
