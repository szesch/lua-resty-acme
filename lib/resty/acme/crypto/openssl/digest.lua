local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new
local ffi_str = ffi.string

local _M = {}
local mt = {__index = _M}

require "resty.acme.crypto.openssl.ossl_typ"
require "resty.acme.crypto.openssl.evp"

function _M.new(typ)
  local ctx = C.EVP_MD_CTX_new()
  if not ctx then
    return nil, "EVP_MD_CTX_new() failed"
  end
  local typ = C.EVP_get_digestbyname(typ or 'sha1')
  if not typ then
    return nil, "EVP_get_digestbyname() failed"
  end
  local code = C.EVP_DigestInit_ex(ctx, typ, nil)
  if code ~= 1 then
    return nil, "EVP_DigestInit_ex() failed"
  end

  ffi_gc(ctx, C.EVP_MD_CTX_free)

  return setmetatable({ ctx = ctx }, mt), nil
end

function _M:update(...)
  for _, s in ipairs({...}) do
    C.EVP_DigestUpdate(self.ctx, s, #s)
  end
end

local uint_ptr = ffi.typeof("unsigned int[1]")

function _M:final(s)
  C.EVP_DigestUpdate(self.ctx, s, #s)
  -- # define EVP_MAX_MD_SIZE                 64/* longest known is SHA512 */
  local buf = ffi_new('unsigned char[?]', 64)
  local length = uint_ptr()
  C.EVP_DigestFinal_ex(self.ctx, buf, length)
  return ffi_str(buf, length[0]), nil
end

return _M