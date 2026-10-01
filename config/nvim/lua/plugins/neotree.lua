return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    default_component_configs = {
      indent = {
        with_markers = false, -- Removes the vertical tree lines
        indent_size = 1, -- Minimum nesting space
        padding = 0, -- Removes the space before icons/names
      },
      icon = {
        folder_closed = "",
        folder_open = "",
        folder_empty = "󰜌",
      },
    },
  },
}
