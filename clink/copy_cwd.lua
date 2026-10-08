if not clink or not clink.popuplist then
    return
end

function cpwd(rl_buffer)
    os.execute('cmd /c "echo %CD%| clip"')
end

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

-- Setup the keys
local binding_defs = {
    {
        name = 'copy_cwd.hotkey',
        default_key =  [[\e[27;6;67~]], -- ctrl+shift+c
        short_description = 'Copy the current working directory',
        long_description = [[Hotkey to copy the current working directory to the clipboard]],
        handler = function(rl_buffer)
            return cpwd(rl_buffer)
        end,
    },
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
