if SERVER then return end

CONTROL_DOOR = CONTROL_DOOR or {}

-- Décalage (unités) de l'écran devant la face de la porte, pour éviter le z-fighting.
local SCREEN_SURFACE_OFFSET = -5

-- Faces de la porte : 1 = avant (côté du forward du cadre), -1 = arrière.
local SIDE_FRONT = 1
local SIDE_BACK = -1
local SIDES = { SIDE_FRONT, SIDE_BACK }
local SIDE_NAMES = { [SIDE_FRONT] = "front", [SIDE_BACK] = "back" }

-- Render target et matériau de chaque face de chaque cadre, indexés par EntIndex puis par face.
local portalViews = {}
-- Vrai pendant le rendu d'une caméra : empêche un écran de s'afficher dans sa propre texture.
local isRenderingPortal = false

--- Retourne la vue déjà créée pour une face d'un cadre, sans en créer.
-- @param frame Entity : cadre de porte (control_door_frame).
-- @param side number : face de la porte (SIDE_FRONT ou SIDE_BACK).
-- @return table|nil : vue de la face, nil si elle n'a jamais été rendue.
local function FindPortalView(frame, side)
    local views = portalViews[frame:EntIndex()]
    return views and views[side]
end

--- Retourne (et crée au besoin) la render target et le matériau associés à une face d'un cadre.
-- @param frame Entity : cadre de porte (control_door_frame).
-- @param side number : face de la porte (SIDE_FRONT ou SIDE_BACK).
-- @return table : { rt = ITexture, mat = IMaterial, nextRender = number }.
local function GetPortalView(frame, side)
    local existing = FindPortalView(frame, side)
    if existing then return existing end

    local idx = frame:EntIndex()
    local size = CONTROL_DOOR.PortalCamera.Resolution
    local name = "control_door_portal_" .. idx .. "_" .. SIDE_NAMES[side]
    local rt = GetRenderTarget(name, size, size)
    local mat = CreateMaterial(name, "UnlitGeneric", { ["$basetexture"] = rt:GetName() })
    -- CreateMaterial renvoie le matériau existant s'il porte déjà ce nom : on rebranche la texture.
    mat:SetTexture("$basetexture", rt)

    portalViews[idx] = portalViews[idx] or {}
    portalViews[idx][side] = { rt = rt, mat = mat, nextRender = 0 }
    return portalViews[idx][side]
end

--- Calcule l'écran posé sur une face de la porte stable d'un cadre.
-- La face est perpendiculaire à l'axe horizontal le plus fin du modèle (son épaisseur).
-- @param frame Entity : cadre de porte (control_door_frame).
-- @param side number : face de la porte (SIDE_FRONT ou SIDE_BACK).
-- @return Vector|nil, Vector, number, number : centre de l'écran, normale (sortante de la face), largeur et hauteur ; nil sans porte.
local function GetPortalScreen(frame, side)
    local door = frame:GetPortalDoor()
    if not IsValid(door) then return nil end

    local mins, maxs = door:OBBMins(), door:OBBMaxs()
    local size = maxs - mins
    local axis, width, thickness

    if size.x <= size.y then
        axis, width, thickness = door:GetForward(), size.y, size.x
    else
        axis, width, thickness = door:GetRight(), size.x, size.y
    end

    local frontNormal = axis:Dot(frame:GetForward()) >= 0 and axis or -axis
    local normal = frontNormal * side
    local center = door:LocalToWorld(door:OBBCenter()) + normal * (thickness * 0.5 + SCREEN_SURFACE_OFFSET)

    return center, normal, width - 4, size.z - 4
end

--- Éclaircit l'image de la render target en cours en la mélangeant à une couleur claire.
-- Doit être appelée entre render.PushRenderTarget et render.PopRenderTarget.
-- @param size number : taille (px) de la render target, carrée.
-- @return nil
local function ApplyPortalTint(size)
    local tint = CONTROL_DOOR.PortalTint
    local alpha = math.Clamp(tint.Strength, 0, 1) * 255
    if alpha <= 0 then return end

    cam.Start2D()
        surface.SetDrawColor(tint.Color.r, tint.Color.g, tint.Color.b, alpha)
        surface.DrawRect(0, 0, size, size)
    cam.End2D()
end

--- Rend la vue de la caméra fixe placée en face d'une face de la porte dans sa render target.
-- @param view table : vue retournée par GetPortalView.
-- @param center Vector : centre de l'écran.
-- @param normal Vector : normale sortante de la face.
-- @param width number : largeur de l'écran en unités.
-- @param height number : hauteur de l'écran en unités.
-- @return nil
local function RenderPortalView(view, center, normal, width, height)
    local cfg = CONTROL_DOOR.PortalCamera
    local size = cfg.Resolution
    local camPos = center + normal * cfg.Distance + Vector(0, 0, cfg.Height)

    isRenderingPortal = true
    render.PushRenderTarget(view.rt)
        render.Clear(0, 0, 0, 255, true, true)
        render.RenderView({
            origin = camPos,
            angles = (center - camPos):Angle(),
            x = 0, y = 0, w = size, h = size,
            -- La texture carrée est étirée sur l'écran : on rend avec le ratio de l'écran pour garder les proportions.
            aspect = width / height,
            fov = cfg.Fov,
            drawhud = false,
            drawviewmodel = false,
            dopostprocess = false,
            drawmonitors = false
        })
        ApplyPortalTint(size)
    render.PopRenderTarget()
    isRenderingPortal = false
end

--- Indique si l'écran d'un cadre doit être mis à jour à cette image.
-- @param frame Entity : cadre de porte.
-- @param eyePos Vector : position des yeux du joueur local.
-- @return boolean : vrai si la caméra doit être rendue.
local function ShouldRenderPortal(frame, eyePos)
    if not IsValid(frame) or frame:IsDormant() then return false end
    if not CONTROL_DOOR.IsStableDoor(frame) then return false end

    local maxDist = CONTROL_DOOR.PortalCamera.RenderDistance
    return eyePos:DistToSqr(frame:GetPos()) <= maxDist * maxDist
end

local WORLD_UP = Vector(0, 0, 1)
local TWO_PI = math.pi * 2

--- Calcule les coordonnées de texture ondulées d'un point de l'écran.
-- Le décalage dépend en continu de la position et du temps : deux cellules voisines restent jointives.
-- @param u number : position horizontale sur l'écran (0 à gauche, 1 à droite).
-- @param v number : position verticale sur l'écran (0 en haut, 1 en bas).
-- @param t number : temps courant en secondes.
-- @return number, number : coordonnées de texture (u, v) à échantillonner.
local function GetWaveUV(u, v, t)
    local wave = CONTROL_DOOR.PortalWave
    local amp, freq, speed = wave.Amplitude, wave.Frequency * TWO_PI, wave.Speed

    -- Deux ondes croisées, de vitesses légèrement différentes, pour un mouvement dans plusieurs directions.
    local du = amp * math.sin(t * speed + v * freq)
    local dv = amp * math.sin(t * speed * 0.8 + u * freq + 1.3)

    -- On échantillonne la zone [amp, 1 - amp] de la texture : le décalage ne sort jamais de l'image.
    local scale = 1 - amp * 2
    return amp + u * scale + du, amp + v * scale + dv
end

--- Ajoute un sommet de l'écran au mesh en cours.
-- @param origin Vector : coin haut-gauche de l'écran.
-- @param right Vector : vecteur largeur de l'écran (de gauche à droite).
-- @param down Vector : vecteur hauteur de l'écran (de haut en bas).
-- @param u number : position horizontale (0 à 1).
-- @param v number : position verticale (0 à 1).
-- @param t number : temps courant en secondes.
-- @return nil
local function EmitScreenVertex(origin, right, down, u, v, t)
    local tu, tv = GetWaveUV(u, v, t)

    mesh.Position(origin + right * u + down * v)
    mesh.TexCoord(0, tu, tv)
    mesh.Color(255, 255, 255, 255)
    mesh.AdvanceVertex()
end

--- Dessine l'écran de la caméra sur une face de la porte stable d'un cadre, avec l'effet de vague, si le joueur voit cette face.
-- @param frame Entity : cadre de porte (control_door_frame).
-- @param side number : face de la porte (SIDE_FRONT ou SIDE_BACK).
-- @param eyePos Vector : position de la vue en cours de rendu.
-- @return nil
local function DrawPortalScreen(frame, side, eyePos)
    local view = FindPortalView(frame, side)
    if not view then return end

    local center, normal, width, height = GetPortalScreen(frame, side)
    if not center or (eyePos - center):Dot(normal) <= 0 then return end

    -- Repère vu par un joueur face à cette face : la droite du joueur et le bas de l'écran.
    local right = (-normal):Cross(WORLD_UP) * width
    local down = -WORLD_UP * height
    local origin = center - right * 0.5 - down * 0.5

    local cells = math.max(math.floor(CONTROL_DOOR.PortalWave.Subdivisions), 1)
    local step = 1 / cells
    local t = RealTime()

    render.SetMaterial(view.mat)
    -- Chaque cellule est émise dans les deux sens d'enroulement : l'écran reste visible quel que soit le culling.
    -- La face cachée n'est jamais vue, l'écran n'étant dessiné que si le joueur est devant (test ci-dessus).
    mesh.Begin(MATERIAL_QUADS, cells * cells * 2)
        for row = 0, cells - 1 do
            local v0, v1 = row * step, (row + 1) * step
            for col = 0, cells - 1 do
                local u0, u1 = col * step, (col + 1) * step

                EmitScreenVertex(origin, right, down, u0, v0, t)
                EmitScreenVertex(origin, right, down, u1, v0, t)
                EmitScreenVertex(origin, right, down, u1, v1, t)
                EmitScreenVertex(origin, right, down, u0, v1, t)

                EmitScreenVertex(origin, right, down, u0, v0, t)
                EmitScreenVertex(origin, right, down, u0, v1, t)
                EmitScreenVertex(origin, right, down, u1, v1, t)
                EmitScreenVertex(origin, right, down, u1, v0, t)
            end
        end
    mesh.End()
end

--- Met à jour la caméra d'une face si le joueur se trouve de ce côté de la porte et que l'intervalle est écoulé.
-- @param frame Entity : cadre de porte stable.
-- @param side number : face de la porte (SIDE_FRONT ou SIDE_BACK).
-- @param eyePos Vector : position des yeux du joueur local.
-- @param now number : instant courant (RealTime).
-- @return nil
local function UpdatePortalSide(frame, side, eyePos, now)
    local center, normal, width, height = GetPortalScreen(frame, side)
    -- Inutile de rendre la caméra d'une face que le joueur ne peut pas voir.
    if not center or (eyePos - center):Dot(normal) <= 0 then return end

    local view = GetPortalView(frame, side)
    if now < view.nextRender then return end

    RenderPortalView(view, center, normal, width, height)
    view.nextRender = now + 1 / CONTROL_DOOR.PortalCamera.FrameRate
end

--- Met à jour, avant le rendu de l'image, les caméras des portes stables proches.
-- @return nil
hook.Add("PreRender", "control_door_portal_views", function()
    if isRenderingPortal then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local now = RealTime()
    local eyePos = ply:EyePos()

    for _, frame in ipairs(CONTROL_DOOR.GetClientFrames()) do
        if ShouldRenderPortal(frame, eyePos) then
            for _, side in ipairs(SIDES) do
                UpdatePortalSide(frame, side, eyePos, now)
            end
        end
    end
end)

--- Dessine les écrans après les entités translucides : la porte stable (translucide) ne peut plus les recouvrir.
-- @param isDepth boolean : vrai pendant la passe de profondeur.
-- @param isSkybox boolean : vrai pendant le rendu de la skybox.
-- @return nil
hook.Add("PostDrawTranslucentRenderables", "control_door_portal_screens", function(isDepth, isSkybox)
    -- Pendant le rendu d'une caméra, un écran ne doit pas s'afficher dans sa propre texture.
    if isDepth or isSkybox or isRenderingPortal then return end

    local eyePos = EyePos()

    for _, frame in ipairs(CONTROL_DOOR.GetClientFrames()) do
        if IsValid(frame) and not frame:IsDormant() and CONTROL_DOOR.IsStableDoor(frame) then
            for _, side in ipairs(SIDES) do
                DrawPortalScreen(frame, side, eyePos)
            end
        end
    end
end)
