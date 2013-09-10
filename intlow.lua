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
redis.commands.sadd = redis.command('sadd')
redis.commands.zadd = redis.command('zadd')
redis.commands.smembers = redis.command('smembers')
redis.commands.keys = redis.command('keys')
redis.commands.sdiff = redis.command('sdiff')

function sleep(n)
   socket.select(nil, nil, n)
end

-- local data = client:smembers("cac:a54c7a3b89fe377803a3efa30af43d8e:0252297fd6aae3e3ee191605a128e569:avhid")
-- print(table.getn(data))
local org = string.sub(arg[1], 1, 3);
local dst = string.sub(arg[1], 5, 7);
local tkey = string.sub(arg[1], 9, -2);
local date = string.sub(arg[1], 9, 12) .. "-" .. string.sub(arg[1], 13, 14) .. "-" .. string.sub(arg[1], 15, 16);
local ow = {};
ow["goKey"] = JSON.null
ow["x_passengerQuantity"] = JSON.null
ow["x_flightType"] = "0"
ow["x_fromCity"] = string.upper(org)
ow["x_toCity"] = string.upper(dst)
ow["x_fromCity2"] = ""
ow["x_toCity2"] = ""
ow["x_DDate"] = date
ow["x_RDate"] = ""
ow["x_DDate2"] = ""
ow["x_carrierCode"] = ""
ow["x_cabinClass"] = "0"
ow["x_passengerType"] = "1"

function crawler(request)
	local respbody = {};
	-- local hc = http:new()
	local body, code, headers, status = http.request {
	-- local ok, code, headers, status, body = http.request {
		url = "http://iflight.itour.cn/ajaxpro/AjaxMethods,App_Code.ashx",
		--- proxy = "http://127.0.0.1:8888",
		timeout = 10000,
		method = "POST", -- POST or GET
		-- add post content-type and cookie
		-- headers = { ["Content-Type"] = "application/x-www-form-urlencoded", ["Content-Length"] = string.len(form_data) },
		headers = { ["X-AjaxPro-Method"] = "GetIFlightInfo", ["Content-Length"] = string.len(JSON.encode(request))},
		-- body = formdata,
		-- source = ltn12.source.string(form_data);
		source = ltn12.source.string(JSON.encode(request)),
		sink = ltn12.sink.table(respbody)
	}
	return headers, code, respbody
end
local headers, code, respbody = crawler(ow)
if code == 200 then
	local reslimit = "";
	local reslen = table.getn(respbody)
	for i = 1, reslen do
		-- print(respbody[i])
		reslimit = reslimit .. respbody[i]
	end
	-- print(reslimit)

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
			timeout = 10000,
			method = "POST", -- POST or GET
			-- add post content-type and cookie
			-- headers = { ["Content-Type"] = "application/x-www-form-urlencoded", ["Content-Length"] = string.len(form_data) },
			headers = { ["X-AjaxPro-Method"] = "GetFileLimition", ["Content-Length"] = string.len(JSON.encode(req))},
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
			-- print(lim)
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
		local bk = {}
		table.insert(bk, tmpbk)
		tmptab["bunks_idx"] = bk
		tmptab["updateTime"] = os.date("%Y-%m-%d %X", os.time())
		tmptab["fltcomb"] = fltcomb
		tmptab["flytime"] = data[i].TotalFlyTime
		table.insert(bigtab, tmptab)
		-- print(fltcomb)
		-- print("--------------")
		-- print(JSON.encode(tmpbk))
	end
	-- print(JSON.encode(bigtab))
	if table.getn(bigtab) > 0 then
		local data = JSON.encode(bigtab);
		local filet = os.time();
		-- api post file.
		local respup = {};
		local timestamp = os.date("%a, %d %b %Y %X GMT", os.time())
		local obj = "/int/itour/" .. tkey .. "/" .. org .. dst .. "/" .. filet .. ".json";
		local Content= "MBO" .. "\n" .. "Method=PUT" .. "\n" .. "Bucket=bestfly" .. "\n" .. "Object=" .. obj .. "\n"
		local Signature = urlencode(base64.encode(crypto.hmac.digest('sha1', Content, sk, true)))
		
	else
		print("-------No data of " .. arg[1] .. "--------")
	end
else
	print(code)
	for k, v in pairs(headers) do
		print(k, v);
	end
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