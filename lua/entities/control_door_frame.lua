AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "#control_door.entity.frame.name"
ENT.Category = "Control Door"
ENT.Spawnable = true
ENT.AdminOnly = false

--- Déclare les variables réseau de l'entité (état de la porte, synchronisé serveur → clients).
-- Génère ENT:GetDoorState() et ENT:SetDoorState(state : string).
-- @return nil
function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "DoorState")
end

--- Initialise l'entité au spawn (modèle partagé, physique et cycle côté serveur).
-- @return nil
function ENT:Initialize()
    self:SetModel(CONTROL_DOOR.FrameModel)

    if CLIENT then return end

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    self:SetDoorState(CONTROL_DOOR.STATE_UNSTABLE)
    self:StartUnstableCycle()
end

if CLIENT then return end

--- Démarre le cycle d'animation des portes qui défilent.
-- @return nil
function ENT:StartUnstableCycle()
    self:StopUnstableCycle()

    local timerName = "control_door_cycle_" .. tostring(self:EntIndex())
    self._controlDoorTimerName = timerName

    timer.Create(timerName, CONTROL_DOOR.ScrollInterval, 0, function()
        if not IsValid(self) then
            timer.Remove(timerName)
            return
        end

        if self:GetDoorState() ~= CONTROL_DOOR.STATE_UNSTABLE then return end
        self:SpawnGhostDoor()
    end)
end

--- Arrête le cycle d'animation des portes.
-- @return nil
function ENT:StopUnstableCycle()
    if self._controlDoorTimerName then
        timer.Remove(self._controlDoorTimerName)
        self._controlDoorTimerName = nil
    end
end

--- Crée une porte fantôme qui glisse vers le bas puis disparaît.
-- @return nil
function ENT:SpawnGhostDoor()
    local ghost = ents.Create("prop_dynamic_override")
    if not IsValid(ghost) then return end

    -- Positions locales au cadre : la porte fantôme est parentée, on l'anime donc en repère local.
    local startPos = CONTROL_DOOR.PortalOffset + Vector(
        math.random(CONTROL_DOOR.PortalOffsetMinDiff.x, CONTROL_DOOR.PortalOffsetMaxDiff.x),
        math.random(CONTROL_DOOR.PortalOffsetMinDiff.y, CONTROL_DOOR.PortalOffsetMaxDiff.y),
        math.random(CONTROL_DOOR.PortalOffsetMinDiff.z, CONTROL_DOOR.PortalOffsetMaxDiff.z)
    )
    local endPos = startPos + CONTROL_DOOR.DistanceScroll

    ghost:SetModel(table.Random(CONTROL_DOOR.DoorModels))
    ghost:SetPos(self:LocalToWorld(startPos))
    ghost:SetAngles(self:LocalToWorldAngles(Angle(0, 180, 0)))
    ghost:SetSolid(SOLID_NONE)
    ghost:SetMoveType(MOVETYPE_NONE)
    ghost:Spawn()
    ghost:SetParent(self)
    ghost:SetLocalPos(startPos)
    ghost:SetLocalAngles(Angle(0, 180, 0))
    ghost:SetRenderMode(RENDERMODE_TRANSALPHA)
    ghost:SetColor(Color(180, 210, 255, 230))

    local timerName = "control_door_ghost_" .. tostring(ghost:EntIndex())
    local startTime = CurTime()

    timer.Create(timerName, 0, 0, function()
        if not IsValid(ghost) then
            timer.Remove(timerName)
            return
        end

        local progress = math.min((CurTime() - startTime) / CONTROL_DOOR.ScrollDuration, 1)

        ghost:SetLocalPos(LerpVector(progress, startPos, endPos))
        ghost:SetColor(Color(180, 210, 255, 255 - math.floor(progress * 200)))

        if progress >= 1 then
            timer.Remove(timerName)
            ghost:Remove()
        end
    end)
end

--- Crée une porte stable avec un effet de portail.
-- @return nil
function ENT:CreateStableDoor()
    self:RemoveStableDoor()

    local door = ents.Create("prop_dynamic_override")
    if not IsValid(door) then return end

    door:SetModel(table.Random(CONTROL_DOOR.DoorModels))
    door:SetPos(self:LocalToWorld(CONTROL_DOOR.PortalOffset))
    door:SetAngles(self:LocalToWorldAngles(Angle(0, 180, 0)))
    door:SetSolid(SOLID_NONE)
    door:SetMoveType(MOVETYPE_NONE)
    door:Spawn()
    door:SetParent(self)
    door:SetLocalPos(CONTROL_DOOR.PortalOffset)
    door:SetLocalAngles(Angle(0, 180, 0))
    door:SetRenderMode(RENDERMODE_TRANSALPHA)
    door:SetColor(Color(140, 180, 255, 210))
    door:SetMaterial("models/screenspace")
    self.PortalDoor = door
end

--- Supprime la porte stable actuelle.
-- @return nil
function ENT:RemoveStableDoor()
    if IsValid(self.PortalDoor) then
        self.PortalDoor:Remove()
    end

    self.PortalDoor = nil
end

--- Gère l'interaction avec la porte (serveur uniquement).
-- @param activator Entity : entité qui interagit (doit être un joueur).
-- @param caller Entity : entité à l'origine de l'appel.
-- @param useType number : type d'usage (USE_*).
-- @param value number : valeur d'usage.
-- @return nil
function ENT:Use(activator, caller, useType, value)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    if self:GetDoorState() == CONTROL_DOOR.STATE_STABLE then
        CONTROL_DOOR.OpenPanelForPlayer(activator, self, "map")
    end

    if self:GetDoorState() == CONTROL_DOOR.STATE_UNSTABLE then
        self:SetDoorState(CONTROL_DOOR.STATE_STABLE)
        self:StopUnstableCycle()
        self:CreateStableDoor()
        return
    end
end

--- Supprime les objets associés à la porte lors de la suppression.
-- @return nil
function ENT:OnRemove()
    self:StopUnstableCycle()
    self:RemoveStableDoor()
end

--- Fait apparaître la porte depuis le menu Sandbox.
-- @param ply Player : joueur qui a demandé le spawn.
-- @param tr table : trace du point de spawn.
-- @param className string : classe de l'entité à créer.
-- @return Entity|nil : entité créée, nil si la trace ne touche rien.
function ENT:SpawnFunction(ply, tr, className)
    if not tr.Hit then return end

    local ent = ents.Create(className or self.ClassName)
    if not IsValid(ent) then return end

    ent:SetPos(tr.HitPos + Vector(0, 0, 24))
    ent:SetAngles(Angle(0, ply:EyeAngles().yaw, 0))
    ent:Spawn()
    ent:Activate()

    return ent
end
