CONTROL_DOOR = CONTROL_DOOR or {}

--- Retourne vrai si l'entité a bien un état stable.
-- @param ent Entity : entité à vérifier.
-- @return boolean : vrai si la porte est stable.
function CONTROL_DOOR.IsStableDoor(ent)
    if not IsValid(ent) then return false end
    if not ent.GetDoorState then return false end
    return ent:GetDoorState() == CONTROL_DOOR.STATE_STABLE
end

--- Retourne la liste des portes stables du serveur.
-- @return table : tableau des entités stables.
function CONTROL_DOOR.GetStableDoors()
    local stable = {}

    for _, ent in ipairs(ents.FindByClass("control_door_frame")) do
        if CONTROL_DOOR.IsStableDoor(ent) then
            table.insert(stable, ent)
        end
    end

    return stable
end
