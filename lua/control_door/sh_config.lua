CONTROL_DOOR = CONTROL_DOOR or {}

CONTROL_DOOR.STATE_UNSTABLE = "unstable"
CONTROL_DOOR.STATE_STABLE = "stable"
CONTROL_DOOR.FrameModel = "models/foundation/doors/860_doorframe.mdl"
-- Enseigne posée et centrée sur le haut du cadre (ignorée si le modèle est introuvable).
CONTROL_DOOR.ExitSignModel = "models/exit_sign/exit_sign.mdl"
-- Rotation de l'enseigne par rapport au cadre (ajuster le yaw si elle ne fait pas face à l'avant de la porte).
CONTROL_DOOR.ExitSignAngles = Angle(0, 0, 0)
CONTROL_DOOR.ExitSignOffset = Vector(1, 0, -1)  -- Décalage de l'enseigne par rapport au haut du cadre (dans le repère du cadre)
CONTROL_DOOR.DoorModels = {
    "models/props_c17/door03_left.mdl",
    "models/props_c17/door01_left.mdl",
    "models/props_doors/door03_slotted_left.mdl",
    "models/props_doors/doormain01_small.mdl",
}

-- Intervalle (en secondes) entre l'apparition de deux portes fantômes sur une porte instable.
CONTROL_DOOR.ScrollInterval = 0.1
-- Durée de vie (en secondes) d'une porte fantôme : elle chute et s'estompe pendant ce temps, puis est supprimée.
CONTROL_DOOR.ScrollDuration = 0.1
-- Vitesse de chute (en unités par seconde) d'une porte fantôme, dans la direction de DistanceScroll.
CONTROL_DOOR.GhostFallSpeed = 200
CONTROL_DOOR.MapViewFadeIn = 0.5
-- Épaisseur (en unités) ignorée sous le plafond de la map par la vue du dessus, pour passer à travers la skybox.
CONTROL_DOOR.MapViewCeilingClip = 16
-- Largeur de la liste des portes, en fraction de l'écran.
CONTROL_DOOR.MapListWidth = 0.2
-- Durée totale (en secondes) du flash de téléportation : moitié en fondu d'entrée, moitié en fondu de sortie.
CONTROL_DOOR.TeleportFlashDuration = 2
CONTROL_DOOR.TeleportFlashColor = Color(230, 240, 255, 255)
-- Caméra affichée sur la face avant d'une porte stable (rendu client).
CONTROL_DOOR.PortalCamera = {
    Distance = 150,         -- distance (unités) entre la porte et la caméra, devant la porte
    Height = 0,             -- décalage vertical de la caméra par rapport au centre de la porte
    Fov = 70,               -- champ de vision de la caméra
    Resolution = 512,       -- taille (px) de la texture de rendu, carrée
    RenderDistance = 1500,  -- au-delà de cette distance, l'écran n'est plus mis à jour
    FrameRate = 30          -- mises à jour maximales par seconde et par porte
}
-- Couleur de l'écran des portes stables (rendu client) : l'image est mélangée à cette couleur.
CONTROL_DOOR.PortalTint = {
    Color = Color(77, 238, 238),  -- Couleur de l'image
    Strength = 0.05                 -- force du mélange, de 0 (aucun effet) à 1 (couleur unie)
}
-- Effet de vague sur l'écran des portes stables (rendu client).
CONTROL_DOOR.PortalWave = {
    Amplitude = 0.005,  -- déplacement maximal de l'image, en fraction de sa taille (0 = pas de vague)
    Frequency = 3,    -- nombre d'ondulations sur la hauteur / la largeur de l'écran
    Speed = 0.5,          -- vitesse de l'ondulation
    Subdivisions = 8   -- finesse de la grille (plus élevé = vague plus douce, mais plus coûteuse)
}
CONTROL_DOOR.PortalOffset = Vector(1, 36, 5)
CONTROL_DOOR.PortalStableOffset = Vector(1, 38, 0)
CONTROL_DOOR.PortalOffsetMinDiff = Vector(0, 0, 0)
CONTROL_DOOR.PortalOffsetMaxDiff = Vector(0, 0, 0)
-- Direction de chute des portes fantômes (seule la direction compte : la distance vient de GhostFallSpeed × ScrollDuration).
CONTROL_DOOR.DistanceScroll = Vector(0, 0, -1500)
-- Portes fantômes de l'état instable (rendu client uniquement).
CONTROL_DOOR.GhostColor = Color(180, 210, 255)
CONTROL_DOOR.GhostRenderDistance = 2000
-- Échelle des modèles de portes fantômes (1 = taille d'origine).
CONTROL_DOOR.GhostModelScale = 0.9

CONTROL_DOOR.Sounds = {  -- TODO : a faire les sons
    UnstableLoop = "door_control/unstable_door.wav",
    StableOpen = "door_control/stable_door.mp3",
    Click = "door_control/pick_destination.mp3",
}
