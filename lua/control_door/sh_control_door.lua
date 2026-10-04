CONTROL_DOOR = CONTROL_DOOR or {}
local FRAME_CLASS_PATTERN = "control_door_frame*"

--- Retourne vrai si l'entité a bien un état stable.
-- @param ent Entity : entité à vérifier.
-- @return boolean : vrai si la porte est stable.
function CONTROL_DOOR.IsStableDoor(ent)
    if not IsValid(ent) then return false end
    if not ent.GetDoorState then return false end
    return ent:GetDoorState() == CONTROL_DOOR.STATE_STABLE
end

--- Retourne vrai si l'entité est un cadre de porte (de base ou une de ses variantes).
-- @param ent Entity : entité à vérifier.
-- @return boolean : vrai si c'est un cadre de porte.
function CONTROL_DOOR.IsDoorFrame(ent)
    return IsValid(ent) and ent.IsControlDoorFrame == true
end

--- Retourne tous les cadres de porte existants dans le realm courant (toutes variantes).
-- @return table : liste d'entités cadre de porte.
function CONTROL_DOOR.FindDoorFrames()
    return ents.FindByClass(FRAME_CLASS_PATTERN)
end

--- Retourne la liste des portes stables du serveur.
-- @return table : tableau des entités stables.
function CONTROL_DOOR.GetStableDoors()
    local stable = {}

    for _, ent in ipairs(CONTROL_DOOR.FindDoorFrames()) do
        if CONTROL_DOOR.IsStableDoor(ent) then
            table.insert(stable, ent)
        end
    end

    return stable
end

--- Joue un son audible uniquement par le joueur donné.
-- @param ent Entity : entité d'ou le son est émis.
-- @param sound string : chemin du son (relatif à sound/), ignoré s'il est vide.
-- @param loop boolean : vrai si le son doit être lu en boucle.
-- @return nil
function CONTROL_DOOR.PlaySoundSelf(ent, sound, loop)
    if not isstring(sound) or sound == "" then return end

    local filter = nil
    if SERVER then
        filter = RecipientFilter()
        filter:AddPlayer(ent)
    end

    if loop then
        ent:StartLoopingSound(sound)
    else
        ent:EmitSound(sound, 0, 100, 1, CHAN_STATIC, 0, 0, filter)
    end
end