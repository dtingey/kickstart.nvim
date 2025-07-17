local M = {}

local terminal_state = {
  buf = nil,
  win = nil,
  is_open = false,
  job_id = nil,
}

function FloatingTerminal()
  -- If terminal is already open, close it (toggle behavior)
  if terminal_state.is_open and vim.api.nvim_win_is_valid(terminal_state.win) then
    vim.api.nvim_win_close(terminal_state.win, false)
    terminal_state.is_open = false
    return
  end

  -- Create buffer if it doesn't exist or is invalid
  if not terminal_state.buf or not vim.api.nvim_buf_is_valid(terminal_state.buf) then
    terminal_state.buf = vim.api.nvim_create_buf(false, true)
    -- Set buffer options for better terminal experience
    vim.api.nvim_set_option_value('bufhidden', 'hide', { buf = terminal_state.buf })
  end

  -- Calculate window dimensions
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  terminal_state.win = vim.api.nvim_open_win(terminal_state.buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
  })

  -- Set transparency for the floating window
  vim.api.nvim_set_option_value('winblend', 0, { win = terminal_state.win })

  -- Set transparent background for the window
  vim.api.nvim_set_option_value('winhighlight', 'Normal:FloatingTermNormal,FloatBorder:FloatingTermBorder', { win = terminal_state.win })

  -- Define highlight groups for transparency
  vim.api.nvim_set_hl(0, 'FloatingTermNormal', { bg = 'none' })
  vim.api.nvim_set_hl(0, 'FloatingTermBorder', { bg = 'none' })

  -- Start terminal if not already running
  local has_terminal = false
  local lines = vim.api.nvim_buf_get_lines(terminal_state.buf, 0, -1, false)
  for _, line in ipairs(lines) do
    if line ~= '' then
      has_terminal = true
      break
    end
  end

  if not has_terminal then
    -- get shell env
    local shell = os.getenv 'SHELL' or '/bin/zsh'
    terminal_state.job_id = vim.fn.jobstart({ shell }, { term = true })
  end

  terminal_state.is_open = true
  vim.cmd 'startinsert'

  -- Set up auto-close on buffer leave
  vim.api.nvim_create_autocmd('BufLeave', {
    buffer = terminal_state.buf,
    callback = function()
      if terminal_state.is_open and vim.api.nvim_win_is_valid(terminal_state.win) then
        vim.api.nvim_win_close(terminal_state.win, false)
        terminal_state.is_open = false
      end
    end,
    once = true,
  })
end

-- Function to explicitly close the terminal and end the job
function CloseFloatingTerminal()
  if terminal_state.is_open and vim.api.nvim_win_is_valid(terminal_state.win) then
    vim.api.nvim_win_close(terminal_state.win, false)
    terminal_state.is_open = false
  end

  if terminal_state.job_id then
    vim.fn.jobstop(terminal_state.job_id)
    terminal_state.job_id = nil
  end

  -- if terminal_state.buf and vim.api.nvim_buf_is_valid(terminal_state.buf) then
  --   vim.api.nvim_buf_delete(terminal_state.buf, { force = true })
  --   terminal_state.buf = nil
  -- end
end

-- Setup and Key mappings
function M.setup()
  vim.keymap.set('n', '<leader>t', FloatingTerminal, { noremap = true, silent = true, desc = 'Toggle floating terminal' })
  vim.keymap.set('t', '<Esc>', function()
    if terminal_state.is_open then
      vim.api.nvim_win_close(terminal_state.win, false)
      terminal_state.is_open = false
    end
  end, { noremap = true, silent = true, desc = 'Close floating terminal from terminal mode' })

  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
      CloseFloatingTerminal()
    end,
  })

  vim.api.nvim_create_autocmd('ExitPre', {
    callback = function()
      CloseFloatingTerminal()
    end,
  })
end

return M
