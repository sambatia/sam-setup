-- Structured-data viewers. Visual alignment is virtual and never rewrites the
-- underlying delimited file.
return {
  {
    "hat0uma/csvview.nvim",
    cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle", "CsvViewInfo" },
    ft = { "csv", "tsv" },
    keys = {
      { "<leader>cv", "<cmd>CsvViewToggle<cr>", desc = "Toggle CSV view" },
    },
    opts = {
      parser = {
        -- Yield frequently enough to keep the UI responsive on large files.
        async_chunksize = 25,
        delimiter = {
          ft = {
            tsv = "\t",
          },
          fallbacks = { ",", "\t", ";", "|", ":" },
        },
        -- Bound malformed multi-line quote scanning.
        max_lookahead = 50,
      },
      view = {
        display_mode = "border",
      },
    },
  },
}
