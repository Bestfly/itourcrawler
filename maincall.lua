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
    host = 'rhosouth001',
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
-- os.execute
function otaexec (arg, proxy)
	local cmd = "/usr/local/bin/lua /data/rails2.3.5/itourcrawler/dombae.lua " .. arg .. " " .. proxy;
	local r = os.execute(cmd);
	return r
end
-- coroutine start
threads = {}-- list of all live threads
function otaget (arg, proxy)
	-- create coroutine
	local co = coroutine.create(function ()
		otaexec(arg, proxy)
	end)
	-- insert it in the list
	table.insert(threads, co)
end
function dispatcher ()
	while true do
		local n = table.getn(threads)
		if n == 0 then break end-- no more threads to run
		local connections = {}
		for i=1,n do
			local status, res = coroutine.resume(threads[i])
			if not res then-- thread finished its task?
				table.remove(threads, i)
				break
			else-- timeout
				table.insert(connections, res)
			end
		end
		if table.getn(connections) == n then
			socket.select(connections)
		end
	end
end
-- coroutine end
local url = "http://rhosouth001/task-queues/1/";
-- local dis = "http://api.bestfly.cn/distribute/PriceUpdate/";
while url do
	local body, code, headers = http.request(url)
	if code == 200 then
		-- print(JSON.decode(body).taskQueues[1]);
		if JSON.decode(body).resultCode == 0 then
			local arg = JSON.decode(body).taskQueues[1];
			arg = string.gsub(string.sub(arg, 3, -1), "bjs", "bbb")
			arg = string.gsub(arg, "sha", "sss")
			arg = string.gsub(arg, "sia", "xiy")
			print(arg)
			print("-------------")
			while true do
				local res, err = client:blpop("proxy:work", 2)
				if res ~= nil then
					
					local cmd = "/usr/local/bin/lua /data/rails2.3.5/itourcrawler/dombae.lua " .. arg .. " " .. tostring(res[2]);
					local r = os.execute(cmd);
					
					-- local r = otaget(arg, tostring(res[2]))
					if r == 0 then
						break;
					else
						print("------os.execute failure------")
					end
					
				else
					print("------wait for proxy IP------")
				end
			end
			dispatcher();
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
			print("------------NO mission left-----------")
			sleep(5)
		end
	else
		-- if get no mission sleep 10;
		print("------------NO taskQueues Service-----------")
		sleep(30)
	end
	sleep(0.001)
end