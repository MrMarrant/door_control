if SERVER then return end

CONTROL_DOOR = CONTROL_DOOR or {}

local GHOST_LOCAL_ANGLES = Angle(0, 180, 0)
local GHOST_START_ALPHA = 255
local GHOST_ALPHA_LOSS = 200

-- Portes fantômes actives, indexées par cadre : { nextSpawn = number, ghosts = { { model, startPos, velocity, startTime } } }.
local framesGhosts = {}

--- Supprime toutes les portes fantômes d'un cadre.
-- @param frame Entity : cadre de porte (éventuellement déjà invalide).
-- @return nil
local function ClearGhosts(frame)
    local data = framesGhosts[frame]
    if not data then return end

    for _, ghost in ipairs(data.ghosts) do
        if IsValid(ghost.model) then ghost.model:Remove() end
    end

    framesGhosts[frame] = nil
end

--- Indique si un cadre doit afficher des portes fantômes pour le joueur local.
-- @param frame Entity : cadre de porte.
-- @param eyePos Vector : position des yeux du joueur local.
-- @return boolean : vrai si le cadre est instable, présent chez le client et assez proche.
local function ShouldShowGhosts(frame, eyePos)
    if not IsValid(frame) or frame:IsDormant() then return false end
    if frame:GetDoorState() ~= CONTROL_DOOR.STATE_UNSTABLE then return false end

    return eyePos:DistToSqr(frame:GetPos()) <= CONTROL_DOOR.GhostRenderDistance ^ 2
end

--- Tire une position de départ aléatoire (repère local du cadre) pour une porte fantôme.
-- @return Vector : position locale de départ.
local function RandomStartPos()
    local minDiff, maxDiff = CONTROL_DOOR.PortalOffsetMinDiff, CONTROL_DOOR.PortalOffsetMaxDiff

    return CONTROL_DOOR.PortalOffset + Vector(
        math.random(minDiff.x, maxDiff.x),
        math.random(minDiff.y, maxDiff.y),
        math.random(minDiff.z, maxDiff.z)
    )
end

--- Crée une porte fantôme locale, rattachée au cadre, qui glissera vers le bas.
-- @param frame Entity : cadre de porte instable.
-- @param data table : portes fantômes du cadre.
-- @param now number : instant courant (CurTime).
-- @return nil
local function SpawnGhost(frame, data, now)
    local model = ClientsideModel(table.Random(CONTROL_DOOR.DoorModels), RENDERGROUP_TRANSLUCENT)
    if not IsValid(model) then return end

    local startPos = RandomStartPos()
    local color = CONTROL_DOOR.GhostColor

    model:SetParent(frame)
    model:SetLocalPos(startPos)
    model:SetLocalAngles(GHOST_LOCAL_ANGLES)
    model:SetRenderMode(RENDERMODE_TRANSALPHA)
    model:SetColor(Color(color.r, color.g, color.b, GHOST_START_ALPHA))

    table.insert(data.ghosts, {
        model = model,
        startPos = startPos,
        velocity = CONTROL_DOOR.DistanceScroll:GetNormalized() * CONTROL_DOOR.GhostFallSpeed,
        startTime = now
    })
end

--- Fait glisser et s'estomper les portes fantômes d'un cadre, et supprime celles qui ont fini.
-- @param data table : portes fantômes du cadre.
-- @param now number : instant courant (CurTime).
-- @return nil
local function AnimateGhosts(data, now)
    local color = CONTROL_DOOR.GhostColor

    -- Parcours à rebours : on retire des éléments pendant la boucle.
    for i = #data.ghosts, 1, -1 do
        local ghost = data.ghosts[i]
        local elapsed = now - ghost.startTime
        local progress = math.min(elapsed / CONTROL_DOOR.ScrollDuration, 1)

        if progress >= 1 or not IsValid(ghost.model) then
            if IsValid(ghost.model) then ghost.model:Remove() end
            table.remove(data.ghosts, i)
        else
            ghost.model:SetLocalPos(ghost.startPos + ghost.velocity * elapsed)
            -- ghost.model:SetColor(Color(color.r, color.g, color.b, GHOST_START_ALPHA - math.floor(progress * GHOST_ALPHA_LOSS)))
        end
    end
end

--- Fait apparaître et anime les portes fantômes d'un cadre instable visible.
-- @param frame Entity : cadre de porte instable.
-- @param now number : instant courant (CurTime).
-- @return nil
local function UpdateFrameGhosts(frame, now)
    local data = framesGhosts[frame]
    if not data then
        data = { nextSpawn = now, ghosts = {} }
        framesGhosts[frame] = data
    end

    if now >= data.nextSpawn then
        SpawnGhost(frame, data, now)
        data.nextSpawn = now + CONTROL_DOOR.ScrollInterval
    end

    AnimateGhosts(data, now)
end

--- Met à jour, à chaque image, les portes fantômes de tous les cadres connus du client.
-- @return nil
hook.Add("Think", "control_door_ghost_doors", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local now = CurTime()
    local eyePos = ply:EyePos()
    local active = {}

    for _, frame in ipairs(CONTROL_DOOR.GetClientFrames()) do
        if ShouldShowGhosts(frame, eyePos) then
            active[frame] = true
            UpdateFrameGhosts(frame, now)
        end
    end

    -- Cadre devenu stable, hors de portée, sorti de la zone visible ou supprimé : on libère ses modèles.
    for frame in pairs(framesGhosts) do
        if not active[frame] then ClearGhosts(frame) end
    end
end)
