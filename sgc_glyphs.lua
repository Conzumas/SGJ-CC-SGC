-- SGJ-CC-SGC Stargate symbol reference
-- Run on a second CC computer with a monitor on the same wired network.
-- This version reads Stargate Journey's numeric symbol list through
-- getSymbols() / getMappedSymbol() where available.

local function find_interface()
    for _, name in ipairs(peripheral.getNames()) do
        local p = peripheral.wrap(name)
        if p and p.getSymbols then
            return p
        end
    end
    return nil
end

local function get_symbols(gate)
    local ok, symbols = pcall(gate.getSymbols, gate)
    if not ok then return nil end
    return symbols
end

local function draw(monitor, symbols, page)
    local old = term.redirect(monitor)
    monitor.setTextScale(0.5)
    local width, height = monitor.getSize()
    local columns = 3
    local first_row = 6
    local footer = 3
    local rows = math.max(1, height - first_row - footer + 1)
    local column_width = math.max(1, math.floor(width / columns))
    local per_page = rows * columns
    local pages = math.max(1, math.ceil(#symbols / per_page))
    page = math.max(1, math.min(page, pages))

    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.write("S T A R G A T E   J O U R N E Y   G L Y P H S")
    monitor.setCursorPos(1, 2)
    monitor.write("================================================")
    monitor.setCursorPos(1, 3)
    monitor.write("NUMERIC SYMBOL INDEX")
    monitor.setCursorPos(1, 4)
    monitor.write(string.format("PAGE %d / %d    %d SYMBOLS", page, pages, #symbols))

    local first = (page - 1) * per_page + 1
    for offset = 0, per_page - 1 do
        local index = first + offset
        if index > #symbols then break end
        local col = math.floor(offset / rows)
        local row = offset % rows
        monitor.setCursorPos(2 + col * column_width, first_row + row)
        monitor.write(string.format("[%02d] %s", index, tostring(symbols[index])))
    end

    monitor.setCursorPos(1, height - 2)
    monitor.write("LEFT/RIGHT PAGE    B/Q EXIT")
    monitor.setCursorPos(1, height - 1)
    monitor.write("SGJ SYMBOLS ARE NUMERIC INDICES")
    monitor.setCursorPos(1, height)
    monitor.write("SGJ-CC-SGC | GLYPH REFERENCE")
    term.redirect(old)
    return pages
end

local gate = find_interface()
if not gate then print("No Stargate Journey interface found."); return end
local symbols = get_symbols(gate)
if type(symbols) ~= "table" then print("This interface does not expose getSymbols()."); return end
local monitor = peripheral.find("monitor")
if not monitor then print("No monitor found."); return end

local page = 1
while true do
    local pages = draw(monitor, symbols, page)
    local _, key = os.pullEvent("key")
    if key == keys.left then page = math.max(1, page - 1)
    elseif key == keys.right then page = math.min(pages, page + 1)
    elseif key == keys.b or key == keys.q then break end
end
term.redirect(term.native())
