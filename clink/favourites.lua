if not clink or not clink.popuplist then
    return
end

local favourites_path = (os.getenv("USERPROFILE") or (os.getenv("HOMEDRIVE") or "") .. (os.getenv("HOMEPATH") or "")) .. "\\AppData\\Local\\clink\\favourites.txt"

local function maybe_add(name, default_key, short_desc, long_desc)
    if type(name) ~= "string" then
        return
    end

    local current = settings.get(name)
    local key = current or default_key

    local entry = {
        key = key,
        short_description = short_desc,
        long_description = long_desc,
    }

    if current == nil then
        settings.add(name, key, short_desc, long_desc)
    end

    return entry
end

local function trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function make_list_name(index)
    return "Favourites #" .. tostring(index)
end

local function list_names_and_values()
    local order = {}
    local lists = {}
    local file = io.open(favourites_path, "r")

    if file then
        local current = nil
        for raw_line in file:lines() do
            local line = trim(raw_line)
            if line ~= "" and line:sub(1, 1) ~= "#" then
                local section = line:match("^%[([^%]]+)%]$")
                if section then
                    current = trim(section)
                    if current ~= "" then
                        if not lists[current] then
                            lists[current] = {}
                            table.insert(order, current)
                        end
                    end
                elseif current then
                    local value = trim(line)
                    if value ~= "" then
                        local exists = false
                        for _, existing in ipairs(lists[current]) do
                            if existing == value then
                                exists = true
                                break
                            end
                        end
                        if not exists then
                            table.insert(lists[current], value)
                        end
                    end
                end
            end
        end
        file:close()
    end

    if #order == 0 then
        table.insert(order, make_list_name(1))
        lists[make_list_name(1)] = { }
    end

    return order, lists
end

local function save_lists(order, lists)
    local file = io.open(favourites_path, "w")
    if not file then
        return false
    end

    local names = order or {}
    if #names == 0 then
        for name in pairs(lists) do
            table.insert(names, name)
        end
    end

    for _, name in ipairs(names) do
        local values = lists[name] or {}
        file:write("[" .. name .. "]\n")
        for _, value in ipairs(values) do
            file:write(value .. "\n")
        end
        file:write("\n")
    end

    file:close()
    return true
end

local function get_current_dir()
    local dir = os.getcwd and os.getcwd() or os.getenv("CD")
    if not dir or dir == "" then
        dir = os.getenv("CD") or ""
    end
    return dir
end

local function list_number(name)
    if type(name) ~= "string" then
        return nil
    end

    local n = name:match("^Favourites #%s*(%d+)$")
    if n then
        return tonumber(n)
    end

    return nil
end

local function find_list_by_number(order, index)
    if not index then
        return nil
    end

    for _, name in ipairs(order) do
        if list_number(name) == index then
            return name
        end
    end

    return nil
end

local function ensure_list(order, lists, name)
    if not name or name == "" then
        return
    end

    if not lists[name] then
        lists[name] = {}
    end

    local found = false
    for _, existing in ipairs(order) do
        if existing == name then
            found = true
            break
        end
    end

    if not found then
        table.insert(order, name)
    end
end

local function add_value_to_favourites(index, value)
    local text = trim(value)
    if text == "" then
        return false
    end

    local order, lists = list_names_and_values()
    local idx = tonumber(index)
    local name = nil

    if idx and idx >= 1 then
        name = find_list_by_number(order, idx) or make_list_name(idx)
    else
        name = order[1] or make_list_name(1)
    end

    ensure_list(order, lists, name)

    for _, existing in ipairs(lists[name]) do
        if existing == text then
            return true
        end
    end

    table.insert(lists[name], text)
    return save_lists(order, lists)
end

local function add_cmd_to_favourites(index, rl_buffer)
    local input = ""

    if rl_buffer then
        input = rl_buffer:getbuffer() or ""
    end

    return add_value_to_favourites(index, input)
end

local function add_current_to_favourites(index)
    local dir = get_current_dir()
    if not dir or dir == "" then
        return false
    end

    return add_value_to_favourites(index, dir)
end

local function get_all_favourite_values()
    local order, lists = list_names_and_values()
    local values = {}

    for _, name in ipairs(order) do
        local list = lists[name] or {}
        for _, value in ipairs(list) do
            if type(value) == "string" and trim(value) ~= "" then
                table.insert(values, value)
            end
        end
    end

    return values
end

local current_input_word = ""

local function get_current_input_word(line)
    local text = line or ""
    local word = text:match("([^%s]+)$") or ""
    if word == "" then
        return ""
    end
    return word
end

local function update_current_input_word(line)
    current_input_word = get_current_input_word(line)
end

if clink.oninputlinechanged then
    clink.oninputlinechanged(update_current_input_word)
end

local function favourite_matches(value, prefix)
    if type(value) ~= "string" then
        return false
    end

    local pattern = trim(prefix or "")
    if pattern == "" then
        return true
    end

    return value:lower():find(pattern:lower(), 1, true) ~= nil
end

local function favourites_completion_matches(line_state)
    local current = ""
    if line_state and line_state.getendword then
        current = line_state:getendword() or ""
    elseif current_input_word and current_input_word ~= "" then
        current = current_input_word
    end

    local prefix = trim(current):lower()
    local matches = {}

    for _, value in ipairs(get_all_favourite_values()) do
        if favourite_matches(value, prefix) then
            table.insert(matches, value)
        end
    end

    return matches
end

local function add_favourite_matches(match_builder, word)
    local prefix = trim(word or current_input_word or "")
    local count = 0
    for _, value in ipairs(get_all_favourite_values()) do
        if favourite_matches(value, prefix) then
            if match_builder then
                match_builder:addmatch(value, "word")
            else
                clink.add_match(value)
            end
            count = count + 1
        end
    end
    return count > 0
end

local favourites_generator = clink.generator(100)
function favourites_generator:generate(line_state, match_builder)
    if not line_state then
        return false
    end

    local word = line_state:getendword() or current_input_word or ""
    return add_favourite_matches(match_builder, word)
end

if clink.onfiltermatches then
    clink.onfiltermatches(function(matches)
        local prefix = trim(current_input_word or ""):lower()
        if not matches or #matches == 0 then
            if prefix == "" then
                return matches
            end
            matches = {}
        end

        local seen = {}
        for _, match in ipairs(matches) do
            local key = type(match) == "table" and (match.match or "") or tostring(match)
            seen[key] = true
        end

        for _, value in ipairs(get_all_favourite_values()) do
            if favourite_matches(value, prefix) then
                local key = value
                if not seen[key] then
                    table.insert(matches, { match = value, type = "word" })
                    seen[key] = true
                end
            end
        end

        return matches
    end)
end

if clink.register_match_generator then
    local function legacy_favourites_match_generator(text, first, last)
        if type(text) ~= "string" then
            return false
        end

        return add_favourite_matches(nil, text)
    end

    clink.register_match_generator(legacy_favourites_match_generator, 100)
end

local favourites_suggester = clink.suggester("favourites")
function favourites_suggester:suggest(line_state, matches)
    if not line_state then
        return nil
    end

    local line = line_state:getline() or ""
    local cursor = line_state:getcursor() or #line
    local before_cursor = line:sub(1, cursor)
    local prefix = before_cursor:match("([^%s]+)$") or ""
    if prefix == "" then
        return nil
    end

    local lower_prefix = prefix:lower()
    local best_suffix = nil
    for _, value in ipairs(get_all_favourite_values()) do
        local lower_value = value:lower()
        if lower_value:sub(1, #lower_prefix) == lower_prefix then
            local suffix = value:sub(#prefix + 1)
            if not best_suffix or #suffix < #best_suffix then
                best_suffix = suffix
            end
        end
    end

    return best_suffix or nil
end

local function show_list_by_index(index, rl_buffer)
    local order, lists = list_names_and_values()
    local idx = tonumber(index)
    local list_name = nil

    if idx and idx >= 1 then
        list_name = find_list_by_number(order, idx) or make_list_name(idx)
    elseif type(index) == "string" and trim(index) ~= "" then
        list_name = trim(index)
    else
        list_name = order[1] or make_list_name(1)
    end

    if not lists[list_name] then
        lists[list_name] = {}
    end

    local found = false
    for _, existing in ipairs(order) do
        if existing == list_name then
            found = true
            break
        end
    end
    if not found then
        table.insert(order, list_name)
    end

    local items = lists[list_name] or {}

    -- clink.popuplist does not open a popup with zero items, so give it a
    -- sentinel blank entry when the list is empty and ignore that blank selection.
    if #items == 0 then
        items = { "" }
    end

    local update = false
    local function del_callback(item_index)
        if item_index and item_index >= 1 and item_index <= #items then
            local selected = items[item_index]
            if selected == "" then
                return false
            end
            table.remove(items, item_index)
            lists[list_name] = items
            save_lists(order, lists)
            update = true
            return true
        end
        return false
    end

    local value = clink.popuplist(list_name, items, #items, del_callback)
    if update then
        return
    end

    if not value or value == "" then
        return
    end

    if rl_buffer then
        local current = rl_buffer:getbuffer()
        local cursor = rl_buffer:getcursor()

        rl_buffer:beginundogroup()
        rl_buffer:remove(1, -1)
        rl_buffer:setcursor(1)
        rl_buffer:insert(current:sub(1, math.max(0, cursor - 1)) .. value .. " " .. current:sub(math.max(1, cursor)))
        rl_buffer:setcursor(math.min(#current + #value + 1, #current + #value + 1))
        rl_buffer:endundogroup()
        rl_buffer:refreshline()
    end
end

-- Setup the keys
local binding_defs = {
    -- Ctrl 1-9
    {
        name = 'favourites.show_list_1',
        default_key = [[\e[27;5;49~]],
        short_description = 'Hotkey to show favourites list 1',
        long_description = [[The hotkey to show favourites list 1]],
        handler = function(rl_buffer)
            return show_list_by_index(1, rl_buffer)
        end,
    },
    {
        name = 'favourites.show_list_2',
        default_key = [[\C-@]],
        short_description = 'Hotkey to show favourites list 2',
        long_description = [[The hotkey to show favourites list 2]],
        handler = function(rl_buffer)
            return show_list_by_index(2, rl_buffer)
        end,
    },
    {
        name = 'favourites.show_list_3',
        default_key = [[\e[27;5;51~]],
        short_description = 'Hotkey to show favourites list 3',
        long_description = [[The hotkey to show favourites list 3]],
        handler = function(rl_buffer)
            return show_list_by_index(3, rl_buffer)
        end,
    },
    {
        name = 'favourites.show_list_4',
        default_key = [[\e[27;5;52~]],
        short_description = 'Hotkey to show favourites list 4',
        long_description = [[The hotkey to show favourites list 4]],
        handler = function(rl_buffer)
            return show_list_by_index(4, rl_buffer)
        end,
    },
    {
        name = 'favourites.show_list_5',
        default_key = [[\e[27;5;53~]],
        short_description = 'Hotkey to show favourites list 5',
        long_description = [[The hotkey to show favourites list 5]],
        handler = function(rl_buffer)
            return show_list_by_index(5, rl_buffer)
        end,
    },
    {
        name = 'favourites.show_list_6',
        default_key = [[\C-^]],
        short_description = 'Hotkey to show favourites list 6',
        long_description = [[The hotkey to show favourites list 6]],
        handler = function(rl_buffer)
            return show_list_by_index(6, rl_buffer)
        end,
    },
    {
        name = 'favourites.show_list_7',
        default_key = [[\e[27;5;55~]],
        short_description = 'Hotkey to show favourites list 7',
        long_description = [[The hotkey to show favourites list 7]],
        handler = function(rl_buffer)
            return show_list_by_index(7, rl_buffer)
        end,
    },
    {
        name = 'favourites.show_list_8',
        default_key = [[\e[27;5;56~]],
        short_description = 'Hotkey to show favourites list 8',
        long_description = [[The hotkey to show favourites list 8]],
        handler = function(rl_buffer)
            return show_list_by_index(8, rl_buffer)
        end,
    },
    {
        name = 'favourites.show_list_9',
        default_key = [[\e[27;5;57~]],
        short_description = 'Hotkey to show favourites list 9',
        long_description = [[The hotkey to show favourites list 9]],
        handler = function(rl_buffer)
            return show_list_by_index(9, rl_buffer)
        end,
    },

    -- Left alt+Shift+1-9
    {
        name = 'favourites.add_list_1',
        default_key = [[\e!]],
        short_description = 'Hotkey to add current folder to favourites list 1',
        long_description = [[The hotkey to add the current folder to favourites list 1]],
        handler = function(rl_buffer)
            return add_current_to_favourites(1)
        end,
    },
    {
        name = 'favourites.add_list_2',
        default_key = [[\e"]],
        short_description = 'Hotkey to add current folder to favourites list 2',
        long_description = [[The hotkey to add the current folder to favourites list 2]],
        handler = function(rl_buffer)
            return add_current_to_favourites(2)
        end,
    },
    {
        name = 'favourites.add_list_3',
        default_key = [[\e\xc2\xa3]],
        short_description = 'Hotkey to add current folder to favourites list 3',
        long_description = [[The hotkey to add the current folder to favourites list 3]],
        handler = function(rl_buffer)
            return add_current_to_favourites(3)
        end,
    },
    {
        name = 'favourites.add_list_4',
        default_key = [[\e$]],
        short_description = 'Hotkey to add current folder to favourites list 4',
        long_description = [[The hotkey to add the current folder to favourites list 4]],
        handler = function(rl_buffer)
            return add_current_to_favourites(4)
        end,
    },
    {
        name = 'favourites.add_list_5',
        default_key = [[\e%]],
        short_description = 'Hotkey to add current folder to favourites list 5',
        long_description = [[The hotkey to add the current folder to favourites list 5]],
        handler = function(rl_buffer)
            return add_current_to_favourites(5)
        end,
    },
    {
        name = 'favourites.add_list_6',
        default_key = [[\e^]],
        short_description = 'Hotkey to add current folder to favourites list 6',
        long_description = [[The hotkey to add the current folder to favourites list 6]],
        handler = function(rl_buffer)
            return add_current_to_favourites(6)
        end,
    },
    {
        name = 'favourites.add_list_7',
        default_key = [[\e&]],
        short_description = 'Hotkey to add current folder to favourites list 7',
        long_description = [[The hotkey to add the current folder to favourites list 7]],
        handler = function(rl_buffer)
            return add_current_to_favourites(7)
        end,
    },
    {
        name = 'favourites.add_list_8',
        default_key = [[\e*]],
        short_description = 'Hotkey to add current folder to favourites list 8',
        long_description = [[The hotkey to add the current folder to favourites list 8]],
        handler = function(rl_buffer)
            return add_current_to_favourites(8)
        end,
    },
    {
        name = 'favourites.add_list_9',
        default_key = [[\e(]],
        short_description = 'Hotkey to add current folder to favourites list 9',
        long_description = [[The hotkey to add the current folder to favourites list 9]],
        handler = function(rl_buffer)
            return add_current_to_favourites(9)
        end,
    },

    -- Right Alt+Shift+1 to 9
    {
        name = 'favourites.add_cmd_list_1',
        default_key = [[\e[27;8;49~]],
        short_description = 'Hotkey to add command to favourites list 1',
        long_description = [[Hotkey to add command to favourites list 1]],
        handler = function(rl_buffer)
            return add_cmd_to_favourites(1, rl_buffer)
        end,
    },
    {
        name = 'favourites.add_cmd_list_2',
        default_key = [[\e\C-@]],
        short_description = 'Hotkey to add command to favourites list 2',
        long_description = [[Hotkey to add command to favourites list 2]],
        handler = function(rl_buffer)
            return add_cmd_to_favourites(2, rl_buffer)
        end,
    },
    {
        name = 'favourites.add_cmd_list_3',
        default_key = [[\e[27;8;51~]],
        short_description = 'Hotkey to add command to favourites list 3',
        long_description = [[Hotkey to add command to favourites list 3]],
        handler = function(rl_buffer)
            return add_cmd_to_favourites(3, rl_buffer)
        end,
    },
    {
        name = 'favourites.add_cmd_list_4',
        default_key = [[\e[27;8;52~]],
        short_description = 'Hotkey to add command to favourites list 4',
        long_description = [[Hotkey to add command to favourites list 4]],
        handler = function(rl_buffer)
            return add_cmd_to_favourites(4, rl_buffer)
        end,
    },
    {
        name = 'favourites.add_cmd_list_5',
        default_key = [[\e[27;8;53~]],
        short_description = 'Hotkey to add command to favourites list 5',
        long_description = [[Hotkey to add command to favourites list 5]],
        handler = function(rl_buffer)
            return add_cmd_to_favourites(5, rl_buffer)
        end,
    },
    {
        name = 'favourites.add_cmd_list_6',
        default_key = [[\e\C-^]],
        short_description = 'Hotkey to add command to favourites list 6',
        long_description = [[Hotkey to add command to favourites list 6]],
        handler = function(rl_buffer)
            return add_cmd_to_favourites(6, rl_buffer)
        end,
    },
    {
        name = 'favourites.add_cmd_list_7',
        default_key = [[\e[27;8;55~]],
        short_description = 'Hotkey to add command to favourites list 7',
        long_description = [[Hotkey to add command to favourites list 7]],
        handler = function(rl_buffer)
            return add_cmd_to_favourites(7, rl_buffer)
        end,
    },
    {
        name = 'favourites.add_cmd_list_8',
        default_key = [[\e[27;8;56~]],
        short_description = 'Hotkey to add command to favourites list 8',
        long_description = [[Hotkey to add command to favourites list 8]],
        handler = function(rl_buffer)
            return add_cmd_to_favourites(8, rl_buffer)
        end,
    },
    {
        name = 'favourites.add_cmd_list_9',
        default_key = [[\e[27;8;57~]],
        short_description = 'Hotkey to add command to favourites list 9',
        long_description = [[Hotkey to add command to favourites list 9]],
        handler = function(rl_buffer)
            return add_cmd_to_favourites(9, rl_buffer)
        end,
    }
}


-- Bind the keys
for _, def in ipairs(binding_defs) do
    local entry = maybe_add(def.name, def.default_key, def.short_description, def.long_description)
    if entry then
        def.key = entry.key
        def.lua_func = [["luafunc:]] .. def.name:gsub("%.", "_") .. [["]]
    end
end

if rl.getbinding then
    for _, def in ipairs(binding_defs) do
        local fn_name = def.name:gsub("%.", "_")

        if def.key then
            rl.setbinding(def.key, def.lua_func)
        end
        if def.short_description then
            rl.describemacro(def.lua_func, def.short_description)
        end

        _G[fn_name] = def.handler
    end
end
