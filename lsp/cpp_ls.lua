---@brief
---
--- https://github.com/CppCXY/cpp_ls
--- A C/C++ language server written in Rust (with special toolchain support for CUDA `.cu`/`.cuh`)
---
--- It implements its own preprocessor, parser, semantic analysis, and LSP layer in a single binary
--- without requiring `clangd`, a compiler daemon, or `compile_commands.json` (plain source projects
--- work out of the box, while `.cppls.toml` or `compile_commands.json` can supply flags). It expands
--- macros, resolves active conditional branches, and inlines `#include`s so completion, hover,
--- diagnostics, definition/references, rename, call hierarchy, inlay hints, and format-string
--- awareness (`printf` / `std::format` / `fmt::format`) work even on uncompiled or half-typed code.
--- It also includes a built-in fallback formatter (`cpp_formatter`) that reads `.clang-format`
--- presets/options, though `clang-format` is recommended for production formatting.
---
--- Additional features:
--- - Switch Header/Source: Provides fast switching between source and header files (`.cpp` <-> `.h`, `.cppm` <-> `.cpp`).
--- - Inactive Region Dimming: Calculates active `#if` / `#ifdef` branch conditions and highlights or
---   dims inactive preprocessor code regions in real time.
--- - Built-in Formatter: Includes a fallback formatter (`cpp_formatter`) that reads `.clang-format`
---   options, while supporting external formatting integration as needed.

---@param client vim.lsp.Client
---@param bufnr  integer
local function switch_source_header(client, bufnr)
  local method_name = 'textDocument/switchSourceHeader'
  local params = vim.lsp.util.make_text_document_params(bufnr)
  client:request(method_name, params, function (err, result)
    if err then
      error(tostring(err))
    end
    if not result then
      vim.notify('corresponding file cannot be determined')
      return
    end
    vim.cmd.edit(vim.uri_to_fname(result))
  end, bufnr
  )
end

local inactive_ns = vim.api.nvim_create_namespace("cpp_ls_inactive_regions")

vim.api.nvim_set_hl(0, "CppLsInactiveRegion", { fg = "#5c6370", italic = true })

---@param client vim.lsp.Client
---@param bufnr  integer
local function setup_inactive_regions(client, bufnr)
  client.handlers["$/inactiveRegions"] = function (_, result, ctx)
    if ctx.bufnr ~= bufnr or not result or not result.regions then
      return
    end

    vim.api.nvim_buf_clear_namespace(bufnr, inactive_ns, 0, -1)

    for _, region in ipairs(result.regions) do
      local start_line = region.range["start"].line
      local end_line = region.range["end"].line
      local start_col = region.range["start"].character
      local end_col = region.range["end"].character

      -- 跨行或单行高亮
      for line = start_line, end_line do
        local col_s = (line == start_line) and start_col or 0
        local col_e = (line == end_line) and end_col or -1

        vim.api.nvim_buf_set_extmark(bufnr, inactive_ns, line, col_s, {
          end_line = line,
          end_col = col_e == -1 and nil or col_e,
          hl_group = "CppLsInactiveRegion",
          hl_eol = true
        })
      end
    end
  end
end

---@type vim.lsp.Config
return {
  cmd = { 'cpp_ls' },
  filetypes = { 'c', 'cpp', 'cuda' },
  root_markers = { 'compile_commands.json', 'build_database.json', '.git', '.cppls.toml' },
  workspace_required = false,
  on_attach = function (client, bufnr)
    vim.api.nvim_buf_create_user_command(bufnr, 'LspCpplsSwitchSourceHeader', function ()
      switch_source_header(client, bufnr)
    end, { desc = 'Switch between source/module/header' }
    )
    setup_inactive_regions(client, bufnr)
  end
}
