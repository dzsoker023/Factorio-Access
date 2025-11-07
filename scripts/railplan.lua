-- railplan.lua
-- Automatic rail extension helper for Factorio 2 mods
-- Supports all rail variants (straight, curved, half-diagonal, legacy, elevated, etc.)
local Viewpoint = require("scripts.viewpoint")
local Speech = require("scripts.speech")

local railplan = {}

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
    front = selected_entity.get_rail_end(defines.rail_direction.front),
    back  = selected_entity.get_rail_end(defines.rail_direction.back)
}

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
        local diff = (goal_dir - current_dir + 8) % 8

        if side == "forward" then
            if diff == 0 then
                best_extension = ext
                break
            elseif diff < smallest_diff then
                best_extension = ext
                smallest_diff = diff
            end

        elseif side == "left" then
            if diff > 0 and diff < 4 and diff < smallest_diff then
                best_extension = ext
                smallest_diff = diff
            end

        elseif side == "right" then
            local adjusted_diff = (current_dir - goal_dir + 8) % 8
            if adjusted_diff > 0 and adjusted_diff < 4 and adjusted_diff < smallest_diff then
                best_extension = ext
                smallest_diff = adjusted_diff
            end
        end
    end

    if not best_extension then
        Speech.speak(pindex, "no valid extension found")
        return
    end

    Speech.speak(pindex, "placing rail: " .. (best_extension.name or selected_entity.name))

    local created = selected_entity.surface.create_entity{
        name = best_extension.name or selected_entity.name,
        position = best_extension.position,
        direction = best_extension.goal_direction,
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
