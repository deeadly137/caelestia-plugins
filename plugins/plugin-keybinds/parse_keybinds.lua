#!/usr/bin/env lua

local home = os.getenv("HOME") or ""
local hypr = home .. "/.config/hypr"
local caelestia_dir = home .. "/.config/caelestia"

package.path = hypr .. "/?.lua;" .. hypr .. "/?/init.lua;" ..
               caelestia_dir .. "/?.lua;" .. caelestia_dir .. "/?/init.lua;" ..
               package.path

local binds = {}

local function normalise_key(key)
    if not key then return "" end
    return key:gsub("%s+", ""):lower()
end

-- Create a flexible metatable for auto-mocking sub-tables
local function auto_mock()
    local t = {}
    local mt = {}
    mt.__index = function(_, k)
        t[k] = auto_mock()
        return t[k]
    end
    mt.__call = function(_, ...)
        return { type = "mock", args = { ... } }
    end
    setmetatable(t, mt)
    return t
end

local recorded_dispatches = {}

local hl = {
    dsp = {
        window = {},
        workspace = {},
        group = {},
    },
    plugin = {}
}

function hl.bind(key, action, flags)
    if type(key) == "table" then
        for _, k in ipairs(key) do
            table.insert(binds, { key = k, action = action, flags = flags })
        end
    elseif key ~= nil then
        table.insert(binds, { key = key, action = action, flags = flags })
    end
end

function hl.unbind(key)
    local norm = normalise_key(key)
    for i = #binds, 1, -1 do
        if normalise_key(binds[i].key) == norm then
            table.remove(binds, i)
        end
    end
end

function hl.dsp.global(name)
    return {
        type = "global",
        name = name,
        action = "global " .. name,
        desc = name,
        lua = string.format('hl.dispatch(hl.dsp.global(%q))', name)
    }
end

function hl.dsp.exec_cmd(cmd)
    return {
        type = "exec",
        cmd = cmd,
        action = "exec " .. cmd,
        desc = cmd,
        lua = string.format('hl.dispatch(hl.dsp.exec_cmd(%q))', cmd)
    }
end

function hl.dsp.focus(opts)
    opts = opts or {}
    local arg = opts.workspace or opts.direction or ""
    local disp = opts.workspace and "workspace" or (opts.direction and "movefocus" or "focus")
    local lua_str = ""
    if opts.workspace then
        lua_str = string.format('hl.dispatch(hl.dsp.focus({ workspace = %q }))', tostring(opts.workspace))
    elseif opts.direction then
        lua_str = string.format('hl.dispatch(hl.dsp.focus({ direction = %q }))', tostring(opts.direction))
    else
        lua_str = 'hl.dispatch(hl.dsp.focus())'
    end
    return {
        type = "dispatch",
        dispatcher = disp,
        arg = arg,
        action = disp .. " " .. arg,
        desc = opts.workspace and ("Workspace " .. opts.workspace) or ("Focus " .. arg),
        lua = lua_str
    }
end

function hl.dsp.window.move(opts)
    opts = opts or {}
    local arg = opts.workspace or opts.direction or (opts.out_of_group and "outofgroup" or "")
    local disp = opts.workspace and "movetoworkspace" or (opts.direction and "movewindow" or (opts.out_of_group and "moveoutofgroup" or "move"))
    local lua_str = ""
    if opts.workspace then
        lua_str = string.format('hl.dispatch(hl.dsp.window.move({ workspace = %q }))', tostring(opts.workspace))
    elseif opts.direction then
        lua_str = string.format('hl.dispatch(hl.dsp.window.move({ direction = %q }))', tostring(opts.direction))
    elseif opts.out_of_group then
        lua_str = 'hl.dispatch(hl.dsp.window.move({ out_of_group = true }))'
    else
        lua_str = 'hl.dispatch(hl.dsp.window.move())'
    end
    return {
        type = "dispatch",
        dispatcher = disp,
        arg = arg,
        action = disp .. " " .. arg,
        desc = "Move window " .. arg,
        lua = lua_str
    }
end

function hl.dsp.window.fullscreen(opts)
    opts = opts or {}
    local mode = opts.mode == "maximized" and "1" or "0"
    local mode_name = opts.mode == "maximized" and "maximized" or "fullscreen"
    return {
        type = "dispatch",
        dispatcher = "fullscreen",
        arg = mode,
        action = "fullscreen " .. mode,
        desc = (opts.mode == "maximized" and "Bordered fullscreen" or "Fullscreen"),
        lua = string.format('hl.dispatch(hl.dsp.window.fullscreen({ mode = %q }))', mode_name)
    }
end

function hl.dsp.window.float(opts)
    return {
        type = "dispatch",
        dispatcher = "togglefloating",
        arg = "",
        action = "togglefloating",
        desc = "Toggle floating",
        lua = 'hl.dispatch(hl.dsp.window.float())'
    }
end

function hl.dsp.window.close(opts)
    return {
        type = "dispatch",
        dispatcher = "killactive",
        arg = "",
        action = "killactive",
        desc = "Close window",
        lua = 'hl.dispatch(hl.dsp.window.close())'
    }
end

function hl.dsp.window.pin(opts)
    return {
        type = "dispatch",
        dispatcher = "pin",
        arg = "",
        action = "pin",
        desc = "Pin window",
        lua = 'hl.dispatch(hl.dsp.window.pin())'
    }
end

function hl.dsp.window.center(opts)
    return {
        type = "dispatch",
        dispatcher = "centerwindow",
        arg = "",
        action = "centerwindow",
        desc = "Center window",
        lua = 'hl.dispatch(hl.dsp.window.center())'
    }
end

function hl.dsp.window.drag(opts)
    return {
        type = "dispatch",
        dispatcher = "mouse",
        arg = "272",
        action = "mouse:272",
        desc = "Move window (drag)",
        lua = 'hl.dispatch(hl.dsp.window.drag())'
    }
end

function hl.dsp.window.resize(opts)
    if opts and (opts.x or opts.y) then
        local x = opts.x or 0
        local y = opts.y or 0
        if opts.relative == false then
            return {
                type = "dispatch",
                dispatcher = "resizewindowpixel",
                arg = string.format("exact %d %d", x, y),
                action = string.format("resizewindowpixel exact %d %d", x, y),
                desc = string.format("Resize (%dx%d)", x, y),
                lua = string.format('hl.dispatch(hl.dsp.window.resize({ x = %d, y = %d, relative = false }))', x, y)
            }
        else
            return {
                type = "dispatch",
                dispatcher = "resizeactive",
                arg = string.format("%d %d", x, y),
                action = string.format("resizeactive %d %d", x, y),
                desc = string.format("Resize active (%d,%d)", x, y),
                lua = string.format('hl.dispatch(hl.dsp.window.resize({ x = %d, y = %d, relative = true }))', x, y)
            }
        end
    end
    return {
        type = "dispatch",
        dispatcher = "mouse",
        arg = "273",
        action = "mouse:273",
        desc = "Resize window (drag)",
        lua = 'hl.dispatch(hl.dsp.window.resize())'
    }
end

function hl.dsp.window.cycle_next(opts)
    opts = opts or {}
    local arg = opts.next == false and "prev" or ""
    local is_next = opts.next ~= false
    return {
        type = "dispatch",
        dispatcher = "cyclenext",
        arg = arg,
        action = "cyclenext " .. arg,
        desc = (opts.next == false and "Cycle previous window" or "Cycle next window"),
        lua = is_next and 'hl.dispatch(hl.dsp.window.cycle_next())' or 'hl.dispatch(hl.dsp.window.cycle_next({ next = false }))'
    }
end

function hl.dsp.group.next()
    return {
        type = "dispatch",
        dispatcher = "changegroupactive",
        arg = "f",
        action = "changegroupactive f",
        desc = "Next window in group",
        lua = 'hl.dispatch(hl.dsp.group.next())'
    }
end

function hl.dsp.group.prev()
    return {
        type = "dispatch",
        dispatcher = "changegroupactive",
        arg = "b",
        action = "changegroupactive b",
        desc = "Previous window in group",
        lua = 'hl.dispatch(hl.dsp.group.prev())'
    }
end

function hl.dsp.group.toggle()
    return {
        type = "dispatch",
        dispatcher = "togglegroup",
        arg = "",
        action = "togglegroup",
        desc = "Toggle group",
        lua = 'hl.dispatch(hl.dsp.group.toggle())'
    }
end

function hl.dsp.group.lock_active()
    return {
        type = "dispatch",
        dispatcher = "lockactivegroup",
        arg = "toggle",
        action = "lockactivegroup toggle",
        desc = "Lock active group",
        lua = 'hl.dispatch(hl.dsp.group.lock_active())'
    }
end

function hl.dsp.workspace.toggle_special(name)
    name = name or ""
    return {
        type = "dispatch",
        dispatcher = "togglespecialworkspace",
        arg = name,
        action = "togglespecialworkspace " .. name,
        desc = "Toggle special workspace " .. name,
        lua = string.format('hl.dispatch(hl.dsp.workspace.toggle_special(%q))', name)
    }
end

function hl.dsp.no_op()
    return { type = "noop", action = "none", desc = "No-op" }
end

function hl.get_active_workspace()
    return { id = 1, name = "1" }
end

function hl.get_active_monitor()
    return { width = 1920, height = 1080, scale = 1, x = 0, y = 0 }
end

function hl.get_active_window()
    return { address = "0x0", size = { x = 800, y = 600 }, floating = false }
end

function hl.get_windows()
    return {}
end

function hl.get_active_special_workspace()
    return nil
end

function hl.dispatch(req)
    if type(req) == "table" then
        table.insert(recorded_dispatches, req)
    end
    return req
end

function hl.exec_cmd(cmd)
    return cmd
end

function hl.on(evt, cb)
end

function hl.env(k, v)
end

function hl.config(t)
end

function hl.layer_rule(t)
end

function hl.window_rule(t)
end

function hl.workspace_rule(t)
end

function hl.monitor(t)
end

function hl.get_config(k)
    return nil
end

-- Fallback for any undefined hl functions or tables
local hl_mt = {
    __index = function(t, k)
        local sub = auto_mock()
        rawset(t, k, sub)
        return sub
    end
}
setmetatable(hl, hl_mt)
_G.hl = hl

-- Preload rich mock of utils.functions
local mock_fn = {
    wsaction = function(action, range, i)
        local is_group = (range == "group")
        local ws_target = is_group and tostring((i - 1) * 10 + 1) or tostring(i)
        return {
            _type = "fn_wsaction",
            action = (action == "move" and "movetoworkspace " or "workspace ") .. ws_target,
            desc = (action == "move" and "Move Window to Workspace " or "Go to Workspace ") .. (is_group and ("Group " .. i) or i),
            lua = string.format('require("utils.functions").wsaction(%q, %q, %d)()', action, range or "", i)
        }
    end,
    toggle = function(special_workspace)
        local friendly_names = {
            specialws = "Special Workspace",
            sysmon = "System Monitor",
            music = "Music",
            communication = "Communication",
            todo = "To-Do"
        }
        return {
            _type = "fn_toggle",
            action = "togglespecialworkspace " .. (special_workspace == "specialws" and "special" or special_workspace),
            desc = friendly_names[special_workspace] or ("Workspace: " .. special_workspace),
            lua = string.format('require("utils.functions").toggle(%q)()', special_workspace)
        }
    end,
    resize_active_window = function(x, y)
        return {
            _type = "fn_resize",
            action = string.format("resizeactive %d %d", x * 8, y * 6),
            desc = string.format("Resize Window (%d%%, %d%%)", x, y),
            lua = string.format('require("utils.functions").resize_active_window(%d, %d)()', x, y)
        }
    end,
    resize_by_screen = function(x, y) return { x = 1056, y = 756, relative = false } end,
    move_actions = function(win) return {} end,
    resizer = function() end,
}
package.preload["utils.functions"] = function()
    return mock_fn
end

-- Load variables
local vars_ok, vars = pcall(require, "variables")
if not vars_ok or type(vars) ~= "table" then
    vars = {}
end

local ok_ovr, overrides = pcall(require, "hypr-vars")
if ok_ovr and type(overrides) == "table" then
    for k, v in pairs(overrides) do
        vars[k] = v
    end
end

-- Load keybinds and user overrides
pcall(require, "hyprland.keybinds")
pcall(require, "hypr-user")

-- Key name formatting
local function format_key_name(key_str)
    if not key_str then return "" end
    local parts = {}
    for part in string.gmatch(key_str, "[^%+%s]+") do
        local lower = part:lower()
        local formatted = part
        if lower == "super" or lower == "super_l" or lower == "super_r" or lower == "win" then
            formatted = "Super"
        elseif lower == "ctrl" or lower == "control" then
            formatted = "Ctrl"
        elseif lower == "alt" then
            formatted = "Alt"
        elseif lower == "shift" then
            formatted = "Shift"
        elseif lower == "mouse:272" then
            formatted = "Mouse Left"
        elseif lower == "mouse:273" then
            formatted = "Mouse Right"
        elseif lower == "mouse_down" then
            formatted = "Scroll Down"
        elseif lower == "mouse_up" then
            formatted = "Scroll Up"
        elseif lower == "return" or lower == "enter" then
            formatted = "Enter"
        elseif lower == "space" then
            formatted = "Space"
        elseif lower == "tab" then
            formatted = "Tab"
        elseif lower == "escape" or lower == "esc" then
            formatted = "Esc"
        elseif lower == "backspace" then
            formatted = "Backspace"
        elseif lower == "delete" or lower == "del" then
            formatted = "Delete"
        elseif lower == "backslash" then
            formatted = "\\"
        elseif lower == "bracketleft" then
            formatted = "["
        elseif lower == "bracketright" then
            formatted = "]"
        elseif lower == "semicolon" then
            formatted = ";"
        elseif lower == "apostrophe" then
            formatted = "'"
        elseif lower == "grave" then
            formatted = "`"
        elseif lower == "slash" then
            formatted = "/"
        elseif lower == "period" then
            formatted = "."
        elseif lower == "comma" then
            formatted = ","
        elseif lower == "minus" then
            formatted = "-"
        elseif lower == "equal" then
            formatted = "="
        elseif lower == "xf86audiomute" then
            formatted = "Mute"
        elseif lower == "xf86audiomicmute" then
            formatted = "Mic Mute"
        elseif lower == "xf86audioraisevolume" then
            formatted = "Volume Up"
        elseif lower == "xf86audiolowervolume" then
            formatted = "Volume Down"
        elseif lower == "xf86monbrightnessup" then
            formatted = "Brightness Up"
        elseif lower == "xf86monbrightnessdown" then
            formatted = "Brightness Down"
        elseif lower == "xf86audioplay" then
            formatted = "Media Play"
        elseif lower == "xf86audiopause" then
            formatted = "Media Pause"
        elseif lower == "xf86audionext" then
            formatted = "Media Next"
        elseif lower == "xf86audioprev" then
            formatted = "Media Prev"
        elseif lower == "xf86audiostop" then
            formatted = "Media Stop"
        elseif #part == 1 then
            formatted = part:upper()
        else
            formatted = part:sub(1, 1):upper() .. part:sub(2)
        end
        
        -- Avoid adjacent duplicate modifier names (e.g. Super + Super)
        if #parts == 0 or parts[#parts] ~= formatted then
            table.insert(parts, formatted)
        end
    end
    return table.concat(parts, " + ")
end

-- Friendly description mappings
local description_mappings = {
    ["global caelestia:launcher"] = "Toggle Launcher",
    ["global caelestia:session"] = "Session Menu",
    ["global caelestia:sidebar"] = "Toggle Sidebar",
    ["global caelestia:clearNotifs"] = "Clear Notifications",
    ["global caelestia:showall"] = "Toggle All Panels",
    ["global caelestia:lock"] = "Lock Screen",
    ["global caelestia:screenshotFreeze"] = "Screenshot Freeze",
    ["global caelestia:screenshot"] = "Screenshot Region",
    ["global caelestia:mediaToggle"] = "Media: Play / Pause",
    ["global caelestia:mediaNext"] = "Media: Next Track",
    ["global caelestia:mediaPrev"] = "Media: Previous Track",
    ["global caelestia:mediaStop"] = "Media: Stop",
    ["global caelestia:brightnessUp"] = "Brightness Up",
    ["global caelestia:brightnessDown"] = "Brightness Down",
    ["exec caelestia screenshot"] = "Screenshot",
    ["exec caelestia record"] = "Record Screen",
    ["exec caelestia record -s"] = "Record Screen (Sound)",
    ["exec caelestia record -r"] = "Record Region",
    ["exec hyprpicker -a"] = "Color Picker",
    ["exec pkill fuzzel || caelestia clipboard"] = "Clipboard History",
    ["exec pkill fuzzel || caelestia clipboard -d"] = "Delete Clipboard History",
    ["exec pkill fuzzel || caelestia emoji -p"] = "Emoji Picker",
    ["killactive"] = "Close Window",
    ["togglefloating"] = "Toggle Floating",
    ["fullscreen 0"] = "Fullscreen",
    ["fullscreen 1"] = "Bordered Fullscreen",
    ["pin"] = "Pin Window",
    ["centerwindow"] = "Center Window",
    ["togglegroup"] = "Toggle Window Group",
    ["lockactivegroup toggle"] = "Lock Active Group",
    ["moveoutofgroup"] = "Ungroup Window",
    ["cyclenext"] = "Cycle Next Window",
    ["cyclenext prev"] = "Cycle Previous Window",
    ["changegroupactive f"] = "Cycle Next in Group",
    ["changegroupactive b"] = "Cycle Previous in Group",
    ["togglespecialworkspace special"] = "Special Workspace",
    ["togglespecialworkspace sysmon"] = "System Monitor",
    ["togglespecialworkspace music"] = "Music",
    ["togglespecialworkspace communication"] = "Communication",
    ["togglespecialworkspace todo"] = "To-Do",
    ["workspace +1"] = "Next Workspace",
    ["workspace -1"] = "Previous Workspace",
    ["workspace +10"] = "Next Workspace Group",
    ["workspace -10"] = "Previous Workspace Group",
    ["movetoworkspace +1"] = "Move to Next Workspace",
    ["movetoworkspace -1"] = "Move to Previous Workspace",
    ["movetoworkspace special:special"] = "Move to Special Workspace",
    ["movetoworkspace e+0"] = "Move from Special Workspace",
    ["movefocus l"] = "Focus Left",
    ["movefocus r"] = "Focus Right",
    ["movefocus u"] = "Focus Up",
    ["movefocus d"] = "Focus Down",
    ["movefocus left"] = "Focus Left",
    ["movefocus right"] = "Focus Right",
    ["movefocus up"] = "Focus Up",
    ["movefocus down"] = "Focus Down",
    ["movewindow l"] = "Move Window Left",
    ["movewindow r"] = "Move Window Right",
    ["movewindow u"] = "Move Window Up",
    ["movewindow d"] = "Move Window Down",
    ["movewindow left"] = "Move Window Left",
    ["movewindow right"] = "Move Window Right",
    ["movewindow up"] = "Move Window Up",
    ["movewindow down"] = "Move Window Down",
}

-- Check for app variables
if vars.terminal then description_mappings["exec " .. vars.terminal] = "Terminal (" .. vars.terminal .. ")" end
if vars.browser then description_mappings["exec " .. vars.browser] = "Browser (" .. vars.browser .. ")" end
if vars.editor then description_mappings["exec " .. vars.editor] = "Editor (" .. vars.editor .. ")" end
if vars.fileExplorer then description_mappings["exec " .. vars.fileExplorer] = "File Explorer (" .. vars.fileExplorer .. ")" end
if vars.audioSettings then description_mappings["exec " .. vars.audioSettings] = "Audio Settings (" .. vars.audioSettings .. ")" end

local results = {}
local seen = {}

for _, b in ipairs(binds) do
    local raw_key = b.key
    if type(raw_key) == "string" and raw_key ~= "" then
        -- Skip internal device refresh bindings (Caps_Lock / Num_Lock)
        if raw_key ~= "Caps_Lock" and raw_key ~= "Num_Lock" then
            local action_str = ""
            local desc_str = ""
            local cmd_str = nil
            local lua_str = nil
            local act = b.action

            if type(act) == "function" then
                recorded_dispatches = {}
                local ok, res = pcall(act)
                if #recorded_dispatches > 0 then
                    local actions = {}
                    local descs = {}
                    local luas = {}
                    for _, d in ipairs(recorded_dispatches) do
                        if d.action then table.insert(actions, d.action) end
                        if d.desc then table.insert(descs, d.desc) end
                        if d.lua then table.insert(luas, d.lua) end
                    end
                    action_str = table.concat(actions, "; ")
                    desc_str = table.concat(descs, " & ")
                    if #luas > 0 then
                        lua_str = table.concat(luas, "; ")
                    end
                elseif type(res) == "table" then
                    action_str = res.action or ""
                    desc_str = res.desc or res.action or ""
                    lua_str = res.lua
                    cmd_str = res.cmd
                elseif type(res) == "string" then
                    action_str = res
                    desc_str = res
                end
            elseif type(act) == "table" then
                action_str = act.action or ""
                desc_str = act.desc or act.action or ""
                lua_str = act.lua
                cmd_str = act.cmd
            elseif type(act) == "string" then
                action_str = act
                desc_str = act
            end

            -- Clean up action_str
            action_str = action_str:gsub("^%s+", ""):gsub("%s+$", "")

            if action_str ~= "" and action_str ~= "none" then
                local formatted_bind = format_key_name(raw_key)

                -- Extract direct shell command ONLY if action is purely an exec command
                if not cmd_str and action_str:sub(1, 5) == "exec " and not action_str:find(";", 1, true) then
                    cmd_str = action_str:sub(6)
                end

                -- Auto-generate lua_str for common dispatchers if missing
                if not lua_str and not cmd_str then
                    if action_str:sub(1, 7) == "global " then
                        local gname = action_str:sub(8)
                        lua_str = string.format('hl.dispatch(hl.dsp.global(%q))', gname)
                    elseif action_str == "killactive" then
                        lua_str = 'hl.dispatch(hl.dsp.window.close())'
                    elseif action_str == "togglefloating" then
                        lua_str = 'hl.dispatch(hl.dsp.window.float())'
                    elseif action_str == "pin" then
                        lua_str = 'hl.dispatch(hl.dsp.window.pin())'
                    elseif action_str == "centerwindow" then
                        lua_str = 'hl.dispatch(hl.dsp.window.center())'
                    elseif action_str == "fullscreen 0" then
                        lua_str = 'hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen" }))'
                    elseif action_str == "fullscreen 1" then
                        lua_str = 'hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized" }))'
                    elseif action_str == "togglegroup" then
                        lua_str = 'hl.dispatch(hl.dsp.group.toggle())'
                    elseif action_str == "lockactivegroup toggle" then
                        lua_str = 'hl.dispatch(hl.dsp.group.lock_active())'
                    elseif action_str == "moveoutofgroup" or action_str == "moveoutofgroup outofgroup" then
                        lua_str = 'hl.dispatch(hl.dsp.window.move({ out_of_group = true }))'
                    elseif action_str == "cyclenext" then
                        lua_str = 'hl.dispatch(hl.dsp.window.cycle_next())'
                    elseif action_str == "cyclenext prev" then
                        lua_str = 'hl.dispatch(hl.dsp.window.cycle_next({ next = false }))'
                    elseif action_str == "changegroupactive f" then
                        lua_str = 'hl.dispatch(hl.dsp.group.next())'
                    elseif action_str == "changegroupactive b" then
                        lua_str = 'hl.dispatch(hl.dsp.group.prev())'
                    else
                        local ws_num = action_str:match("^workspace (.-)$")
                        if ws_num then
                            lua_str = string.format('hl.dispatch(hl.dsp.focus({ workspace = %q }))', ws_num)
                        else
                            local mws_num = action_str:match("^movetoworkspace (.-)$")
                            if mws_num then
                                lua_str = string.format('hl.dispatch(hl.dsp.window.move({ workspace = %q }))', mws_num)
                            else
                                local fdir = action_str:match("^movefocus (.-)$")
                                if fdir then
                                    lua_str = string.format('hl.dispatch(hl.dsp.focus({ direction = %q }))', fdir)
                                else
                                    local mdir = action_str:match("^movewindow (.-)$")
                                    if mdir then
                                        lua_str = string.format('hl.dispatch(hl.dsp.window.move({ direction = %q }))', mdir)
                                    end
                                end
                            end
                        end
                    end
                end
                
                -- Check friendly description
                local friendly_desc = description_mappings[action_str]
                if not friendly_desc then
                    -- Pattern match workspaces
                    local ws_num = action_str:match("^workspace (%d+)$")
                    if ws_num then
                        friendly_desc = "Go to Workspace " .. ws_num
                    else
                        local move_ws_num = action_str:match("^movetoworkspace (%d+)$")
                        if move_ws_num then
                            friendly_desc = "Move Window to Workspace " .. move_ws_num
                        end
                    end
                end

                if not friendly_desc or friendly_desc == "" then
                    if desc_str ~= "" and desc_str ~= action_str then
                        friendly_desc = desc_str
                    else
                        if cmd_str then
                            friendly_desc = cmd_str
                        elseif action_str:sub(1, 7) == "global " then
                            friendly_desc = action_str:sub(8)
                        else
                            friendly_desc = action_str
                        end
                    end
                end

                local dedupe_key = formatted_bind .. "|||" .. action_str
                if not seen[dedupe_key] then
                    seen[dedupe_key] = true
                    table.insert(results, {
                        bind = formatted_bind,
                        action = action_str,
                        description = friendly_desc,
                        cmd = cmd_str,
                        lua = lua_str
                    })
                end
            end
        end
    end
end

-- JSON Serialization
local function escape_json_str(s)
    local escapes = {
        ["\\"] = "\\\\",
        ["\""] = "\\\"",
        ["\b"] = "\\b",
        ["\f"] = "\\f",
        ["\n"] = "\\n",
        ["\r"] = "\\r",
        ["\t"] = "\\t"
    }
    return "\"" .. tostring(s):gsub("[\\\"\b\f\n\r\t]", escapes) .. "\""
end

local function to_json(val)
    local t = type(val)
    if t == "string" then
        return escape_json_str(val)
    elseif t == "number" or t == "boolean" then
        return tostring(val)
    elseif t == "table" then
        local is_array = #val > 0 or next(val) == nil
        if is_array then
            local items = {}
            for i, v in ipairs(val) do
                table.insert(items, to_json(v))
            end
            return "[" .. table.concat(items, ",") .. "]"
        else
            local fields = {}
            for k, v in pairs(val) do
                table.insert(fields, escape_json_str(tostring(k)) .. ":" .. to_json(v))
            end
            return "{" .. table.concat(fields, ",") .. "}"
        end
    else
        return "null"
    end
end

io.stdout:write(to_json(results))
io.stdout:write("\n")
