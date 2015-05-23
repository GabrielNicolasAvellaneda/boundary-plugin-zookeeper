-- Copyright 2015 Boundary, Inc.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local framework = require('framework')
local split = framework.string.split
local notEmpty = framework.string.notEmpty
local Plugin = framework.Plugin
local NetDataSource = framework.NetDataSource
local Accumulator = framework.Accumulator
local map = framework.functional.map
local reduce = framework.functional.reduce
local each = framework.functional.each

local params = framework.params
params.name = 'Boundary Zookeeper plugin'
params.version = '2.0'
params.tags = 'zookeeper'

local zookeeperDataSource = NetDataSource:new(params.service_host, params.service_port)
function zookeeperDataSource:onFetch(socket)
  socket:write('mntr\n')
end

local zookeeperPlugin = Plugin:new(params, zookeeperDataSource)

function parseLine(line)
  local parts = split(line, '\t')
  return parts
end

function toMapReducer (acc, x)
  local k = x[1]
  local v = x[2]
  acc[k] = v

  return acc
end

function parse(data)
  local lines = {}
  table.foreach(split(data, '\n'), function(i, v) if notEmpty(v) then table.insert(lines, v) end end)
  local parsedLines = map(parseLine, lines)
  local m = reduce(toMapReducer, {}, parsedLines)

  return m
end

local accumulated = Accumulator:new() 

function zookeeperPlugin:onParseValues(data)
  local parsed = parse(data)

  local metrics = {}
	
  metrics['ZK_WATCH_COUNT'] = false
  metrics['ZK_NUM_ALIVE_CONNECTIONS'] = false
  metrics['ZK_OPEN_FILE_DESCRIPTOR_COUNT'] = false
  metrics['ZK_OUTSTANDING_REQUESTS'] = false
  metrics['ZK_PACKETS_SENT'] =  true
  metrics['ZK_PACKETS_RECEIVED'] = true
  metrics['ZK_APPROXIMATE_DATA_SIZE'] = true
  metrics['ZK_MIN_LATENCY'] = false
  metrics['ZK_MAX_LATENCY'] = false
  metrics['ZK_AVG_LATENCY'] = false
  metrics['ZK_EPHEMERALS_COUNT'] = false
  metrics['ZK_ZNODE_COUNT'] = false
  metrics['ZK_MAX_FILE_DESCRIPTOR_COUNT'] = false
  metrics['ZK_SERVER_STATE'] = false
  metrics['ZK_FOLLOWERS'] = false
  metrics['ZK_SYNCED_FOLLOWERS'] = false
  metrics['ZK_PENDING_SYNCS'] = false

  local result = {}
  each(
    function (boundaryName, acc) 
      local metricName = boundaryName:lower()
      if parsed[metricName] then
        local value = (metricName == "zk_server_state" and (parsed[metricName] == "leader" and 1 or 0)) or tonumber(parsed[metricName])

        table.insert(result, framework.util.pack(boundaryName, acc and accumulated:accumulate(boundaryName, value) or value, nil, zookeeperPlugin.source))
      end
    end, metrics)

  return result
end

zookeeperPlugin:run()

