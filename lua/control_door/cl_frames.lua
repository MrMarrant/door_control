if SERVER then return end

CONTROL_DOOR = CONTROL_DOOR or {}

local FRAME_SCAN_INTERVAL = 1

-- Cadres de porte connus du client, rafraîchis périodiquement (évite un ents.FindByClass par image).
local knownFrames = {}

--- Retourne les cadres de porte connus du client (liste rafraîchie chaque seconde, peut contenir des entités invalides).
-- @return table : liste d'entités control_door_frame.
function CONTROL_DOOR.GetClientFrames()
    return knownFrames
end

--- Rafraîchit périodiquement la liste des cadres de porte connus du client.
-- @return nil
timer.Create("control_door_frame_scan", FRAME_SCAN_INTERVAL, 0, function()
    knownFrames = CONTROL_DOOR.FindDoorFrames()
end)
