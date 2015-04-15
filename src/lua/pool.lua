package.path = package.path .. ";lua/?.lua;../?.lua"

local ffi = require("ffi")
local C = ffi.C

ffi.cdef[[
      struct server;
      typedef int rstatus_t;

      void ffi_pool_clear_servers(struct server_pool *pool);
      void ffi_pool_add_server(struct server_pool *pool, struct server *server);

      rstatus_t ffi_server_table_set(struct server_pool *pool, const char *name, struct server *server);
      void ffi_server_table_delete(struct server_pool *pool, const char *name);

      rstatus_t ffi_stats_reset(struct server_pool *pool);
]]

local server = require("server")
local replica_set = require("replica_set")

local _M = {
   server_map = {},
   replica_sets = {},

   -- for check change
   last_server_names = {},

   -- struct server_pool {}
   pool = __pool,

   -- resource pools
   _rs_pool = {},
   _se_pool = {},
}

function _M.fetch_server(self, config)
   local s = nil

   if #self._se_pool == 0 then
      s = server:new(config)
   else
      s = table.remove(self._se_pool, 1)
   end
   
   return s
end

function _M.put_server(self, s)
   s:disconnect()
   table.insert(self._se_pool, s)
end

function _M.fetch_replica_set(self)
   local rs = nil

   if #self._rs_pool == 0 then
      rs = replica_set:new(self.pool)
   else
      rs = table.remove(self._rs_pool, 1)
   end
   
   return rs
end

function _M.put_replica_set(self, rs)
   rs:deinit()
   table.insert(self._rs_pool, rs)
end

-- Public Methods

function _M.set_servers(self, configs)
   local configs = configs
   local tmp_server_map = {}

   -- Update server status
   for _, config in ipairs(configs) do
      local id = config.id

      if self.server_map[id] then
         local s = self.server_map[id]
         s:update_config(config)
         tmp_server_map[id] = s
         self.server_map[id] = nil
      else
         tmp_server_map[id] = self:fetch_server(config)
      end
   end

   -- Swap server_map
   self.server_map, tmp_server_map = tmp_server_map, self.server_map

   -- Check server list changes

   -- Drop servers that we no longer use
   for id, s in pairs(tmp_server_map) do
      C.ffi_server_table_delete(__pool, s.addr)
      print("delete server from table", s.addr)
      self:put_server(s)
   end

   local tmp_server_names = {}
   local server_changed = false

   for _, s in pairs(self.server_map) do
      table.insert(tmp_server_names, s.addr)
      -- Add a chance to reconnection
      s:connect()
   end

   table.sort(tmp_server_names)
   if #tmp_server_names ~= #self.last_server_names then
      server_changed = true
   elseif table.concat(tmp_server_names) ~= table.concat(self.last_server_names) then
      server_changed = true
   end
   
   if server_changed then
      print("server list changed, will update stats and server_table")
      -- Reset stats
      C.ffi_pool_clear_servers(__pool)

      for _, s in pairs(self.server_map) do
         -- Set server addr->server map
         print("insert server to table", s.addr)
         if C.ffi_server_table_set(__pool, s.addr, s.raw) < 0 then
            error("set server table failed")
         end
         C.ffi_pool_add_server(__pool, s.raw)
      end

      C.ffi_stats_reset(__pool)
   end

   self.last_server_names = tmp_server_names
end

function _M.build_replica_sets(self)
   local tmp_rss = {}

   -- Set masters
   for id,s in pairs(self.server_map) do
      if s:is_master() then
         local rs = self:fetch_replica_set()
         rs:set_master(s)        -- for write
         rs:add_tagged_server(s) -- for read
         table.insert(tmp_rss, rs)
      end
   end

   -- Set slaves
   for id,s in pairs(self.server_map) do
      if s:is_slave() then
         local ms = self.server_map[s.master_id]
         if ms ~= nil then
            local rs = ms.replica_set
            rs:add_tagged_server(s)
         end
      end
   end

   -- Swap replicasets
   self.replica_sets, tmp_rss = tmp_rss, self.replica_sets

   -- Recycle
   for _, rs in ipairs(tmp_rss) do
      self:put_replica_set(rs)
   end
end

function _M.bind_slots(self)
   for _,rs in ipairs(self.replica_sets) do
      rs:bind_slots()
   end
end

return _M
