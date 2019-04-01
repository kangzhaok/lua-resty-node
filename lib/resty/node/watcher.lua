
local setmetatable = setmetatable
local new_timer = ngx.timer.at
local tonumber = tonumber
local pcall = pcall
local error = error

local _M = { _VERSION = '0.0.1' }
local mt = { __index = _M }

local function do_watcher(premature, watcher)
    if premature or not watcher.started then
        return
    end
    local ctx = watcher.ctx

    local data, err = watcher.client:get_data(ctx, watcher.timeout)
    if not data then
        pcall(watcher.event, ctx, nil, err)
        return
    end

    local kvs = data["kvs"]
    local header = data["header"]
    if not kvs or not header then
        pcall(watcher.event, ctx, nil, "null result")
    else
        -- 第一次获取 或者 版本发生变化
        local version = tonumber(header.revision)
        local data = {
            version = version,
            kvs = kvs
        }
        if not watcher.last_version or version > watcher.last_version then
            watcher.last_version = version
            pcall(watcher.event, ctx, data, nil)
        end
    end

    local ok, err = new_timer(watcher.interval, do_watcher, watcher)
    if not ok then
        error(err)
    end
end

function _M.new(client, ctx, event)
    return setmetatable({
        client = client,
        ctx = ctx,
        event = event,
        interval = 5,
        timeout = 3000,
        started = false
    }, mt)
end

function _M.start(self)
    self.started = true

    local ok, err = new_timer(0, do_watcher, self)
    if not ok then
        error(err)
    end
end

function _M.stop(self)
    self.started = false
end

return _M