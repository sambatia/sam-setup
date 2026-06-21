local map = vim.keymap.set

map('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Clear search highlight' })
map('n', '<leader>w', '<cmd>write<CR>', { desc = 'Save' })
map('n', '<leader>q', '<cmd>quit<CR>', { desc = 'Quit' })

-- Window navigation
map('n', '<C-h>', '<C-w>h', { desc = 'Window left' })
map('n', '<C-j>', '<C-w>j', { desc = 'Window down' })
map('n', '<C-k>', '<C-w>k', { desc = 'Window up' })
map('n', '<C-l>', '<C-w>l', { desc = 'Window right' })

-- Diagnostics (0.11+ API)
map('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Diagnostic float' })
map('n', '[d', function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = 'Prev diagnostic' })
map('n', ']d', function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = 'Next diagnostic' })
