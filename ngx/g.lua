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
table.insert(cloudfetch, "bestfly")
--[[
table.insert(cloudfetch, "deekpark")
table.insert(cloudfetch, "huangqi")
table.insert(cloudfetch, "mpicloud")
table.insert(cloudfetch, "cloudset")
table.insert(cloudfetch, "updous")
table.insert(cloudfetch, "taowap")
table.insert(cloudfetch, "faceba")
table.insert(cloudfetch, "jijilu")
table.insert(cloudfetch, "cloudavh")
--]]
local baseurl = "http://%s.duapp.com%s";
ngx.say(type(ngx.var.uri));
local index = string.find(ngx.var.uri, "gw");
local tmpuri = string.sub(ngx.var.uri, index+2, -1);
-- local tmpuri = "/tz.php"
if ngx.var.request_method == "POST" then
	-- ngx.exit(ngx.HTTP_FORBIDDEN);
	ngx.req.read_body();
	-- local uargs = ngx.req.get_uri_args();
	-- local pargs = ngx.req.get_post_args();
	-- local phead = ngx.req.get_headers();
	local pcontent = ngx.req.get_body_data();
	if pcontent then
		local tmprandom = math.random(1,2);
		local hc = http:new()
		local ok, code, headers, status, body = hc:request {
			url = string.format(baseurl, cloudfetch[tmprandom], tmpuri) .. "?" .. ngx.var.args,
			-- proxy = "http://" .. ngx.decode_base64(ngx.var.proxy),
			timeout = 3000,
			method = "POST", -- POST or GET
			-- add post content-type and cookie
			-- headers = phead,
			headers = { ["Host"] = cloudfetch[tmprandom] .. ".duapp.com" },
			-- body = ltn12.source.string(form_data),
			body = pcontent,
		}
		if code == 200 and body ~= nil then
			ngx.print(body);
		else
			local wname = "/data/logs/rholog.txt"
			local wfile = io.open(wname, "w+");
			wfile:write(os.date());
			wfile:write("\r\n---------------------\r\n");
			wfile:write(pcontent);
			wfile:write("\r\n---------------------\r\n");
			wfile:write(code);
			wfile:write("\r\n---------------------\r\n");
			wfile:write(ngx.var.remote_addr);
			wfile:write("\r\n---------------------\r\n");
			wfile:write(string.format(baseurl, cloudfetch[tmprandom], tmpuri) .. "?" .. ngx.var.args);
			wfile:write("\r\n---------------------\r\n");
			io.close(wfile);
			ngx.print(error000(code, status))
		end
	else
		ngx.print(0)
	end
else
	local tmprandom = math.random(1,2);
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
		headers = { ["Host"] = cloudfetch[tmprandom] .. ".duapp.com" },
		-- headers = { ["User-Agent"] = "Mozilla/5.0 (Windows; U; Windows NT 5.1; zh-CN; rv:1.9.1.6) Gecko/20091201 Firefox/3.5.6"},
		-- body = ltn12.source.string(form_data),
		-- body = form_data,
	}
	if code == 200 and body ~= nil then
		ngx.print(body);
	else
		ngx.print(error000(code, status))
	end
end