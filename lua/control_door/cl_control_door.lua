if SERVER then return end

CONTROL_DOOR = CONTROL_DOOR or {}
CONTROL_DOOR.StableDoors = CONTROL_DOOR.StableDoors or {}
CONTROL_DOOR.MapFrame = nil
CONTROL_DOOR.MirrorFrame = nil
CONTROL_DOOR.PanelOpen = false

--- Retourne le nom traduit d'une porte stable.
-- @param entIndex number : index de l'entité porte.
-- @return string : nom affiché de la porte.
local function GetDoorName(entIndex)
    return string.format(language.GetPhrase("control_door.ui.door_name"), entIndex)
end

--- Ferme le panneau actuel s'il existe.
-- @return nil
local function CloseCurrentPanel()
    if IsValid(CONTROL_DOOR.MapFrame) then
        CONTROL_DOOR.MapFrame:Remove()
    end

    if IsValid(CONTROL_DOOR.MirrorFrame) then
        CONTROL_DOOR.MirrorFrame:Remove()
    end

    CONTROL_DOOR.MapFrame = nil
    CONTROL_DOOR.MirrorFrame = nil
    CONTROL_DOOR.PanelOpen = false
end

--- Crée le panneau miroir de la porte.
-- @return Panel : panneau miroir créé.
local function BuildMirrorPanel()
    if IsValid(CONTROL_DOOR.MirrorFrame) then
        CONTROL_DOOR.MirrorFrame:Remove()
    end

    local pnl = vgui.Create("DFrame")
    pnl:SetSize(ScrW() * 0.56, ScrH() * 0.68)
    pnl:Center()
    pnl:SetTitle("")
    pnl:ShowCloseButton(false)
    pnl:SetDraggable(false)
    pnl:MakePopup()
    pnl._fadeStart = RealTime()
    pnl.Paint = function(self, w, h)
        local fade = math.Clamp((RealTime() - self._fadeStart) / 0.45, 0, 1)
        local offset = Lerp(fade, -h * 0.3, 0)

        draw.RoundedBox(8, 0, 0, w, h, Color(12, 16, 24, 220))
        draw.RoundedBox(8, 6, 6 + offset, w - 12, h - 12, Color(28, 42, 64, 180))
    end

    local mirror = vgui.Create("DPanel", pnl)
    mirror:SetPos(18, 18)
    mirror:SetSize(pnl:GetWide() - 36, pnl:GetTall() - 64)
    mirror.Paint = function(self, w, h)
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        draw.RoundedBox(12, 0, 0, w, h, Color(58, 80, 125, 140))

        -- RenderView attend des coordonnées écran, pas des coordonnées locales au panneau.
        local x, y = self:LocalToScreen(0, 0)
        render.RenderView({
            origin = ply:EyePos(),
            angles = ply:EyeAngles(),
            x = x,
            y = y,
            w = w,
            h = h,
            drawhud = false,
            drawviewmodel = false,
            fov = 75,
            aspect = w / h
        })

        surface.SetDrawColor(25, 40, 75, 180)
        surface.DrawRect(0, 0, w, h)
    end

    local button = vgui.Create("DButton", pnl)
    button:SetPos(18, pnl:GetTall() - 42)
    button:SetSize(pnl:GetWide() - 36, 24)
    button:SetText("#control_door.ui.close")
    button.DoClick = CloseCurrentPanel

    CONTROL_DOOR.MirrorFrame = pnl
    CONTROL_DOOR.PanelOpen = true
    return pnl
end

--- Crée le panneau de sélection des portes stables.
-- @return Panel : panneau de carte créé.
local function BuildMapPanel()
    if IsValid(CONTROL_DOOR.MapFrame) then
        CONTROL_DOOR.MapFrame:Remove()
    end

    local pnl = vgui.Create("DFrame")
    pnl:SetSize(ScrW() * 0.42, ScrH() * 0.72)
    pnl:Center()
    pnl:SetTitle("")
    pnl:ShowCloseButton(false)
    pnl:SetDraggable(false)
    pnl:MakePopup()
    pnl._fadeStart = RealTime()
    pnl.Paint = function(self, w, h)
        local fade = math.Clamp((RealTime() - self._fadeStart) / 0.45, 0, 1)
        local offset = Lerp(fade, -h * 0.25, 0)

        draw.RoundedBox(8, 0, 0, w, h, Color(8, 12, 18, 220))
        draw.RoundedBox(8, 6, 6 + offset, w - 12, h - 12, Color(18, 24, 34, 160))
    end

    local list = vgui.Create("DListView", pnl)
    list:SetPos(20, 20)
    list:SetSize(pnl:GetWide() - 40, pnl:GetTall() - 80)
    list:SetMultiSelect(false)
    list:AddColumn("#control_door.ui.column.door")
    list:AddColumn("#control_door.ui.column.position")
    list:AddColumn("#control_door.ui.column.distance")
    list.OnRowSelected = function(_, _, row)
        if not IsValid(row) or not row.ControlDoorEntIndex then return end

        net.Start("control_door_select")
            net.WriteUInt(row.ControlDoorEntIndex, 16)
        net.SendToServer()
    end

    local ply = LocalPlayer()
    for _, data in ipairs(CONTROL_DOOR.StableDoors) do
        local dist = IsValid(ply) and math.floor(ply:GetPos():Distance(data.pos)) or 0
        local line = list:AddLine(GetDoorName(data.entIndex), math.Round(data.pos.x) .. ", " .. math.Round(data.pos.y), dist .. " u")
        line.ControlDoorEntIndex = data.entIndex
    end

    local closeButton = vgui.Create("DButton", pnl)
    closeButton:SetPos(20, pnl:GetTall() - 42)
    closeButton:SetSize(pnl:GetWide() - 40, 24)
    closeButton:SetText("#control_door.ui.close")
    closeButton.DoClick = CloseCurrentPanel

    CONTROL_DOOR.MapFrame = pnl
    CONTROL_DOOR.PanelOpen = true
    return pnl
end

--- Ouvre le bon panneau en fonction du message serveur.
-- @param kind string : type d'interface à ouvrir ("mirror", "map" ou "close").
-- @return nil
local function OpenPanel(kind)
    CloseCurrentPanel()

    if kind == "mirror" then
        BuildMirrorPanel()
    elseif kind == "map" then
        -- La liste est poussée par le serveur juste après ce message : le panneau se reconstruit à sa réception.
        BuildMapPanel()
    end
end

--- Met à jour la liste des portes stables reçue du serveur.
-- @return nil
net.Receive("control_door_list", function()
    local count = net.ReadUInt(8)
    local doors = {}

    for i = 1, count do
        doors[i] = { entIndex = net.ReadUInt(16), pos = net.ReadVector() }
    end

    CONTROL_DOOR.StableDoors = doors

    if IsValid(CONTROL_DOOR.MapFrame) then
        BuildMapPanel()
    end
end)

--- Ouvre le bon panneau selon la commande du serveur.
-- @return nil
net.Receive("control_door_open_panel", function()
    OpenPanel(net.ReadString())
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
    if not IsValid(ply) then return end

    for _, info in ipairs(CONTROL_DOOR.StableDoors) do
        local pos = info.pos + MARKER_OFFSET
        local screen = pos:ToScreen()

        if screen.visible then
            local dist = math.floor(ply:GetPos():Distance(pos))
            draw.SimpleTextOutlined("•", "DermaLarge", screen.x, screen.y, MARKER_COLOR, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, MARKER_OUTLINE)
            draw.SimpleTextOutlined(GetDoorName(info.entIndex) .. " (" .. dist .. "u)", "DermaDefaultBold", screen.x, screen.y + 12, LABEL_COLOR, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, LABEL_OUTLINE)
        end
    end
end)
