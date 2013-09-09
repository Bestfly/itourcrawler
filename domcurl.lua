local socket = require 'socket'
local http = require 'socket.http'
local JSON = require 'cjson'
local md5 = require 'md5'
local zlib = require 'zlib'
local base64 = require 'base64'
local cURL = require 'cURL'

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
redis.commands.sadd = redis.command('sadd')
redis.commands.zadd = redis.command('zadd')
redis.commands.smembers = redis.command('smembers')
redis.commands.keys = redis.command('keys')
redis.commands.sdiff = redis.command('sdiff')

function sleep(n)
   socket.select(nil, nil, n)
end

function urlencode(s) return s and (s:gsub("[^a-zA-Z0-9.~_-]", function (c) return format("%%%02x", c:byte()); end)); end
function urldecode(s) return s and (s:gsub("%%(%x%x)", function (c) return char(tonumber(c,16)); end)); end

local function _formencodepart(s)
	return s and (s:gsub("%W", function (c)
		if c ~= " " then
			return format("%%%02x", c:byte());
		else
			return "+";
		end
	end));
end
function formencode(form)
	local result = {};
 	if form[1] then -- Array of ordered { name, value }
 		for _, field in ipairs(form) do
 			-- t_insert(result, _formencodepart(field.name).."=".._formencodepart(field.value));
			table.insert(result, field.name .. "=" .. tostring(field.value));
 		end
 	else -- Unordered map of name -> value
 		for name, value in pairs(form) do
 			-- table.insert(result, _formencodepart(name).."=".._formencodepart(value));
			table.insert(result, name .. "=" .. tostring(value));
 		end
 	end
 	return table.concat(result, "&");
end
--[[
function formencode(form)
	local result = {};
	if form[1] then -- Array of ordered { name, value }
		for _, field in ipairs(form) do
			t_insert(result, _formencodepart(field.name).."=".._formencodepart(field.value));
		end
	else -- Unordered map of name -> value
		for name, value in pairs(form) do
			t_insert(result, _formencodepart(name).."=".._formencodepart(value));
		end
	end
	return t_concat(result, "&");
end
--]]
function formdecode(s)
	if not s:match("=") then return urldecode(s); end
	local r = {};
	for k, v in s:gmatch("([^=&]*)=([^&]*)") do
		k, v = k:gsub("%+", "%%20"), v:gsub("%+", "%%20");
		k, v = urldecode(k), urldecode(v);
		t_insert(r, { name = k, value = v });
		r[k] = v;
	end
	return r;
end
--[[
-- mongoDB
local p = "/usr/local/webserver/lua/lib/"
local m_package_path = package.path
package.path = string.format("%s?.lua;%s?/init.lua;%s",
    p, p, m_package_path)
local mongo = require "resty.mongol"
-- ready to connect to mongodb
local mog, err = mongo:new()
if not mog then
	print("failed to instantiate mongodb: ", err)
	return
end
-- lua socket timeout
-- Sets the timeout (in ms) protection for subsequent operations, including the connect method.
mog:set_timeout(1000) -- 1 sec
local ok, err = mog:connect("127.0.0.1", 27017)
if not ok then
    print("failed to connect mongodb: ", err)
end

-- mongodb auth
local db = mog:new_db_handle("admin")
local ok, err = db:auth("bestfly", "b6x7p6")
if ok then
	local db = mog:new_db_handle("test")
	col = db:get_col("test")
end

-- mongoDB no auth
local db = mog:new_db_handle("test")
col = db:get_col("test")

-- begin do mongoDB.
r, err = col:insert({{name="dog",n=20,m=30}, {name="cat"}}, 
            nil, true)
if not r then ngx.say("insert failed: "..err) end
print(r)

r = col:find({name="dog"}, nil, 100)
-- r:limit(5)
for k,v in r:pairs() do
    print(v["n"])
    -- break
end

r = col:find_one({name="dog"})

-- ngx.say(r["_id"].id)
print(r["_id"]:tostring())
print(r["_id"]:get_ts())
print(r["_id"]:get_hostname())
print(r["_id"]:get_pid())
print(r["_id"]:get_inc())
print(r["name"])
--]]
-- local data = client:smembers("cac:a54c7a3b89fe377803a3efa30af43d8e:0252297fd6aae3e3ee191605a128e569:avhid")
-- print(table.getn(data))
-- Get the mission.(org/dst/t)
local org = string.sub(arg[1], 1, 3);
local dst = string.sub(arg[1], 5, 7);
local tkey = string.sub(arg[1], 9, -2);
local date = string.sub(arg[1], 9, 12) .. "-" .. string.sub(arg[1], 13, 14) .. "-" .. string.sub(arg[1], 15, 16);

local request = {};
-- request["parms"] = "HGH|CGQ|2013-09-20||"
request["parms"] = string.upper(org) .. "|" .. string.upper(dst) .. "|" .. date .. "||"
request["cabinClass"] = ""
request["number"] = -1

local respbody = {};
-- local hc = http:new()
local body, code, headers, status = http.request {
-- local ok, code, headers, status, body = http.request {
	url = "http://flight.itour.cn/ajaxpro/AjaxMethods,App_Code.ashx",
	--- proxy = "http://127.0.0.1:8888",
	timeout = 10000,
	method = "POST", -- POST or GET
	-- add post content-type and cookie
	-- headers = { ["Content-Type"] = "application/x-www-form-urlencoded", ["Content-Length"] = string.len(form_data) },
	headers = { ["X-AjaxPro-Method"] = "GetFlight", ["Content-Length"] = string.len(JSON.encode(request))},
	-- body = formdata,
	-- source = ltn12.source.string(form_data);
	source = ltn12.source.string(JSON.encode(request)),
	sink = ltn12.sink.table(respbody)
}
if code == 200 then
	local reslimit = "";
	local reslen = table.getn(respbody)
	for i = 1, reslen do
		-- print(respbody[i])
		reslimit = reslimit .. respbody[i]
	end
	-- print(reslimit)
	local data = string.sub(reslimit, 2, -5)
	data = string.gsub(data, "'", '"');
	data = string.gsub(data, 'LstDetailInfo', '"LstDetailInfo"')
	data = JSON.decode(data)
	local bigtab = {}
	for i = 1, table.getn(data) do
		local dt = string.gsub(data[i].DepartureTime, ":", "")
		local at = string.gsub(data[i].ArrivalTime, ":", "")
		local oflt = data[i].FromCityCode .. dt .. "/" .. data[i].ToCityCode .. at;
		local tmptab = {}
		local prices_data = {}
		local pridata = {}
		local pritmp = {}
		local priceinfo = {}
		
		priceinfo["StandardPrice"] = data[i].AllPrice
		priceinfo["Price"] = data[i].LstDetailInfo[1].Price
		priceinfo["Reward"] = data[i].LstDetailInfo[1].Reward
		priceinfo["AdultOilFee"] = data[i].AirdromeFee
		priceinfo["AdultTax"] = data[i].OilTax
		priceinfo["ChildTax"] = data[i].OilTaxCHD
		priceinfo["Rate"] = data[i].LstDetailInfo[1].Discount
		pritmp["priceinfo"] = priceinfo
		
		local salelimit = {}
		local reqlim = {};
		-- {"parms":"CSX,DLC,2013-10-16,CZ,G,70"}
		reqlim["parms"] = string.upper(org) .. "," .. string.upper(dst) .. "," .. date .. "," .. string.sub(data[i].FlightNO, 1, 2) .. "," .. data[i].LstDetailInfo[1].Class .. "," .. data[i].LstDetailInfo[1].DiscountValue
		-- print(JSON.encode(reqlim))
		
		local resplim = {};
		-- local hc = http:new()
		local body, code, headers, status = http.request {
		-- local ok, code, headers, status, body = http.request {
			url = "http://flight.itour.cn/ajaxpro/AjaxMethods,App_Code.ashx",
			--- proxy = "http://127.0.0.1:8888",
			timeout = 10000,
			method = "POST", -- POST or GET
			-- add post content-type and cookie
			-- headers = { ["Content-Type"] = "application/x-www-form-urlencoded", ["Content-Length"] = string.len(form_data) },
			headers = { ["X-AjaxPro-Method"] = "GetPolicyChangeAndRefund", ["Content-Length"] = string.len(JSON.encode(reqlim))},
			-- body = formdata,
			-- source = ltn12.source.string(form_data);
			source = ltn12.source.string(JSON.encode(reqlim)),
			sink = ltn12.sink.table(resplim)
		}
		if code == 200 then
			local lim = "";
			local len = table.getn(resplim)
			for i = 1, len do
				-- print(respbody[i])
				lim = lim .. resplim[i]
			end
			local idx1 = string.find(lim, "<td>");
			local idx2 = string.find(lim, "</td>");
			lim = string.sub(lim, idx1+4, idx2-1);
			salelimit["Notes"] = lim
			-- print(lim)
		end
		
		salelimit["Remarks"] = data[i].LstDetailInfo[1].Remark
		-- salelimit["Notes"] = "不得签转；起飞(含)前变更免费；起飞后变更每次收取5%。起飞(含)前退票收取5%；起飞后退票收取10%。此规定仅供参考！退改签以航空公司最新规定为准，可咨询客服电话4008-168-168"
		pritmp["salelimit"] = salelimit
		pridata["itour"] = pritmp
		table.insert(prices_data, pridata)
		
		tmptab["prices_data"] = prices_data
		tmptab["flightline_id"] = md5.sumhexa(oflt)
		tmptab["ns_flts"] = oflt
		tmptab["fltcomb"] = data[i].FlightNO
		
		local bunk = {}
		local tmpbk = {}
		local bk = {}
		bunk["Quantity"] = data[i].LstDetailInfo[1].Nums
		bunk["Class"] = data[i].LstDetailInfo[1].Class
		bunk["ClassGrade"] = data[i].LstDetailInfo[1].ClassName
		table.insert(bk, bunk)
		table.insert(tmpbk, bk)
		tmptab["bunks_idx"] = tmpbk

		local checksum_seg = {}
		local tmpseg = {}
		tmpseg["AirlineCode"] = data[i].CarrierEn
		tmpseg["Flight"] = data[i].FlightNO
		tmpseg["CraftType"] = data[i].Aircraft
		tmpseg["depTerm"] = data[i].BoardPointAT
		tmpseg["DepartCityCode"] = data[i].FromCityCode
		tmpseg["ArriveCityCode"] = data[i].ToCityCode
		tmpseg["TakeOffTime"] = data[i].DepartureTime
		tmpseg["ArriveTime"] = data[i].ArrivalTime
		table.insert(checksum_seg, tmpseg)
		tmptab["checksum_seg"] = checksum_seg

		-- tmptab["sourceCode"] = "itour"
		-- tmptab["sourceName"] = "itour.cn"
		-- tmptab["updateTime"] = os.date("%Y%m%d", os.time())
		tmptab["updateTime"] = os.date("%Y-%m-%d %X", os.time())
		
		table.insert(bigtab, tmptab)
		
	end
	-- print(JSON.encode(bigtab))
	if table.getn(bigtab) > 0 then
		local data = JSON.encode(bigtab);
		local filet = md5.sumhexa(os.time() .. arg[1])
		-- formdata post file to upyun.com
		local options = {}
		options["bucket"] = "bestfly";
		-- options["bucket"] = "rhomobile";
		options["expiration"] = os.time() + 600;
		options["save-key"] = "/dom/itour/" .. tkey .. "/" .. org .. dst .. "/" .. filet .. ".json";
		options["content-md5"] = md5.sumhexa(data);
		options["content-type"] = "application/json";
		local policy = base64.encode(JSON.encode(options));
		local form_api_secret = "E7g0GII/bMg6zl6EKrKHDZDzpaQ="
		-- local form_api_secret = "lG/+p6zMIwNLwuNsGodrvA4PAO8="
		local signature = md5.sumhexa(policy .. "&" .. form_api_secret)
		local formdata = {}
		formdata["policy"] = policy;
		formdata["signature"] = signature;
		formdata["file"] = data;
		local form_data = formencode(formdata);
		local cl = string.len(form_data)
		local pdata = data;
		--[[
		-- api post file.
		local respup = {};
		local timestamp = os.date("%a, %d %b %Y %X GMT", os.time())
		local requri = "/besftly-js/dom/itour/" .. tkey .. "/" .. org .. dst .. "/" .. filet .. ".json";
		local sign = md5.sumhexa("POST&" .. requri .. "&" .. timestamp .. "&" .. cl .. "&" .. md5.sumhexa("b6x7p6b6x7p6"))
		-- local hc = http:new()
		print(sign)
		print(cl)
		print(md5.sumhexa("b6x7p6b6x7p6"))
		print(requri)
		print(timestamp)
		print("--------------")
		--]]
		--[[
		local body, code, headers, status = http.request {
		-- local ok, code, headers, status, body = http.request {
			url = "http://v0.api.upyun.com/bestfly",
			--- proxy = "http://127.0.0.1:8888",
			timeout = 10000,
			method = "POST", -- POST or GET
			-- add post content-type and cookie
			-- headers = { ["Content-Type"] = "application/x-www-form-urlencoded", ["Content-Length"] = string.len(form_data) },
			-- headers = { ["Date"] = timestamp, ["Authorization"] = "UpYun bestfly:" .. sign, ["Content-Length"] = cl, ["Mkdir"] = "true", ["Content-Type"] = "application/json" },
			headers = { ["Content-Length"] = cl, ["Content-Type"] = "application/x-www-form-urlencoded" },
			-- body = formdata,
			-- source = ltn12.source.string(form_data);
			source = ltn12.source.string(form_data),
			sink = ltn12.sink.table(respup)
		}
		if code == 200 then
			local upyun = "";
			local len = table.getn(respup)
			for i = 1, len do
				upyun = upyun .. respup[i]
			end
			print(upyun)
		else
			print(code)
			for k, v in pairs(headers) do
				print(k, v);
			end
			print(status)
			print(body)
		end
		
		-- local djson = zlib.compress(JSON.encode(bigtab))
		print(type(zlib.compress(JSON.encode(bigtab))))
		-- local djson = JSON.encode(bigtab)
		client:hdel('dom:itour:' .. tkey, org .. dst);
		local res, err = client:hset('dom:itour:' .. tkey, org .. dst, zlib.compress(JSON.encode(bigtab)))
		if not res then
			print("-------Failed to hset " .. arg[1] .. "--------")
		else
			client:expire('dom:itour:' .. tkey, 300)
			print("-------well done " .. arg[1] .. "--------")
		end
		--]]
		
		c = cURL.easy_init()
		c:setopt_url("http://v0.api.upyun.com/bestfly")
		postdata = {
			name1 = {file="policy",
				data=policy},
			name2 = {file="signature",
				data=signature},
		   -- post file from data variable
		   name3 = {file="1.json",
			    data=pdata,
			    type="application/json"}}
		c:post(postdata)
		c:perform()
		print("Done")
	else
		print("-------No data of " .. arg[1] .. "--------")
	end
	-- print(zlib.compress(JSON.encode(bigtab)))
	--[[
	local req = zlib.compress(JSON.encode(bigtab));
	local respbody = {};
	-- local hc = http:new()
	local body, code, headers, status = http.request {
	-- local ok, code, headers, status, body = http.request {
		url = "http://localhost:6001/data-gzip",
		--- proxy = "http://127.0.0.1:8888",
		timeout = 10000,
		method = "POST", -- POST or GET
		-- add post content-type and cookie
		-- headers = { ["Content-Type"] = "application/x-www-form-urlencoded", ["Content-Length"] = string.len(form_data) },
		headers = { ["Content-Length"] = string.len(req)},
		-- body = formdata,
		-- source = ltn12.source.string(form_data);
		source = ltn12.source.string(req),
		sink = ltn12.sink.table(respbody)
	}
	print(code)
	for k, v in pairs(headers) do
		print(k, v);
	end
	print(status)
	print(body)
	--]]
else
	print(code)
	print("--------------")
	print(status)
	print(body)
end

--[[
local wname = "/data/logs/localcityhasline.ini"
local wfile = io.open(wname, "w+");
for k, v in ipairs(data) do
	wfile:write(v .. "\n");
end
io.close(wfile);

local keydata = client:keys("???/???")
print(table.getn(keydata))
for k, v in ipairs(keydata) do
	client:sadd("citys:done", v)
end
local data = client:smembers("citys:done")
print(table.getn(data))


-- init task of localcity.
local luasql = require "luasql.mysql"
local env = assert(luasql.mysql())
local con = assert (env:connect("biyifei_base", "rhomobi_dev", "b6x7p6b6x7p6", "localhost", 3306))
local sqlcmd = "SELECT `city_code`, `city_name` FROM `localcitys`";
local cur = assert (con:execute(sqlcmd))

local row = cur:fetch ({}, "a")
local citycn = {};
while row do
	-- print(row.city_code)
	table.insert(citycn, row.city_code)
	-- print(row.city_name)
	row = cur:fetch (row, "a")
end
cur:close()
local lencn = table.getn(citycn)
-- print(lencn)
-- print(citycn[lens])
local lkey = {};
local i = 1;
while i <= lencn do
	local j = 1;
	while j <= lencn do
		if j ~= i then
			table.insert(lkey, string.lower(citycn[i]) .. "/" .. string.lower(citycn[j]))
		end
		j = j + 1;
	end
	i = i + 1;
end

local idxs = table.getn(lkey)
for idxi = 1, idxs do
	client:sadd("city:init", lkey[idxi])
end
local data = client:smembers("city:init")
print(table.getn(data))

local task = client:sdiff("city:init", "citys:xxxx")
print(table.getn(task))

-- begin to continue task
local server = "http://api.bestfly.cn/ext-price/"
local clears = "http://api.bestfly.cn/capi/ext-price/"
local query = "%s%s/"

print("\r\n----------continue to work for localcitys-----------\r\n");

for t = 20130718, 20130724 do
	local idxs = table.getn(task)
	for idxi = 1, idxs do
		print("---------------------------")
		print("国内数据共" .. idxs .. ",当前第" .. idxi);
		print("---------------------------")
		local uri = task[idxi] .. "/ow/" .. tostring(t);
		local url = string.format(query, clears, uri);
		print(url);
		print("-----------clear-----------")
		local body, code, headers = http.request(url)
		if code == 200 then
			print(body);
			url = string.format(query, server, uri)
			print(url);
			print("-----------update----------")
			local body, code, headers = http.request(url)
			if code == 200 then
				local res = JSON.decode(body);
				-- print(res).res is table
				-- print(table.getn(res))
				local pricenum = table.getn(res);
				if pricenum == 0 then
					client:hset("loc:" .. task[idxi], tostring(t), 1)
					client:sadd("city:err:" .. tostring(t), task[idxi])
					print("key is null")
				else
					for k, v in ipairs(res) do
						print(v.flightline_id)
						if v.flightline_id == nil then
							client:hset("loc:" .. task[idxi], tostring(t), 1)
							client:sadd("city:err:" .. tostring(t), task[idxi])
							break;
						else
							client:hset("loc:" .. task[idxi], tostring(t), 0)
							client:zadd("city:loc", pricenum, task[idxi])
							print(code)
							for k, v in pairs(headers) do
								print(k, v);
							end
							break;
						end
					end
				end
			else
				client:hset("loc:" .. task[idxi], tostring(t), 1)
				client:sadd("city:err:" .. tostring(t), task[idxi])
				print(code)
			end
		else
			print(code)
		end
		sleep(0.1)
	end
end

-- mongoDB for nginx
local ok, err = mog:set_keepalive(0, 512)
if not ok then
	ngx.say("failed to set keepalive mongodb: ", err)
	return
end
--]]