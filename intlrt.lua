local socket = require 'socket'
local http = require 'socket.http'
local JSON = require 'cjson'
local md5 = require 'md5'
local zlib = require 'zlib'
local base64 = require 'base64'
local crypto = require 'crypto'

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
-- Cloud set.
function urlencode(s) return s and (s:gsub("[^a-zA-Z0-9.~_-]", function (c) return string.format("%%%02x", c:byte()); end)); end
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
-- local data = client:smembers("cac:a54c7a3b89fe377803a3efa30af43d8e:0252297fd6aae3e3ee191605a128e569:avhid")
-- print(table.getn(data))
local ak = "8fed80908d9683600e1d30f2a64006f2"
local sk = "8047E3D8b60e2887d1d866b4b12028c6"
local org = string.sub(arg[1], 1, 3);
local dst = string.sub(arg[1], 5, 7);
local gdate = string.sub(arg[1], 9, 12) .. "-" .. string.sub(arg[1], 13, 14) .. "-" .. string.sub(arg[1], 15, 16);
local bdate = string.sub(arg[1], 18, 21) .. "-" .. string.sub(arg[1], 22, 23) .. "-" .. string.sub(arg[1], 24, 25);
local tkey = string.sub(arg[1], 9, 16) .. "," .. string.sub(arg[1], 18, 25);
local idxt = string.sub(arg[1], 9, 16)
local expiret = os.time({year=string.sub(idxt, 1, 4), month=tonumber(string.sub(idxt, 5, 6)), day=tonumber(string.sub(idxt, 7, 8)), hour="00"});
local rt = {};
rt["goKey"] = JSON.null
rt["x_passengerQuantity"] = JSON.null
rt["x_flightType"] = "1"
rt["x_fromCity"] = string.upper(org)
rt["x_toCity"] = string.upper(dst)
rt["x_fromCity2"] = ""
rt["x_toCity2"] = ""
rt["x_DDate"] = gdate
rt["x_RDate"] = bdate
rt["x_DDate2"] = ""
rt["x_carrierCode"] = ""
rt["x_cabinClass"] = "0"
rt["x_passengerType"] = "1"

function crawler(request, pry)
	local respbody = {};
	-- local hc = http:new()
	local body, code, headers, status = http.request {
	-- local ok, code, headers, status, body = http.request {
		url = "http://iflight.itour.cn/ajaxpro/AjaxMethods,App_Code.ashx",
		--- proxy = "http://127.0.0.1:8888",
		proxy = "http://" .. pry,
		timeout = 10000,
		method = "POST", -- POST or GET
		-- add post content-type and cookie
		-- headers = { ["Content-Type"] = "application/x-www-form-urlencoded", ["Content-Length"] = string.len(form_data) },
		headers = { ["Host"] = "iflight.itour.cn", ["X-AjaxPro-Method"] = "GetIFlightInfo", ["Content-Length"] = string.len(JSON.encode(request)), ["Content-Type"] = "application/json" },
		-- body = formdata,
		-- source = ltn12.source.string(form_data);
		source = ltn12.source.string(JSON.encode(request)),
		sink = ltn12.sink.table(respbody)
	}
	return headers, code, respbody
end
print(JSON.encode(rt));
print("--------------");
local headers, code, respbody = crawler(rt, tostring(arg[2]))
if code == 200 then
	local reslimit = "";
	local reslen = table.getn(respbody)
	for i = 1, reslen do
		-- print(respbody[i])
		reslimit = reslimit .. respbody[i]
	end
	print(reslimit)

	local data = string.sub(reslimit, 1, -4)
	data = JSON.decode(data)
	-- print(JSON.encode(data.listView))
	data = data.listView
	-- print(JSON.encode(data))
	-- print(table.getn(data))
	local bigtab = {}
	for i = 1, table.getn(data) do
		local tmptab = {}
		local prices_data = {}
		local pridata = {}
		local pri = data[i].ListB2GIFlightCabinInfoView[1]
		local priceinfo = {}
		local pritmp = {}
		priceinfo["StandardPrice"] = pri.SalePrice + pri.Reward
		priceinfo["Price"] = pri.SalePrice
		priceinfo["Reward"] = pri.Reward
		priceinfo["ChildPrice"] = pri.ChildSalePrice
		-- priceinfo["AdultOilFee"] = 0
		priceinfo["AdultTax"] = pri.TotalTax
		priceinfo["ChildTax"] = pri.ChildTotalTax
		-- priceinfo["Rate"] = 0
		pritmp["priceinfo"] = priceinfo
		
		local salelimit = {}
		local req = {};
		req["parms"] = pri.FareNo
		local res = {};
		-- local hc = http:new()
		local body, code, headers, status = http.request {
		-- local ok, code, headers, status, body = http.request {
			url = "http://iflight.itour.cn/ajaxpro/AjaxMethods,App_Code.ashx",
			--- proxy = "http://127.0.0.1:8888",
			proxy = "http://" .. tostring(arg[2]),
			timeout = 10000,
			method = "POST", -- POST or GET
			-- add post content-type and cookie
			-- headers = { ["Content-Type"] = "application/x-www-form-urlencoded", ["Content-Length"] = string.len(form_data) },
			headers = { ["Host"] = "iflight.itour.cn", ["X-AjaxPro-Method"] = "GetFileLimition", ["Content-Length"] = string.len(JSON.encode(req))},
			-- body = formdata,
			-- source = ltn12.source.string(form_data);
			source = ltn12.source.string(JSON.encode(req)),
			sink = ltn12.sink.table(res)
		}
		if code == 200 then
			local lim = "";
			local len = table.getn(res)
			for i = 1, len do
				-- print(respbody[i])
				lim = lim .. res[i]
			end
			local idx1 = string.find(lim, "<td>");
			local idx2 = string.find(lim, "</td>");
			lim = string.sub(lim, idx1+4, idx2-1);
			salelimit["Notes"] = lim
			print(lim)
		end
		
		pritmp["salelimit"] = salelimit
		pridata["itour"] = pritmp
		table.insert(prices_data, pridata)
		tmptab["prices_data"] = prices_data
		-- print(JSON.encode(pridata))
		local fltcomb = ""
		local fis = data[i].ListB2GIFlightInfoView
		local tmpbk = {}
		for fi = 1, table.getn(fis) do
			local bunk = {}
			bunk["Class"] = fis[fi].Class
			bunk["ClassGrade"] = fis[fi].CabinName
			table.insert(tmpbk, bunk)
			if string.len(fltcomb) == 0 then
				fltcomb = fis[fi].FlightNumer
			else
				fltcomb = fltcomb .. "-" .. fis[fi].FlightNumer
			end
		end
		-- print(string.gsub(pri.FlightKey, "|" .. pri.FareNo .. "|", "|"))
		local subrt = {}
		subrt["goKey"] = string.gsub(pri.FlightKey, "|" .. pri.FareNo .. "|", "|")
		subrt["x_passengerQuantity"] = JSON.null
		subrt["x_flightType"] = "1"
		subrt["x_fromCity"] = string.upper(org)
		subrt["x_toCity"] = string.upper(dst)
		subrt["x_fromCity2"] = ""
		subrt["x_toCity2"] = ""
		subrt["x_DDate"] = gdate
		subrt["x_RDate"] = bdate
		subrt["x_DDate2"] = ""
		subrt["x_carrierCode"] = ""
		subrt["x_cabinClass"] = "0"
		subrt["x_passengerType"] = "1"
		print("--------------");
		print(JSON.encode(subrt));
		local tmprandom = math.random(2,4);
		print(tostring(arg[tmprandom]));
		local headers, code, respbody = crawler(subrt, tostring(arg[tmprandom]))
		print("--------------");
		if code == 200 then
			local subres = "";
			local subreslen = table.getn(respbody)
			for si = 1, subreslen do
				-- print(respbody[i])
				subres = subres .. respbody[si]
			end
			local subdata = string.sub(subres, 1, -4)
			print(subdata)
			subdata = JSON.decode(subdata)
			subdata = subdata.listView
			for j = 1, table.getn(subdata)-1 do
				local fltcombrt = ""
				local fjs = subdata[j].ListB2GIFlightInfoView
				local tmprt = {}
				for fj = 1, table.getn(fjs) do
					local bunk = {}
					bunk["Class"] = fjs[fj].Class
					bunk["ClassGrade"] = fjs[fj].CabinName
					table.insert(tmprt, bunk)
					if string.len(fltcombrt) == 0 then
						fltcombrt = fjs[fj].FlightNumer
					else
						fltcombrt = fltcombrt .. "-" .. fjs[fj].FlightNumer
					end
				end
				-- print(fltcomb .. "," .. fltcombrt)
				-- init bunk.
				local bk = {}
				-- ow bunk insert.
				table.insert(bk, tmpbk)
				-- rt bunk insert
				table.insert(bk, tmprt)
				tmptab["bunks_idx"] = bk
				tmptab["updateTime"] = os.date("%Y-%m-%d %X", os.time())
				tmptab["fltcomb"] = fltcomb .. "," .. fltcombrt
				tmptab["flytime"] = subdata[j].TotalFlyTime
				table.insert(bigtab, tmptab)
			end
		end
	end
	-- print(JSON.encode(bigtab))
	if table.getn(bigtab) > 0 then
		local data = JSON.encode(bigtab);
		local cl = string.len(data)
		local filet = os.time();
		-- api post file.
		local respup = {};
		local timestamp = os.date("%a, %d %b %Y %X GMT", os.time())
		local obj = "/intl/itour/" .. tkey .. "/" .. org .. dst .. "/" .. filet .. ".json";
		local Content= "MBO" .. "\n" .. "Method=PUT" .. "\n" .. "Bucket=bestfly" .. "\n" .. "Object=" .. obj .. "\n"
		local Signature = urlencode(base64.encode(crypto.hmac.digest('sha1', Content, sk, true)));
		local body, code, headers, status = http.request {
		-- local ok, code, headers, status, body = http.request {
			-- url = "http://v0.api.upyun.com" .. requri,
			url = "http://bcs.duapp.com/bestfly" .. obj .. "?sign=MBO:" .. ak .. ":" .. Signature,
			--- proxy = "http://127.0.0.1:8888",
			timeout = 10000,
			method = "PUT", -- POST or GET
			-- add post content-type and cookie
			-- headers = { ["Content-Type"] = "application/x-www-form-urlencoded", ["Content-Length"] = string.len(form_data) },
			-- headers = { ["Date"] = timestamp, ["Authorization"] = "UpYun bestfly:" .. sign, ["Content-Length"] = cl, ["Mkdir"] = "true", ["Content-Type"] = "application/json" },
			-- headers = { ["Mkdir"] = "true", ["Date"] = timestamp, ["Authorization"] = "UpYun bestfly:" .. sign, ["Content-Length"] = cl, ["Content-Type"] = "application/json" },
			headers = { ["Content-Length"] = cl, ["Content-Type"] = "text/plain" },
			-- body = formdata,
			-- source = ltn12.source.string(form_data);
			source = ltn12.source.string(data),
			sink = ltn12.sink.table(respup)
		}
		if code == 200 then
			local upyun = "";
			local len = table.getn(respup)
			for i = 1, len do
				upyun = upyun .. respup[i]
			end
			print(upyun)
			local res, err = client:hget('intl:itour:' .. tkey, org .. dst)
			if res ~= nil and res ~= JSON.null and res ~= "" then
				local tobj = "/intl/itour/" .. tkey .. "/" .. org .. dst .. "/" .. tostring(res) .. ".json"
				local Content= "MBO" .. "\n" .. "Method=DELETE" .. "\n" .. "Bucket=bestfly" .. "\n" .. "Object=" .. tobj .. "\n"
				local Signature = urlencode(base64.encode(crypto.hmac.digest('sha1', Content, sk, true)))
				local respup = {};
				local body, code, headers, status = http.request {
				-- local ok, code, headers, status, body = http.request {
					-- url = "http://v0.api.upyun.com" .. requri,
					url = "http://bcs.duapp.com/bestfly" .. tobj .. "?sign=MBO:" .. ak .. ":" .. Signature,
					--- proxy = "http://127.0.0.1:8888",
					timeout = 10000,
					method = "DELETE", -- POST or GET
					-- add post content-type and cookie
					-- headers = { ["Content-Type"] = "application/x-www-form-urlencoded", ["Content-Length"] = string.len(form_data) },
					-- headers = { ["Date"] = timestamp, ["Authorization"] = "UpYun bestfly:" .. sign, ["Content-Length"] = cl, ["Mkdir"] = "true", ["Content-Type"] = "application/json" },
					-- headers = { ["Mkdir"] = "true", ["Date"] = timestamp, ["Authorization"] = "UpYun bestfly:" .. sign, ["Content-Length"] = cl, ["Content-Type"] = "application/json" },
					-- headers = { ["Content-Length"] = cl, ["Content-Type"] = "text/plain" },
					-- body = formdata,
					-- source = ltn12.source.string(form_data);
					-- source = ltn12.source.string(data),
					sink = ltn12.sink.table(respup)
				}
				if code == 200 then
					client:hdel('intl:itour:' .. tkey, org .. dst);
					local res, err = client:hset('intl:itour:' .. tkey, org .. dst, filet)
					if not res then
						print("-------Failed to hset " .. arg[1] .. "--------")
					else
						client:expire('intl:itour:' .. tkey, (expiret - os.time()))
						print("-------well done " .. arg[1] .. "--------")
					end
				else
					print(code)
					print("-------Failed to DELETE " .. tobj .. "--------")
					print(status)
					print(body)
				end
			else
				local res, err = client:hset('intl:itour:' .. tkey, org .. dst, filet)
				if not res then
					print("-------Failed to hset " .. arg[1] .. "--------")
				else
					client:expire('intl:itour:' .. tkey, (expiret - os.time()))
					print("-------well done " .. arg[1] .. "--------")
				end
			end
		else
			print(code)
			print(status)
			print(body)
		end
	else
		print("-------No data of " .. arg[1] .. "--------")
	end
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
--]]