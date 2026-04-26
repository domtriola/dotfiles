return {
	{
		"saghen/blink.cmp",
		opts = {
			-- https://cmp.saghen.dev/configuration/keymap
			keymap = {
				["<CR>"] = { "fallback" },
				["<Tab>"] = { "select_and_accept", "fallback" },
			},

			-- https://cmp.saghen.dev/configuration/completion#list
			completion = {
				list = {
					selection = {
						preselect = true,
						auto_insert = false,
					},
				},
			},
		},
	},
}
