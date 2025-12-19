local fields = {
    DialogField.create("Bpm")
        .setLabel("BPM").defaultTo("153"),
    DialogField.create("BaseTiming")
        .setLabel("起始时间").defaultTo("0"),
    DialogField.create("EndTiming")
        .setLabel("结束时间").defaultTo("10000"),
    DialogField.create("Divide")
        .setLabel("节拍划分").defaultTo("16"),
    DialogField.create("MaxFanshou")
        .setLabel("出张程度(1-3)").dropdownMenu("1","2","3"),
    DialogField.create("qishou")
        .setLabel("起手(1左2右0不指定)").dropdownMenu("0","1","2"),
    DialogField.create("Stack")
        .setLabel("叠键(true/false)").dropdownMenu("true","false"),
}

local function RandStreamHandler()
    local DialogRequest = DialogInput.withTitle("参数输入").requestInput(fields)
    coroutine.yield()

    local Bpm = tonumber(DialogRequest.result["Bpm"])
    local BaseTiming = tonumber(DialogRequest.result["BaseTiming"])
    local EndTiming = tonumber(DialogRequest.result["EndTiming"])
    local Divide = tonumber(DialogRequest.result["Divide"])
    local MaxFanshou = tonumber(DialogRequest.result["MaxFanshou"])
    local qishou = tonumber(DialogRequest.result["qishou"]) or 0
    local Stack = DialogRequest.result["Stack"]
    Stack = (Stack == "true" or Stack == true)

    if MaxFanshou < 1 or MaxFanshou > 3 then
        notifyWarn("出张程度不合法")
        return
    end

    local output = Command.create("RandStream")

    local function RandInt(low, high)
        return math.random(low, high - 1)
    end         

    local function check(l, r, fanshou, MaxFanshou, Stack)
        if (Stack == false) and (l == r) then return -100 end
        if l - r >= 3 then return -100 end
        local x = 0
        if (l - r) % 2 == 0 then
            if l <= r then
                x = 0
            else
                x = 3
                if fanshou < 0 then x = -3 end
            end
        else
            if r % 2 == 1 then
                if l < r then x = 1 else x = 2 end
            else
                if l < r then x = -1 else x = -2 end
            end
        end
        if (x - fanshou > 2) or (x - fanshou < -2) then return -100 end
        if (x > MaxFanshou) or (x < -MaxFanshou) then return -100 end
        if (fanshou >= 2 or fanshou <= -2) and (x >= 2 or x <= -2) and (RandInt(1,3) == 1) then return -100 end
        return x
    end

    local function DrawTap(k, Timing)
        if k % 2 == 1 then
            local track = math.floor(k/2) + 1
            local tap = Event.tap(Timing, track, Context.currentTimingGroup)
            output.add(tap.save())
        else
            local startPosition = xy((k - 2) / 4, 1)
            local endPosition = xy((k - 2) / 4, 1)
            local arc = Event.arc(
                Timing,
                startPosition,
                Timing + 1,
                endPosition,
                true,   -- isVoid
                0,      -- color
                's',    -- lineType
                Context.currentTimingGroup,
                'none'  -- easing
            )
            output.add(arc.save())
            local arcTap = Event.arctap(Timing, arc)
            output.add(arcTap.save())
        end
    end

    local function RandJiaoHu(Bpm, BaseTiming, EndTiming, Divide, MaxFanshou, qishou, Stack)
        if MaxFanshou < 1 or MaxFanshou > 3 then return "出张程度不合法" end

        local n = 0.5 + (EndTiming - BaseTiming) / (60 / Bpm * 1000 * 4 / Divide) + 1
        n = n - n % 1
        if qishou == 0 then
            qishou = RandInt(0, 2)
        elseif qishou == 1 then
            qishou = 0
        else
            qishou = 1
        end

        local l, r
        repeat
            l, r = RandInt(1,8), RandInt(1,8)
        until l - r > 1 or r - l > 1

        if l > r then l, r = r, l end

        local fanshou = check(l, r, 0, MaxFanshou, Stack)
        local trycount = 0

        for i = 0, n-1 do
            local Timing = math.floor(BaseTiming + i * (60 / Bpm * 1000 * 4 / Divide))
            local temp
            if i % 2 == qishou then
                DrawTap(l, Timing)
                repeat
                    l = RandInt(1,8)
                    temp = check(l, r, fanshou, MaxFanshou, Stack)
                    trycount = trycount + 1
                until temp ~= -100 or trycount > 10000
                if temp == -100 then return "Error" end
                fanshou = temp
            else
                DrawTap(r, Timing)
                repeat
                    r = RandInt(1,8)
                    temp = check(l, r, fanshou, MaxFanshou, Stack)
                    trycount = trycount + 1
                until temp ~= -100 or trycount > 10000
                if temp == -100 then return "Error" end
                fanshou = temp
            end
            if trycount > 10002 then return "Error" end
        end
        return "1"
    end

    local result = RandJiaoHu(Bpm, BaseTiming, EndTiming, Divide, MaxFanshou, qishou, Stack)
    if result ~= "1" then
        notifyWarn("执行过程中出现错误: "..tostring(result))
        return
    end
    output.commit()
    notify("操作完成")
end

addMacroWithIcon("RandStream","randstream","randstream","e145", RandStreamHandler)