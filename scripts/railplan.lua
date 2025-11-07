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
   local text = text
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
            script.on_event(defines.events.on_tick, nil) -- leiratkozás, hogy ne fusson tovább
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
rail_ends .front.move_to_segment_end()
rail_ends .back.move_to_segment_end()
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


    local current_dir = chosen_end.direction
    local best_extension
    local smallest_diff = math.huge

    for _, ext in pairs(extensions) do
        local goal_dir = ext.goal.direction
   --      if current_dir < 4 and goal_dir > 10 then goal_dir = goal_dir-16 
   --  elseif current_dir > 12 and goal_dir < 4 then goal_dir = goal_dir+16 end
   --      local diff = goal_dir - current_dir
local diff = (goal_dir - current_dir + 16) % 16

        if side == "forward" then
            if diff == 0 and ext.direction == current_dir  then
                best_extension = ext
                break
            elseif diff < smallest_diff then
                best_extension = ext
                smallest_diff = diff
            end

elseif side == "left" then
    local turn = (goal_dir - current_dir + 16) % 16
    -- balra jellemzően 12–15 (negatív, azaz “nagyobb” a ciklusban)
    if (turn >= 12 or turn <= 2) and turn > 0 and turn < smallest_diff then
        best_extension = ext
        smallest_diff = turn
    end

elseif side == "right" then
    local turn = (goal_dir - current_dir + 16) % 16
    -- jobbra jellemzően 1–4 között
    if turn > 0 and turn < 4 and turn < smallest_diff then
        best_extension = ext
        smallest_diff = turn
    end
end
end

    if not best_extension then
        Speech.speak(pindex, "no valid extension found")
        return
    end

    table.insert(extensions, best_extension)
totextbox(extensions)


    Speech.speak(pindex, "placing rail: " .. (best_extension.name or selected_entity.name))

    local created = selected_entity.surface.create_entity{
        name = best_extension.name or selected_entity.name,
        position = best_extension.position,
        direction = best_extension.direction,
        force = selected_entity.force,
        raise_built = true
    }

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
