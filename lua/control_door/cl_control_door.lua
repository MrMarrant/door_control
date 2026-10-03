if SERVER then return end

CONTROL_DOOR = CONTROL_DOOR or {}
CONTROL_DOOR.StableDoors = CONTROL_DOOR.StableDoors or {}
CONTROL_DOOR.ActiveMenu = nil
CONTROL_DOOR.ActiveKind = nil
CONTROL_DOOR.PanelOpen = false

local UI = CONTROL_DOOR.UI
local COLORS = CONTROL_DOOR.UI_CONFIG.Colors
local ROW_HEIGHT = 48
local ROW_GAP = 4
local CONTENT_PADDING = 10

--- Retourne le nom traduit d'une porte stable.
-- @param entIndex number : index de l'entité porte.
-- @return string : nom affiché de la porte.
local function GetDoorName(entIndex)
    return string.format(language.GetPhrase("control_door.ui.door_name"), entIndex)
end

--- Ferme le menu actuellement ouvert s'il existe.
-- @return nil
local function CloseCurrentPanel()
    if IsValid(CONTROL_DOOR.ActiveMenu) then
        CONTROL_DOOR.ActiveMenu:Remove()
    end

    CONTROL_DOOR.ActiveMenu = nil
    CONTROL_DOOR.ActiveKind = nil
    CONTROL_DOOR.PanelOpen = false
end

--- Retourne la zone de contenu commune aux écrans, sous le titre (fractions de l'écran).
-- @return number, number, number, number : x, y, largeur et hauteur en pixels.
local function GetContentArea()
    local margin = ScrW() * 0.02
    local top = ScrH() * 0.12

    return margin, top, ScrW() - margin * 2, ScrH() - top - ScrH() * 0.04
end

--- Dessine une vue 3D dans la zone intérieure d'un panneau de contenu, avec fondu et liseré.
-- @param pnl Panel : panneau de contenu.
-- @param w number : largeur du panneau en pixels.
-- @param h number : hauteur du panneau en pixels.
-- @param fade number : facteur de fondu de l'overlay (0 → 1).
-- @param view table : paramètres de render.RenderView (sans x, y, w, h).
-- @param drawOver function|nil : dessin 2D par-dessus la vue, reçoit (offsetX, offsetY, innerW, innerH).
-- @return nil
local function DrawContentView(pnl, w, h, fade, view, drawOver)
    local innerW, innerH = w - CONTENT_PADDING * 2, h - CONTENT_PADDING * 2

    UI.DrawBorderedRect(0, 0, w, h, UI.WithAlpha(COLORS.PANEL, fade), UI.WithAlpha(COLORS.WHITE, fade), 1)

    -- RenderView attend des coordonnées écran, pas des coordonnées locales au panneau.
    view.x, view.y = pnl:LocalToScreen(CONTENT_PADDING, CONTENT_PADDING)
    view.w, view.h = innerW, innerH
    render.RenderView(view)

    if drawOver then
        drawOver(CONTENT_PADDING, CONTENT_PADDING, innerW, innerH)
    end

    -- La vue 3D ne gère pas l'alpha : un voile PANEL qui s'efface simule le fondu d'ouverture.
    draw.RoundedBox(0, CONTENT_PADDING, CONTENT_PADDING, innerW, innerH, UI.WithAlpha(COLORS.PANEL, 1 - fade))
end

--- Crée l'écran plein écran de la vue miroir.
-- @return Panel : overlay créé.
local function BuildMirrorPanel()
    local overlay = UI.CreateOverlay()
    UI.CreateTitle(overlay, "control_door.ui.portal")
    UI.CreateQuitButton(overlay, CloseCurrentPanel)

    local x, y, w, h = GetContentArea()
    local mirror = vgui.Create("DPanel", overlay)
    mirror:SetPos(x, y)
    mirror:SetSize(w, h)
    mirror.Paint = function(self, pw, ph)
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        DrawContentView(self, pw, ph, overlay:GetFade(), {
            origin = ply:EyePos(),
            angles = ply:EyeAngles(),
            drawhud = false,
            drawviewmodel = false,
            fov = 75,
            aspect = (pw - CONTENT_PADDING * 2) / (ph - CONTENT_PADDING * 2)
        }, function(ox, oy, iw, ih)
            surface.SetDrawColor(UI.WithAlpha(COLORS.BLUE, 0.75))
            surface.DrawRect(ox, oy, iw, ih)
        end)
    end

    return overlay
end

--- Calcule le cadrage de la vue du dessus pour que toute la map tienne dans la zone.
-- @param w number : largeur de la zone en pixels.
-- @param h number : hauteur de la zone en pixels.
-- @return Vector, number, number : centre de la map, demi-largeur et demi-hauteur visibles (en unités).
local function GetMapFraming(w, h)
    local mins, maxs = CONTROL_DOOR.WorldMins, CONTROL_DOOR.WorldMaxs
    local aspect = w / h
    local halfW = math.max((maxs.x - mins.x) * 0.5, (maxs.y - mins.y) * 0.5 * aspect)

    return (mins + maxs) * 0.5, halfW, halfW / aspect
end

--- Convertit une position du monde en coordonnées locales à la zone de la carte (nord en haut).
-- @param pos Vector : position dans le monde.
-- @param center Vector : centre de la map.
-- @param halfW number : demi-largeur visible en unités.
-- @param halfH number : demi-hauteur visible en unités.
-- @param w number : largeur de la zone en pixels.
-- @param h number : hauteur de la zone en pixels.
-- @return number, number : coordonnées x, y dans la zone.
local function WorldToMap(pos, center, halfW, halfH, w, h)
    return w * 0.5 + (pos.x - center.x) / halfW * w * 0.5,
           h * 0.5 - (pos.y - center.y) / halfH * h * 0.5
end

--- Dessine un marqueur carré et son libellé sur la carte.
-- @param x number : position x du centre du marqueur.
-- @param y number : position y du centre du marqueur.
-- @param label string : texte affiché sous le marqueur.
-- @param fill Color : couleur de fond du marqueur.
-- @param border Color : couleur du liseré du marqueur.
-- @param size number : taille du marqueur en pixels.
-- @return nil
local function DrawMapMarker(x, y, label, fill, border, size)
    UI.DrawBorderedRect(math.floor(x - size * 0.5), math.floor(y - size * 0.5), size, size, fill, border, 1)
    draw.SimpleText(label, "control_door_ui_small", x, y + size * 0.5 + 2, COLORS.WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end

--- Retourne l'index d'entité de la ligne survolée dans la liste des portes.
-- @param scroll Panel : liste des portes (DScrollPanel).
-- @return number|nil : index d'entité de la porte survolée, nil si aucune.
local function GetHoveredDoor(scroll)
    if not IsValid(scroll) then return nil end

    for _, row in ipairs(scroll:GetCanvas():GetChildren()) do
        if row:IsHovered() then return row.ControlDoorEntIndex end
    end
end

--- Dessine les marqueurs des portes stables et du joueur sur la carte.
-- @param ox number : décalage x de la zone de la carte dans le panneau.
-- @param oy number : décalage y de la zone de la carte dans le panneau.
-- @param w number : largeur de la zone en pixels.
-- @param h number : hauteur de la zone en pixels.
-- @param hovered number|nil : index d'entité de la porte survolée dans la liste.
-- @return nil
local function DrawMapMarkers(ox, oy, w, h, hovered)
    local center, halfW, halfH = GetMapFraming(w, h)

    for _, data in ipairs(CONTROL_DOOR.StableDoors) do
        local x, y = WorldToMap(data.pos, center, halfW, halfH, w, h)
        if data.entIndex == hovered then
            DrawMapMarker(ox + x, oy + y, GetDoorName(data.entIndex), COLORS.WHITE, COLORS.BLUE, 16)
        else
            DrawMapMarker(ox + x, oy + y, GetDoorName(data.entIndex), COLORS.BLUE, COLORS.WHITE, 10)
        end
    end

    local ply = LocalPlayer()
    if IsValid(ply) then
        local x, y = WorldToMap(ply:GetPos(), center, halfW, halfH, w, h)
        DrawMapMarker(ox + x, oy + y, language.GetPhrase("control_door.ui.you"), COLORS.GREEN, COLORS.WHITE, 10)
    end
end

--- Crée la vue du dessus de la map, avec les portes stables et le joueur.
-- @param overlay Panel : overlay du menu (pour le fondu).
-- @param scroll Panel : liste des portes, pour surligner la porte survolée.
-- @return Panel : panneau de la vue de la carte.
local function BuildMapView(overlay, scroll)
    local view = vgui.Create("DPanel", overlay)
    view.Paint = function(self, w, h)
        local fade = overlay:GetFade()
        if not CONTROL_DOOR.WorldMins then
            UI.DrawBorderedRect(0, 0, w, h, UI.WithAlpha(COLORS.PANEL, fade), UI.WithAlpha(COLORS.WHITE, fade), 1)
            return
        end

        local innerW, innerH = w - CONTENT_PADDING * 2, h - CONTENT_PADDING * 2
        local center, halfW, halfH = GetMapFraming(innerW, innerH)
        local mins, maxs = CONTROL_DOOR.WorldMins, CONTROL_DOOR.WorldMaxs

        -- Caméra orthographique au-dessus de la map, regard vers le bas, nord (+Y) en haut et est (+X) à droite.
        DrawContentView(self, w, h, fade, {
            origin = Vector(center.x, center.y, maxs.z + 1),
            angles = Angle(90, 90, 0),
            ortho = { left = -halfW, right = halfW, top = -halfH, bottom = halfH },
            znear = CONTROL_DOOR.MapViewCeilingClip,
            zfar = maxs.z - mins.z + CONTROL_DOOR.MapViewCeilingClip,
            drawhud = false,
            drawviewmodel = false,
            dopostprocess = false,
            drawmonitors = false
        }, function(ox, oy, iw, ih)
            DrawMapMarkers(ox, oy, iw, ih, GetHoveredDoor(scroll))
        end)
    end

    return view
end

--- Crée une ligne de la liste des portes (nom à gauche, distance à droite).
-- @param scroll Panel : liste des portes (DScrollPanel).
-- @param overlay Panel : overlay du menu (pour le fondu).
-- @param data table : porte stable { entIndex = number, pos = Vector }.
-- @return Panel : ligne créée.
local function BuildDoorRow(scroll, overlay, data)
    local name = GetDoorName(data.entIndex)
    local ply = LocalPlayer()
    local dist = IsValid(ply) and math.floor(ply:GetPos():Distance(data.pos)) or 0

    local row = scroll:Add("DButton")
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, ROW_GAP)
    row:SetTall(ROW_HEIGHT)
    row:SetText("")
    row.ControlDoorEntIndex = data.entIndex
    row.Paint = function(self, w, h)
        local fade = overlay:GetFade()
        local bg = self:IsHovered() and COLORS.BLUE_HOVER or COLORS.BLACK_BTN

        UI.DrawBorderedRect(0, 0, w, h, UI.WithAlpha(bg, fade), UI.WithAlpha(COLORS.WHITE, fade), 1)
        draw.SimpleText(name, "control_door_ui_button", 12, h * 0.5, UI.WithAlpha(COLORS.WHITE, fade), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(dist .. " u", "control_door_ui_small", w - 12, h * 0.5, UI.WithAlpha(COLORS.WHITE, fade), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    row.DoClick = function(self)
        UI.PlayClick()

        net.Start("control_door_select")
            net.WriteUInt(self.ControlDoorEntIndex, 16)
        net.SendToServer()
    end

    return row
end

--- Remplit la liste des portes avec les portes stables connues.
-- @param scroll Panel : liste des portes (DScrollPanel).
-- @param overlay Panel : overlay du menu (pour le fondu).
-- @return nil
local function RefreshDoorList(scroll, overlay)
    scroll:Clear()

    for _, data in ipairs(CONTROL_DOOR.StableDoors) do
        BuildDoorRow(scroll, overlay, data)
    end
end

--- Crée la colonne de gauche : titre de section et liste des portes stables.
-- @param overlay Panel : overlay du menu.
-- @param x number : position x de la colonne.
-- @param y number : position y de la colonne.
-- @param w number : largeur de la colonne.
-- @param h number : hauteur de la colonne.
-- @return Panel : liste des portes (DScrollPanel).
local function BuildDoorColumn(overlay, x, y, w, h)
    local sectionH = ScrH() * 0.04

    local section = vgui.Create("DPanel", overlay)
    section:SetPos(x, y)
    section:SetSize(w, sectionH)
    section.Paint = function(_, _, sh)
        draw.SimpleText(language.GetPhrase("control_door.ui.section.doors"), "control_door_ui_button", 0, sh * 0.5, UI.WithAlpha(COLORS.WHITE, overlay:GetFade()), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local container = vgui.Create("DPanel", overlay)
    container:SetPos(x, y + sectionH)
    container:SetSize(w, h - sectionH)
    container:DockPadding(CONTENT_PADDING, CONTENT_PADDING, CONTENT_PADDING, CONTENT_PADDING)
    container.Paint = function(_, cw, ch)
        local fade = overlay:GetFade()
        UI.DrawBorderedRect(0, 0, cw, ch, UI.WithAlpha(COLORS.PANEL, fade), UI.WithAlpha(COLORS.WHITE, fade), 1)
    end

    local scroll = vgui.Create("DScrollPanel", container)
    scroll:Dock(FILL)

    RefreshDoorList(scroll, overlay)
    return scroll
end

--- Crée l'écran plein écran de la carte : liste des portes à gauche, vue de la map à droite.
-- @return Panel : overlay créé.
local function BuildMapPanel()
    local overlay = UI.CreateOverlay()
    UI.CreateTitle(overlay, "control_door.ui.map")
    UI.CreateQuitButton(overlay, CloseCurrentPanel)

    local x, y, w, h = GetContentArea()
    local listW = ScrW() * CONTROL_DOOR.MapListWidth
    local gap = ScrW() * 0.015

    overlay.DoorList = BuildDoorColumn(overlay, x, y, listW, h)

    local view = BuildMapView(overlay, overlay.DoorList)
    view:SetPos(x + listW + gap, y)
    view:SetSize(w - listW - gap, h)

    return overlay
end

-- Constructeurs d'écran par type d'interface demandé par le serveur.
local MENU_BUILDERS = {
    mirror = BuildMirrorPanel,
    map = BuildMapPanel
}

--- Ouvre le bon écran en fonction du message serveur ("close" ou un type inconnu ferme le menu).
-- @param kind string : type d'interface à ouvrir ("mirror", "map" ou "close").
-- @return nil
local function OpenPanel(kind)
    CloseCurrentPanel()

    local builder = MENU_BUILDERS[kind]
    if not builder then return end

    CONTROL_DOOR.ActiveMenu = builder()
    CONTROL_DOOR.ActiveKind = kind
    CONTROL_DOOR.PanelOpen = true
end

--- Met à jour les limites de la map et la liste des portes stables reçues du serveur.
-- @return nil
net.Receive("control_door_list", function()
    CONTROL_DOOR.WorldMins = net.ReadVector()
    CONTROL_DOOR.WorldMaxs = net.ReadVector()

    local count = net.ReadUInt(8)
    local doors = {}

    for i = 1, count do
        doors[i] = { entIndex = net.ReadUInt(16), pos = net.ReadVector() }
    end

    CONTROL_DOOR.StableDoors = doors

    local menu = CONTROL_DOOR.ActiveMenu
    if IsValid(menu) and IsValid(menu.DoorList) then
        RefreshDoorList(menu.DoorList, menu)
    end
end)

--- Ouvre le bon écran selon la commande du serveur.
-- @return nil
net.Receive("control_door_open_panel", function()
    OpenPanel(net.ReadString())
end)

--- Ferme le menu ouvert avec Échap au lieu d'afficher le menu pause.
-- @return boolean|nil : false pour bloquer le menu pause si un menu de l'addon était ouvert.
hook.Add("OnPauseMenuShow", "control_door_close_on_escape", function()
    if not IsValid(CONTROL_DOOR.ActiveMenu) then return end

    CloseCurrentPanel()
    return false
end)

--- Reconstruit le menu ouvert à la nouvelle résolution.
-- @return nil
hook.Add("OnScreenSizeChanged", "control_door_rebuild_menu", function()
    local kind = CONTROL_DOOR.ActiveKind
    if kind and IsValid(CONTROL_DOOR.ActiveMenu) then
        OpenPanel(kind)
    end
end)

local MARKER_OFFSET = Vector(0, 0, 18)
local MARKER_COLOR = Color(104, 210, 255, 255)
local MARKER_OUTLINE = Color(0, 0, 0, 180)
local LABEL_COLOR = Color(255, 255, 255, 255)
local LABEL_OUTLINE = Color(0, 0, 0, 160)

--- Dessine les marqueurs des portes stables connues dans le monde.
-- @return nil
hook.Add("HUDPaint", "control_door_world_markers", function()
    local ply = LocalPlayer()
    -- if not IsValid(ply) then return end

    -- for _, info in ipairs(CONTROL_DOOR.StableDoors) do
    --     local pos = info.pos + MARKER_OFFSET
    --     local screen = pos:ToScreen()

    --     if screen.visible then
    --         local dist = math.floor(ply:GetPos():Distance(pos))
    --         draw.SimpleTextOutlined("•", "DermaLarge", screen.x, screen.y, MARKER_COLOR, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, MARKER_OUTLINE)
    --         draw.SimpleTextOutlined(GetDoorName(info.entIndex) .. " (" .. dist .. "u)", "DermaDefaultBold", screen.x, screen.y + 12, LABEL_COLOR, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, LABEL_OUTLINE)
    --     end
    -- end
end)
