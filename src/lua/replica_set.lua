local ffi = require("ffi")
local C = ffi.C

ffi.cdef[[
      struct replicaset;
      struct server;
      struct server_pool;

      int ffi_slots_set_replicaset(struct server_pool *pool, struct replicaset *rs, int left, int right);

      struct replicaset* ffi_replicaset_new();
      void ffi_replicaset_deinit(struct replicaset *rs);
      void ffi_replicaset_delete(struct replicaset *rs);
      void ffi_replicaset_set_master(struct replicaset *rs, struct server *server);
      void ffi_replicaset_add_tagged_server(struct replicaset *rs, int tag_idx, struct server *server);
]]

local _M = {}
local mt = { __index = _M }

function _M.new(self)
   local raw = C.ffi_replicaset_new();
   return setmetatable({ raw = raw }, mt)
end

function _M.set_master(self, s)
   self.ranges = s.ranges
   s.replica_set = self
   if s.writable then
      C.ffi_replicaset_set_master(self.raw, s.raw)
   end
end

function _M.add_tagged_server(self, s)
   if s.tag_idx >= 0 and s.readable then
      C.ffi_replicaset_add_tagged_server(self.raw, s.tag_idx, s.raw)
   end
end

function _M.bind_slots(self)
   for i, range in ipairs(self.ranges) do
      C.ffi_slots_set_replicaset(__pool, self.raw, range.left, range.right)
   end
end

function _M.deinit(self)
   C.ffi_replicaset_deinit(self.raw);
end

return _M
