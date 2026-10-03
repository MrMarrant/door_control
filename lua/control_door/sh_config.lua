CONTROL_DOOR = CONTROL_DOOR or {}

CONTROL_DOOR.STATE_UNSTABLE = "unstable"
CONTROL_DOOR.STATE_STABLE = "stable"
CONTROL_DOOR.FrameModel = "models/foundation/doors/860_doorframe.mdl"
CONTROL_DOOR.DoorModels = {
    "models/props_c17/door03_left.mdl",
    "models/props_c17/door01_left.mdl",
    "models/props_doors/door03_slotted_left.mdl",
    "models/props_doors/doormain01_small.mdl",
}

CONTROL_DOOR.ScrollInterval = 0.1
CONTROL_DOOR.ScrollDuration = 1.5
CONTROL_DOOR.FadeDuration = 0.4
CONTROL_DOOR.MapViewFadeIn = 0.5
-- Épaisseur (en unités) ignorée sous le plafond de la map par la vue du dessus, pour passer à travers la skybox.
CONTROL_DOOR.MapViewCeilingClip = 16
-- Largeur de la liste des portes, en fraction de l'écran.
CONTROL_DOOR.MapListWidth = 0.2
-- Durée totale (en secondes) du flash de téléportation : moitié en fondu d'entrée, moitié en fondu de sortie.
CONTROL_DOOR.TeleportFlashDuration = 2
CONTROL_DOOR.TeleportFlashColor = Color(230, 240, 255, 255)
CONTROL_DOOR.PortalOffset = Vector(1, 38, 0)
CONTROL_DOOR.PortalOffsetMinDiff = Vector(0, -5, 5)
CONTROL_DOOR.PortalOffsetMaxDiff = Vector(0, 5, 5)
CONTROL_DOOR.DistanceScroll = Vector(0, 0, -1500)

CONTROL_DOOR.Sounds = {  -- TODO : a faire les sons
    UnstableLoop = "control_door/unstable_loop.wav",
    Teleport = "control_door/teleport.wav",
    StableOpen = "control_door/stable_open.wav",
    Click = "buttons/button14.wav",
}
