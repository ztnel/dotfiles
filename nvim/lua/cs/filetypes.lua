local extension_map = {
    hpp = "cpp",
    hxx = "cpp",
    hh = "cpp",
    h = "c",
    cla = "c",
    yml = "yaml",
}

vim.filetype.add({
    extension = extension_map,
})

local fallback_group = vim.api.nvim_create_augroup("cs_filetype_fallbacks", { clear = true })

vim.api.nvim_create_autocmd("BufEnter", {
    group = fallback_group,
    callback = function(args)
        if vim.bo[args.buf].filetype ~= "" or vim.bo[args.buf].buftype ~= "" then
            return
        end

        local ext = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(args.buf), ":e")
        local ft = extension_map[ext]
        if ft then
            vim.bo[args.buf].filetype = ft
        end
    end,
})

