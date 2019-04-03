--
-- upstream.lua
-- @author jianhao.dai@fraudmetrix.cn 16/3/8 14:24
--
local yaml = require "resty.yaml"
local upstream = require "resty.upstream"
local cjosn = require "cjson"

local client = require "resty.node.client"

local LOGGER = ngx.log
local ERROR = ngx.ERR
local NOTICE = ngx.NOTICE
local WARN = ngx.WARN
local INFO = ngx.INFO
local DEBUG = ngx.DEBUG

local setmetatable = setmetatable
local tonumber = tonumber
local ipairs = ipairs
local pcall = pcall
local str_lower = string.lower

local _M = { _VERSION = '0.0.1' }
local mt = { __index = _M }

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function(narr, nrec) return {} end
end

local function update_hosts(ups, version, hosts)
    for _, peer in ipairs(hosts) do
        peer.port = tonumber(peer.port) or 8088
        peer.default_down = false
        if not peer.name then
            peer.name = peer.host .. ":" .. peer.port
        end
    end

    upstream.update_upstream(ups, {
        version = version,
        hosts = hosts
    })
end

local function cluster_event(ctx, data, err)
    if not data then
        LOGGER(NOTICE, "app:", ctx.app, ", ups:", ctx.ups, ", err:", err)
        return
    end
    local version = tonumber(data.version)
    local kvs = data.kvs
    if not kvs then
        LOGGER(NOTICE, "no hosts data: ", ctx.app, ",", ctx.ups)
        return
    end

    local hosts = new_tab(0, #kvs)
    for _, host in ipairs(kvs) do
        hosts[#hosts + 1] = cjosn.decode(host.value)
    end

    update_hosts(ctx.ups, version, hosts)
end

local function default_event(ctx, data)
    local hosts = yaml.parse(data)
    update_hosts(ctx.env, 1, hosts[ctx.env])
end

function _M.new(opts)
    local maclient = client.new(opts.healthcheck)
    local defaultc = {
        watcher = function(_, ups, ctx, event)
            pcall(event, ctx, ups)
        end
    }

    return setmetatable({
        maclient = maclient,
        defaultc = defaultc
    }, mt)
end

function _M.watcher(self, data)
    if str_lower(data.discovery) == "default" then
        -- default模式下，ups上保存了data数据，使用yaml解析
        self:unwatcher(data.app)
        self.defaultc:watcher(data.ups, {
            app = data.app,
            ups = data.app,
            env = data.env,
        }, default_event)
    else
        self:unwatcher(data.ups)
        self.maclient:watcher(data.ups, {
            url = data.url,
            headers = data.headers
        }, cluster_event)
    end
end

function _M:unwatcher(ups)
    self.maclient:unwatcher(ups)
end

function _M.update_weight(self, u, name, weight)
    if not u then
        return false, "invalid resolver"
    end
    local ups = upstream.get_upstream(u)
    if not ups then
        return false, "no resolver defined: " .. u
    end

    if not name then
        return true, ups.peers
    end

    if (tonumber(weight) or -1) < 0 then
        return false, "invalid weight value: " .. weight
    end

    for _, peer in ipairs(ups.peers) do
        if peer.name == name then
            peer.weight = tonumber(weight)
        end
    end
    upstream.update_upstream(u, {
        version = ups.version,
        hosts = ups.peers
    })

    return true, ups.peers
end

return _M