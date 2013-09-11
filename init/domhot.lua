local socket = require 'socket'
local http = require 'socket.http'
local JSON = require 'cjson'

package.path = "/usr/local/webserver/lua/lib/?.lua;";
-- pcall(require, "luarocks.require")

local redis = require 'redis'

local params = {
    host = '127.0.0.1',
    port = 6388,
}

local paramswork = {
    host = 'rhomobi.com',
    port = 6388,
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
redis.commands.zrangebyscore = redis.command('zrangebyscore')


function sleep(n)
   socket.select(nil, nil, n)
end

-- zrange city:local 0 -1
local done = client:zrange("city:loc", 0, -1)
local idxs = table.getn(done)
print(idxs)
local hot = client:zrangebyscore("city:loc", "(10", "+inf")
print(table.getn(hot))

for idx = 1, table.getn(hot) do
	-- print(hot[idx])
	-- local t = string.sub(hot[idx], 1, 3);
	-- print(string.upper(t))
	-- print(ex[string.upper(t)])
	local tmpscore = 3 * client:zscore("city:loc", hot[idx])
	print(tmpscore, hot[idx])
	clientwork:zadd("city:hot", tmpscore, hot[idx])
end

--[[
for idxi = 1, idxs do
	client:sadd("city:local:done", done[idxi])
end

local task = client:sdiff("city:cn", "city:err", "city:local:done")
print(table.getn(task))


local hot = client:zrangebyscore("city:local", "(3", "+inf")
print(table.getn(hot))

local wname = "/data/logs/localcityishot.ini"
local wfile = io.open(wname, "w+");
for k, v in ipairs(hot) do
	wfile:write(v .. "\n");
end
io.close(wfile);
--]]