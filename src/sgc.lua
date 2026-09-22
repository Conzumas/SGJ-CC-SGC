-- SGJ-CC-SGC
-- Stargate Command-style ComputerCraft control system for Stargate Journey.
-- Target: Minecraft 1.21.1 NeoForge + Stargate Journey + CC:Tweaked.
--
-- This is a clean SGJourney rewrite of the original JSG SGC-CC program.
-- Stargate Journey's actual CC API is kept behind the helpers below.

local CONFIG = {
    data_file = "sgc_data",
    event_file = "sgc_events",
    max_events = 200,
    refresh = 0.5,

    -- Incoming connections are locked unless explicitly opened from the UI.
    fail_closed = true,

    -- Set true only if you want the program to automatically open the iris
    -- after an incoming connection ends.
    reopen_after_disconnect = false,
}

local state = {
    running = true,
    peripheral = nil,
    peripheral_name = nil,
    peripheral_type = nil,

    generation = nil,
    gate_type = nil,
    variant = nil,
    point_of_origin = nil,
    connected = false,
    dialing_out = false,
    wormhole = false,
    energy = 0,
    energy_capacity = 0,
    energy_target = 0,
    chevrons = 0,
    open_time = 0,
    dialed_address = nil,
    local_address = nil,

    iris = nil,
    iris_progress = nil,
    iris_progress_pct = nil,
    iris_durability = nil,
    iris_max_durability = nil,

    incoming = false,
    incoming_address = nil,
    alert = nil,
    dialing = false,
    dial_target = nil,
    dial_last = nil,

    addresses = {},
    selected = 1,
    events = {},
    last_event = "System initialized",
}

local function now()
    return os.date("%Y-%m-%d %H:%M:%S")
end

local function safe_call(fn, ...)
    if type(fn) ~= "function" then
        return false, nil, "missing_method"
    end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then
        return false, nil, tostring(a), nil, nil
    end
    return true, a, b, c, d
end

local function call_method(name, ...)
    if not state.peripheral then
        return false, nil, "No Stargate Journey interface is connected"
    end
    return safe_call(state.peripheral[name], ...)
end

local function trim(s)
    if type(s) ~= "string" then return "" end
    return s:match("^%s*(.-)%s*$") or ""
end

local function copy_address(address)
    local out = {}
    if type(address) ~= "table" then return out end
    for i = 1, #address do
        out[i] = tonumber(address[i]) or address[i]
    end
    return out
end

local function address_string(address)
    if type(address) ~= "table" or #address == 0 then
        return "NONE"
    end
    local out = {}
    for i, v in ipairs(address) do
        out[i] = tostring(v)
    end
    return table.concat(out, " - ")
end

local function same_address(a, b)
    if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then
        return false
    end
    for i = 1, #a do
        if tonumber(a[i]) ~= tonumber(b[i]) then
            return false
        end
    end
    return true
end

local function save_table(path, value)
    local h = fs.open(path, "w")
    if not h then return false end
    h.write(textutils.serialize(value))
    h.close()
    return true
end

local function load_table(path, fallback)
    if not fs.exists(path) then return fallback, true end
    local h = fs.open(path, "r")
    if not h then return fallback, false end
    local raw = h.readAll()
    h.close()
    if not raw or raw == "" then return fallback, false end
    local ok, value = pcall(textutils.unserialize, raw)
    if not ok or type(value) ~= "table" then return fallback, false end
    return value, true
end

local function log_event(message)
    local line = now() .. " | " .. tostring(message)
    table.insert(state.events, line)
    while #state.events > CONFIG.max_events do
        table.remove(state.events, 1)
    end
    state.last_event = tostring(message)
end

local function load_data()
    local data, ok = load_table(CONFIG.data_file, { addresses = {} })
    if ok and type(data.addresses) == "table" then
        state.addresses = data.addresses
    else
        state.addresses = {}
    end

    local events, events_ok = load_table(CONFIG.event_file, {})
    if events_ok and type(events) == "table" then
        state.events = events
    end
end

local function save_data()
    save_table(CONFIG.data_file, { addresses = state.addresses })
    save_table(CONFIG.event_file, state.events)
end

local function discover_peripheral()
    local preferred = {
        "advanced_crystal_interface",
        "crystal_interface",
        "basic_interface",
    }

    for _, ptype in ipairs(preferred) do
        local p = peripheral.find(ptype)
        if p and p.getStargateType then
            return p, ptype
        end
    end

    for _, name in ipairs(peripheral.getNames()) do
        local p = peripheral.wrap(name)
        if p and p.getStargateType then
            return p, name
        end
    end

    return nil, nil
end

local function refresh_gate()
    if not state.peripheral then return end

    local ok, value = call_method("getStargateGeneration")
    if ok then state.generation = value end

    ok, value = call_method("getStargateType")
    if ok then state.gate_type = value end

    ok, value = call_method("getStargateVariant")
    if ok then state.variant = value end

    ok, value = call_method("getPointOfOrigin")
    if ok then state.point_of_origin = value end

    ok, value = call_method("isStargateConnected")
    if ok then state.connected = value == true end

    ok, value = call_method("isStargateDialingOut")
    if ok then state.dialing_out = value == true end

    ok, value = call_method("isWormholeOpen")
    if ok then state.wormhole = value == true end

    ok, value = call_method("getStargateEnergy")
    if ok then state.energy = tonumber(value) or 0 end

    ok, value = call_method("getChevronsEngaged")
    if ok then state.chevrons = tonumber(value) or 0 end

    ok, value = call_method("getOpenTime")
    if ok then state.open_time = tonumber(value) or 0 end

    ok, value = call_method("getDialedAddress")
    if ok and type(value) == "table" and #value > 0 then
        state.dialed_address = copy_address(value)
    elseif ok then
        state.dialed_address = nil
    end

    ok, value = call_method("getLocalAddress")
    if ok and type(value) == "table" then
        state.local_address = copy_address(value)
    end

    ok, value = call_method("getEnergy")
    if ok then state.energy_capacity = tonumber(value) or state.energy_capacity end

    ok, value = call_method("getEnergyCapacity")
    if ok then state.energy_capacity = tonumber(value) or state.energy_capacity end

    ok, value = call_method("getEnergyTarget")
    if ok then state.energy_target = tonumber(value) or state.energy_target end

    -- Iris telemetry is optional. Unsupported calls are simply ignored.
    ok, value = call_method("getIris")
    if ok then state.iris = value end

    ok, value = call_method("getIrisProgress")
    if ok then state.iris_progress = value end

    ok, value = call_method("getIrisProgressPercentage")
    if ok then state.iris_progress_pct = value end

    ok, value = call_method("getIrisDurability")
    if ok then state.iris_durability = value end

    ok, value = call_method("getIrisMaxDurability")
    if ok then state.iris_max_durability = value end
end

local function ensure_peripheral()
    if state.peripheral then
        local ok = pcall(state.peripheral.getStargateType)
        if ok then return true end
        state.peripheral = nil
    end

    local p, name = discover_peripheral()
    if not p then
        state.peripheral = nil
        state.peripheral_name = nil
        state.peripheral_type = nil
        return false
    end

    state.peripheral = p
    state.peripheral_name = name
    state.peripheral_type = name
    log_event("SGJ interface connected: " .. tostring(name))
    refresh_gate()
    return true
end

local function operation_result(ok, a, b)
    if not ok then
        return false, tostring(b or a or "ComputerCraft call failed")
    end

    -- Crystal interfaces return numeric feedback codes. Negative codes are
    -- failures in Stargate Journey's Feedback system; positive/zero values are
    -- feedback states. Treat the call itself as successful and let the UI show
    -- the feedback unless it is clearly negative.
    if type(a) == "number" and a < 0 then
        return false, tostring(b or ("SGJ feedback " .. a))
    end

    return true, a, b
end

local function iris_action(method)
    if not state.peripheral then
        return false, "No Stargate interface"
    end

    local ok, a, b = call_method(method)
    if not ok then
        return false, tostring(b or a)
    end

    return operation_result(true, a, b)
end

local function force_close_iris(reason)
    if not state.peripheral then return false end
    local ok, detail = iris_action("closeIris")
    if ok then
        log_event("IRIS CLOSE REQUESTED: " .. tostring(reason))
        return true
    end
    log_event("IRIS CLOSE FAILED: " .. tostring(detail))
    return false
end

local function open_iris(reason)
    local ok, detail = iris_action("openIris")
    if ok then
        log_event("IRIS OPEN REQUESTED: " .. tostring(reason))
        return true
    end
    log_event("IRIS OPEN FAILED: " .. tostring(detail))
    return false
end

local function dial_address(address)
    if type(address) ~= "table" or #address == 0 then
        log_event("DIAL REJECTED: empty address")
        return false
    end
    if not ensure_peripheral() then
        log_event("DIAL REJECTED: no Stargate interface")
        return false
    end

    state.dialing = true
    state.dial_target = copy_address(address)
    state.dial_last = nil
    state.alert = nil
    log_event("DIAL START: " .. address_string(address))

    refresh_gate()
    local start = math.max(1, state.chevrons + 1)

    for i = start, #address do
        if not state.running then break end

        local symbol = tonumber(address[i])
        if symbol == nil then
            state.dialing = false
            log_event("DIAL FAILED: non-numeric symbol at position " .. i)
            return false
        end

        local ok, feedback, message = call_method("engageSymbol", symbol, false, true)
        if not ok then
            state.dialing = false
            log_event("DIAL FAILED at chevron " .. i .. ": " .. tostring(feedback))
            return false
        end

        state.dial_last = symbol
        refresh_gate()

        -- Wait for the requested symbol/chevron operation to advance.
        local deadline = os.clock() + 15
        while os.clock() < deadline do
            if state.chevrons >= i or state.wormhole or state.connected then
                break
            end
            sleep(0.05)
            refresh_gate()
        end

        if state.chevrons < i and not state.wormhole and not state.connected then
            log_event("DIAL TIMEOUT at chevron " .. i)
            state.dialing = false
            return false
        end
    end

    state.dialing = false
    refresh_gate()
    log_event("DIAL COMPLETE: " .. address_string(address))
    return true
end

local function add_address()
    term.clear()
    term.setCursorPos(2, 2)
    term.write("ADD ADDRESS")
    term.setCursorPos(2, 4)
    term.write("Name: ")
    local name = trim(read())
    if name == "" then return end

    term.setCursorPos(2, 5)
    term.write("Symbols (space separated): ")
    local raw = read()
    local symbols = {}
    for token in string.gmatch(raw, "%S+") do
        local n = tonumber(token)
        if not n then
            term.setCursorPos(2, 7)
            term.write("Invalid symbol: " .. token)
            sleep(2)
            return
        end
        table.insert(symbols, n)
    end

    if #symbols == 0 then return end
    table.insert(state.addresses, { name = name, symbols = symbols })
    state.selected = #state.addresses
    save_data()
    log_event("ADDRESS ADDED: " .. name)
end

local function edit_address(index)
    local entry = state.addresses[index]
    if not entry then return end

    term.clear()
    term.setCursorPos(2, 2)
    term.write("EDIT ADDRESS")
    term.setCursorPos(2, 4)
    term.write("Name [" .. tostring(entry.name) .. "]: ")
    local name = trim(read())
    if name ~= "" then entry.name = name end

    term.setCursorPos(2, 5)
    term.write("Symbols [" .. address_string(entry.symbols) .. "]: ")
    local raw = read()
    if trim(raw) ~= "" then
        local symbols = {}
        for token in string.gmatch(raw, "%S+") do
            local n = tonumber(token)
            if not n then
                term.setCursorPos(2, 7)
                term.write("Invalid symbol: " .. token)
                sleep(2)
                return
            end
            table.insert(symbols, n)
        end
        entry.symbols = symbols
    end

    save_data()
    log_event("ADDRESS EDITED: " .. entry.name)
end

local function remove_address(index)
    local entry = state.addresses[index]
    if not entry then return end
    table.remove(state.addresses, index)
    state.selected = math.max(1, math.min(state.selected, #state.addresses))
    save_data()
    log_event("ADDRESS REMOVED: " .. tostring(entry.name))
end

local function dial_selected()
    local entry = state.addresses[state.selected]
    if not entry then
        log_event("DIAL REJECTED: no address selected")
        return
    end
    dial_address(entry.symbols)
end

local function status_text()
    if not state.peripheral then return "OFFLINE" end
    if state.wormhole then return "WORMHOLE OPEN" end
    if state.connected then
        return state.dialing_out and "CONNECTED / OUTGOING" or "CONNECTED / INCOMING"
    end
    return state.dialing and "DIALING" or "IDLE"
end

local function energy_text()
    if state.energy_capacity and state.energy_capacity > 0 then
        local pct = math.floor((state.energy / state.energy_capacity) * 100 + 0.5)
        return string.format("%d / %d (%d%%)", state.energy, state.energy_capacity, pct)
    end
    return tostring(state.energy)
end

local function draw_header(title)
    local width = term.getSize()
    term.clear()
    term.setCursorPos(2, 1)
    term.write("S T A R G A T E   C O M M A N D")
    term.setCursorPos(2, 2)
    term.write(string.rep("=", math.max(1, width - 3)))
    term.setCursorPos(2, 3)
    term.write(title)
end

local function draw_main()
    draw_header("MAIN CONTROL")

    term.setCursorPos(2, 5)
    term.write("INTERFACE: " .. tostring(state.peripheral_type or "NONE"))
    term.setCursorPos(2, 6)
    term.write("GATE TYPE: " .. tostring(state.gate_type or "UNKNOWN"))
    term.setCursorPos(2, 7)
    term.write("STATUS:    " .. status_text())
    term.setCursorPos(2, 8)
    term.write("ENERGY:    " .. energy_text())
    term.setCursorPos(2, 9)
    term.write("TARGET:    " .. tostring(state.energy_target))
    term.setCursorPos(2, 10)
    term.write("CHEVRONS:  " .. tostring(state.chevrons))
    term.setCursorPos(2, 11)
    term.write("IRIS:      " .. tostring(state.iris or "UNKNOWN"))
    term.setCursorPos(2, 12)
    term.write("LOCAL:     " .. address_string(state.local_address))

    if state.dialed_address then
        term.setCursorPos(2, 13)
        term.write("DIALED:    " .. address_string(state.dialed_address))
    end

    local row = 15
    if state.incoming then
        term.setCursorPos(2, row)
        term.write("!!! INCOMING CONNECTION !!!")
        row = row + 1
        term.setCursorPos(4, row)
        term.write("ADDRESS: " .. address_string(state.incoming_address))
        row = row + 1
    end

    if state.alert then
        term.setCursorPos(2, row)
        term.write("ALERT: " .. tostring(state.alert))
        row = row + 1
    end

    term.setCursorPos(2, row)
    term.write("LAST: " .. tostring(state.last_event):sub(1, 70))

    local _, h = term.getSize()
    term.setCursorPos(2, h - 3)
    term.write("1 ADDRESS BOOK   2 DIAL SELECTED   3 IRIS")
    term.setCursorPos(2, h - 2)
    term.write("4 EVENT LOG      5 REFRESH          Q QUIT")
end

local function draw_addresses()
    draw_header("ADDRESS BOOK")
    if #state.addresses == 0 then
        term.setCursorPos(2, 5)
        term.write("NO SAVED ADDRESSES")
    else
        for i, entry in ipairs(state.addresses) do
            local marker = i == state.selected and ">" or " "
            term.setCursorPos(2, 4 + i)
            term.write(string.format("%s %02d %-20s %s", marker, i, tostring(entry.name):sub(1,20), address_string(entry.symbols)))
        end
    end

    local _, h = term.getSize()
    term.setCursorPos(2, h - 3)
    term.write("UP/DOWN SELECT   D DIAL   A ADD")
    term.setCursorPos(2, h - 2)
    term.write("E EDIT           R REMOVE B BACK")
end

local function address_menu()
    while state.running do
        draw_addresses()
        local event, key = os.pullEvent("key")
        if event == "key" then
            if key == keys.up then
                state.selected = math.max(1, state.selected - 1)
            elseif key == keys.down then
                state.selected = math.min(math.max(1, #state.addresses), state.selected + 1)
            elseif key == keys.d then
                dial_selected()
            elseif key == keys.a then
                add_address()
            elseif key == keys.e then
                edit_address(state.selected)
            elseif key == keys.r then
                remove_address(state.selected)
            elseif key == keys.b then
                return
            end
        end
    end
end

local function draw_iris()
    draw_header("IRIS CONTROL / SECURITY")

    term.setCursorPos(2, 5)
    term.write("IRIS:       " .. tostring(state.iris or "UNKNOWN"))
    term.setCursorPos(2, 6)
    term.write("PROGRESS:   " .. tostring(state.iris_progress))
    term.setCursorPos(2, 7)
    term.write("PROGRESS %: " .. tostring(state.iris_progress_pct))
    term.setCursorPos(2, 8)
    term.write("DURABILITY: " .. tostring(state.iris_durability))
    term.setCursorPos(2, 9)
    term.write("MAX DUR.:   " .. tostring(state.iris_max_durability))
    term.setCursorPos(2, 10)
    term.write("INCOMING:   " .. tostring(state.incoming))
    term.setCursorPos(2, 11)
    term.write("POLICY:     " .. (CONFIG.fail_closed and "FAIL CLOSED" or "MANUAL"))

    local _, h = term.getSize()
    term.setCursorPos(2, h - 4)
    term.write("O OPEN IRIS   C CLOSE IRIS   S STOP IRIS")
    term.setCursorPos(2, h - 3)
    term.write("B BACK        AUTO-LOCK INCOMING CONNECTIONS")
end

local function iris_menu()
    while state.running do
        refresh_gate()
        draw_iris()
        local event, key = os.pullEvent("key")
        if event == "key" then
            if key == keys.o then
                open_iris("manual control")
            elseif key == keys.c then
                force_close_iris("manual control")
            elseif key == keys.s then
                iris_action("stopIris")
                log_event("IRIS STOP REQUESTED")
            elseif key == keys.b then
                return
            end
        end
    end
end

local function draw_log()
    draw_header("EVENT LOG")
    local _, h = term.getSize()
    local first = math.max(1, #state.events - (h - 7))
    local row = 5
    for i = first, #state.events do
        term.setCursorPos(2, row)
        term.write(tostring(state.events[i]):sub(1, 75))
        row = row + 1
        if row >= h - 2 then break end
    end
    term.setCursorPos(2, h - 1)
    term.write("B BACK")
end

local function log_menu()
    while state.running do
        draw_log()
        local event, key = os.pullEvent("key")
        if event == "key" and key == keys.b then return end
    end
end

local function handle_event(event, ...)
    local args = { ... }

    -- Stargate Journey queues the peripheral attachment name as the first
    -- event argument. Strip it for interface-generated events.
    local attachment = table.remove(args, 1)

    if event == "stargate_incoming_connection" then
        state.incoming = true
        state.alert = "INCOMING STARGATE CONNECTION"
        log_event("INCOMING CONNECTION DETECTED")

        if CONFIG.fail_closed then
            force_close_iris("incoming connection")
        end

    elseif event == "stargate_incoming_wormhole" then
        state.incoming = true
        state.alert = "INCOMING WORMHOLE"
        if #args > 0 and type(args[1]) == "table" and #args[1] > 0 then
            state.incoming_address = copy_address(args[1])
        end
        log_event("INCOMING WORMHOLE")

        if CONFIG.fail_closed then
            force_close_iris("incoming wormhole")
        end

    elseif event == "stargate_outgoing_wormhole" then
        state.incoming = false
        log_event("OUTGOING WORMHOLE")

    elseif event == "stargate_chevron_engaged" then
        log_event("CHEVRON ENGAGED: " .. table.concat(args, ", "))

    elseif event == "stargate_rotation_started" then
        log_event("RING ROTATION STARTED: " .. tostring(args[1]))

    elseif event == "stargate_rotation_stopped" then
        log_event("RING ROTATION STOPPED")

    elseif event == "stargate_disconnected" then
        state.incoming = false
        state.alert = nil
        log_event("STARGATE DISCONNECTED")

        if CONFIG.reopen_after_disconnect then
            open_iris("automatic disconnect restoration")
        end
    end
end

local function security_loop()
    while state.running do
        local event, a, b, c, d, e = os.pullEvent()
        if event == "peripheral" or event == "peripheral_detach" then
            ensure_peripheral()
        elseif event == "stargate_incoming_connection"
            or event == "stargate_incoming_wormhole"
            or event == "stargate_outgoing_wormhole"
            or event == "stargate_disconnected"
            or event == "stargate_chevron_engaged"
            or event == "stargate_rotation_started"
            or event == "stargate_rotation_stopped" then
            handle_event(event, a, b, c, d, e)
        end
    end
end

local function refresh_loop()
    while state.running do
        ensure_peripheral()
        refresh_gate()

        if state.incoming and CONFIG.fail_closed then
            local iris = tostring(state.iris or ""):lower()
            if iris ~= "closed" and iris ~= "closing" then
                force_close_iris("incoming connection safety loop")
            end
        end

        sleep(CONFIG.refresh)
    end
end

local function ui_loop()
    while state.running do
        draw_main()
        local event, key = os.pullEvent("key")
        if event == "key" then
            if key == keys.one then
                address_menu()
            elseif key == keys.two then
                dial_selected()
            elseif key == keys.three then
                iris_menu()
            elseif key == keys.four then
                log_menu()
            elseif key == keys.five then
                refresh_gate()
                log_event("MANUAL REFRESH")
            elseif key == keys.q then
                state.running = false
            end
        end
    end
end

local function startup()
    term.setCursorBlink(false)
    load_data()

    if ensure_peripheral() then
        refresh_gate()
        log_event("SGJ SYSTEM ONLINE: " .. tostring(state.gate_type))
    else
        log_event("NO STARGATE JOURNEY INTERFACE FOUND")
    end
end

startup()
parallel.waitForAny(security_loop, refresh_loop, ui_loop)

state.running = false
save_data()
term.clear()
term.setCursorPos(1, 1)
print("SGJ-CC-SGC offline.")
