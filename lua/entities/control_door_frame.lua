AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "#control_door.entity.frame.name"
ENT.Category = "Control Door"
ENT.Spawnable = true
ENT.AdminOnly = false

--- Déclare les variables réseau de l'entité (synchronisées serveur → clients).
-- Génère ENT:Get/SetDoorState (string) et ENT:Get/SetPortalDoor (Entity : porte stable affichée).
-- @return nil
function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "DoorState")
    self:NetworkVar("Entity", 0, "PortalDoor")
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

-- Côté client : l'écran des portes stables est dessiné par cl_portal_view.lua,
-- et les portes fantômes de l'état instable sont créées et animées par cl_ghost_doors.lua.
if CLIENT then return end

--- Démarre l'ambiance de l'état instable (son en boucle) ; les portes fantômes sont gérées côté client.
-- @return nil
function ENT:StartUnstableCycle()
    self:StopUnstableCycle()
    CONTROL_DOOR.PlaySound(self, CONTROL_DOOR.Sounds.UnstableLoop, true)
    self._unstableLoopPlaying = true
end

--- Arrête l'ambiance de l'état instable.
-- @return nil
function ENT:StopUnstableCycle()
    if self._unstableLoopPlaying then
        self:StopSound(CONTROL_DOOR.Sounds.UnstableLoop)
        self._unstableLoopPlaying = nil
    end
end

--- Crée une porte stable avec un effet de portail.
-- @return nil
function ENT:CreateStableDoor()
    self:RemoveStableDoor()

    local door = ents.Create("prop_dynamic_override")
    if not IsValid(door) then return end

    door:SetModel("models/props_c17/door01_left.mdl")
    door:SetPos(self:LocalToWorld(CONTROL_DOOR.PortalOffset))
    door:SetAngles(self:LocalToWorldAngles(Angle(0, 180, 0)))
    door:SetSolid(SOLID_NONE)
    door:SetMoveType(MOVETYPE_NONE)
    door:Spawn()
    door:SetParent(self)
    door:SetLocalPos(CONTROL_DOOR.PortalOffset)
    door:SetLocalAngles(Angle(0, 180, 0))
    door:SetRenderMode(RENDERMODE_TRANSALPHA)
    door:SetColor(Color(199, 217, 252, 0))
    door:DrawShadow(false)
    self.PortalDoor = door
    self:SetPortalDoor(door)

    CONTROL_DOOR.PlaySound(self, CONTROL_DOOR.Sounds.StableOpen)
end

--- Supprime la porte stable actuelle.
-- @return nil
function ENT:RemoveStableDoor()
    if IsValid(self.PortalDoor) then
        self.PortalDoor:Remove()
    end

    self.PortalDoor = nil
    self:SetPortalDoor(NULL)
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
