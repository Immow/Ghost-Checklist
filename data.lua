data:extend({
	{
		type = "selection-tool",
		name = "ghost-checker",
		icon = "__build-planner__/graphics/icon.png",
		icon_size = 28,
		flags = { "only-in-cursor" },
		subgroup = "tool",
		order = "c[selection-tool]-a[ghost-checker]",
		stack_size = 1,
		selection_color = { r = 0, g = 1, b = 0 },
		alt_selection_color = { r = 1, g = 0, b = 0 },
		selection_cursor_box_type = "entity",
		alt_selection_cursor_box_type = "entity",
		selection_mode = { "buildable-type" },
		alt_selection_mode = { "buildable-type" },
		select = {
			border_color = { 1, 0, 0, 1 },
			cursor_box_type = "entity",
			mode = "entity-ghost"
		},
		alt_select = {
			border_color = { 1, 0, 0, 1 },
			cursor_box_type = "entity",
			mode = "entity-ghost"
		},
	}
})
