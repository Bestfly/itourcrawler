-- buyhome <huangqi@rhomobi.com> 20130705 (v0.5.1)
-- License: same to the Lua one
-- TODO: copy the LICENSE file
-------------------------------------------------------------------------------
-- begin of the idea : http://rhomobi.com/topics/
-- price of extension for elong website : http://flight.elong.com/beijing-shanghai/cn_day19.html
-- load library
local JSON = require("cjson");
local http = require "resty.http"
-- originality
function error000 (mes)
	local res = JSON.encode({ ["resultCode"] = 0, ["description"] = mes});
	return res
end
local cloudfetch = {}
table.insert(cloudfetch, "bestfly")
table.insert(cloudfetch, "deekpark")
table.insert(cloudfetch, "huangqi")
table.insert(cloudfetch, "mpicloud")
table.insert(cloudfetch, "cloudset")
table.insert(cloudfetch, "updous")
table.insert(cloudfetch, "taowap")
table.insert(cloudfetch, "faceba")
table.insert(cloudfetch, "jijilu")
table.insert(cloudfetch, "cloudavh")
local baseurl = "http://%s.duapp.com%s";
ngx.say(type(ngx.var.uri));
local index = string.find(ngx.var.uri, "gw");
local tmpuri = string.sub(ngx.var.uri, index+2, -1);
-- local tmpuri = "/tz.php"
if ngx.var.request_method == "GET" then
	local tmprandom = math.random(1,10);
	-- tmpuri = string.gsub(tmpuri, "/data-gw/", "/")
	ngx.say(tmpuri)
	ngx.say(string.format(baseurl, cloudfetch[tmprandom], tmpuri))
	local hc = http:new()
	local ok, code, headers, status, body = hc:request {
		url = string.format(baseurl, cloudfetch[tmprandom], tmpuri),
		-- proxy = "http://" .. ngx.decode_base64(ngx.var.proxy),
		timeout = 3000,
		method = "GET", -- POST or GET
		-- add post content-type and cookie
		headers = { ["User-Agent"] = "Mozilla/5.0 (Windows; U; Windows NT 5.1; zh-CN; rv:1.9.1.6) Gecko/20091201 Firefox/3.5.6"},
		-- body = ltn12.source.string(form_data),
		-- body = form_data,
	}
	if code == 200 and body ~= nil then
		ngx.print(body);
	else
		ngx.print(error000(code, status))
	end
else
	-- ngx.exit(ngx.HTTP_FORBIDDEN);
	ngx.req.read_body();
	local pcontent = ngx.req.get_body_data();
	if pcontent then
		local tmprandom = math.random(1,10);
		local hc = http:new()
		local ok, code, headers, status, body = hc:request {
			url = string.format(baseurl, cloudfetch[tmprandom], tmpuri),
			-- proxy = "http://" .. ngx.decode_base64(ngx.var.proxy),
			timeout = 3000,
			method = "POST", -- POST or GET
			-- add post content-type and cookie
			headers = { ["Host"] = cloudfetch[tmprandom] .. ".duapp.com", ["User-Agent"] = "Mozilla/5.0 (Windows; U; Windows NT 5.1; zh-CN; rv:1.9.1.6) Gecko/20091201 Firefox/3.5.6" },
			-- body = ltn12.source.string(form_data),
			body = pcontent,
		}
		if code == 200 and body ~= nil then
			ngx.print(body);
		else
			ngx.print(error000(code, status))
		end
	else
		ngx.print(0)
	end
end