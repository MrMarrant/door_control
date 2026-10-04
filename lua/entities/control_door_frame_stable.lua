AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "control_door_frame"
ENT.PrintName = "#control_door.entity.frame.stable.name"
ENT.Category = "Control"
ENT.Spawnable = true
ENT.AdminOnly = false

if CLIENT then return end

--- Place la porte directement dans l'état stable, avec sa porte fixe.
-- @return nil
function ENT:ApplyInitialState()
    self:SetDoorState(CONTROL_DOOR.STATE_STABLE)
    self:CreateStableDoor()
end
