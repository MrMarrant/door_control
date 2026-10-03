if not SERVER then return end

util.AddNetworkString("control_door_open_panel")
util.AddNetworkString("control_door_list")
util.AddNetworkString("control_door_select")

local MAX_LISTED_DOORS = 255
local MAX_USE_DISTANCE_SQR = 200 * 200
local SELECT_COOLDOWN = 1

-- Porte depuis laquelle chaque joueur a ouvert la carte (clés faibles : nettoyé à la déconnexion).
local openedFrom = setmetatable({}, { __mode = "k" })
-- Dernière sélection traitée par joueur, pour limiter le débit.
local lastSelect = setmetatable({}, { __mode = "k" })

--- Envoie la liste des portes stables à un joueur.
-- @param ply Player : joueur destinataire.
-- @return nil
local function SendStableList(ply)
    local doors = CONTROL_DOOR.GetStableDoors()
    local count = math.min(#doors, MAX_LISTED_DOORS)

    net.Start("control_door_list")
        net.WriteUInt(count, 8)
        for i = 1, count do
            net.WriteUInt(doors[i]:EntIndex(), 16)
            net.WriteVector(doors[i]:GetPos())
        end
    net.Send(ply)
end

--- Indique si le joueur a ouvert la carte depuis une porte stable toujours à portée.
-- @param ply Player : joueur à vérifier.
-- @return Entity|nil : porte d'origine si la session est valide, nil sinon.
local function GetValidSource(ply)
    local source = openedFrom[ply]
    if not CONTROL_DOOR.IsStableDoor(source) then return nil end
    if ply:GetPos():DistToSqr(source:GetPos()) > MAX_USE_DISTANCE_SQR then return nil end

    return source
end

--- Téléporte le joueur devant la porte cible.
-- @param ply Player : joueur à téléporter.
-- @param target Entity : porte stable de destination.
-- @return nil
local function TeleportToDoor(ply, target)
    if ply:InVehicle() then ply:ExitVehicle() end

    local targetPos = target:GetPos() + target:GetForward() * 95 + Vector(0, 0, 18)
    local targetAng = (target:GetPos() - targetPos):Angle()

    ply:SetPos(targetPos)
    ply:SetEyeAngles(Angle(targetAng.p, targetAng.y, 0))
end

--- Réception de la sélection d'une porte stable par un joueur.
-- @param len number : longueur du message en bits.
-- @param ply Player : joueur qui a sélectionné une entrée.
-- @return nil
net.Receive("control_door_select", function(len, ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local now = CurTime()
    if lastSelect[ply] and now - lastSelect[ply] < SELECT_COOLDOWN then return end
    lastSelect[ply] = now

    local source = GetValidSource(ply)
    if not source then return end

    local target = Entity(net.ReadUInt(16))
    if target == source or not IsValid(target) then return end
    if target:GetClass() ~= "control_door_frame" or not CONTROL_DOOR.IsStableDoor(target) then return end

    openedFrom[ply] = nil
    TeleportToDoor(ply, target)

    net.Start("control_door_open_panel")
        net.WriteString("close")
    net.Send(ply)
end)

--- Crée une porte de démonstration au point visé par le joueur.
-- @param ply Player : joueur qui demande la création.
-- @param trace table : trace de pointage (TraceResult).
-- @return nil
local function SpawnTestDoor(ply, trace)
    local ent = ents.Create("control_door_frame")
    if not IsValid(ent) then return end

    ent:SetPos(trace.HitPos + Vector(0, 0, 24))
    ent:SetAngles(Angle(0, ply:EyeAngles().yaw, 0))
    ent:Spawn()
    ent:Activate()
end

--- Commande de test réservée aux superadmins : fait apparaître une porte.
-- @param ply Player : joueur qui exécute la commande.
-- @return nil
concommand.Add("control_door_spawn", function(ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end

    SpawnTestDoor(ply, ply:GetEyeTrace())
end)

--- Ouvre une interface de portail pour un joueur.
-- @param ply Player : joueur qui interagit.
-- @param ent Entity : porte concernée.
-- @param kind string : type d'interface à ouvrir ("mirror" ou "map").
-- @return nil
function CONTROL_DOOR.OpenPanelForPlayer(ply, ent, kind)
    if not IsValid(ply) or not IsValid(ent) then return end
    if kind ~= "mirror" and kind ~= "map" then return end

    openedFrom[ply] = kind == "map" and ent or nil

    net.Start("control_door_open_panel")
        net.WriteString(kind)
    net.Send(ply)

    if kind == "map" then
        SendStableList(ply)
    end
end
