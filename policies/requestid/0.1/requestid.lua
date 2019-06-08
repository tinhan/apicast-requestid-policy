local _M = require('apicast.policy').new('Generate Request Id', '0.1')

local new = _M.new

local ipairs = ipairs
local insert = table.insert

local random = math.random
local function uuid()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

function _M.new(configuration)
  local self = new()

  local ops = {}

  local config = configuration or {}
  local set_header = config.set_header or {}
  
  for _, header in ipairs(set_header) do
    local rqid = uuid()
    insert(ops, function()
      ngx.log(ngx.NOTICE, 'setting header: ', header.name, ' to: ', rqid)
      ngx.req.set_header(header.name, rqid)
    end)
  end

  self.ops = ops

  return self
end

function _M:rewrite()
  for _,op in ipairs(self.ops) do
    op()
  end
end

return _M
