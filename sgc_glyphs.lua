-- SGJ-CC-SGC Stargate symbol reference
-- Stargate Journey's getSymbols() returns a RESOURCE LOCATION STRING,
-- not an array of glyph names. This utility therefore displays the symbol
-- resource set plus the numeric symbol IDs used by engageSymbol().

local function find_interface()
    return peripheral.find("advanced_crystal_interface")
        or peripheral.find("crystal_interface")
        or peripheral.find("basic_interface")
end

local gate = find_interface()
if not gate then
    print("No Stargate Journey interface found.")
    return
end

local symbols = gate.getSymbols()
local gate_type = gate.getStargateType and gate.getStargateType() or "unknown"
local point = gate.getPointOfOrigin and gate.getPointOfOrigin() or "unknown"
local monitor = peripheral.find("monitor")

local function draw(target)
    local old = term.redirect(target)
    target.setTextScale(0.5)
    local w, h = target.getSize()
    target.clear()
    target.setCursorPos(1, 1)
    target.write("S T A R G A T E   J O U R N E Y")
    target.setCursorPos(1, 2)
    target.write("SYMBOL RESOURCE: " .. tostring(symbols))
    target.setCursorPos(1, 3)
    target.write("GATE: " .. tostring(gate_type))
    target.setCursorPos(1, 4)
    target.write("POINT OF ORIGIN: " .. tostring(point))
    target.setCursorPos(1, 6)
    target.write("NUMERIC SYMBOLS")
    target.setCursorPos(1, 7)
    target.write("Use these IDs with engageSymbol(symbol).")
    local max_symbol = 38
    if gate_type == "sgjourney:universe_stargate" then
        max_symbol = 35
    elseif gate_type == "sgjourney:tollan_stargate"
        or gate_type == "sgjourney:pegasus_stargate" then
        max_symbol = 47
    end
    target.setCursorPos(1, 7)
    target.write("NUMERIC RANGE: 0-" .. tostring(max_symbol) .. " (0 = PoO)")
    local columns = 4
    local rows = math.max(1, h - 10)
    local per_page = columns * rows
    local page = 1
    local pages = math.max(1, math.ceil((max_symbol + 1) / per_page))
    local running = true
    while running do
        target.setCursorPos(1, 8)
        target.clearLine()
        target.write(string.format("PAGE %d/%d", page, pages))
        local first = (page - 1) * per_page
        for offset = 0, per_page - 1 do
            local id = first + offset
            if id > max_symbol then break end
            local col = math.floor(offset / rows)
            local row = offset % rows
            target.setCursorPos(2 + col * math.floor(w / columns), 9 + row)
            target.write(string.format("[%02d]", id))
        end
        target.setCursorPos(1, h - 1)
        target.write("LEFT/RIGHT PAGE    B/Q EXIT")
        local _, key = os.pullEvent("key")
        if key == keys.left then page = math.max(1, page - 1)
        elseif key == keys.right then page = math.min(pages, page + 1)
        elseif key == keys.b or key == keys.q then running = false end
    end
    term.redirect(old)
end

if monitor then
    draw(monitor)
else
    print("Symbol resource: " .. tostring(symbols))
    print("Gate: " .. tostring(gate_type))
    print("Point of Origin: " .. tostring(point))
    print("Supported numeric symbol IDs: 0-" .. tostring(gate_type == "sgjourney:universe_stargate" and 35 or 38) .. " (0 = Point of Origin)")
end
