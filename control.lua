local mod_gui = require("mod-gui")

-- Initialize persistent storage
script.on_init(function()
	storage.checklists = {}
	storage.cached_inventories = {}
end)

script.on_configuration_changed(function()
	storage.checklists = storage.checklists or {}
	storage.cached_inventories = storage.cached_inventories or {}
end)

-- Create mod button for all players
local function create_mod_button(player)
	local flow = mod_gui.get_button_flow(player)
	if not flow.ghost_toggle_button then
		flow.add {
			type = "sprite-button",
			name = "ghost_toggle_button",
			sprite = "item/blueprint",
			tooltip = "Select Ghosts"
		}
	end
end

-- When a new player is created
script.on_event(defines.events.on_player_created, function(event)
	local player = game.get_player(event.player_index)
	if player then
		create_mod_button(player)
	end
end)

-- When mod is added/updated in an existing save
script.on_configuration_changed(function(cfg)
	for _, player in pairs(game.players) do
		create_mod_button(player)
	end
end)

script.on_event(defines.events.on_tick, function(event)
	if event.tick == 1 then
		for _, player in pairs(game.players) do
			create_mod_button(player)
		end
	end
end)

-- Build GUI window
local function build_gui(player)
	if player.gui.left.ghost_checklist then
		player.gui.left.ghost_checklist.destroy()
	end

	local frame = player.gui.left.add {
		type = "frame",
		name = "ghost_checklist",
		direction = "vertical",
		caption = "Ghost Checklist"
	}
	frame.add { type = "button", name = "ghost_clear", caption = "Clear" }
	frame.add { type = "flow", name = "ghost_list", direction = "vertical" }
end

-- Update GUI contents
local function update_gui(player)
	if not player.gui.left.ghost_checklist then return end
	local flow = player.gui.left.ghost_checklist.ghost_list
	flow.clear()

	local checklist = storage.checklists[player.index]
	if not checklist or next(checklist) == nil then
		flow.add { type = "label", caption = "No items needed." }
		return
	end

	for name, data in pairs(checklist) do
		flow.add {
			type = "label",
			caption = name .. ": " .. data.have .. "/" .. data.need
		}
	end
end

-- Calculate how many items player has (normal view or cached)
local function recalc_checklist(player)
	local checklist = storage.checklists[player.index]
	if not checklist then return end

	local inv_contents
	if player.controller_type == defines.controllers.remote then
		-- Use cached inventory if in remote view
		inv_contents = storage.cached_inventories[player.index] or {}
	else
		-- Normal view: get actual inventory
		local inv = player.get_main_inventory()
		inv_contents = inv and inv.get_contents() or {}
	end

	for name, data in pairs(checklist) do
		data.have = inv_contents[name] or 0
		if data.have >= data.need then
			checklist[name] = nil
		end
	end

	update_gui(player)
end

-- GUI button clicks
script.on_event(defines.events.on_gui_click, function(event)
	local player = game.get_player(event.player_index)
	if event.element.name == "ghost_toggle_button" then
		player.cursor_stack.set_stack { name = "ghost-checker", count = 1 }
		player.print("Ghost Checklist: Select an area with ghosts.")
	elseif event.element.name == "ghost_clear" then
		storage.checklists[player.index] = nil
		if player.gui.left.ghost_checklist then
			player.gui.left.ghost_checklist.destroy()
		end
	end
end)

-- Handle ghost selection
script.on_event(defines.events.on_player_selected_area, function(event)
	if event.item ~= "ghost-checker" then return end
	local player = game.get_player(event.player_index)

	-- If existing checklist exists, merge instead of clearing
	local checklist = storage.checklists[player.index] or {}
	storage.checklists[player.index] = checklist

	for _, entity in pairs(event.entities) do
		if entity.ghost_name then
			local name = entity.ghost_name
			checklist[name] = checklist[name] or { need = 0, have = 0 }
			checklist[name].need = checklist[name].need + 1
		end
	end

	build_gui(player)
	recalc_checklist(player)
end)

-- Inventory change updates
script.on_event(defines.events.on_player_main_inventory_changed, function(event)
	local player = game.get_player(event.player_index)
	if storage.checklists[player.index] then
		recalc_checklist(player)
	end
end)

-- Cache inventory when entering remote view and refresh when leaving
if defines.events.on_player_changed_controller then
	script.on_event(defines.events.on_player_changed_controller, function(event)
		local player = game.get_player(event.player_index)
		if not player or not player.valid then return end

		if player.controller_type == defines.controllers.remote then
			-- Cache current inventory before entering map view
			local inv = player.get_main_inventory()
			if inv then
				storage.cached_inventories[player.index] = inv.get_contents()
			else
				storage.cached_inventories[player.index] = {}
			end
		else
			-- Back to normal, refresh checklist
			if storage.checklists[player.index] then
				recalc_checklist(player)
			end
		end
	end)
end
