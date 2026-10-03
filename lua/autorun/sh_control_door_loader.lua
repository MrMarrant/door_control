CONTROL_DOOR = CONTROL_DOOR or {}

local ROOT = "control_door/"

local function LoadFile(path)
    local prefix = string.GetFileFromFilename(path):sub(1, 3)

    if prefix == "sv_" then
        if SERVER then include(path) end
    elseif prefix == "cl_" then
        if SERVER then AddCSLuaFile(path) else include(path) end
    elseif prefix == "sh_" then
        if SERVER then AddCSLuaFile(path) end
        include(path)
    end
end

LoadFile(ROOT .. "sh_config.lua")
LoadFile(ROOT .. "sh_control_door.lua")
LoadFile(ROOT .. "sv_control_door.lua")
LoadFile(ROOT .. "cl_ui.lua")
LoadFile(ROOT .. "cl_frames.lua")
LoadFile(ROOT .. "cl_portal_view.lua")
LoadFile(ROOT .. "cl_ghost_doors.lua")
LoadFile(ROOT .. "cl_control_door.lua")
