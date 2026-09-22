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

    -- SGJourney Transceiver / GDO settings.
    -- Leave idc_code empty to keep incoming iris authorization disabled.
    transceiver_frequency = 0,
    idc_code = "",

    audio = {
        incoming_drive = "drive_3",
        outgoing_drive = "drive_2",
        incoming_repeat_seconds = 3.0,
        outgoing_repeat_seconds = 3.0,
        poll_interval = 0.05,
    },
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
    interface_energy = 0,
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
    iris_authorized = false,

    connected_address = nil,

    transceiver = nil,
    transceiver_name = nil,
    transceiver_frequency = nil,
    transceiver_code = nil,
    remote_iris_pct = nil,

    audio_alarm = nil,
    audio_alarm_since = nil,
    audio_last_drive = nil,
    audio_error_reported = {},

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
    -- Persist the event log as events occur so a crash/reboot does not erase
    -- the operational history. This mirrors the original SGC behavior.
    save_table(CONFIG.event_file, state.events)
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
    local data_ok = save_table(CONFIG.data_file, { addresses = state.addresses })
    local events_ok = save_table(CONFIG.event_file, state.events)
    return data_ok and events_ok
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

local function discover_transceiver()
    for _, name in ipairs(peripheral.getNames()) do
        local p = peripheral.wrap(name)
        if p and p.setFrequency and p.setCurrentCode and p.sendTransmission then
            return p, name
        end
    end
    return nil, nil
end

local function ensure_transceiver()
    if state.transceiver then
        local ok = pcall(state.transceiver.getFrequency)
        if ok then return true end
        state.transceiver = nil
        state.transceiver_name = nil
    end

    local p, name = discover_transceiver()
    if not p then
        state.transceiver = nil
        state.transceiver_name = nil
        return false
    end

    state.transceiver = p
    state.transceiver_name = name

    if type(CONFIG.transceiver_frequency) == "number"
        and CONFIG.transceiver_frequency >= 0
        and CONFIG.transceiver_frequency <= 2147483647
        and p.setFrequency then
        pcall(p.setFrequency, CONFIG.transceiver_frequency)
    end

    if type(CONFIG.idc_code) == "string" and CONFIG.idc_code ~= "" and p.setCurrentCode then
        pcall(p.setCurrentCode, CONFIG.idc_code)
    end

    log_event("SGJ transceiver connected: " .. tostring(name))
    return true
end

local function refresh_transceiver()
    if not state.transceiver then return end

    local ok, value = safe_call(state.transceiver.getFrequency)
    if ok then state.transceiver_frequency = tonumber(value) end

    ok, value = safe_call(state.transceiver.getCurrentCode)
    if ok then state.transceiver_code = tostring(value or "") end

    ok, value = safe_call(state.transceiver.checkConnectedShielding)
    if ok then
        state.remote_iris_pct = value
    else
        state.remote_iris_pct = nil
    end
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

    ok, value = call_method("getConnectedAddress")
    if ok and type(value) == "table" and #value > 0 then
        state.connected_address = copy_address(value)
        if state.incoming then
            state.incoming_address = copy_address(value)
        end
    elseif ok then
        state.connected_address = nil
    end

    ok, value = call_method("getEnergy")
    if ok then state.interface_energy = tonumber(value) or state.interface_energy end

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

    -- SGJourney uses booleans for iris actions and numeric feedback codes for
    -- Stargate operations. Never treat a false boolean as success.
    if a == false then
        return false, tostring(b or "SGJourney rejected the operation")
    end

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
    if state.incoming and CONFIG.fail_closed and not state.iris_authorized then
        log_event("IRIS OPEN BLOCKED: incoming connection is not IDC-authorized")
        return false, "incoming connection is not authorized"
    end

    local ok, detail = iris_action("openIris")
    if ok then
        log_event("IRIS OPEN REQUESTED: " .. tostring(reason))
        return true
    end
    log_event("IRIS OPEN FAILED: " .. tostring(detail))
    return false
end

local function audio_drive_for_alarm(kind)
    if kind == "incoming" then return CONFIG.audio.incoming_drive end
    if kind == "outgoing" then return CONFIG.audio.outgoing_drive end
    return nil
end

local function audio_repeat_seconds(kind)
    if kind == "incoming" then return CONFIG.audio.incoming_repeat_seconds end
    if kind == "outgoing" then return CONFIG.audio.outgoing_repeat_seconds end
    return nil
end

local function stop_alarm_audio()
    for _, drive in ipairs({ CONFIG.audio.incoming_drive, CONFIG.audio.outgoing_drive }) do
        pcall(disk.stopAudio, drive)
    end
    state.audio_alarm = nil
    state.audio_alarm_since = nil
    state.audio_last_drive = nil
end

local function set_alarm_audio(kind, reason)
    if kind ~= "incoming" and kind ~= "outgoing" then
        stop_alarm_audio()
        return
    end

    if kind == "outgoing" and state.audio_alarm == "incoming" then
        return
    end

    local drive = audio_drive_for_alarm(kind)
    if not drive then return end

    for _, other in ipairs({ CONFIG.audio.incoming_drive, CONFIG.audio.outgoing_drive }) do
        if other ~= drive then pcall(disk.stopAudio, other) end
    end

    state.audio_alarm = kind
    state.audio_alarm_since = nil
    state.audio_last_drive = drive
    log_event("AUDIO ALARM: " .. kind:upper() .. " / " .. tostring(reason or "event"))
end

local function audio_play_once(kind)
    local drive = audio_drive_for_alarm(kind)
    if not drive then return false end

    local ok_has, has_audio = pcall(disk.hasAudio, drive)
    if not ok_has or has_audio ~= true then
        if not state.audio_error_reported[drive] then
            state.audio_error_reported[drive] = true
            log_event("AUDIO " .. kind:upper() .. " FAILED: " .. tostring(drive) .. " has no music disc")
        end
        return false
    end

    local ok = pcall(disk.playAudio, drive)
    if not ok then
        if not state.audio_error_reported[drive] then
            state.audio_error_reported[drive] = true
            log_event("AUDIO " .. kind:upper() .. " FAILED: unable to play " .. tostring(drive))
        end
        return false
    end

    state.audio_error_reported[drive] = nil
    state.audio_alarm_since = os.epoch("utc")
    return true
end

local function audio_loop()
    while state.running do
        local kind = state.audio_alarm
        if kind then
            local repeat_seconds = audio_repeat_seconds(kind)
            if repeat_seconds then
                if not state.audio_alarm_since
                    or (os.epoch("utc") - state.audio_alarm_since) >= repeat_seconds * 1000 then
                    audio_play_once(kind)
                end
            end
        else
            state.audio_alarm_since = nil
        end
        sleep(CONFIG.audio.poll_interval)
    end
end

local function dial_address(address)
    if type(address) ~= "table" or #address == 0 then
        log_event("DIAL REJECTED: empty address")
        return false
    end
    if #address < 7 or #address > 9 then
        log_event("DIAL REJECTED: address must contain 7-9 symbols")
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

    -- Do not append to an unrelated active connection. A partial address may
    -- only be resumed when the gate is connected by our outgoing dial attempt.
    local already = 0
    if type(state.dialed_address) == "table" then
        already = #state.dialed_address
        if already > 0 and not state.dialing_out then
            state.dialing = false
            log_event("DIAL REJECTED: gate already has an incoming/active address")
            return false
        end
        if already > #address then
            state.dialing = false
            log_event("DIAL REJECTED: existing dialed address is longer than target")
            return false
        end
        for i = 1, already do
            if tonumber(state.dialed_address[i]) ~= tonumber(address[i]) then
                state.dialing = false
                log_event("DIAL REJECTED: existing encoded address does not match target")
                return false
            end
        end
    end
    local start = math.max(1, already + 1)

    for i = start, #address do
        if not state.running then break end

        local symbol = tonumber(address[i])
        if symbol == nil then
            state.dialing = false
            log_event("DIAL FAILED: non-numeric symbol at position " .. i)
            return false
        end

        local ok, feedback, message = call_method("engageSymbol", symbol, false, false)
        if not ok then
            state.dialing = false
            log_event("DIAL FAILED at chevron " .. i .. ": " .. tostring(feedback))
            return false
        end

        state.dial_last = symbol
        refresh_gate()

        -- SGJ does not require a fixed delay: wait until the encoded address
        -- contains this symbol. This also works across rotating gate types.
        local deadline = os.epoch("utc") + 20000
        while os.epoch("utc") < deadline do
            refresh_gate()
            local count = type(state.dialed_address) == "table" and #state.dialed_address or 0
            if count >= i then break end
            sleep(0.05)
        end

        local count = type(state.dialed_address) == "table" and #state.dialed_address or 0
        if count < i then
            log_event("DIAL TIMEOUT at chevron " .. i)
            state.dialing = false
            return false
        end
    end

    refresh_gate()
    local encoded = type(state.dialed_address) == "table" and #state.dialed_address or 0
    if encoded < #address then
        state.dialing = false
        log_event("DIAL FAILED: address encoding incomplete")
        return false
    end

    local ok, feedback, message = call_method("engageStargate")
    if not ok then
        state.dialing = false
        log_event("DIAL ENGAGE FAILED: " .. tostring(feedback))
        return false
    end
    if type(feedback) == "number" and feedback < 0 then
        state.dialing = false
        log_event("DIAL ENGAGE REJECTED: " .. tostring(message or feedback))
        return false
    end

    state.dialing = false
    refresh_gate()
    log_event("DIAL ENGAGED: " .. address_string(address))
    return true
end

local function validate_address(symbols)
    if type(symbols) ~= "table" or #symbols < 7 or #symbols > 9 then
        return false, "Address must contain 7-9 symbols including the Point of Origin"
    end

    local seen = {}
    for i, symbol in ipairs(symbols) do
        local n = tonumber(symbol)
        if n == nil or n < 0 or n > 38 or n % 1 ~= 0 then
            return false, "Invalid symbol at position " .. tostring(i) .. ": " .. tostring(symbol)
        end
        if n == 0 and i ~= #symbols then
            return false, "Point of Origin (0) must be the final symbol"
        end
        if n ~= 0 then
            if seen[n] then
                return false, "Duplicate symbol: " .. tostring(n)
            end
            seen[n] = true
        end
    end

    if tonumber(symbols[#symbols]) ~= 0 then
        return false, "Address must end with Point of Origin (0)"
    end

    local normalized = {}
    for i, symbol in ipairs(symbols) do normalized[i] = tonumber(symbol) end
    return true, normalized
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

    local valid, normalized = validate_address(symbols)
    if not valid then
        term.setCursorPos(2, 7)
        term.write(normalized)
        sleep(2)
        return
    end

    for _, entry in ipairs(state.addresses) do
        if same_address(entry.symbols, normalized) then
            term.setCursorPos(2, 7)
            term.write("Duplicate address")
            sleep(2)
            return
        end
    end

    table.insert(state.addresses, { name = name, symbols = normalized })
    state.selected = #state.addresses
    if not save_data() then
        table.remove(state.addresses, #state.addresses)
        state.selected = math.max(1, math.min(state.selected, #state.addresses))
        log_event("ADDRESS ADD FAILED: unable to save address data")
        return
    end
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
        local valid, normalized = validate_address(symbols)
        if not valid then
            term.setCursorPos(2, 7)
            term.write(normalized)
            sleep(2)
            return
        end
        entry.symbols = normalized
    end

    if not save_data() then
        log_event("ADDRESS EDIT FAILED: unable to save address data")
        return
    end
    log_event("ADDRESS EDITED: " .. entry.name)
end

local function remove_address(index)
    local entry = state.addresses[index]
    if not entry then return end
    table.remove(state.addresses, index)
    state.selected = math.max(1, math.min(state.selected, #state.addresses))
    if not save_data() then
        table.insert(state.addresses, index, entry)
        state.selected = math.max(1, math.min(state.selected, #state.addresses))
        log_event("ADDRESS REMOVE FAILED: unable to save address data")
        return
    end
    log_event("ADDRESS REMOVED: " .. tostring(entry.name))
end

local function send_idc()
    if not ensure_transceiver() then
        log_event("IDC SEND FAILED: no SGJourney transceiver")
        return false
    end
    if type(CONFIG.idc_code) ~= "string" or CONFIG.idc_code == "" then
        log_event("IDC SEND FAILED: IDC code is not configured")
        return false
    end

    local ok, result = safe_call(state.transceiver.sendTransmission)
    if not ok or result == false then
        log_event("IDC SEND FAILED: " .. tostring(result or "transceiver rejected transmission"))
        return false
    end

    log_event("IDC TRANSMISSION SENT")
    return true
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
    term.write("GATE PWR:  " .. energy_text())
    term.setCursorPos(2, 9)
    term.write("IFACE FE:  " .. tostring(state.interface_energy))
    term.setCursorPos(2, 10)
    term.write("TARGET:    " .. tostring(state.energy_target))
    term.setCursorPos(2, 11)
    term.write("CHEVRONS:  " .. tostring(state.chevrons))
    term.setCursorPos(2, 12)
    term.write("IRIS:      " .. tostring(state.iris or "NONE"))
    term.setCursorPos(2, 13)
    term.write("LOCAL:     " .. address_string(state.local_address))

    term.setCursorPos(2, 14)
    term.write("CONNECTED: " .. address_string(state.connected_address or state.dialed_address))

    term.setCursorPos(2, 15)
    term.write("TRANSCEIVER: " .. (state.transceiver and "ONLINE" or "OFFLINE")
        .. " FREQ=" .. tostring(state.transceiver_frequency or "N/A"))

    local row = 18
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
    term.write("B BACK        T SEND IDC       AUTO-LOCK INCOMING")
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
            elseif key == keys.t then
                send_idc()
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

    -- Stargate Journey places the peripheral name immediately after the event.
    -- The remaining values are the documented event payload.
    local attachment = table.remove(args, 1)

    if event == "stargate_incoming_connection" then
        state.incoming = true
        state.iris_authorized = false
        state.alert = "INCOMING STARGATE CONNECTION"
        set_alarm_audio("incoming", "incoming connection")
        log_event("INCOMING CONNECTION DETECTED")

        if CONFIG.fail_closed then
            force_close_iris("incoming connection")
        end

    elseif event == "stargate_incoming_wormhole" then
        state.incoming = true
        state.alert = "INCOMING WORMHOLE"
        set_alarm_audio("incoming", "incoming wormhole")
        if #args > 0 and type(args[1]) == "table" and #args[1] > 0 then
            state.incoming_address = copy_address(args[1])
        end
        log_event("INCOMING WORMHOLE")

        if CONFIG.fail_closed then
            force_close_iris("incoming wormhole")
        end

    elseif event == "stargate_outgoing_wormhole" then
        state.incoming = false
        set_alarm_audio("outgoing", "outgoing wormhole")
        if #args > 0 and type(args[1]) == "table" then
            state.dialed_address = copy_address(args[1])
        end
        log_event("OUTGOING WORMHOLE")

    elseif event == "stargate_message_received" then
        log_event("STARGATE MESSAGE RECEIVED: " .. tostring(args[1] or ""))

    elseif event == "stargate_chevron_engaged" then
        local fields = {}
        for i, value in ipairs(args) do fields[i] = tostring(value) end
        log_event("CHEVRON ENGAGED: " .. table.concat(fields, ", "))

    elseif event == "stargate_deconstructing_entity" then
        log_event("ENTITY ENTERED WORMHOLE: type=" .. tostring(args[1])
            .. " name=" .. tostring(args[2]) .. " uuid=" .. tostring(args[3])
            .. " wrong_end=" .. tostring(args[4]))

    elseif event == "stargate_reconstructing_entity" then
        log_event("ENTITY EXITED WORMHOLE: type=" .. tostring(args[1])
            .. " name=" .. tostring(args[2]) .. " uuid=" .. tostring(args[3]))

    elseif event == "stargate_disconnected" then
        state.incoming = false
        state.iris_authorized = false
        state.alert = nil
        state.incoming_address = nil
        stop_alarm_audio()
        log_event("STARGATE DISCONNECTED: feedback=" .. tostring(args[1])
            .. " message=" .. tostring(args[2] or ""))

        if CONFIG.reopen_after_disconnect then
            open_iris("automatic disconnect restoration")
        end

    elseif event == "stargate_reset" then
        state.incoming = false
        state.iris_authorized = false
        state.alert = nil
        state.incoming_address = nil
        stop_alarm_audio()
        log_event("STARGATE RESET: feedback=" .. tostring(args[1])
            .. " message=" .. tostring(args[2] or ""))

    elseif event == "transceiver_transmission_received" then
        local frequency = tonumber(args[1])
        local received_idc = tostring(args[2] or "")
        local configured_match = args[3] == true

        if state.transceiver_name and attachment ~= state.transceiver_name then
            return
        end

        log_event("IDC RECEIVED: frequency=" .. tostring(frequency)
            .. " match=" .. tostring(configured_match))

        if not state.incoming then
            log_event("IDC REJECTED: no incoming Stargate connection")
            return
        end

        if type(CONFIG.idc_code) ~= "string" or CONFIG.idc_code == "" then
            state.alert = "!!! IDC CODE NOT CONFIGURED !!!"
            log_event("IDC REJECTED: local IDC code is not configured")
            return
        end

        if frequency ~= tonumber(CONFIG.transceiver_frequency)
            or received_idc ~= CONFIG.idc_code then
            log_event("IDC REJECTED: invalid frequency or code")
            return
        end

        state.iris_authorized = true
        local opened = open_iris("IDC authenticated")
        if opened then
            state.alert = nil
            log_event("IDC AUTHENTICATED: IRIS OPEN AUTHORIZED")
        else
            state.iris_authorized = false
            state.alert = "!!! IRIS OPEN FAILED !!!"
            log_event("IDC AUTHENTICATED BUT IRIS OPEN FAILED")
        end
    end
end

local function security_loop()
    while state.running do
        local event, a, b, c, d, e = os.pullEvent()
        if event == "peripheral" or event == "peripheral_detach" then
            ensure_peripheral()
            ensure_transceiver()
        elseif event == "stargate_incoming_connection"
            or event == "stargate_incoming_wormhole"
            or event == "stargate_outgoing_wormhole"
            or event == "stargate_disconnected"
            or event == "stargate_chevron_engaged"
            or event == "stargate_deconstructing_entity"
            or event == "stargate_reconstructing_entity"
            or event == "stargate_reset"
            or event == "stargate_message_received"
            or event == "transceiver_transmission_received" then
            handle_event(event, a, b, c, d, e)
        end
    end
end

local function refresh_loop()
    while state.running do
        ensure_peripheral()
        ensure_transceiver()
        refresh_gate()
        refresh_transceiver()

        if state.incoming and CONFIG.fail_closed and not state.iris_authorized then
            local pct = tonumber(state.iris_progress_pct)
            if state.iris == nil then
                state.alert = "!!! NO IRIS INSTALLED / UNSAFE INCOMING !!!"
            elseif not pct or pct < 100 then
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

    local gate_ok = ensure_peripheral()
    local transceiver_ok = ensure_transceiver()

    if gate_ok then
        refresh_gate()
        log_event("SGJ SYSTEM ONLINE: " .. tostring(state.gate_type))
    else
        log_event("NO STARGATE JOURNEY INTERFACE FOUND")
    end

    if transceiver_ok then
        refresh_transceiver()
        log_event("TRANSCEIVER READY: frequency=" .. tostring(state.transceiver_frequency or "unknown"))
    else
        log_event("NO SGJ TRANSCEIVER FOUND")
    end
end

startup()
parallel.waitForAny(security_loop, refresh_loop, audio_loop, ui_loop)

state.running = false
stop_alarm_audio()
save_data()
term.clear()
term.setCursorPos(1, 1)
print("SGJ-CC-SGC offline.")
