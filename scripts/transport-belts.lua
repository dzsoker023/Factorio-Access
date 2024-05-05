--Here: functions about belts, splitters, underground belts

local localising = require("scripts.localising")
local util = require("util")
local fa_utils = require("scripts.fa-utils")

local mod = {}

--Takes some stats about a belt unit and explains what type of junction the belt is.
function mod.transport_belt_junction_info(
   sideload_count,
   backload_count,
   outload_count,
   this_dir,
   outload_dir,
   say_middle,
   outload_is_corner
)
   local say_middle = say_middle or false
   local outload_is_corner = outload_is_corner or false
   local result = ""
   if sideload_count == 0 and backload_count == 0 and outload_count == 0 then
      result = " unit "
   elseif sideload_count == 0 and backload_count == 1 and outload_count == 0 then
      result = " stopping end "
   elseif sideload_count == 1 and backload_count == 0 and outload_count == 0 then
      result = " stopping end corner "
   elseif sideload_count == 1 and backload_count == 1 and outload_count == 0 then
      result = " sideloading stopping end "
   elseif sideload_count == 2 and backload_count == 1 and outload_count == 0 then
      result = " double sideloading stopping end "
   elseif sideload_count == 2 and backload_count == 0 and outload_count == 0 then
      result = " safe merging stopping end "
   elseif sideload_count == 0 and backload_count == 0 and outload_count == 1 and this_dir == outload_dir then
      result = " start "
   elseif sideload_count == 0 and backload_count == 1 and outload_count == 1 and this_dir == outload_dir then
      if say_middle then
         result = " middle "
      else
         result = " "
      end
   elseif sideload_count == 1 and backload_count == 0 and outload_count == 1 and this_dir == outload_dir then
      result = " corner "
   elseif sideload_count == 1 and backload_count == 1 and outload_count == 1 and this_dir == outload_dir then
      result = " sideloading junction "
   elseif sideload_count == 2 and backload_count == 1 and outload_count == 1 and this_dir == outload_dir then
      result = " double sideloading junction "
   elseif sideload_count == 2 and backload_count == 0 and outload_count == 1 and this_dir == outload_dir then
      result = " safe merging junction "
   elseif sideload_count == 0 and backload_count == 0 and outload_count == 1 and this_dir ~= outload_dir then
      if outload_is_corner == false then
         result = " unit pouring end "
      else
         result = " start "
      end
   elseif sideload_count == 0 and backload_count == 1 and outload_count == 1 and this_dir ~= outload_dir then
      if outload_is_corner == false then
         result = " pouring end "
      else
         if say_middle then
            result = " middle "
         else
            result = " "
         end
      end
   elseif sideload_count == 1 and backload_count == 0 and outload_count == 1 and this_dir ~= outload_dir then
      if outload_is_corner == false then
         result = " corner pouring end "
      else
         result = " corner "
      end
   elseif sideload_count == 1 and backload_count == 1 and outload_count == 1 and this_dir ~= outload_dir then
      if outload_is_corner == false then
         result = " sideloading pouring end "
      else
         result = " sideloading junction "
      end
   elseif sideload_count == 2 and backload_count == 1 and outload_count == 1 and this_dir ~= outload_dir then
      if outload_is_corner == false then
         result = " double sideloading pouring end "
      else
         result = " double sideloading junction "
      end
   elseif sideload_count == 2 and backload_count == 0 and outload_count == 1 and this_dir ~= outload_dir then
      if outload_is_corner == false then
         result = " safe merging pouring end "
      else
         result = " safe merging junction "
      end
   elseif
      sideload_count + backload_count > 1 and (outload_count == 0 or (outload_count == 1 and this_dir == outload_dir))
   then
      result = " unidentified junction " --this should not be reachable any more
   elseif sideload_count + backload_count > 1 and outload_count == 1 and this_dir ~= outload_dir then
      result = " unidentified pouring end "
   elseif outload_count > 1 then
      result = " multiple outputs " --unexpected case
   else
      result = " unknown state " --unexpected case
   end
   return result
   --Note: A pouring end either pours into a sideloading junction, or into a corner and this can now be identified. Lanes are preserved if the target is a corner.
end

--Belt analyzer: Returns a navigable list of items that are found in the input transport belt line.
function mod.get_line_items(network)
   local result = {
      combined = { left = {}, right = {} },
      downstream = { left = {}, right = {} },
      upstream = { left = {}, right = {} },
   }
   local dict = {}
   for i, line in pairs(network.downstream.left) do
      for name, count in pairs(line.get_contents()) do
         if dict[name] == nil then
            dict[name] = count
         else
            dict[name] = dict[name] + count
         end
      end
   end
   local total = table_size(network.downstream.left) * 4
   for name, count in pairs(dict) do
      table.insert(result.downstream.left, {
         name = name,
         count = count,
         percent = math.floor(1000 * count / total) / 10,
         valid = true,
         valid_for_read = true,
      })
   end
   table.sort(result.downstream.left, function(k1, k2)
      return k1.percent > k2.percent
   end)

   local dict = {}
   for i, line in pairs(network.downstream.right) do
      for name, count in pairs(line.get_contents()) do
         if dict[name] == nil then
            dict[name] = count
         else
            dict[name] = dict[name] + count
         end
      end
   end
   local total = table_size(network.downstream.right) * 4
   for name, count in pairs(dict) do
      table.insert(result.downstream.right, {
         name = name,
         count = count,
         percent = math.floor(1000 * count / total) / 10,
         valid = true,
         valid_for_read = true,
      })
   end
   table.sort(result.downstream.right, function(k1, k2)
      return k1.percent > k2.percent
   end)

   local dict = {}
   for i, line in pairs(network.upstream.left) do
      for name, count in pairs(line.get_contents()) do
         if dict[name] == nil then
            dict[name] = count
         else
            dict[name] = dict[name] + count
         end
      end
   end
   local total = table_size(network.upstream.left) * 4
   for name, count in pairs(dict) do
      table.insert(result.upstream.left, {
         name = name,
         count = count,
         percent = math.floor(1000 * count / total) / 10,
         valid = true,
         valid_for_read = true,
      })
   end
   table.sort(result.upstream.left, function(k1, k2)
      return k1.percent > k2.percent
   end)

   local dict = {}
   for i, line in pairs(network.upstream.right) do
      for name, count in pairs(line.get_contents()) do
         if dict[name] == nil then
            dict[name] = count
         else
            dict[name] = dict[name] + count
         end
      end
   end
   local total = table_size(network.upstream.right) * 4
   for name, count in pairs(dict) do
      table.insert(result.upstream.right, {
         name = name,
         count = count,
         percent = math.floor(1000 * count / total) / 10,
         valid = true,
         valid_for_read = true,
      })
   end
   table.sort(result.upstream.right, function(k1, k2)
      return k1.percent > k2.percent
   end)
   local dict = {}
   for i, item in pairs(result.downstream.left) do
      dict[item.name] = item.count
   end
   for i, item in pairs(result.upstream.left) do
      if dict[item.name] == nil then
         dict[item.name] = item.count
      else
         dict[item.name] = dict[item.name] + item.count
      end
   end

   local total = table_size(network.combined.left) * 4

   for name, count in pairs(dict) do
      table.insert(result.combined.left, {
         name = name,
         count = count,
         percent = math.floor(1000 * count / total) / 10,
         valid = true,
         valid_for_read = true,
      })
   end
   table.sort(result.combined.left, function(k1, k2)
      return k1.percent > k2.percent
   end)

   local dict = {}
   for i, item in pairs(result.downstream.right) do
      dict[item.name] = item.count
   end
   for i, item in pairs(result.upstream.right) do
      if dict[item.name] == nil then
         dict[item.name] = item.count
      else
         dict[item.name] = dict[item.name] + item.count
      end
   end

   local total = table_size(network.combined.right) * 4

   for name, count in pairs(dict) do
      table.insert(result.combined.right, {
         name = name,
         count = count,
         percent = math.floor(1000 * count / total) / 10,
         valid = true,
         valid_for_read = true,
      })
   end
   table.sort(result.combined.right, function(k1, k2)
      return k1.percent > k2.percent
   end)

   return result
end

--Belt analyzer: Creates a list of transport lines that involve the belt uint B.
function mod.get_connected_lines(B)
   local left = {}
   local right = {}
   local frontier = {}
   local precursors = {}
   local hash = {}
   hash[B.unit_number] = true
   local upstreams = {}
   local inputs = B.belt_neighbours["inputs"]
   local outputs = B.belt_neighbours["outputs"]
   for i, belt in pairs(outputs) do
      if belt.name ~= "entity-ghost" then
         if hash[belt.unit_number] ~= true then
            hash[belt.unit_number] = true
            table.insert(frontier, { side = 1, belt = belt })
         end
      end
   end

   for i, belt in pairs(inputs) do
      if belt.name ~= "entity-ghost" then
         if hash[belt.unit_number] ~= true then
            local side = 1
            if #inputs == 1 then
               side = 1
            elseif belt.direction == (B.direction + 2) % 8 then
               side = 0
            elseif belt.direction == (B.direction + 6) % 8 then
               side = 2
            end

            table.insert(precursors, { side = side, belt = belt })
         end
      end
   end

   table.insert(left, B.get_transport_line(1))
   table.insert(right, B.get_transport_line(2))

   while #frontier > 0 do
      local explored = table.remove(frontier, 1)
      local outputs = explored.belt.belt_neighbours["outputs"]
      local inputs = explored.belt.belt_neighbours["inputs"]
      for i, belt in pairs(outputs) do
         if belt.name ~= "entity-ghost" then
            if hash[belt.unit_number] ~= true then
               hash[belt.unit_number] = true

               table.insert(frontier, { side = 1, belt = belt })
            end
         end
      end

      for i, belt in pairs(inputs) do
         if belt.name ~= "entity-ghost" then
            if hash[belt.unit_number] ~= true then
               local side = 1
               if explored.side == 0 or explored.side == 2 then
                  side = explored.side
               elseif #inputs == 1 then
                  side = 1
               elseif belt.direction == (explored.belt.direction + 2) % 8 then
                  side = 0
               elseif belt.direction == (explored.belt.direction + 6) % 8 then
                  side = 2
               end

               table.insert(upstreams, { side = side, belt = belt })
            end
         end
      end
      if explored.side == 0 then
         table.insert(left, explored.belt.get_transport_line(1))
         table.insert(left, explored.belt.get_transport_line(2))
      elseif explored.side == 2 then
         table.insert(right, explored.belt.get_transport_line(1))
         table.insert(right, explored.belt.get_transport_line(2))
      elseif explored.side == 1 then
         table.insert(left, explored.belt.get_transport_line(1))
         table.insert(right, explored.belt.get_transport_line(2))
      end
   end

   for i, belt in pairs(upstreams) do
      if hash[belt.belt.unit_number] ~= true then
         hash[belt.belt.unit_number] = true
         table.insert(frontier, belt)
      end
   end

   while #frontier > 0 do
      local explored = table.remove(frontier, 1)
      local inputs = explored.belt.belt_neighbours["inputs"]

      for i, belt in pairs(inputs) do
         if belt.name ~= "entity-ghost" then
            if hash[belt.unit_number] ~= true then
               hash[belt.unit_number] = true
               local side = 1
               if explored.side == 0 or explored.side == 2 then
                  side = explored.side
               elseif #inputs == 1 then
                  side = 1
               elseif belt.direction == (explored.belt.direction + 2) % 8 then
                  side = 0
               elseif belt.direction == (explored.belt.direction + 6) % 8 then
                  side = 2
               end

               table.insert(frontier, { side = side, belt = belt })
            end
         end
      end
      if explored.side == 0 then
         table.insert(left, explored.belt.get_transport_line(1))
         table.insert(left, explored.belt.get_transport_line(2))
      elseif explored.side == 2 then
         table.insert(right, explored.belt.get_transport_line(1))
         table.insert(right, explored.belt.get_transport_line(2))
      elseif explored.side == 1 then
         table.insert(left, explored.belt.get_transport_line(1))
         table.insert(right, explored.belt.get_transport_line(2))
      end
   end

   for i, belt in pairs(precursors) do
      if hash[belt.belt.unit_number] ~= true then
         hash[belt.belt.unit_number] = true
         table.insert(frontier, belt)
      end
   end

   local downstream = { left = table.deepcopy(left), right = table.deepcopy(right) }
   local upstream = { left = {}, right = {} }

   while #frontier > 0 do
      local explored = table.remove(frontier, 1)
      local inputs = explored.belt.belt_neighbours["inputs"]

      for i, belt in pairs(inputs) do
         if belt.name ~= "entity-ghost" then
            if hash[belt.unit_number] ~= true then
               hash[belt.unit_number] = true
               local side = 1
               if explored.side == 0 or explored.side == 2 then
                  side = explored.side
               elseif #inputs == 1 then
                  side = 1
               elseif belt.direction == (explored.belt.direction + 2) % 8 then
                  side = 0
               elseif belt.direction == (explored.belt.direction + 6) % 8 then
                  side = 2
               end

               table.insert(frontier, { side = side, belt = belt })
            end
         end
      end
      if explored.side == 0 then
         table.insert(left, explored.belt.get_transport_line(1))
         table.insert(left, explored.belt.get_transport_line(2))
         table.insert(upstream.left, explored.belt.get_transport_line(1))
         table.insert(upstream.left, explored.belt.get_transport_line(2))
      elseif explored.side == 2 then
         table.insert(right, explored.belt.get_transport_line(1))
         table.insert(right, explored.belt.get_transport_line(2))
         table.insert(upstream.right, explored.belt.get_transport_line(1))
         table.insert(upstream.right, explored.belt.get_transport_line(2))
      elseif explored.side == 1 then
         table.insert(left, explored.belt.get_transport_line(1))
         table.insert(right, explored.belt.get_transport_line(2))
         table.insert(upstream.left, explored.belt.get_transport_line(1))
         table.insert(upstream.right, explored.belt.get_transport_line(2))
      end
   end

   return { combined = { left = left, right = right }, upstream = upstream, downstream = downstream }
end

--Belt analyzer: Returns a hash table of the belt units connected to the belt unit B.
function mod.get_connected_belts(B)
   local result = {}
   local frontier = { table.deepcopy(B) }
   local hash = {}
   hash[B.unit_number] = true
   while #frontier > 0 do
      local explored = table.remove(frontier, 1)
      local inputs = explored.belt_neighbours["inputs"]
      local outputs = explored.belt_neighbours["outputs"]
      for i, belt in pairs(inputs) do
         if hash[belt.unit_number] ~= true then
            hash[belt.unit_number] = true
            table.insert(frontier, table.deepcopy(belt))
         end
      end
      for i, belt in pairs(outputs) do
         if hash[belt.unit_number] ~= true then
            hash[belt.unit_number] = true
            table.insert(frontier, table.deepcopy(belt))
         end
      end
      table.insert(result, table.deepcopy(explored))
   end

   return { hash = hash, ents = result }
end

--Transport belt analyzer: Read a results list slot
function mod.read_belt_slot(pindex, start_phrase)
   start_phrase = start_phrase or ""
   local stack = nil
   local array = {}
   local result = start_phrase
   local direction = players[pindex].belt.direction

   --Read lane direction
   if players[pindex].belt.side == 1 then
      if direction == 0 then
         result = result .. "West lane "
      elseif direction == 4 then
         result = result .. "East lane "
      elseif direction == 6 then
         result = result .. "South lane "
      elseif direction == 2 then
         result = result .. "North lane "
      else
         result = result .. "Unspecified lane, "
      end
   elseif players[pindex].belt.side == 2 then
      if direction == 0 then
         result = result .. "East lane "
      elseif direction == 4 then
         result = result .. "West lane "
      elseif direction == 6 then
         result = result .. "North lane "
      elseif direction == 2 then
         result = result .. "South lane "
      else
         result = result .. "Unspecified lane, "
      end
   end
   --Read lane contents
   if players[pindex].belt.sector == 1 and players[pindex].belt.side == 1 then
      array = players[pindex].belt.line1
   elseif players[pindex].belt.sector == 1 and players[pindex].belt.side == 2 then
      array = players[pindex].belt.line2
   elseif players[pindex].belt.sector == 2 then
      if players[pindex].belt.side == 1 then
         array = players[pindex].belt.network.combined.left
      elseif players[pindex].belt.side == 2 then
         array = players[pindex].belt.network.combined.right
      end
   elseif players[pindex].belt.sector == 3 then
      if players[pindex].belt.side == 1 then
         array = players[pindex].belt.network.downstream.left
      elseif players[pindex].belt.side == 2 then
         array = players[pindex].belt.network.downstream.right
      end
   elseif players[pindex].belt.sector == 4 then
      if players[pindex].belt.side == 1 then
         array = players[pindex].belt.network.upstream.left
      elseif players[pindex].belt.side == 2 then
         array = players[pindex].belt.network.upstream.right
      end
   else
      return
   end
   pcall(function()
      stack = array[players[pindex].belt.index]
   end)

   if stack ~= nil and stack.valid_for_read and stack.valid then
      result = result .. stack.name .. " x " .. stack.count
      if players[pindex].belt.sector > 1 then result = result .. ", " .. stack.percent .. "%" end
   else
      result = result .. "Empty slot"
   end
   printout(result, pindex)
end

--Set the input priority or the output priority or filter for a splitter
function mod.set_splitter_priority(splitter, is_input, is_left, filter_item_stack, clear)
   local clear = clear or false
   local result = "no message"
   local filter = splitter.splitter_filter

   if clear then
      splitter.splitter_filter = nil
      filter = splitter.splitter_filter
      result = "Cleared splitter filter"
      splitter.splitter_output_priority = "none"
   elseif filter_item_stack ~= nil and filter_item_stack.valid_for_read then
      splitter.splitter_filter = filter_item_stack.prototype
      filter = splitter.splitter_filter
      result = "filter set to " .. filter_item_stack.name
      if splitter.splitter_output_priority == "none" then
         splitter.splitter_output_priority = "left"
         result = result .. ", from the left"
      end
   elseif is_input and is_left then
      if splitter.splitter_input_priority == "left" then
         splitter.splitter_input_priority = "none"
         result = "equal input priority"
      else
         splitter.splitter_input_priority = "left"
         result = "left input priority"
      end
   elseif is_input and not is_left then
      if splitter.splitter_input_priority == "right" then
         splitter.splitter_input_priority = "none"
         result = "equal input priority"
      else
         splitter.splitter_input_priority = "right"
         result = "right input priority"
      end
   elseif not is_input and is_left then
      if splitter.splitter_output_priority == "left" then
         if filter == nil then
            splitter.splitter_output_priority = "none"
            result = "equal output priority"
         else
            result = "left filter output"
         end
      else
         if filter == nil then
            splitter.splitter_output_priority = "left"
            result = "left output priority"
         else
            splitter.splitter_output_priority = "left"
            result = "left filter output"
         end
      end
   elseif not is_input and not is_left then
      if splitter.splitter_output_priority == "right" then
         if filter == nil then
            splitter.splitter_output_priority = "none"
            result = "equal output priority"
         else
            result = "right filter output"
         end
      else
         if filter == nil then
            splitter.splitter_output_priority = "right"
            result = "right output priority"
         else
            splitter.splitter_output_priority = "right"
            result = "right filter output"
         end
      end
   else
      result = "Splitter config error"
   end

   return result
end

--Returns an info string about a splitter's input and output settings.
function mod.splitter_priority_info(ent)
   local result = ","
   local input = ent.splitter_input_priority
   local output = ent.splitter_output_priority
   local filter = ent.splitter_filter
   if input == "none" then
      result = result .. " input balanced, "
   elseif input == "right" then
      result = result
         .. " input priority "
         .. "right"
         .. " which is "
         .. fa_utils.direction_lookup(fa_utils.rotate_90(ent.direction))
         .. ", "
   elseif input == "left" then
      result = result
         .. " input priority "
         .. "left"
         .. " which is "
         .. fa_utils.direction_lookup(fa_utils.rotate_270(ent.direction))
         .. ", "
   end
   if filter == nil then
      if output == "none" then
         result = result .. " output balanced, "
      elseif output == "right" then
         result = result
            .. " output priority "
            .. "right"
            .. " which is "
            .. fa_utils.direction_lookup(fa_utils.rotate_90(ent.direction))
            .. ", "
      elseif output == "left" then
         result = result
            .. " output priority "
            .. "left"
            .. " which is "
            .. fa_utils.direction_lookup(fa_utils.rotate_270(ent.direction))
            .. ", "
      end
   else
      local item_name = localising.get(filter, pindex)
      if item_name == nil or item_name == "" then item_name = "unknown item" end
      if output == "right" then
         result = result
            .. " output filtering "
            .. item_name
            .. " towards the "
            .. "right"
            .. " which is "
            .. fa_utils.direction_lookup(fa_utils.rotate_90(ent.direction))
            .. ", "
      elseif output == "left" then
         result = result
            .. " output filtering "
            .. item_name
            .. " towards the "
            .. "left"
            .. " which is "
            .. fa_utils.direction_lookup(fa_utils.rotate_270(ent.direction))
            .. ", "
      end
   end
   return result
end

return mod
