local mod_gui = require("mod-gui")

-- Initialize persistent storage on mod init and config change
script.on_init(function()
	storage.checklists = {}
	storage.cached_inventories = {}
	-- Add mod buttons for all existing players on init
	for _, player in pairs(game.players) do
		create_mod_button(player)
	end
end)

script.on_configuration_changed(function()
	storage.checklists = storage.checklists or {}
	storage.cached_inventories = storage.cached_inventories or {}
	-- Add mod buttons for all existing players after update
	for _, player in pairs(game.players) do
		create_mod_button(player)
	end
end)

-- Create mod button
function create_mod_button(player)
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

-- Update cached inventory snapshot for player (if inventory accessible)
local function update_inventory_cache(player)
	local inv = player.get_main_inventory()
	if not inv then return end

	local cached = storage.cached_inventories[player.index] or {}

	local checklist = storage.checklists[player.index]
	if checklist then
		for name, _ in pairs(checklist) do
			cached[name] = inv.get_item_count(name)
		end
	end

	storage.cached_inventories[player.index] = cached
end

-- Recalculate checklist using cached inventory counts
local function recalc_checklist(player)
	local checklist = storage.checklists[player.index]
	if not checklist then return end

	local cached = storage.cached_inventories[player.index] or {}

	for name, data in pairs(checklist) do
		data.have = cached[name] or 0
		if data.have >= data.need then
			checklist[name] = nil
		end
	end
	update_gui(player)
end

-- Add mod button when player joins (existing saves)
script.on_event(defines.events.on_player_created, function(event)
	local player = game.get_player(event.player_index)
	create_mod_button(player)
end)
script.on_event(defines.events.on_player_joined_game, function(event)
	local player = game.get_player(event.player_index)
	create_mod_button(player)
end)

-- Handle button clicks
script.on_event(defines.events.on_gui_click, function(event)
	if event.element.name == "ghost_toggle_button" then
		local player = game.get_player(event.player_index)
		-- Give selection tool to player
		player.cursor_stack.set_stack { name = "ghost-checker", count = 1 }
		player.print("Ghost Checklist: Select an area with ghosts.")
	elseif event.element.name == "ghost_clear" then
		local player = game.get_player(event.player_index)
		storage.checklists[player.index] = nil
		storage.cached_inventories[player.index] = nil
		if player.gui.left.ghost_checklist then
			player.gui.left.ghost_checklist.destroy()
		end
	end
end)

-- When player selects ghosts with the selection tool (adds cumulatively)
script.on_event(defines.events.on_player_selected_area, function(event)
	if event.item ~= "ghost-checker" then return end

	local player = game.get_player(event.player_index)
	storage.checklists[player.index] = storage.checklists[player.index] or {}
	local checklist = storage.checklists[player.index]

	for _, entity in pairs(event.entities) do
		if entity.ghost_name then
			local name = entity.ghost_name
			checklist[name] = checklist[name] or { need = 0, have = 0 }
			checklist[name].need = checklist[name].need + 1
		end
	end

	update_inventory_cache(player)
	build_gui(player)
	recalc_checklist(player)
end)

-- When inventory changes (normal view), update cache and recalc checklist
script.on_event(defines.events.on_player_main_inventory_changed, function(event)
	local player = game.get_player(event.player_index)
	if storage.checklists[player.index] then
		update_inventory_cache(player)
		recalc_checklist(player)
	end
end)
