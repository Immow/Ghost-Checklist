local mod_gui = require("mod-gui")

-- Initialize persistent storage and create buttons for all players
local function create_buttons_for_all_players()
	for _, player in pairs(game.connected_players) do
		create_mod_button(player)
	end
end

script.on_init(function()
	storage.checklists = {}
	storage.cached_inventories = {}
	create_buttons_for_all_players()
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

-- Create button for newly created player
script.on_event(defines.events.on_player_created, function(event)
	local player = game.get_player(event.player_index)
	create_mod_button(player)
end)

-- Toggle selection mode or clear checklist
script.on_event(defines.events.on_gui_click, function(event)
	if event.element.name == "ghost_toggle_button" then
		local player = game.get_player(event.player_index)
		player.cursor_stack.set_stack { name = "ghost-checker", count = 1 }
		player.print("Ghost Checklist: Select an area with ghosts.")
	elseif event.element.name == "ghost_clear" then
		local player = game.get_player(event.player_index)
		storage.checklists[player.index] = nil
		if player.gui.left.ghost_checklist then
			player.gui.left.ghost_checklist.destroy()
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

-- Recalculate how many items player has
local function recalc_checklist(player)
	local checklist = storage.checklists[player.index]
	if not checklist then return end

	local inv = player.get_main_inventory()
	for name, data in pairs(checklist) do
		if inv then
			data.have = inv.get_item_count(name)
			if data.have >= data.need then
				checklist[name] = nil
			end
		else
			-- no inventory, set have to 0 so it still shows up
			data.have = 0
		end
	end

	update_gui(player)
end

-- When player switches to map mode
-- script.on_event(defines.events.on_player_controller_changed, function(event)
-- 	if event.item ~= "ghost-checker" then return end
-- 	storage.cached_inventories = storage.checklists
-- end)

-- Handle selection of ghosts (add to list)
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

	build_gui(player)
	recalc_checklist(player)
end)

-- Update when inventory changes
script.on_event(defines.events.on_player_main_inventory_changed, function(event)
	local player = game.get_player(event.player_index)
	if storage.checklists[player.index] then
		recalc_checklist(player)
	end
end)
