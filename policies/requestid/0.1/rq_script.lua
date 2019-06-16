local setmetatable = setmetatable

local _M = require('apicast.policy').new('Gen UUID', '0.1')
local mt = { __index = _M }

function _M.new()
  return setmetatable({}, mt)
end

function _M:rewrite()
  local config = configuration or {}
  local set_header = config.set_header or {}
  local random = math.random
  local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  local rq_uuid = string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v) end)
  
  ngx.req.set_header('x-request-id', rq_uuid)
  ngx.log(0, 'In coming request { x-request-id : ', rq_uuid, ', { Body : ', ngx.var.request_body , ' } }')
  
end

function _M:body_filter()
    local resp = ""
    local rq_uid = ngx.req.get_headers()["x-request-id"]
    ngx.ctx.buffered = (ngx.ctx.buffered or "") .. string.sub(ngx.arg[1], 1, 1000)
    if ngx.arg[2] then
      resp = ngx.ctx.buffered
    end

    ngx.log(0, 'Out going response { x-request-id : ', rq_uid, ', { Body : ', resp , ' } }')
  
end



return _M
