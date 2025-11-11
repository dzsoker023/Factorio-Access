-- railplan.lua
-- Automatic rail extension helper for Factorio 2 mods
-- Supports all rail variants (straight, curved, half-diagonal, legacy, elevated, etc.)
local Viewpoint = require("scripts.viewpoint")
local Speech = require("scripts.speech")

local railplan = {}

function totextbox(what)
    local function table_to_string(tbl, indent)
        indent = indent or 0
        local result = ""
        local prefix = string.rep("  ", indent)
        
        for k, v in pairs(tbl) do
            if type(v) == "table" then
                result = result .. prefix .. tostring(k) .. ":\n" .. table_to_string(v, indent + 1)
            else
                result = result .. prefix .. tostring(k) .. " = " .. tostring(v) .. "\n"
            end
        end
        return result
    end

    local text 
    if type(what) == "table" then
        text = table_to_string(what)
    else
        text = tostring(what)
    end
    storage.players[1].text_field_open = true
    local frame = game.get_player(1).gui.screen.add({ type = "frame", name = "copy"})
    frame.bring_to_front()
    frame.force_auto_center()
    frame.focus()
    local input = frame.add({ type = "textfield", name = "input", text = text })
    input.focus()
    local remove_tick = game.tick + (5 * 60)
    script.on_event(defines.events.on_tick, function(event)
        if event.tick >= remove_tick then
            if frame and frame.valid then
                frame.destroy()
            end
            script.on_event(defines.events.on_tick, nil)
        end
    end)
    return frame
end

-- Helper: calculate distance between two positions
local function distance(p1, p2)
    local dx, dy = p1.x - p2.x, p1.y - p2.y
    return math.sqrt(dx * dx + dy * dy)
end

-- Helper: check if entity is some type of rail
local function is_rail_entity(entity)
    if not entity or not entity.valid then return false end
    local name = entity.name or ""
    return string.find(name, "rail") ~= nil
end

-- Internal: main placement logic
local function extend(player, selected_entity, cursor_pos, side)
    local pindex = player.index

    Speech.speak(pindex, "railplan.extend start: " .. side)

    if not is_rail_entity(selected_entity) then
        Speech.speak(pindex, "no rail selected")
        return
    end

    local rail_ends = {
        front = selected_entity.get_rail_segment_end(defines.rail_direction.front).get_rail_end(defines.rail_direction.front),
        back  = selected_entity.get_rail_segment_end(defines.rail_direction.back).get_rail_end(defines.rail_direction.front)
    }
    rail_ends.front.move_to_segment_end()
    rail_ends.back.move_to_segment_end()
    
    if not (rail_ends.front and rail_ends.back) then
        Speech.speak(pindex, "no rail ends found")
        return
    end

    -- choose closer end
    local front_dist = distance(rail_ends.front.location.position, cursor_pos)
    local back_dist  = distance(rail_ends.back.location.position, cursor_pos)
    local chosen_end = front_dist < back_dist and rail_ends.front or rail_ends.back

    Speech.speak(pindex, "chosen end: " .. (front_dist < back_dist and "front" or "back"))

    -- get possible extensions
    local extensions = chosen_end.get_rail_extensions("rail")
    if not extensions or #extensions == 0 then
        Speech.speak(pindex, "no rail extensions available")
        return
    end

    local current_dir = chosen_end.location.direction  -- This is defines.direction (0-15)
    local best_extension = nil
    local best_diff = nil

    -- Debug: print all extensions
    Speech.speak(pindex, "current_dir: " .. tostring(current_dir))
    
    for _, ext in pairs(extensions) do
        local goal_dir = ext.goal.direction
        
        -- The key insight: we need to compare goal_dir with current_dir
        -- goal_dir is where the rail will END UP pointing
        -- Positive diff = turning left (counter-clockwise)
        -- Negative diff (or > 8) = turning right (clockwise)
        local diff = (goal_dir - current_dir + 16) % 16
        
        Speech.speak(pindex, string.format("ext: goal_dir=%d, diff=%d", goal_dir, diff))

        if side == "forward" then
            -- Forward: prefer straight ahead (diff == 0)
            if diff == 0 and chosen_end.location.rail_layer == ext.goal.rail_layer then
                best_extension = ext
                best_diff = 0
                break
            -- Also accept very small deviations (1 step either direction)
            elseif best_diff == nil or diff == 1 or diff == 15 and chosen_end.location.rail_layer == ext.goal.rail_layer then
                if best_diff == nil or diff < best_diff or (diff == 15 and (best_diff == nil or best_diff > 1)) then
                    best_extension = ext
                    best_diff = diff
                end
            end

        elseif side == "left" then
            -- Left turn: counter-clockwise = DECREASING direction numbers
            -- Calculate the turn: negative = left, positive = right, 0 = straight
            -- Using signed difference with wrapping
            local turn_diff = (goal_dir - current_dir + 16) % 16
            -- Convert to signed: 0-8 = right turns, 9-15 = left turns (16-x steps left)
            local is_left_turn = turn_diff > 8 and turn_diff < 16
            local turn_magnitude = is_left_turn and (16 - turn_diff) or 999
            
            Speech.speak(pindex, string.format("LEFT check: goal=%d, turn_diff=%d, is_left=%s, magnitude=%d", 
                goal_dir, turn_diff, tostring(is_left_turn), turn_magnitude))
            
            if is_left_turn then
                if best_diff == nil or turn_magnitude < best_diff then
                    best_extension = ext
                    best_diff = turn_magnitude
                end
            end

        elseif side == "right" then
            -- Right turn: clockwise = INCREASING direction numbers
            -- Calculate the turn: 1-8 = right turns, 9-15 = left turns (wrapping)
            local turn_diff = (goal_dir - current_dir + 16) % 16
            local is_right_turn = turn_diff > 0 and turn_diff <= 8
            local turn_magnitude = is_right_turn and turn_diff or 999
            
            if is_right_turn then
                if best_diff == nil or turn_magnitude < best_diff then
                    best_extension = ext
                    best_diff = turn_magnitude
                end
            end

        elseif side == "ramp" then
            if chosen_end.location.rail_layer ~= ext.goal.rail_layer then
                best_extension = ext
                break
            end
        end
    end

    if not best_extension then
        Speech.speak(pindex, "no valid extension found for " .. side)
        return
    end

    table.insert(extensions,best_extension)
--totextbox(extensions)

    Speech.speak(pindex, string.format("placing rail: %s (diff: %s)", 
        best_extension.name or selected_entity.name, 
        tostring(best_diff)))


    local plan_ghost = {
        name = "entity-ghost", 
        inner_name = best_extension.name or selected_entity.name,
        position = best_extension.position,
        direction = best_extension.direction,
        force = selected_entity.force,
        raise_built = true
    }
    local plan = {
        name = best_extension.name or selected_entity.name,
        position = best_extension.position,
        direction = best_extension.direction,
        force = selected_entity.force,
        raise_built = true
    }

local required_item = nil
local required_number=nil
if best_extension.name == "rail-ramp" then
    required_item = "rail-ramp"
    required_number=1
else
    required_item = "rail"
    if best_extension.name == "straight-rail" or best_extension.name == "elevated-straight-rail" then required_number = 1
    elseif best_extension.name == "curved-rail-a" or best_extension.name == "elevated-curved-rail-a" or best_extension.name == "curved-rail-b" or best_extension.name == "elevated-curved-rail-b" then required_number = 3
    elseif best_extension.name == "half-diagonal-rail" or best_extension.name == "elevated-half-diagonal-rail" then required_number = 2
    else required_number=1
    end
end

local stack = storage.players[pindex].cursor_stack
local stack2 = nil
       if not (stack.valid and stack.valid_for_read and stack.name == required_item  and stack.count >= required_number) then
      --Check if the inventory has enough
      if storage.players[pindex].inventory.lua_inventory.get_item_count(required_item) < required_number then
         --game.get_player(pindex).play_sound({ path = "utility/cannot_build" })
         --printout("You need at least 10 rails in your inventory to build this turn.", pindex)
         return
      else
         --Take from the inventory.
         stack2 = storage.players[pindex].inventory.lua_inventory.find_item_stack(required_item)
         storage.players[pindex].cursor_stack.swap_stack(stack2)
         stack = storage.players[pindex].cursor_stack
         storage.players[pindex].inventory.max = #storage.players[pindex].inventory.lua_inventory
      end
   end
   local created = false
if selected_entity.surface.can_place(plan) then 
game.get_player(pindex).cursor_stack.count = game.get_player(pindex).cursor_stack.count - required_number
selected_entity.surface.create_entity(plan)
created=true
end

    if not created then
        Speech.speak(pindex, "rail placement failed")
    else
        Speech.speak(pindex, "rail placement success")

    end
end

-- Public: extend left
function railplan.extend_left(pindex)
    local player = game.get_player(pindex)
    if not player then return end
    local entity = player.selected
    if not entity then
        Speech.speak(player.index, "no selected entity")
        return
    end

    local vp = Viewpoint.get_viewpoint(pindex)
    local cursor_pos = vp and vp:get_cursor_pos() or entity.position
    extend(player, entity, cursor_pos, "left")
end

-- Public: extend forward
function railplan.extend_forward(pindex)
    local player = game.get_player(pindex)
    if not player then return end
    local entity = player.selected
    if not entity then
        Speech.speak(player.index, "no selected entity")
        return
    end

    local vp = Viewpoint.get_viewpoint(pindex)
    local cursor_pos = vp and vp:get_cursor_pos() or entity.position
    extend(player, entity, cursor_pos, "forward")
end

-- Public: extend ramp
function railplan.extend_ramp(pindex)
    local player = game.get_player(pindex)
    if not player then return end
    local entity = player.selected
    if not entity then
        Speech.speak(player.index, "no selected entity")
        return
    end

    local vp = Viewpoint.get_viewpoint(pindex)
    local cursor_pos = vp and vp:get_cursor_pos() or entity.position
    extend(player, entity, cursor_pos, "ramp")
end

-- Public: extend right
function railplan.extend_right(pindex)
    local player = game.get_player(pindex)
    if not player then return end
    local entity = player.selected
    if not entity then
        Speech.speak(player.index, "no selected entity")
        return
    end

    local vp = Viewpoint.get_viewpoint(pindex)
    local cursor_pos = vp and vp:get_cursor_pos() or entity.position
    extend(player, entity, cursor_pos, "right")
end

return railplan