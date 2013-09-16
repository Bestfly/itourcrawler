-- buyhome <huangqi@rhomobi.com> 20130811 (v0.5.1)
-- License: same to the Lua one
-- TODO: copy the LICENSE file
-------------------------------------------------------------------------------
-- begin of the idea : http://rhomobi.com/topics/
-- price of extension for bestfly service ifl's rt type.
-- load library
local JSON = require("cjson");
local xml = require("LuaXml");
local redis = require "resty.redis"
local http = require "resty.http"
local zlib = require 'zlib'
-- originality
local error001 = JSON.encode({ ["resultCode"] = 1, ["description"] = "No response because you has inputted error"});
local error002 = JSON.encode({ ["resultCode"] = 2, ["description"] = "Get Prices from extension is no response"});
function error003 (mes)
	local res = JSON.encode({ ["resultCode"] = 3, ["description"] = mes});
	return res
end
-- ready to connect to master redis.
local red, err = redis:new()
if not red then
	ngx.say("failed to instantiate redis: ", err)
	return
end
-- lua socket timeout
-- Sets the timeout (in ms) protection for subsequent operations, including the connect method.
red:set_timeout(1000) -- 1 sec
-- nosql connect
local ok, err = red:connect("rhomobi.com", 6388)
if not ok then
	ngx.say("failed to connect redis: ", err)
	return
end
-- end of nosql init.
if ngx.var.request_method == "GET" then
	-- dom:itour:20130913
	local res, err = red:hget(ngx.var.type .. ":" .. ngx.var.source .. ":" .. ngx.var.date, ngx.var.org .. ngx.var.dst)
	if not res then
		ngx.print(error003("failed to HGET prices_data info: " .. ngx.var.type .. ngx.var.source .. ngx.var.date, err));
		return
	else
		-- ngx.say(res);
		if res ~= nil and res ~= JSON.null then
			local spaname = "bestfly"
			local baseurl = "http://bcs.duapp.com/";
			local uri = ngx.var.type .. "/" .. ngx.var.source .. "/" .. ngx.var.date .. "/" .. ngx.var.org .. ngx.var.dst .. "/" .. res .. ".json";
			-- ngx.say(baseurl .. spaname .. "/" .. uri)
			local hc = http:new()
			local ok, code, headers, status, body = hc:request {
				url = baseurl .. spaname .. "/" .. uri;
				--- proxy = "http://127.0.0.1:8888",
				--- timeout = 3000,
				method = "GET", -- POST or GET
				-- add post content-type and cookie
				-- headers = { skybusAuth = skybusAuth, ["Content-Type"] = "application/json" },
				-- body = commandata,
			}
			-- ngx.say(code, status, body)
			if code == 200 then
				body = zlib.decompress(body);
				ngx.print(body);
			else
				ngx.print(error002);
			end
		else
			ngx.print(error002);
		end
	end
end
-- put it into the connection pool of size 512,
-- with 0 idle timeout
local ok, err = red:set_keepalive(0, 512)
if not ok then
	ngx.say("failed to set keepalive redis: ", err)
	return
end