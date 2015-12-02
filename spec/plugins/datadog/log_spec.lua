local spec_helper = require "spec.spec_helpers"
local http_client = require "kong.tools.http_client"

local STUB_GET_URL = spec_helper.STUB_GET_URL

local UDP_PORT = spec_helper.find_port()

describe("Datadog Plugin", function()

  setup(function()
    spec_helper.prepare_db()
    spec_helper.insert_fixtures {
      api = {
        { request_host = "logging1.com", upstream_url = "http://mockbin.com" },
        { request_host = "logging2.com", upstream_url = "http://mockbin.com" },
        { request_host = "logging3.com", upstream_url = "http://mockbin.com" },
        { request_host = "logging4.com", upstream_url = "http://mockbin.com" }
      },
      plugin = {
        { name = "datadog", config = { host = "127.0.0.1", port = UDP_PORT, metrics = { "request_count" } }, __api = 1 },
        { name = "datadog", config = { host = "127.0.0.1", port = UDP_PORT, metrics = { "latency" } }, __api = 2 },
        { name = "datadog", config = { host = "127.0.0.1", port = UDP_PORT, metrics = { "status_count" } }, __api = 3 },
        { name = "datadog", config = { host = "127.0.0.1", port = UDP_PORT, metrics = { "request_size" } }, __api = 4 },
      }
    }
    spec_helper.start_kong()
  end)

  teardown(function()
    spec_helper.stop_kong()
  end)

  it("should log to UDP when metrics is request_count", function()
    local thread = spec_helper.start_udp_server(UDP_PORT) -- Starting the mock TCP server

    local _, status = http_client.get(STUB_GET_URL, nil, { host = "logging1.com" })
    assert.are.equal(200, status)

    local ok, res = thread:join()
    assert.truthy(ok)
    assert.truthy(res)
    assert.are.equal("kong.logging1_com.request.count:1|c", res)
  end)
  
  it("should log to UDP when metrics is status_count", function()
    local thread = spec_helper.start_udp_server(UDP_PORT) -- Starting the mock TCP server

    local _, status = http_client.get(STUB_GET_URL, nil, { host = "logging3.com" })
    assert.are.equal(200, status)

    local ok, res = thread:join()
    assert.truthy(ok)
    assert.truthy(res)
    assert.are.equal("kong.logging3_com.request.status.200:1|c", res)
  end)
  
  it("should log to UDP when metrics is request_size", function()
    local thread = spec_helper.start_udp_server(UDP_PORT) -- Starting the mock TCP server

    local _, status = http_client.get(STUB_GET_URL, nil, { host = "logging4.com" })
    assert.are.equal(200, status)

    local ok, res = thread:join()
    assert.truthy(ok)
    assert.truthy(res)
    assert.are.equal("kong.logging4_com.request.size:111|g", res)
  end)
  
  it("should log to UDP when metrics is latency", function()
    local thread = spec_helper.start_udp_server(UDP_PORT) -- Starting the mock TCP server

    local _, status = http_client.get(STUB_GET_URL, nil, { host = "logging2.com" })
    assert.are.equal(200, status)

    local ok, res = thread:join()
    assert.truthy(ok)
    assert.truthy(res)
    
    local message = {}
    for w in string.gmatch(res,"kong.logging2_com.latency:.*|g") do
      table.insert(message, w)
    end

    assert.are.equal(#message, 1)
  end)
end)
