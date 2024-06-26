local http = require("resty.http")
local cjson = require("cjson")

local _M = {}
local mt = {__index = _M}

function _M.new(token)
  if not token or token == "" then
    return nil, "api token is needed"
  end

  local self = setmetatable({
    endpoint = "https://dynv6.com/api/v2",
    httpc = nil,
    token = token,
    zone = nil,
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. token,
    }
  }, mt)

  self.httpc = http.new()
  return self
end

local function get_zone_id(self, fqdn)
  local url = self.endpoint .. "/zones"
  local resp, err = self.httpc:request_uri(url,
    {
      method = "GET",
      headers = self.headers
    }
  )
  if err then
    return nil, err
  end

  if resp and resp.status == 200 then
    -- [{
    --  "name":"domain.dynv6.net",
    --  "ipv4address":"",
    --  "ipv6prefix":"",
    --  "id":1,
    --  "createdAt":"2022-08-14T17:32:57+02:00",
    --  "updatedAt":"2022-08-14T17:32:57+02:00"
    -- }]
    local body = cjson.decode(resp.body)
    if not body then
      return nil, "json decode error"
    end

    for _, zone in ipairs(body) do
      local start, _, err = fqdn:find(zone.name, 1, true)
      if err then
        return nil, err
      end
      if start then
        self.zone = zone.name
        return zone.id
      end
    end
  end

  return nil, "no matched dns zone found"
end

function _M:post_txt_record(fqdn, content)
  local zone_id, err = get_zone_id(self, fqdn)
  if err then
    return nil, err
  end
  local url = self.endpoint .. "/zones/" .. zone_id .. "/records"
  local body = {
    ["type"] = "TXT",
    ["name"] = fqdn:gsub("." .. self.zone, ""),
    ["data"] = content
  }
  local resp, err = self.httpc:request_uri(url,
    {
      method = "POST",
      headers = self.headers,
      body = cjson.encode(body)
    }
  )
  if err then
    return nil, err
  end

  return resp.status
end

local function get_record_id(self, zone_id, fqdn)
  local url = self.endpoint .. "/zones/" .. zone_id .. "/records"
  local resp, err = self.httpc:request_uri(url,
    {
      method = "GET",
      headers = self.headers
    }
  )
  if err then
    return nil, err
  end

  if resp and resp.status == 200 then
    -- [{
    --   "type":"TXT",
    --   "name":"_acme-challenge",
    --   "data":"record_content",
    --   "priority":null,
    --   "flags":null,
    --   "tag":null,
    --   "weight":null,
    --   "port":null,
    --   "id":1,
    --   "zoneID":1
    -- }]
    local body = cjson.decode(resp.body)
    if not body then
      return nil, "json decode error"
    end

    for _, record in ipairs(body) do
      local start, _, err = fqdn:find(record.name, 1, true)
      if err then
        return nil, err
      end
      if start then
        return record.id
      end
    end
  end

  return nil, "no matched dns record found"
end

function _M:delete_txt_record(fqdn)
  local zone_id, err = get_zone_id(self, fqdn)
  if err then
    return nil, err
  end
  local record_id, err = get_record_id(self, zone_id, fqdn)
  if err then
    return nil, err
  end
  local url = self.endpoint .. "/zones/" .. zone_id .. "/records/" .. record_id
  local resp, err = self.httpc:request_uri(url,
    {
      method = "DELETE",
      headers = self.headers
    }
  )
  if err then
    return nil, err
  end
  -- return 204 not content
  return resp.status
end

return _M
