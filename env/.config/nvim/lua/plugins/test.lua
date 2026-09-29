return {
  {
    "nvim-neotest/neotest",
    dependencies = { "marilari88/neotest-vitest" },
    opts = {
      adapters = {
        -- Option reference: https://github.com/marilari88/neotest-vitest
        ["neotest-vitest"] = {},
      },
    },
  },
}
