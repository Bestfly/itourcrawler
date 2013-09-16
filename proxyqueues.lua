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
local url = "http://www.dailiaaa.com/?ddh=396849983172055&dq=&sl=1&issj=0&xl=3&tj=fff&api=14&cf=4&yl=0";
while url do
	local len, err = client:llen("proxy:work")
	print(tonumber(len))
	while tonumber(len) < 60 do
		local body, code, headers = http.request(url)
		if code == 200 then
			local pt = string.match(body, ":([0-9]+)")
			local ip = string.match(body, "(.+):([0-9]+)")
			local buyproxy = ip .. ":" .. pt;
			print(buyproxy)
			-- local buyproxy = string.sub(body, 1, index-1) .. ":" .. string.sub(body, index+1, -8)
			-- local buyproxy = string.sub(body, index)
			local respbody = {}
			local body, code, headers, status = http.request {
				url = "http://www.baidu.com",
				--- proxy = "http://127.0.0.1:8888",
				proxy = "http://" .. buyproxy,
				timeout = 1500,
				method = "GET", -- POST or GET
				-- add post content-type and cookie
				headers = { ["Host"] = "www.baidu.com", ["User-Agent"] = "Mozilla/5.0 (Windows; U; Windows NT 5.1; zh-CN; rv:1.9.1.6) Gecko/20091201 Firefox/3.5.6" },
				-- body = formdata,
				-- source = ltn12.source.string(form_data);
				sink = ltn12.sink.table(respbody)
			}
			print(code, status)
			if code == 200 then
				print(buyproxy)
				print("----------")
				client:rpush("proxy:work", buyproxy)
			end
		end
		len = client:llen("proxy:work")
	end
	sleep(5)
end
