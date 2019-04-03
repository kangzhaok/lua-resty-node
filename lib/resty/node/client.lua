local http = require "resty.http"
local cjson = require "cjson.safe"
local watcher = require "resty.node.watcher"
local monitor = require "resty.upstream.monitor"

local setmetatable = setmetatable
local pcall = pcall

local _M = { _VERSION = '0.0.2' }
local mt = { __index = _M }

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function(narr, nrec) return {} end
end

function _M.new(healthcheck)
    return setmetatable({
        healthcheck = healthcheck,
        watchers = {} -- watcher缓存
    }, mt)
end

function _M.request(self, uri, params, timeout)
    local httpc = http:new()
    if not timeout then
        timeout = 3000
    end
    httpc:set_timeout(timeout)
    local res, err = httpc:request_uri(uri, params)
    if not res then
        return nil, err
    end

    if res.status ~= 200 then
        return nil, res.body
    end

    local data = cjson.decode(res.body)
    if not data then
        return nil, "json decode error"
    end

    return data
end

function _M.get_data(self, ctx, timeout)
    local data, err = self:request(ctx.url, {
        headers = ctx.headers
    }, timeout)
    if not data then
        return nil, err
    end

    return data
end

function _M.watcher(self, ups, ctx, event)
    -- 停掉旧的watcher
    if self:haswatcher(ups) then
        self:unwatcher(ups)
    end

    local wt = watcher.new(self, ctx, event)
    self.watchers[ups] = wt
    wt:start()

    -- 进行健康检查
    local hc = self.healthcheck
    monitor.spawn_checker({
        upstream = ups,
        shm = hc.shm,
        type = hc.type,
        http_req = hc.http_req,
        valid_statuses = hc.valid_statuses,
        timeout = hc.timeout,
        interval = hc.interval,
        fall = hc.fall,
        rise = hc.rise,
        concurrency = hc.concurrency
    })
end

function _M.haswatcher(self, ups)
    return self.watchers[ups] and true or false
end

function _M.unwatcher(self, ups)
    local watcher = self.watchers[ups]
    if watcher then
        watcher:stop()
        self.watchers[ups] = nil
        monitor.kill_checker(ups)
    end
end

return _M