Name
=============

lua-resty-node - pure lua dynamic node module


Description
===========

This library requires an nginx build with [ngx_lua module](https://github.com/openresty/lua-nginx-module), and [LuaJIT 2.0](http://luajit.org/luajit.html).

Dependencies
==========

- [lua-resty-upstream](https://github.com/toruneko/lua-resty-upstream)
- [lua-resty-http](https://github.com/pintsized/lua-resty-http)

Synopsis
========

```lua
    # nginx.conf:

    lua_package_path "/path/to/lua-resty-node/lib/?.lua;;";
    lua_shared_dict upstream    1m;
    lua_shared_dict monitor 1m;
    
    server {
        location = /t {
            content_by_lua_block {
                local config = {
                    healthcheck = {
                        shm = "memcache",
                        type = "http",
                         http_req = {
                            method = "HEAD",
                            path = "/ok.htm"
                         ,
                         valid_statuses = { 200 },
                         timeout = 2000,
                         interval = 3000,
                         fall = 2,
                         rise = 2,
                         concurrency = 10,
                    }
                } 
                local management = require "resty.node.management"
                management.new(upstream)
                -- update foo.com upstream
                management:watcher({
                    env = "dev",
                    app = "app",
                    ups = "upstream",
                    discovery = "discovery",
                    url = url,
                    headers = headers
                })
            }
        }
    }
    
```

Methods
=======

To load this library,

1. you need to specify this library's path in ngx_lua's [lua_package_path](https://github.com/openresty/lua-nginx-module#lua_package_path) directive. For example, `lua_package_path "/path/to/lua-resty-upstream/lib/?.lua;;";`.
2. you use `require` to load the library into a local Lua variable:

```lua
    local management = require "resty.node.management"
```

init
---
`syntax: management.new(config)`

`phase: init_by_lua`

initialize upstream management with configuration:

```nginx
lua_shared_dict upstream  1m;
```

```lua
local config = {
          healthcheck = {
              shm = "memcache",
              type = "http",
              http_req = {
                  method = "HEAD",
                  path = "/ok.htm"
              },
              valid_statuses = { 200 },
              timeout = 2000,
              interval = 3000,
              fall = 2,
              rise = 2,
              concurrency = 10,
          }
     } 
```

The healthcheck option for sub module [lua-resty-upstream-monitor](https://github.com/toruneko/lua-resty-upstream/blob/master/lib/resty/monitor.md).

watch_node
----
```lua
management:watcher({
              env = "dev",
              app = "app",
              ups = "upstream",
              discovery = "discovery",
              url = url,
              headers = headers
           })
```

The url, headers option for query node info

unwatch_node
------
`syntax: management:unwatcher(upstream)`

unwatch node with upstream

Author
======

kk


Copyright and License
=====================

This module is licensed under the MIT license.

Copyright (C) 2019, by kk

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


See Also
========
* the ngx_lua module: https://github.com/openresty/lua-nginx-module
