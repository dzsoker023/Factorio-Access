--Here: functions about the warnings menu
local fa_belts = require("transport-belts")

local fa_warnings = {}

--Reads out a selected warning from the menu.
function fa_warnings.read_warnings_slot(pindex)
   local warnings = {}
   if players[pindex].warnings.sector == 1 then
      warnings = players[pindex].warnings.short.warnings
   elseif players[pindex].warnings.sector == 2 then
      warnings = players[pindex].warnings.medium.warnings
   elseif players[pindex].warnings.sector == 3 then
      warnings= players[pindex].warnings.long.warnings
   end
   if players[pindex].warnings.category <= #warnings and players[pindex].warnings.index <= #warnings[players[pindex].warnings.category].ents then
      local ent = warnings[players[pindex].warnings.category].ents[players[pindex].warnings.index]
      if ent ~= nil and ent.valid then
         printout(ent.name .. " has " .. warnings[players[pindex].warnings.category].name .. " at " .. math.floor(ent.position.x) .. ", " .. math.floor(ent.position.y), pindex)
      else
         printout("Blank", pindex)
      end
   else
      printout("No warnings for this range.  Press tab to pick a larger range, or press E to close this menu.", pindex)
   end
end

--Warnings menu: Creates a structured data network to track production systems.
function fa_warnings.generate_production_network(pindex)
   local surf = game.get_player(pindex).surface
   local connectors = surf.find_entities_filtered{type="inserter"}
   local sources = surf.find_entities_filtered{type = "mining-drill"}
   local hash = {}
   local lines = {}
   local function explore_source(source)
      if hash[source.unit_number] == nil then
         hash[source.unit_number] = {
            production_line = math.huge,
            inputs = {},
            outputs = {},
            ent = source
         }
         local target = surf.find_entities_filtered{position = source.drop_position, type = production_types}[1]
         if target ~= nil then
            if target.type == "mining-drill" then
               table.insert(hash[source.unit_number].outputs, target.unit_number)
               explore_source(target)
               table.insert(hash[target.unit_number].inputs, source.unit_number)
               local new_line = math.min(hash[target.unit_number].production_line, table.maxn(lines) + 1)
               hash[source.unit_number].production_line = new_line
               lines[new_line] = lines[new_line] or {}
               table.insert(lines[new_line], source.unit_number)
            elseif target.type == "transport-belt" then
               if hash[target.unit_number] == nil then

                  local belts = fa_belts.get_connected_belts(target)
                  for i, belt in pairs(belts.hash) do
                     hash[i] = {link = target.unit_number}
                  end

                  local new_line = table.maxn(lines)+1
                  hash[target.unit_number] = {
                     production_line = new_line,
                     inputs = {source.unit_number},
                     outputs = {},
                     ent = target
                  }

                  hash[source.unit_number].production_line = new_line
                  lines[new_line] = {source.unit_number, target.unit_number}
               else
                  if hash[target.unit_number].link ~= nil then
                     hash[target.unit_number].ent = target
                     target = hash[hash[target.unit_number].link].ent
                  end
                  table.insert(hash[target.unit_number].inputs, source.unit_number)
                  table.insert(hash[source.unit_number].outputs, target.unit_number)
                  local new_line = hash[target.unit_number].production_line
                  hash[source.unit_number].production_line = new_line

                  table.insert(lines[new_line], source.unit_number)
               end
            else
               if hash[target.unit_number] == nil then
                  local new_line = table.maxn(lines)+1
                  hash[target.unit_number] = {
                     production_line = new_line,
                     inputs = {source.unit_number},
                     outputs = {},
                     ent = target
                  }
                  hash[source.unit_number].production_line = new_line
                  lines[new_line] = {source.unit_number, target.unit_number}
               else
                  table.insert(hash[target.unit_number].inputs, source.unit_number)
                  table.insert(hash[source.unit_number].outputs, target.unit_number)
                  hash[source.unit_number].production_line = hash[target.unit_number].production_line
                  table.insert(lines[hash[target.unit_number].production_line], source.unit_number)
               end
            end
         else
            local new_line = table.maxn(lines) + 1
            hash[source.unit_number].production_line = new_line
            lines[new_line] = {source.unit_number}
         end
      end
      end
   for i, source in pairs(sources) do
      explore_source(source)
   end

   local function explore_connector(connector)
      if hash[connector.unit_number] == nil then
         hash[connector.unit_number] = {
            production_line = math.huge,
            inputs = {},
            outputs = {},
            ent = connector
         }
         local drop_target = surf.find_entities_filtered{position = connector.drop_position, type = production_types}[1]
         local pickup_target = surf.find_entities_filtered{position = connector.pickup_position, type = production_types}[1]
         if drop_target ~= nil then
            if drop_target.type == "inserter" then
               explore_connector(drop_target)
               local check = true
               for i, v in pairs(hash[drop_target.unit_number].inputs) do
                  if v == connector.unit_number then
                     check = false
                  end
               end
               if check then
                  table.insert(hash[drop_target.unit_number].inputs, connector.unit_number)
               end

               local check = true
               for i, v in pairs(hash[connector.unit_number].outputs) do
                  if v == drop_target.unit_number then
                     check = false
                  end
               end
               if check then
                  table.insert(hash[connector.unit_number].outputs, drop_target.unit_number)
               end
            elseif drop_target.type == "transport-belt" then
               if hash[drop_target.unit_number] == nil then
                  local belts = fa_belts.get_connected_belts(drop_target)
                  for i, belt in pairs(belts.hash) do
                     hash[i] = {link = drop_target.unit_number}
                  end

                  hash[drop_target.unit_number] = {
                     production_line = math.huge,
                     inputs = {connector.unit_number},
                     outputs = {},
                     ent = drop_target
                  }
                  table.insert(hash[connector.unit_number].outputs, drop_target.unit_number)
               else
                  if hash[drop_target.unit_number].link ~= nil then
                     hash[drop_target.unit_number].ent = drop_target
                     drop_target = hash[hash[drop_target.unit_number].link].ent
                  end
                  table.insert(hash[drop_target.unit_number].inputs, connector.unit_number)
                  table.insert(hash[connector.unit_number].outputs, drop_target.unit_number)
               end
            else
               if hash[drop_target.unit_number] == nil then
                  hash[drop_target.unit_number] = {
                     production_line = math.huge,
                     inputs = {},
                     outputs = {},
                     ent = drop_target
                  }
               end
               table.insert(hash[drop_target.unit_number].inputs, connector.unit_number)
               table.insert(hash[connector.unit_number].outputs, drop_target.unit_number)
            end
         end

         if pickup_target ~= nil then
            if pickup_target.type == "inserter" then
               explore_connector(pickup_target)
               local check = true
               for i, v in pairs(hash[pickup_target.unit_number].outputs) do
                  if v == connector.unit_number then
                     check = false
                  end
               end
               if check then
                  table.insert(hash[pickup_target.unit_number].outputs, connector.unit_number)
               end

               local check = true
               for i, v in pairs(hash[connector.unit_number].inputs) do
                  if v == pickup_target.unit_number then
                     check = false
                  end
               end
               if check then
                  table.insert(hash[connector.unit_number].inputs, pickup_target.unit_number)
               end

            elseif pickup_target.type == "transport-belt" then
               if hash[pickup_target.unit_number] == nil then
                  local belts = fa_belts.get_connected_belts(pickup_target)
                  for i, belt in pairs(belts.hash) do
                     hash[i] = {link = pickup_target.unit_number}
                  end
                  hash[pickup_target.unit_number] = {
                     production_line = math.huge,
                     inputs = {},
                     outputs = {connector.unit_number},
                     ent = pickup_target
                  }
                  table.insert(hash[connector.unit_number].outputs, pickup_target.unit_number)

               else
                  if hash[pickup_target.unit_number].link ~= nil then
                     hash[pickup_target.unit_number].ent = pickup_target
                     pickup_target = hash[hash[pickup_target.unit_number].link].ent
                  end
                  table.insert(hash[pickup_target.unit_number].outputs, connector.unit_number)
                  table.insert(hash[connector.unit_number].inputs, pickup_target.unit_number)
               end
            else
               if hash[pickup_target.unit_number] == nil then
                  hash[pickup_target.unit_number] = {
                     production_line = math.huge,
                     inputs = {},
                     outputs = {},
                     ent = pickup_target
                  }
               end
               table.insert(hash[pickup_target.unit_number].outputs, connector.unit_number)
               table.insert(hash[connector.unit_number].inputs, pickup_target.unit_number)

            end
         end

         local choices = {hash[connector.unit_number]}
         if drop_target ~= nil then
            table.insert(choices, hash[drop_target.unit_number])
         end
         if pickup_target ~= nil then
            table.insert(choices, hash[pickup_target.unit_number])
         end
         local line_choices = {}
         for i, choice in pairs(choices) do
            table.insert(line_choices, choice.production_line)
         end
         table.insert(line_choices, table.maxn(lines)+1)
         local new_line = math.min(unpack(line_choices))
         for i, choice in pairs(choices) do
            if choice.production_line ~= new_line then
               local old_line = choice.production_line
               if old_line ~= math.huge then
                  for i1, ent in pairs(lines[old_line]) do
                     hash[ent].production_line = new_line
                     lines[new_line] = lines[new_line] or {}
                     table.insert(lines[new_line], ent)
                  end
                  lines[old_line] = nil
               else
                  choice.production_line = new_line
                  if lines[new_line] == nil then
                     lines[new_line] = {}
                  end
                  table.insert(lines[new_line], choice.ent.unit_number)
               end
            end
         end
      end
   end

   for i, connector in pairs(connectors) do
      explore_connector(connector)
   end

--   print(table_size(lines))
--   print(table_size(hash))

--   local count = 0
--   for i, entry in pairs(hash) do
--      if entry.ent ~= nil then
--         count = count + 1
--   end
--   end
--   print(count)
   return {hash = hash, lines = lines}
end

--Warnings menu: scans for problems in the production network it defines and creates the warnings list.
function fa_warnings.scan_for_warnings(L,H,pindex)
   local prod =       fa_warnings.generate_production_network(pindex)
   local surf = game.get_player(pindex).surface
   local pos = players[pindex].cursor_pos
   local area = {{pos.x - L, pos.y - H}, {pos.x + L, pos.y + H}}
   local ents = surf.find_entities_filtered{area = area, type = entity_types}
   local warnings = {}
   warnings["noFuel"] = {}
   warnings["noRecipe"] = {}
   warnings["noInserters"] = {}
   warnings["noPower"] = {}
   warnings ["notConnected"] = {}
   for i, ent in pairs(ents) do
      if ent.prototype.burner_prototype ~= nil then
         local fuel_inv = ent.get_fuel_inventory()
         if ent.energy == 0 and (fuel_inv == nil or (fuel_inv and fuel_inv.valid and fuel_inv.is_empty())) then
            table.insert(warnings["noFuel"], ent)
         end
      end

      if ent.prototype.electric_energy_source_prototype ~= nil and ent.is_connected_to_electric_network() == false then
         table.insert(warnings["notConnected"], ent)
      elseif ent.prototype.electric_energy_source_prototype ~= nil and ent.energy == 0 then
         table.insert(warnings["noPower"], ent)
      end
      local recipe = nil
      if pcall(function()
         recipe = ent.get_recipe()
     end) then
         if recipe == nil and ent.type ~= "furnace" then
            table.insert(warnings["noRecipe"], ent)
         end
      end
      local check = false
      for i1, type in pairs(production_types) do
         if ent.type == type then
            check = true
         end
      end
      if check and prod.hash[ent.unit_number] == nil then
         table.insert(warnings["noInserters"], ent)
      end
   end
   local str = ""
   local result = {}
   for i, warning in pairs(warnings) do
      if #warning > 0 then
         str = str .. i .. " " .. #warning .. ", "
         table.insert(result, {name = i, ents = warning})
      end
   end
   if str == "" then
      str = "No warnings displayed    "
   end
   str = string.sub(str, 1, -3)
   return {summary = str, warnings = result}
end

return fa_warnings