local M = {}

local function create_temp_init_file()
  -- startup sql commands
  local init_cmds = [[
.mode table --wrap 60
.tables
]]

  local tmpfile = vim.fn.tempname() .. '.sql'
  local f, err = io.open(tmpfile, 'w')
  if not f then
    vim.api.nvim_echo({ { 'Failed to create init file: ' .. (err or 'unknown error') } }, true, { err = true })
    return nil
  end

  f:write(init_cmds)
  f:close()
  return tmpfile
end

function M.open(db_path)
  if db_path == nil or db_path == '' then
    vim.api.nvim_echo({ { 'You must provide a path to a database file.\n' } }, true, { err = true })
    return
  end

  if not db_path:match '%.sqlite3?$' and not db_path:match '%.db$' then
    vim.api.nvim_echo({ { 'File is not a valid SQLite database.\n' } }, true, { err = true })
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)

  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local opts = {
    style = 'minimal',
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    border = 'rounded',
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  local init_file = create_temp_init_file()
  if not init_file then
    return
  end
  vim.cmd('term sqlite3 -init ' .. init_file .. ' ' .. db_path)
  vim.cmd 'startinsert'

  -- Escape handling
  -- 1. Set a normal mode map that closes the window
  vim.api.nvim_create_autocmd('TermEnter', {
    buffer = buf,
    once = true,
    callback = function()
      -- After exiting insert mode (first <Esc>), allow the second <Esc> to close
      vim.keymap.set('n', '<Esc>', function()
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end, { buffer = buf, noremap = true, silent = true })
    end,
  })
end

function M.setup()
  -- Command
  vim.api.nvim_create_user_command('SQLiteFloatTerm', function(opts)
    M.open(opts.args)
  end, { nargs = 1, complete = 'file' })

  -- Keymap with prompt
  vim.keymap.set('n', '<leader>sq', function()
    vim.ui.input({ prompt = 'Path to SQLite DB: ' }, function(input)
      if input then
        M.open(input)
      end
    end)
  end, { desc = 'Open SQLite in floating terminal' })
end

function M.open_from_path(path)
  if not path or path == '' then
    vim.api.nvim_echo({ { 'No valid path provided.\n' } }, true, { err = true })
    return
  end
  M.open(vim.fn.fnameescape(path))
end

return M
