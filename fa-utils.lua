--Here: Utility functions called by other files. Examples include distance and position calculations, string processing.
local util = require('util')
local dirs = defines.direction

local fa_utils = {}

function fa_utils.center_of_tile(pos)
   return {x = math.floor(pos.x)+0.5, y = math.floor(pos.y)+ 0.5}
end

function fa_utils.add_position(p1,p2)
   return { x = p1.x + p2.x, y = p1.y + p2.y}
end

function fa_utils.sub_position(p1,p2)
   return { x = p1.x - p2.x, y = p1.y - p2.y}
end

function fa_utils.mult_position(p,m)
   return { x = p.x * m, y = p.y * m }
end

function fa_utils.offset_position(oldpos,direction,distance)
   if direction == defines.direction.north then
      return { x = oldpos.x, y = oldpos.y - distance}
   elseif direction == defines.direction.south then
      return { x = oldpos.x, y = oldpos.y + distance}
   elseif direction == defines.direction.east then
      return { x = oldpos.x + distance, y = oldpos.y}
   elseif direction == defines.direction.west then
      return { x = oldpos.x - distance, y = oldpos.y}
   elseif direction == defines.direction.northwest then
      return { x = oldpos.x - distance, y = oldpos.y - distance}
   elseif direction == defines.direction.northeast then
      return { x = oldpos.x + distance, y = oldpos.y - distance}
   elseif direction == defines.direction.southwest then
      return { x = oldpos.x - distance, y = oldpos.y + distance}
   elseif direction == defines.direction.southeast then
      return { x = oldpos.x + distance, y = oldpos.y + distance}
   end
end

function fa_utils.dir_dist(pos1,pos2)
   local x1 = pos1.x
   local x2 = pos2.x
   local dx = x2 - x1
   local y1 = pos1.y
   local y2 = pos2.y
   local dy = y2 - y1
   if dx == 0 and dy == 0 then
      return {8,0}
   end
   local dir = math.atan2(dy,dx) --scaled -pi to pi 0 being east
   dir = dir + math.sin(4*dir)/4 --bias towards the diagonals
   dir = dir/math.pi -- now scaled as -0.5 north, 0 east, 0.5 south
   dir=math.floor(dir*defines.direction.south + defines.direction.east + 0.5) --now scaled correctly
   dir=dir%(2*defines.direction.south) --now wrapped correctly
   local dist = math.sqrt(dx*dx+dy*dy)
   return {dir, dist}
end

function fa_utils.dir(pos1,pos2)
   return fa_utils.dir_dist(pos1,pos2)[1]
end

function fa_utils.direction(pos1, pos2)
   return fa_utils.direction_lookup(fa_utils.dir(pos1,pos2))
end

function fa_utils.distance(pos1, pos2)
   return fa_utils.dir_dist( pos1, pos2)[2]
end

function fa_utils.squared_distance(pos1, pos2)
   local offset = {x = pos1.x - pos2.x, y = pos1.y - pos2.y}
   local result = offset.x * offset.x + offset.y * offset.y
   return result
end

--[[
* Returns the direction of that entity from this entity, with a bias against the 4 cardinal directions so that you can align with them more easily.
* Returns 1 of 8 main directions, based on the ratios of the x and y distances. 
* The deciding ratio is 1 to 4, meaning that for an object that is 100 tiles north, it can be offset by up to 25 tiles east or west before it stops being counted as "directly" in the north. 
* The arctangent of 1/4 is about 14 degrees, meaning that the field of view that directly counts as a cardinal direction is about 30 degrees, while for a diagonal direction it is about 60 degrees.]]
function fa_utils.get_direction_biased(pos_that,pos_this)
   local diff_x = pos_that.x - pos_this.x
   local diff_y = pos_that.y - pos_this.y
   local dir = -1
   
   if math.abs(diff_x) > 4 * math.abs(diff_y) then --along east-west
      if diff_x > 0 then 
	     dir = defines.direction.east 
	  else 
	     dir = defines.direction.west 
	  end
   elseif math.abs(diff_y) > 4 * math.abs(diff_x) then --along north-south
      if diff_y > 0 then 
	     dir = defines.direction.south 
	  else 
	     dir = defines.direction.north 
	  end
   else --along diagonals
      if diff_x > 0 and diff_y > 0 then
	     dir = defines.direction.southeast
      elseif diff_x > 0 and diff_y < 0 then
	     dir = defines.direction.northeast
      elseif diff_x < 0 and diff_y > 0 then
	     dir = defines.direction.southwest
	  elseif diff_x < 0 and diff_y < 0 then
	     dir = defines.direction.northwest
	  elseif diff_x == 0 and diff_y == 0 then
        dir = defines.direction.north
     else
	     dir = -2
	  end
   end

   if dir < 0 then
      dir = dirs.north
   end
   return dir
end

--[[
* Returns the direction of that entity from this entity, with each of 8 directions getting equal representation.
* Returns 1 of 8 main directions, based on the ratios of the x and y distances. 
* The deciding ratio is 1 to 2.5, meaning that for an object that is 25 tiles north, it can be offset by up to 10 tiles east or west before it stops being counted as "directly" in the north. 
* The arctangent of 1/2.5 is about 22 degrees, meaning that the field of view that directly counts as a cardinal direction is about 44 degrees, while for a diagonal direction it is about 46 degrees.]]
function fa_utils.get_direction_precise(pos_that,pos_this)
   local diff_x = pos_that.x - pos_this.x
   local diff_y = pos_that.y - pos_this.y
   local dir = -1
   
   if math.abs(diff_x) > 2.5 * math.abs(diff_y) then --along east-west
      if diff_x > 0 then 
	     dir = defines.direction.east 
	  else 
	     dir = defines.direction.west 
	  end
   elseif math.abs(diff_y) > 2.5 * math.abs(diff_x) then --along north-south
      if diff_y > 0 then 
	     dir = defines.direction.south 
	  else 
	     dir = defines.direction.north 
	  end
   else --along diagonals
      if diff_x > 0 and diff_y > 0 then
	     dir = defines.direction.southeast
      elseif diff_x > 0 and diff_y < 0 then
	     dir = defines.direction.northeast
      elseif diff_x < 0 and diff_y > 0 then
	     dir = defines.direction.southwest
	  elseif diff_x < 0 and diff_y < 0 then
	     dir = defines.direction.northwest
	  elseif diff_x == 0 and diff_y == 0 then
        dir = defines.direction.north
     else
	     dir = -2
	  end
   end

   if dir < 0 then
      dir = dirs.north
   end
   return dir
end

--Converts an input direction into a localised string. 
--Note: Directions are integeres but we need to use only defines because they will change in update 2.0. Todo: localise error cases.
function fa_utils.direction_lookup(dir)
   local reading = "unknown"
   if dir < 0 then
      return "unknown direction ID " .. dir
   end
   if dir >= dirs.north and dir <= dirs.northwest then
      return game.direction_to_string(dir)
   else
      if dir == 99 then --Defined by mod 
         reading = "Here"
      else
         reading = "unknown direction ID " .. dir
      end
      return reading
   end
end

function fa_utils.rotate_90(dir)
   return (dir + dirs.east) % (2 * dirs.south)
end

function fa_utils.rotate_180(dir)
   return (dir + dirs.south) % (2 * dirs.south)
end

function fa_utils.rotate_270(dir)
   return (dir + dirs.east * 3) % (2 * dirs.south)
end

function fa_utils.reset_rotation(pindex)
   players[pindex].building_direction = dirs.north
end

--Returns the length and width of the entity version of an item. Todo: review and cleanup direction defines.
function fa_utils.get_tile_dimensions(item, dir)
   if item.place_result ~= nil then
      local dimensions = item.place_result.selection_box
      x = math.ceil(dimensions.right_bottom.x - dimensions.left_top.x)
      y = math.ceil(dimensions.right_bottom.y - dimensions.left_top.y)
      if (dir/2)%2 == 0 then
         return {x = x, y = y}
      else
         return {x = y, y = x}
      end
   end
   return {x = 0, y = 0}
end


--Small utility function for getting an entity's footprint area using just its name.
function fa_utils.get_ent_area_from_name(ent_name,pindex)
   -- local ents = game.get_player(pindex).surface.find_entities_filtered{name = ent_name, limit = 1}
   -- if #ents == 0 then
      -- return -1
   -- else
      -- return ents[1].tile_height * ents[1].tile_width
   -- end
   return game.entity_prototypes[ent_name].tile_width * game.entity_prototypes[ent_name].tile_height
end

--Returns true/false on whether an entity is located within a defined area.
function fa_utils.is_ent_inside_area(ent_name, area_left_top, area_right_bottom, pindex)
   local ents = game.get_player(pindex).surface.find_entities_filtered{name = ent_name, area = {area_left_top,area_right_bottom}, limit = 1}
   return #ents > 0
end

--Returns the map position of the northwest corner of an entity.
function fa_utils.get_ent_northwest_corner_position(ent)
   if ent.valid == false or ent.tile_width == nil then
      return ent.position
   end
   local width  = ent.tile_width
   local height = ent.tile_height
   if ent.direction == dirs.east or ent.direction == dirs.west then
      width  = ent.tile_height
      height = ent.tile_width
   end
   local pos = fa_utils.center_of_tile({x = ent.position.x - math.floor(width/2), y = ent.position.y - math.floor(height/2)})
   --rendering.draw_rectangle{color = {0.75,1,1,0.75}, surface = ent.surface, draw_on_ground = true, players = nil, width = 2, left_top = {math.floor(pos.x)+0.05,math.floor(pos.y)+0.05}, right_bottom = {math.ceil(pos.x)-0.05,math.ceil(pos.y)-0.05}, time_to_live = 30}
   return pos
end

--Reports which part of the selected entity has the cursor. E.g. southwest corner, center...
function fa_utils.get_entity_part_at_cursor(pindex)
	 local p = game.get_player(pindex)
	 local x = players[pindex].cursor_pos.x
	 local y = players[pindex].cursor_pos.y
    local excluded_names = {"character", "flying-text", "highlight-box", "combat-robot", "logistic-robot", "construction-robot", "rocket-silo-rocket-shadow"}
	 local ents = p.surface.find_entities_filtered{position = {x = x,y = y}, name = excluded_names, invert = true}
	 local north_same = false
	 local south_same = false
	 local east_same = false
	 local west_same = false
	 local location = nil

    --First check if there is an entity at the cursor
	 if #ents > 0 then
      --Choose something else if ore is selected
      local preferred_ent = ents[1]
      for i, ent in ipairs(ents) do
         if ent.valid and ent.type ~= "resource" then
            preferred_ent = ent
         end
      end
      p.selected = preferred_ent

		--Report which part of the entity the cursor covers.
      rendering.draw_circle{color = {1, 0.0, 0.5},radius = 0.1,width = 2,target = {x = x+0 ,y = y-1}, surface = p.surface, time_to_live = 30}
      rendering.draw_circle{color = {1, 0.0, 0.5},radius = 0.1,width = 2,target = {x = x+0 ,y = y+1}, surface = p.surface, time_to_live = 30}
      rendering.draw_circle{color = {1, 0.0, 0.5},radius = 0.1,width = 2,target = {x = x-1 ,y = y-0}, surface = p.surface, time_to_live = 30}
      rendering.draw_circle{color = {1, 0.0, 0.5},radius = 0.1,width = 2,target = {x = x+1 ,y = y-0}, surface = p.surface, time_to_live = 30}

		local ent_north = p.surface.find_entities_filtered{position = {x = x,y = y-1}, name = excluded_names, invert = true}
		if     #ent_north > 0 and ent_north[1].unit_number == preferred_ent.unit_number then north_same = true
      elseif #ent_north > 1 and ent_north[2].unit_number == preferred_ent.unit_number then north_same = true
      elseif #ent_north > 2 and ent_north[3].unit_number == preferred_ent.unit_number then north_same = true end
		local ent_south = p.surface.find_entities_filtered{position = {x = x,y = y+1}, name = excluded_names, invert = true}
		if     #ent_south > 0 and ent_south[1].unit_number == preferred_ent.unit_number then south_same = true
      elseif #ent_south > 1 and ent_south[2].unit_number == preferred_ent.unit_number then south_same = true
      elseif #ent_south > 2 and ent_south[3].unit_number == preferred_ent.unit_number then south_same = true end
		local ent_east = p.surface.find_entities_filtered{position = {x = x+1,y = y}, name = excluded_names, invert = true}
		if     #ent_east > 0 and ent_east[1].unit_number == preferred_ent.unit_number then east_same = true
      elseif #ent_east > 1 and ent_east[2].unit_number == preferred_ent.unit_number then east_same = true
      elseif #ent_east > 2 and ent_east[3].unit_number == preferred_ent.unit_number then east_same = true end
		local ent_west = p.surface.find_entities_filtered{position = {x = x-1,y = y}, name = excluded_names, invert = true}
		if     #ent_west > 0 and ent_west[1].unit_number == preferred_ent.unit_number then west_same = true
      elseif #ent_west > 1 and ent_west[2].unit_number == preferred_ent.unit_number then west_same = true
      elseif #ent_west > 2 and ent_west[3].unit_number == preferred_ent.unit_number then west_same = true end

		if north_same and south_same then
		   if east_same and west_same then
			  location = "center"
		   elseif east_same and not west_same then
			  location = "west edge"
		   elseif not east_same and west_same then
			  location = "east edge"
		   elseif not east_same and not west_same then
			  location = "middle"
		   end
		elseif north_same and not south_same then
		   if east_same and west_same then
			  location = "south edge"
		   elseif east_same and not west_same then
			  location = "southwest corner"
		   elseif not east_same and west_same then
			  location = "southeast corner"
		   elseif not east_same and not west_same then
			  location = "south tip"
		   end
		elseif not north_same and south_same then
		   if east_same and west_same then
			  location = "north edge"
		   elseif east_same and not west_same then
			  location = "northwest corner"
		   elseif not east_same and west_same then
			  location = "northeast corner"
		   elseif not east_same and not west_same then
			  location = "north tip"
		   end
		elseif not north_same and not south_same then
		   if east_same and west_same then
			  location = "middle"
		   elseif east_same and not west_same then
			  location = "west tip"
		   elseif not east_same and west_same then
			  location = "east tip"
		   elseif not east_same and not west_same then
			  location = "all"
		   end
		end
	 end
	 return location
end

--For a list of edge points of an aggregate entity, returns the nearest one.
function fa_utils.nearest_edge(edges, pos, name)
   local pos = table.deepcopy(pos)
   if name == "forest" then
      pos.x = pos.x / 8 
      pos.y = pos.y / 8 
   end
   local result = {}
   local min = math.huge
   for str, b in pairs(edges) do
      local edge_pos = fa_utils.str2pos(str)
      local d = util.distance(pos, edge_pos)
      if d < min then
         result = edge_pos
         min = d
      end
   end
   if name == "forest" then
      result.x = result.x * 8 - 4
      result.y = result.y * 8 - 4
   end
   return result
end

function fa_utils.scale_area(area, factor)
   result = table.deepcopy(area)
   result.left_top.x = area.left_top.x * factor
   result.left_top.y = area.left_top.y * factor
   result.right_bottom.x = area.right_bottom.x * factor
   result.right_bottom.y = area.right_bottom.y * factor
   return result
end

--todo: use defines directions here
function fa_utils.area_edge(area,dir,pos,name)
   local adjusted_area = table.deepcopy(area)
   if name == "forest" then
      local chunk_size = 8
      adjusted_area.left_top.x = adjusted_area.left_top.x / chunk_size
      adjusted_area.left_top.y = adjusted_area.left_top.y / chunk_size
      adjusted_area.right_bottom.x = adjusted_area.right_bottom.x / chunk_size
      adjusted_area.right_bottom.y = adjusted_area.right_bottom.y / chunk_size
   end
   if dir == 0 then
      if adjusted_area.left_top.y == math.floor(pos.y) then
         return true
      else
         return false
      end
   elseif dir == 2 then
      if adjusted_area.right_bottom.x == math.ceil( .001 + pos.x) then
         return true
      else
         return false
      end
   elseif dir == 4 then
      if adjusted_area.right_bottom.y == math.ceil(.001+pos.y) then
         return true
      else
         return false
      end

   elseif dir == 6 then
      if adjusted_area.left_top.x == math.floor(pos.x) then
         return true
      else
         return false
      end
   end
end

function fa_utils.table_concat (T1, T2)
   if T2 == nil then
      return
   end
   if T1 == nil then
      T1 = {}
   end
   for i, v in pairs(T2) do
         table.insert(T1, v)
   end
end

function fa_utils.pos2str (pos)
   return pos.x .. " " .. pos.y
end

function fa_utils.str2pos(str)
   local t = {}
   for s in string.gmatch(str, "([^%s]+)") do
      table.insert(t, s)
   end
      return {x = t[1], y = t[2]}
end

function fa_utils.breakup_string(str)
   result = {""}
   if table_size(str) > 20 then
      local i = 0
      while i < #str do
         if i%20 == 0 then
         table.insert(result, {""})
         end
         ---@diagnostic disable-next-line: param-type-mismatch
         table.insert(result[math.ceil((i+1)/20)+1], table.deepcopy(str[i+1]))
         i = i + 1
      end
      return result
   else
      return str
   end
end

--Converts a dictionary into an iterable array.
function fa_utils.get_iterable_array(dict)
   result = {}
   for i, v in pairs(dict) do
      table.insert(result, v)
   end
   return result
end

--Converts an array into a lookup table based on the keys it has.
function fa_utils.into_lookup(array)
    local lookup = {}
    for key, value in pairs(array) do
        lookup[value] = key
    end
    return lookup
end

--Returns the part of a substring before a space character. BUG: Breaks when parsing dashes.
function fa_utils.get_substring_before_space(str)
   local first, final = string.find(str," ")
   if first == nil or first == 1 then --No space, or space at the start only
      return str
   else
      return string.sub(str,1,first-1)
   end
end

--Returns the part of a substring after a space character. BUG: Breaks when parsing dashes.
function fa_utils.get_substring_after_space(str)
   local first, final = string.find(str," ")
   if final == nil then --No spaces
      return str
   end
   if first == 1 then --spaces at start only
      return string.sub(str,final+1,string.len(str))
   end
   
   if final == string.len(str) then --space at the end only?
      return str
   end
   
   return string.sub(str,final+1,string.len(str))
end

--Returns the part of a substring before a comma character. BUG: Breaks when parsing dashes.
function fa_utils.get_substring_before_comma(str)
   local first, final = string.find(str,",")
   if first == nil or first == 1 then
      return str
   else
      return string.sub(str,1,first-1)
   end
end

function fa_utils.get_substring_before_dash(str)
   local first, final = string.find(str,"-")
   if first == nil or first == 1 then
      return str
   else
      return string.sub(str,1,first-1)
   end
end

function fa_utils.dir_dist_locale_h(dir_dist)
   return {"access.dir-dist",{"access.direction",dir_dist[1]},math.floor(dir_dist[2]+0.5)}
end

function fa_utils.dir_dist_locale(pos1,pos2)
   return fa_utils.dir_dist_locale_h( fa_utils.dir_dist(pos1,pos2) )
end

function fa_utils.ent_name_locale(ent)
   if ent.name == "water" then
      print("todo: water isn't an entity")
      return {"gui-map-generator.water"}
   end
   if ent.name == "forest" then
      print("todo: forest isn't an entity")
      return {"access.forest"}
   end
   if not game.entity_prototypes[ent.name] then
      error(ent.name .. " is not an entity")
   end
   return ent.localised_name or game.entity_prototypes[ent.name].localised_name
end

--small utility function for getting the index of a named object from an array of objects.
function fa_utils.index_of_entity(array, value)
   if next(array) == nil then
      return nil
   end
    for i = 1, #array,1 do
        if array[i].name == value then
            return i
      end
   end
   return nil
end

--Rounds down a number to the nearest thousand after 10 thousand, and nearest 100 thousand after 1 million.
function fa_utils.floor_to_nearest_k_after_10k(num_in)
   local num = num_in
   num = math.ceil(num)
   if num > 10000 then
      num = 1000 * math.floor(num/1000)
   end
   if num > 1000000 then
      num = 100000 * math.floor(num/100000)
   end
   return num
end

return fa_utils
