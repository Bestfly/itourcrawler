-- buyhome <huangqi@rhomobi.com> 20130705 (v0.5.1)
-- License: same to the Lua one
-- TODO: copy the LICENSE file
-------------------------------------------------------------------------------
-- begin of the idea : http://rhomobi.com/topics/
-- price of agent for elong website : http://flight.elong.com/beijing-shanghai/cn_day19.html
-- load library
local socket = require 'socket'
local http = require 'socket.http'
local JSON = require 'cjson'
local md5 = require 'md5'

package.path = "/usr/local/webserver/lua/lib/?.lua;";
-- pcall(require, "luarocks.require")
local redis = require 'redis'
local params = {
    host = 'rhomobi.com',
    port = 6388,
}
local client = redis.connect(params)
client:select(0) -- for testing purposes
-- commands defined in the redis.commands table are available at module
-- level and are used to populate each new client instance.
redis.commands.hset = redis.command('hset')
redis.commands.hdel = redis.command('hdel')
redis.commands.sadd = redis.command('sadd')
redis.commands.zadd = redis.command('zadd')
redis.commands.smembers = redis.command('smembers')
redis.commands.keys = redis.command('keys')
redis.commands.sdiff = redis.command('sdiff')
redis.commands.zrange = redis.command('zrange')
redis.commands.expire = redis.command('expire')
redis.commands.rpush = redis.command('rpush')
redis.commands.llen = redis.command('llen')

function sleep(n)
   socket.select(nil, nil, n)
end
local url = "http://api.bestfly.cn/task-queues/1/";
-- local dis = "http://api.bestfly.cn/distribute/PriceUpdate/";
while url do
	local body, code, headers = http.request(url)
	if code == 200 then
		-- print(JSON.decode(body).taskQueues[1]);
		local arg = JSON.decode(body).taskQueues[1];
		arg = string.gsub(string.sub(arg, 3, -1), "bjs", "bbb")
		arg = string.gsub(arg, "sha", "sss")
		arg = string.gsub(arg, "sia", "xiy")
		print(arg)
		print("-------------")
		local cmd = "/usr/local/bin/lua /data/rails2.3.5/itourcrawler/dombae.lua " .. arg;
		os.execute(cmd);
		--[[
		while true do
			local ok, err = client:rpush("price:comb", arg)
			if ok then
				print("----------price:comb ok-----------")
				break;
			end
		end
		local body, code, headers = http.request(dis .. arg)
                if code == 200 then
			print("---------Distribute sucess-------------")
		else
			print("---------Distribute failer-------------")
		end
		--]]
	else
		-- if get no mission sleep 10;
		print("------------NO mission left-----------")
		sleep(10)
	end
	sleep(0.001)
end
