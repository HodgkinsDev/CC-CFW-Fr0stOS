local preload = type(package) == "table" and type(package.preload) == "table" and package.preload or {}

local require = require
if type(require) ~= "function" then
	local loading = {}
	local loaded = {}
	require = function(name)
		local result = loaded[name]

		if result ~= nil then
			if result == loading then
				error("loop or previous error loading module '" .. name .. "'", 2)
			end

			return result
		end

		loaded[name] = loading
		local contents = preload[name]
		if contents then
			result = contents(name)
		else
			error("cannot load '" .. name .. "'", 2)
		end

		if result == nil then result = true end
		loaded[name] = result
		return result
	end
end
preload["objects"] = function(...)
local inflate_zlib = require "deflate".inflate_zlib
local sha = require "metis.crypto.sha1"

local band, bor, lshift, rshift = bit32.band, bit32.bor, bit32.lshift, bit32.rshift
local byte, format, sub = string.byte, string.format, string.sub

local types = { [0] = "none", "commit", "tree", "blob", "tag", nil, "ofs_delta", "ref_delta", "any", "max" }

--- Get the type of a specific object
-- @tparam Object x The object to get the type of
-- @treturn string The object's type.
local function get_type(x) return types[x.ty] or "?" end

local event = ("luagit-%08x"):format(math.random(0, 2^24))
local function check_in()
  os.queueEvent(event)
  os.pullEvent(event)
end

local sha_format = ("%02x"):rep(20)

local function reader(str)
  local expected_checksum = format(sha_format, byte(str, -20, -1))
  local actual_checksum = sha(str:sub(1, -21));
  if expected_checksum ~= actual_checksum then
    error(("checksum mismatch: expected %s, got %s"):format(expected_checksum, actual_checksum))
  end

  str = str:sub(1, -20)

  local pos = 1

  local function consume_read(len)
    if len <= 0 then error("len < 0", 2) end
    if pos > #str then error("end of stream") end

    local cur_pos = pos
    pos = pos + len
    local res = sub(str, cur_pos, pos - 1)
    if #res ~= len then error("expected " .. len .. " bytes, got" .. #res) end
    return res
  end

  local function read8()
    if pos > #str then error("end of stream") end
    local cur_pos = pos
    pos = pos + 1
    return byte(str, cur_pos)
  end

  return {
    offset = function() return pos - 1 end,
    read8 = read8,
    read16 = function() return (read8() * (2^8)) + read8() end,
    read32 = function() return (read8() * (2^24)) + (read8() * (2^16)) + (read8() * (2^8)) + read8() end,
    read = consume_read,

    close = function()
      if pos ~= #str then error(("%d of %d bytes remaining"):format(#str - pos + 1, #str)) end
    end,
  }
end

--- Consume a string from the given input buffer
--
-- @tparam Reader handle The handle to read from
-- @tparam number size The number of decompressed bytes to read
-- @treturn string The decompressed data
local function get_data(handle, size)
  local tbl, n = {}, 1

  inflate_zlib {
    input = handle.read8,
    output = function(x) tbl[n], n = string.char(x), n + 1 end
  }

  local res = table.concat(tbl)
  if #res ~= size then error(("expected %d decompressed bytes, got %d"):format(size, #res)) end
  return res
end

--- Decode a binary delta file, applying it to the original
--
-- The format is described in more detail in [the Git documentation][git_pack]
--
-- [git_pack]: https://git-scm.com/docs/pack-format#_deltified_representation
--
-- @tparam string original The original string
-- @tparam string delta The binary delta
-- @treturn string The patched string
local function apply_delta(original, delta)
  local delta_offset = 1
  local function read_size()
    local c = byte(delta, delta_offset)
    delta_offset = delta_offset + 1

    local size = band(c, 0x7f)
    local shift = 7
    while band(c, 0x80) ~= 0 do
      c, delta_offset = byte(delta, delta_offset), delta_offset + 1
      size, shift = size + lshift(band(c, 0x7f), shift), shift + 7
    end

    return size
  end

  local original_length = read_size()
  local patched_length = read_size()
  if original_length ~= #original then
    error(("expected original of size %d, got size %d"):format(original_length, #original))
  end

  local parts, n = {}, 1
  while delta_offset <= #delta do
    local b = byte(delta, delta_offset)
    delta_offset = delta_offset + 1

    if band(b, 0x80) ~= 0 then
      -- Copy from the original file. Each bit represents which optional length/offset
      -- bits are used.
      local offset, length = 0, 0

      if band(b, 0x01) ~= 0 then
        offset, delta_offset = bor(offset, byte(delta, delta_offset)), delta_offset + 1
      end
      if band(b, 0x02) ~= 0 then
        offset, delta_offset = bor(offset, lshift(byte(delta, delta_offset), 8)), delta_offset + 1
      end
      if band(b, 0x04) ~= 0 then
        offset, delta_offset = bor(offset, lshift(byte(delta, delta_offset), 16)), delta_offset + 1
      end
      if band(b, 0x08) ~= 0 then
        offset, delta_offset = bor(offset, lshift(byte(delta, delta_offset), 24)), delta_offset + 1
      end

      if band(b, 0x10) ~= 0 then
        length, delta_offset = bor(length, byte(delta, delta_offset)), delta_offset + 1
      end
      if band(b, 0x20) ~= 0 then
        length, delta_offset = bor(length, lshift(byte(delta, delta_offset), 8)), delta_offset + 1
      end
      if band(b, 0x40) ~= 0 then
        length, delta_offset = bor(length, lshift(byte(delta, delta_offset), 16)), delta_offset + 1
      end
      if length == 0 then length = 0x10000 end

      parts[n], n = sub(original, offset + 1, offset + length), n + 1
    elseif b > 0 then
      -- Copy from the delta. The opcode encodes the length
      parts[n], n = sub(delta, delta_offset, delta_offset + b - 1), n + 1
      delta_offset = delta_offset + b
    else
      error(("unknown opcode '%02x'"):format(b))
    end
  end

  local patched = table.concat(parts)
  if patched_length ~= #patched then
    error(("expected patched of size %d, got size %d"):format(patched_length, #patched))
  end

  return patched
end

--- Unpack a single object, populating the output table
--
-- @tparam Reader handle The handle to read from
-- @tparam { [string] = Object } out The populated data
local function unpack_object(handle, out)
  local c = handle.read8()
  local ty = band(rshift(c, 4), 7)
  local size = band(c, 15)
  local shift = 4
  while band(c, 0x80) ~= 0 do
    c = handle.read8()
    size = size + lshift(band(c, 0x7f), shift)
    shift = shift + 7
  end

  local data
  if ty >= 1 and ty <= 4 then
    -- commit/tree/blob/tag
    data = get_data(handle, size)
  elseif ty == 6 then
    -- ofs_delta
    data = get_data(handle, size)
    error("ofs_delta not yet implemented")

  elseif ty == 7 then
    -- ref_delta
    local base_hash = sha_format:format(handle.read(20):byte(1, 20))
    local delta = get_data(handle, size)

    local original = out[base_hash]
    if not original then error(("cannot find object %d to apply diff"):format(base_hash)) return end
    ty = original.ty
    data = apply_delta(original.data, delta)
  else
    error(("unknown object of type '%d'"):format(ty))
  end

  -- We've got to do these separately. Format doesn't like null bytes
  local whole = ("%s %d\0"):format(types[ty], #data) .. data
  local sha = sha(whole)
  out[sha] = { ty = ty, data = data, sha = sha }
end

local function unpack(handle, progress)
  local header = handle.read(4)
  if header ~= "PACK" then error("expected PACK, got " .. header, 0) end

  local version = handle.read32()
  local entries = handle.read32()

  local out = {}
  for i = 1, entries do
    if progress then progress(i, entries) end
    check_in()

    unpack_object(handle, out)
  end

  return out
end

local function build_tree(objects, object, prefix, out)
  if not prefix then prefix = "" end
  if not out then out = {} end

  local idx = 1

  while idx <= #object do
    -- dddddd NAME\0<SHA>
    local _, endidx, mode, name = object:find("^(%x+) ([^%z]+)%z", idx)
    if not endidx then break end
    name = prefix .. name

    local sha = object:sub(endidx + 1, endidx + 20):gsub(".", function(x) return ("%02x"):format(string.byte(x)) end)

    local entry = objects[sha]
    if not entry then error(("cannot find %s %s (%s)"):format(mode, name, sha)) end

    if entry.ty == 3 then
      out[name] = entry.data
    elseif entry.ty == 2 then
      build_tree(objects, entry.data, name .. "/", out)
    else
      error("unknown type for " .. name .. " (" .. sha .. "): " .. get_type(entry))
    end

    idx = endidx + 21
  end

  return out
end

local function build_commit(objects, sha)
  local commit = objects[sha]
  if not commit then error("cannot find commit " .. sha) end
  if commit.ty ~= 1 then error("Expected commit, got " .. types[commit.ty]) end

  local tree_sha = commit.data:match("tree (%x+)\n")
  if not tree_sha then error("Cannot find tree from commit") end

  local tree = objects[tree_sha]
  if not tree then error("cannot find tree " .. tree_sha) end
  if tree.ty ~= 2 then error("Expected tree, got " .. tree[tree.ty]) end

  return build_tree(objects, tree.data)
end

return {
  reader = reader,
  unpack = unpack,
  build_tree = build_tree,
  build_commit = build_commit,
  type = get_type,
}
end
preload["network"] = function(...)
local function pkt_line(msg)
  return ("%04x%s\n"):format(5 + #msg, msg)
end

local function pkt_linef(fmt, ...)
  return pkt_line(fmt:format(...))
end

local flush_line = "0000"

local function read_pkt_line(handle)
  local data = handle.read(4)
  if data == nil or data == "" then return nil end

  local len = tonumber(data, 16)
  if len == nil then
    error(("read_pkt_line: cannot convert %q to a number"):format(data))
  elseif len == 0 then
    return false, data
  else
    return handle.read(len - 4), data
  end
end

local function fetch(url, lines, content_type)
  if type(lines) == "table" then lines = table.concat(lines) end

  local ok, err = http.request(url, lines, {
    ['User-Agent'] = 'CCGit/1.0',
    ['Content-Type'] = content_type,
  }, true)

  if ok then
    while true do
      local event, event_url, param1, param2 = os.pullEvent()
      if event == "http_success" and event_url == url then
        return true, param1
      elseif event == "http_failure" and event_url == url then
        printError("Cannot fetch " .. url .. ": " .. param1)
        return false, param2
      end
    end
  else
    printError("Cannot fetch " .. url .. ": " .. err)
    return false, nil
  end
end

local function force_fetch(...)
  local ok, handle, err_handle = fetch(...)
  if not ok then
    if err_handle then
      print(err_handle.getStatusCode())
      print(textutils.serialize(err_handle.getResponseHeaders()))
      print(err_handle.readAll())
    end
    error("Cannot fetch", 0)
  end

  return handle
end

local function receive(handle)
  local out = {}
  while true do
    local line = read_pkt_line(handle)
    if line == nil then break end
    out[#out + 1] = line
  end

  handle.close()
  return out
end

return {
  read_pkt_line = read_pkt_line,
  force_fetch = force_fetch,
  receive = receive,

  pkt_linef = pkt_linef,
  flush_line = flush_line,
}
end
preload["deflate"] = function(...)
--[[
  (c) 2008-2011 David Manura.  Licensed under the same terms as Lua (MIT).

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
  (end license)
--]]

local assert, error, ipairs, pairs, tostring, type, setmetatable, io, math
    = assert, error, ipairs, pairs, tostring, type, setmetatable, io, math
local table_sort, math_max, string_char = table.sort, math.max, string.char
local band, lshift, rshift = bit32.band, bit32.lshift, bit32.rshift

local function make_outstate(outbs)
  local outstate = {}
  outstate.outbs = outbs
  outstate.len = 0
  outstate.window = {}
  outstate.window_pos = 1
  return outstate
end


local function output(outstate, byte)
  local window_pos = outstate.window_pos
  outstate.outbs(byte)
  outstate.len = outstate.len + 1
  outstate.window[window_pos] = byte
  outstate.window_pos = window_pos % 32768 + 1  -- 32K
end


local function noeof(val)
  return assert(val, 'unexpected end of file')
end

local function memoize(f)
  return setmetatable({}, {
    __index = function(self, k)
      local v = f(k)
      self[k] = v
      return v
    end
  })
end

-- small optimization (lookup table for powers of 2)
local pow2 = memoize(function(n) return 2^n end)

local function bitstream_from_bytestream(bys)
  local buf_byte = 0
  local buf_nbit = 0
  local o = { type = "bitstream" }

  function o:nbits_left_in_byte()
    return buf_nbit
  end

  function o:read(nbits)
     nbits = nbits or 1
     while buf_nbit < nbits do
      local byte = bys()
      if not byte then return end  -- note: more calls also return nil
      buf_byte = buf_byte + lshift(byte, buf_nbit)
      buf_nbit = buf_nbit + 8
     end
     local bits
     if nbits == 0 then
      bits = 0
     elseif nbits == 32 then
      bits = buf_byte
      buf_byte = 0
     else
      bits = band(buf_byte, rshift(0xffffffff, 32 - nbits))
      buf_byte = rshift(buf_byte, nbits)
     end
     buf_nbit = buf_nbit - nbits
     return bits
  end

  return o
end

local function get_bitstream(o)
  if type(o) == "table" and o.type == "bitstream" then
    return o
  elseif io.type(o) == 'file' then
    return bitstream_from_bytestream(function() local sb = o:read(1) if sb then return sb:byte() end end)
  elseif type(o) == "function" then
    return bitstream_from_bytestream(o)
  else
    error 'unrecognized type'
  end
end


local function get_obytestream(o)
  local bs
  if io.type(o) == 'file' then
    bs = function(sbyte) o:write(string_char(sbyte)) end
  elseif type(o) == 'function' then
    bs = o
  else
    error('unrecognized type: ' .. tostring(o))
  end
  return bs
end


local function HuffmanTable(init, is_full)
  local t = {}
  if is_full then
    for val,nbits in pairs(init) do
      if nbits ~= 0 then
        t[#t+1] = {val=val, nbits=nbits}
      end
    end
  else
    for i=1,#init-2,2 do
      local firstval, nbits, nextval = init[i], init[i+1], init[i+2]
      if nbits ~= 0 then
        for val=firstval,nextval-1 do
          t[#t+1] = {val=val, nbits=nbits}
        end
      end
    end
  end
  table_sort(t, function(a,b)
    return a.nbits == b.nbits and a.val < b.val or a.nbits < b.nbits
  end)

  -- assign codes
  local code = 1  -- leading 1 marker
  local nbits = 0
  for _, s in ipairs(t) do
    if s.nbits ~= nbits then
      code = code * pow2[s.nbits - nbits]
      nbits = s.nbits
    end
    s.code = code
    code = code + 1
  end

  local minbits = math.huge
  local look = {}
  for _, s in ipairs(t) do
    minbits = math.min(minbits, s.nbits)
    look[s.code] = s.val
  end

  local msb = function(bits, nbits)
    local res = 0
    for _ = 1, nbits do
      res = lshift(res, 1) + band(bits, 1)
      bits = rshift(bits, 1)
    end
    return res
  end

  local tfirstcode = memoize(
    function(bits) return pow2[minbits] + msb(bits, minbits) end)

  function t:read(bs)
    local code = 1 -- leading 1 marker
    local nbits = 0
    while 1 do
      if nbits == 0 then  -- small optimization (optional)
        code = tfirstcode[noeof(bs:read(minbits))]
        nbits = nbits + minbits
      else
        local b = noeof(bs:read())
        nbits = nbits + 1
        code = code * 2 + b   -- MSB first
      end
      local val = look[code]
      if val then
        return val
      end
    end
  end

  return t
end

local function parse_zlib_header(bs)
  local cm = bs:read(4) -- Compression Method
  local cinfo = bs:read(4) -- Compression info
  local fcheck = bs:read(5) -- FLaGs: FCHECK (check bits for CMF and FLG)
  local fdict = bs:read(1) -- FLaGs: FDICT (present dictionary)
  local flevel = bs:read(2) -- FLaGs: FLEVEL (compression level)
  local cmf = cinfo * 16  + cm -- CMF (Compresion Method and flags)
  local flg = fcheck + fdict * 32 + flevel * 64 -- FLaGs

  if cm ~= 8 then -- not "deflate"
    error("unrecognized zlib compression method: " .. cm)
  end
  if cinfo > 7 then
    error("invalid zlib window size: cinfo=" .. cinfo)
  end
  local window_size = 2^(cinfo + 8)

  if (cmf*256 + flg) %  31 ~= 0 then
    error("invalid zlib header (bad fcheck sum)")
  end

  if fdict == 1 then
    error("FIX:TODO - FDICT not currently implemented")
    local dictid_ = bs:read(32)
  end

  return window_size
end

local function parse_huffmantables(bs)
    local hlit = bs:read(5)  -- # of literal/length codes - 257
    local hdist = bs:read(5) -- # of distance codes - 1
    local hclen = noeof(bs:read(4)) -- # of code length codes - 4

    local ncodelen_codes = hclen + 4
    local codelen_init = {}
    local codelen_vals = {
      16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15}
    for i=1,ncodelen_codes do
      local nbits = bs:read(3)
      local val = codelen_vals[i]
      codelen_init[val] = nbits
    end
    local codelentable = HuffmanTable(codelen_init, true)

    local function decode(ncodes)
      local init = {}
      local nbits
      local val = 0
      while val < ncodes do
        local codelen = codelentable:read(bs)
        --FIX:check nil?
        local nrepeat
        if codelen <= 15 then
          nrepeat = 1
          nbits = codelen
        elseif codelen == 16 then
          nrepeat = 3 + noeof(bs:read(2))
          -- nbits unchanged
        elseif codelen == 17 then
          nrepeat = 3 + noeof(bs:read(3))
          nbits = 0
        elseif codelen == 18 then
          nrepeat = 11 + noeof(bs:read(7))
          nbits = 0
        else
          error 'ASSERT'
        end
        for _ = 1, nrepeat do
          init[val] = nbits
          val = val + 1
        end
      end
      local huffmantable = HuffmanTable(init, true)
      return huffmantable
    end

    local nlit_codes = hlit + 257
    local ndist_codes = hdist + 1

    local littable = decode(nlit_codes)
    local disttable = decode(ndist_codes)

    return littable, disttable
end


local tdecode_len_base
local tdecode_len_nextrabits
local tdecode_dist_base
local tdecode_dist_nextrabits
local function parse_compressed_item(bs, outstate, littable, disttable)
  local val = littable:read(bs)
  if val < 256 then -- literal
    output(outstate, val)
  elseif val == 256 then -- end of block
    return true
  else
    if not tdecode_len_base then
      local t = {[257]=3}
      local skip = 1
      for i=258,285,4 do
        for j=i,i+3 do t[j] = t[j-1] + skip end
        if i ~= 258 then skip = skip * 2 end
      end
      t[285] = 258
      tdecode_len_base = t
    end
    if not tdecode_len_nextrabits then
      local t = {}
      for i=257,285 do
        local j = math_max(i - 261, 0)
        t[i] = rshift(j, 2)
      end
      t[285] = 0
      tdecode_len_nextrabits = t
    end
    local len_base = tdecode_len_base[val]
    local nextrabits = tdecode_len_nextrabits[val]
    local extrabits = bs:read(nextrabits)
    local len = len_base + extrabits

    if not tdecode_dist_base then
      local t = {[0]=1}
      local skip = 1
      for i=1,29,2 do
        for j=i,i+1 do t[j] = t[j-1] + skip end
        if i ~= 1 then skip = skip * 2 end
      end
      tdecode_dist_base = t
    end
    if not tdecode_dist_nextrabits then
      local t = {}
      for i=0,29 do
        local j = math_max(i - 2, 0)
        t[i] = rshift(j, 1)
      end
      tdecode_dist_nextrabits = t
    end
    local dist_val = disttable:read(bs)
    local dist_base = tdecode_dist_base[dist_val]
    local dist_nextrabits = tdecode_dist_nextrabits[dist_val]
    local dist_extrabits = bs:read(dist_nextrabits)
    local dist = dist_base + dist_extrabits

    for _ = 1,len do
      local pos = (outstate.window_pos - 1 - dist) % 32768 + 1  -- 32K
      output(outstate, assert(outstate.window[pos], 'invalid distance'))
    end
  end
  return false
end


local function parse_block(bs, outstate)
  local bfinal = bs:read(1)
  local btype = bs:read(2)

  local BTYPE_NO_COMPRESSION = 0
  local BTYPE_FIXED_HUFFMAN = 1
  local BTYPE_DYNAMIC_HUFFMAN = 2
  local _BTYPE_RESERVED = 3

  if btype == BTYPE_NO_COMPRESSION then
    bs:read(bs:nbits_left_in_byte())
    local len = bs:read(16)
    local _nlen = noeof(bs:read(16))

    for i=1,len do
      local by = noeof(bs:read(8))
      output(outstate, by)
    end
  elseif btype == BTYPE_FIXED_HUFFMAN or btype == BTYPE_DYNAMIC_HUFFMAN then
    local littable, disttable
    if btype == BTYPE_DYNAMIC_HUFFMAN then
      littable, disttable = parse_huffmantables(bs)
    else
      littable  = HuffmanTable {0,8, 144,9, 256,7, 280,8, 288,nil}
      disttable = HuffmanTable {0,5, 32,nil}
    end

    repeat
      local is_done = parse_compressed_item(
        bs, outstate, littable, disttable)
    until is_done
  else
    error('unrecognized compression type '..btype)
  end

  return bfinal ~= 0
end


local function inflate(t)
  local bs = get_bitstream(t.input)
  local outbs = get_obytestream(t.output)
  local outstate = make_outstate(outbs)

  repeat
    local is_final = parse_block(bs, outstate)
  until is_final
end

local function adler32(byte, crc)
  local s1 = crc % 65536
  local s2 = (crc - s1) / 65536
  s1 = (s1 + byte) % 65521
  s2 = (s2 + s1) % 65521
  return s2*65536 + s1
end -- 65521 is the largest prime smaller than 2^16

local function inflate_zlib(t)
  local bs = get_bitstream(t.input)
  local outbs = get_obytestream(t.output)
  local disable_crc = t.disable_crc
  if disable_crc == nil then disable_crc = false end

  local _window_size = parse_zlib_header(bs)

  local data_adler32 = 1

  inflate {
    input=bs,
    output = disable_crc and outbs or function(byte)
      data_adler32 = adler32(byte, data_adler32)
      outbs(byte)
    end,
    len = t.len,
  }

  bs:read(bs:nbits_left_in_byte())

  local b3 = bs:read(8)
  local b2 = bs:read(8)
  local b1 = bs:read(8)
  local b0 = bs:read(8)
  local expected_adler32 = ((b3*256 + b2)*256 + b1)*256 + b0

  if not disable_crc then
    if data_adler32 ~= expected_adler32 then
      error('invalid compressed data--crc error')
    end
  end
end

return {
  inflate = inflate,
  inflate_zlib = inflate_zlib,
}
end
preload["clone"] = function(...)
--- Git clone in Lua, from the bottom up
--
-- http://stefan.saasen.me/articles/git-clone-in-haskell-from-the-bottom-up/#the_clone_process
-- https://github.com/creationix/lua-git

do -- metis loader
  local modules = {
    ["metis.argparse"] = "src/metis/argparse.lua",
    ["metis.crypto.sha1"] = "src/metis/crypto/sha1.lua",
    ["metis.timer"] = "src/metis/timer.lua",
  }
  package.loaders[#package.loaders + 1] = function(name)
    local path = modules[name]
    if not path then return nil, "not a metis module" end

    local local_path = "/.cache/metis/ae11085f261e5b506654162c80d21954c0d54e5e/" .. path
    if not fs.exists(local_path) then
      local url = "https://raw.githubusercontent.com/SquidDev-CC/metis/ae11085f261e5b506654162c80d21954c0d54e5e/" .. path
      local request, err = http.get(url)
      if not request then return nil, "Cannot download " .. url .. ": " .. err end

      local out = fs.open(local_path, "w")
      out.write(request.readAll())
      out.close()

      request.close()
    end


    local fn, err = loadfile(local_path, nil, _ENV)
    if fn then return fn, local_path else return nil, err end
  end
end

local network = require "network"
local objects = require "objects"

local url, name = ...
if not url or url == "-h" or url == "--help" then error("clone.lua URL [name]", 0) end

if url:sub(-1) == "/" then url = url:sub(1, -2) end
name = name or fs.getName(url):gsub("%.git$", "")

local destination = shell.resolve(name)
if fs.exists(destination) then
  error(("%q already exists"):format(name), 0)
end

local function report(msg)
  local last = ""
  for line in msg:gmatch("[^\n]+") do last = line end
  term.setCursorPos(1, select(2, term.getCursorPos()))
  term.clearLine()
  term.write(last)
end

local head
do -- Request a list of all refs
  report("Cloning from " .. url)

  local handle = network.force_fetch(url .. "/info/refs?service=git-upload-pack")
  local res = network.receive(handle)

  local sha_ptrn = ("%x"):rep(40)

  local caps = {}
  local refs = {}
  for i = 1, #res do
    local line = res[i]
    if line ~= false and line:sub(1, 1) ~= "#" then
      local sha, name = line:match("(" .. sha_ptrn .. ") ([^%z\n]+)")
      if sha and name then
        refs[name] = sha

        local capData = line:match("%z([^\n]+)\n")
        if capData then
          for cap in (capData .. " "):gmatch("%S+") do
            local eq = cap:find("=")
            if eq then
              caps[cap:sub(1, eq - 1)] = cap:sub(eq + 1)
            else
              caps[cap] = true
            end
          end
        end
      else
        printError("Unexpected line: " .. line)
      end
    end
  end
  head = refs['HEAD'] or refs['refs/heads/master'] or error("Cannot find master", 0)

  if not caps['shallow'] then error("Server does not support shallow fetching", 0) end

  -- TODO: Handle both. We don't even need the side-band really?
  if not caps['side-band-64k'] then error("Server does not support side band", 0) end
end

do -- Now actually perform the clone
  local handle = network.force_fetch(url .. "/git-upload-pack", {
    network.pkt_linef("want %s side-band-64k shallow", head),
    network.pkt_linef("deepen 1"),
    network.flush_line,
    network.pkt_linef("done"),
  }, "application/x-git-upload-pack-request")

  local pack, head = {}, nil
  while true do
    local line = network.read_pkt_line(handle)
    if line == nil then break end

    if line == false or line == "NAK\n" then
      -- Skip
    elseif line:byte(1) == 1 then
      table.insert(pack, line:sub(2))
    elseif line:byte(1) == 2 or line:byte(1) == 3 then
      report(line:sub(2):gsub("\r", "\n"))
    elseif line:find("^shallow ") then
      head = line:sub(#("shallow ") + 1)
    else
      printError("Unknown line: " .. tostring(line))
    end
  end
  handle.close()

  local stream = objects.reader(table.concat(pack))
  local objs = objects.unpack(stream, function(x, n)
    report(("Extracting %d/%d (%.2f%%)"):format(x, n, x/n*100))
  end)
  stream.close()

  if not head then error("Cannot find HEAD commit", 0) end

  for k, v in pairs(objects.build_commit(objs, head)) do
    local out = fs.open(fs.combine(destination, fs.combine(k, "")), "wb")
    out.write(v)
    out.close()
  end
end

report(("Cloned to %q"):format(name))
print()
end
return preload["clone"](...)