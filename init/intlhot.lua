local socket = require 'socket'
local http = require 'socket.http'
local JSON = require 'cjson'
local luasql = require "luasql.mysql"
local env = assert(luasql.mysql())
local con = assert (env:connect("biyifei_base", "rhomobi_dev", "b6x7p6b6x7p6", "127.0.0.1", 3306))
package.path = "/usr/local/webserver/lua/lib/?.lua;";
-- pcall(require, "luarocks.require")

local redis = require 'redis'

local params = {
    host = '127.0.0.1',
    port = 6389,
}


local paramswork = {
    host = '127.0.0.1',
    port = 6389,
}

local client = redis.connect(params)
client:select(0) -- for testing purposes

local clientwork = redis.connect(paramswork)
clientwork:select(0) -- for testing purposes

-- commands defined in the redis.commands table are available at module
-- level and are used to populate each new client instance.
redis.commands.hset = redis.command('hset')
redis.commands.sadd = redis.command('sadd')
redis.commands.zadd = redis.command('zadd')
redis.commands.smembers = redis.command('smembers')
redis.commands.keys = redis.command('keys')
redis.commands.sdiff = redis.command('sdiff')
redis.commands.zrange = redis.command('zrange')
redis.commands.zscore = redis.command('zscore')

function sleep(n)
   socket.select(nil, nil, n)
end

-- zrange city:local 0 -1
local data = client:zrange("city:int", 0, -1)
local idxs = table.getn(data)
print(idxs)
local hot = client:zrangebyscore("city:int", "(28", "+inf")
print(table.getn(hot))

print("\r\n----------local & international-----------\r\n");
sqlcmd = "SELECT `city_code`, `city_name` FROM `internationalcitys`";
local cur = assert (con:execute(sqlcmd))

local row = cur:fetch ({}, "a")
local cityex = {};
while row do
	-- print(row.city_code)
	table.insert(cityex, row.city_code)
	-- print(row.city_name)
	row = cur:fetch (row, "a")
end
cur:close()

local lenex = table.getn(cityex)
print(lenex)
con:close()
env:close()
local ex = {};
for i = 1, lenex do
	-- print(lenex)
	if ex[cityex[i]] ~= true then
		ex[cityex[i]] = true
	end
end
-- print(cityex[1])
-- print(ex[cityex[1]])
-- print(ex["TGG"])
-- print(table.getn(ex))

for idx = 1, table.getn(hot) do
	-- print(hot[idx])
	local t = string.sub(hot[idx], 1, 3);
	-- print(string.upper(t))
	-- print(ex[string.upper(t)])
	if ex[string.upper(t)] ~= true then
		print(hot[idx])
		local tmpscore = client:zscore("city:int", hot[idx])
		clientwork:zadd("city:hot", tmpscore, hot[idx])
	end
end
--[[

local task = client:sdiff("city:int:hot", "city:err", "city:local:done")
print(table.getn(task))

for idxi = 1, idxs do
	local checkcity = string.sub(data[idxi], 5, 7) .. "/" .. string.sub(data[idxi], 1, 3);
	local index, err = client:zrank("city:loc", checkcity)
	if index == nil then
		print(checkcity)
		-- client:zadd("city:loc", 0, checkcity)
	end
	-- client:sadd("city:local:done", done[idxi])
end
local wname = "/data/logs/intnaltolocal.ini"
local wfile = io.open(wname, "w+");
for idxi = 1, idxs do
	local checkcity = string.sub(data[idxi], 5, 7) .. "/" .. string.sub(data[idxi], 1, 3);
	local index, err = client:zrank("city:int", checkcity)
	if index == nil then
		-- print(idxi, checkcity)
		wfile:write(checkcity .. "\n");
	end
	-- client:sadd("city:local:done", done[idxi])
end
io.close(wfile);

local wname = "/data/logs/internationalcityhasline.ini"
local wfile = io.open(wname, "w+");
for k, v in ipairs(data) do
	wfile:write(v .. "\n");
end
io.close(wfile);

for idxi = 1, idxs do
	client:sadd("city:local:done", done[idxi])
end

local task = client:sdiff("city:cn", "city:err", "city:local:done")
print(table.getn(task))
--]]