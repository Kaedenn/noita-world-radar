--[[ Simple profiler ]]

Profiler = {
    interval = 5,

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
    self.data[name] = {
        start = GameGetRealWorldTimeSinceStarted(),
        start_frame = GameGetFrameNum(),
        samples = {},
        current = 0,
    }
end

function Profiler:tick(name)
    if not self.data[name] then self:start(name) end
    local curr = GameGetRealWorldTimeSinceStarted()
    local curr_frame = GameGetFrameNum()

    local data = self.data[name]

    local dt = curr - data.start
    local df = curr_frame - data.start_frame
    local framenum = df % self.interval
    if framenum == 0 then
        data.current = profiler_aggregate(data.samples, self.rule)
    end
    data.samples[framenum + 1] = dt

    return data.current
end

-- vim: set ts=4 sts=4 sw=4:
