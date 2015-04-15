package.path = package.path .. ";lua/?.lua;../?.lua"

print ("Script Init Begin")

local pool = require("pool")

function parse(lines)
   local configs = {}
   local idx = 1
   local node_lines = {}
   -- skip summary
   for i,line in ipairs(lines) do
      if string.sub(line,1,2) ~= "# " then
         table.insert(node_lines,line)
      end
   end
   -- parse nodes
   for _,line in ipairs(node_lines) do
      local xs = line:split(" ")
      local addr = xs[4]:split(":")
      ip, port = addr[1], addr[2]

      local role = "master"
      if string.find(xs[5], "master") == nil then
         role = "slave"
      end

      local loc = xs[2]:split(":")

      local c = {
         id = xs[3],
         addr = xs[4],
         ip = ip,
         port = tonumber(port),
         role = role,
         master_id = xs[6],
         status = xs[10],
         readable = false,
         writable = false,
         region = loc[1],
         zone = loc[2],
         room = loc[3],
      }

      if string.find(xs[1], "r") then
         c.readable = true
      end
      if string.find(xs[1], "w") then
         c.writable = true
      end

      if role == "master" then
         local ranges = {}
         for i = 11, #xs do
            -- skip importing/migrating info
            if string.sub(xs[i],1,1) == "[" then
               break
            end

            local range = {}
            local pair = xs[i]:split("-")

            if #pair == 2 then
               range.left = tonumber(pair[1])
               range.right = tonumber(pair[2])
            else
               range.left = tonumber(xs[i])
               range.right = tonumber(xs[i])
            end

            table.insert(ranges, range)
         end
         c.ranges = ranges
      end

      table.insert(configs, c)
   end
   return configs
end

function update_cluster_nodes(msg)
   if string.sub(msg,1,3) == "+OK" or string.sub(msg,1,3) == "$-1" then
      return
   end

   local lines = msg:strip():split("\n")
   local bytes = tonumber(string.sub(lines[1],2,-1))
   if bytes == nil then
      error("nodes info invalid")
      return
   end
   if bytes > 16384 then
      error("nodes info too large > 16384 (FIXME)")
      return
   end
   table.remove(lines, 1)

   -- parse message returned by 'cluster nodes'
   local configs = parse(lines)

   if #configs == 0 then
      error("no server found")
      return
   end

   if #configs == 1 and configs[1].ranges ~= nil and #configs[1].ranges == 0 then
      error("free node found")
      return
   end
   
   -- reconstruct servers, fix adds and drops
   pool:set_servers(configs)

   -- rebuild replica sets
   pool:build_replica_sets()

   -- bind replica sets to slots
   pool:bind_slots()
end

print ("Script Init Done")
