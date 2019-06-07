--- Headers policy
-- This policy allows to include custom headers that will be sent to the
-- upstream as well as modify or delete the ones included in the original
-- request.
-- Similarly, this policy also allows to add, modify, and delete the headers
-- included in the response.

local ipairs = ipairs
local type = type
local insert = table.insert

local TemplateString = require 'apicast.template_string'
local default_value_type = 'plain'

local policy = require('apicast.policy')
local _M = policy.new('Headers policy')

local new = _M.new

local random = math.random

local function uuid()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

local function new_header_value(current_value, value_to_add)
  if not value_to_add then return current_value end

  local new_value = current_value or {}

  if type(new_value) == 'string' then
    new_value = { new_value }
  end

  insert(new_value, value_to_add)
  return new_value
end

local function push_request_header(header_name, req_headers)
  local new_value = new_header_value(req_headers[header_name], uuid())
  ngx.req.set_header(header_name, new_value)
end

local function add_request_header(header_name, req_headers)
  if req_headers[header_name] then
    push_request_header(header_name, req_headers)
  end
end


local command_functions = {
  request = {
    add = add_request_header
  }
}

-- header_type can be 'request' or 'response'.
local function run_commands(context, commands, header_type, ...)
  for _, command in ipairs(commands) do
    local command_func = command_functions[header_type][command.op]
    local value = command.template_string:render(context)

    command_func(command.header, value, ...)
  end
end

-- Initialize the config so we do not have to check for nulls in the rest of
-- the code.
local function init_config(config)
  local res = config or {}
  res.request = res.request or {}
  return res
end

local function build_templates(commands)
  for _, command in ipairs(commands) do
    command.template_string = TemplateString.new(
      command.value, command.value_type or default_value_type)
  end
end

--- Initialize a Headers policy
-- @tparam[opt] table config
-- @field[opt] request Table with the operations to apply to the request headers
-- @field[opt] response Table with the operations to apply to the response headers
-- Each operation is a table with three elements:
--   1) op: can be 'add', 'set', 'push' or 'delete'.
--   2) header
--   3) value
--   4) value_type (can be 'liquid' or 'plain'). Defaults to 'plain'.
-- The push operation:
--   1) When the header is not set, creates it with the given value.
--   2) When the header is set, it creates a new header with the same name and
--      the given value.
-- The set operation:
--   1) When the header is not set, creates it with the given value.
--   2) When the header is set, replaces its value with the given one.
--   3) Deletes a header when the value is "".
-- The add operation:
--   1) When the header is not set, it does nothing.
--   2) When the header is set, it creates a new header with the same name and
--      the given value.
-- The delete operation:
--   1) Deletes a header when it is set.
function _M.new(config)
  local self = new(config)
  self.config = init_config(config)

  for _, commands in ipairs(self.config.request) do
    build_templates(commands)
  end

  return self
end

function _M:rewrite(context)
  -- This is here to avoid calling ngx.req.get_headers() in every command
  -- applied to the request headers.
  local req_headers = ngx.req.get_headers() or {}
  run_commands(context, self.config.request, 'request', req_headers)
end


return _M
