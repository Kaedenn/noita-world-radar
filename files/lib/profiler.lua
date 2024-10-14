--[[ Simple profiler
--
-- Profiles time between each start() and tick() call.
--]]

Profiler = {
    interval = 10,

    rule = "average",
    data = {},
}

Profiler.RULES = {
    average = function(samples)
        local total = 0
        for _, sample in ipairs(samples) do
            total = total + sample
        end
        return total / #samples
    end,
    min = function(samples)
        return math.min(unpack(samples))
    end,
    max = function(samples)
        return math.max(unpack(samples))
    end
}

function profiler_aggregate(samples, rule)
    if #samples == 0 then return 0 end
    local func = Profiler.RULES[rule] or Profiler.RULES.average
    return func(samples)
end

function Profiler:start(name)
    if not self.data[name] then
        self.data[name] = {
            prior = 0,
            samples = {},
            current = 0,
        }
    end
    local curr = GameGetRealWorldTimeSinceStarted()
    self.data[name].prior = curr
end

function Profiler:tick(name)
    local data = self.data[name]
    local curr = GameGetRealWorldTimeSinceStarted()
    local dt = curr - data.prior
    if #data.samples >= self.interval then
        data.current = profiler_aggregate(data.samples, self.rule)
        data.samples = {}
    end
    data.prior = curr
    data.samples[#data.samples+1] = dt

    return data.current
end

-- vim: set ts=4 sts=4 sw=4:
