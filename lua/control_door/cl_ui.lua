if SERVER then return end

-- Kit graphique de la direction artistique (docs/claude/da.md), préfixé au nom de l'addon.
CONTROL_DOOR = CONTROL_DOOR or {}
CONTROL_DOOR.UI = CONTROL_DOOR.UI or {}
CONTROL_DOOR.UI_CONFIG = CONTROL_DOOR.UI_CONFIG or {}

local UI = CONTROL_DOOR.UI

CONTROL_DOOR.UI_CONFIG.Colors = {
    BLUE        = Color(10, 30, 80, 240),
    BLUE_HOVER  = Color(15, 43, 112, 240),
    BLACK       = Color(7, 0, 44, 150),
    BLACK_BTN   = Color(7, 0, 44, 50),
    PANEL       = Color(0, 0, 0, 240),
    WHITE       = Color(255, 255, 255, 255),
    WHITE_HOVER = Color(255, 255, 255, 50),
    RED         = Color(107, 0, 0, 255),
    GREEN       = Color(0, 109, 9, 255),
    VEIL        = Color(0, 0, 0, 200),
    CLOSE       = Color(65, 65, 88, 200),
    CLOSE_HOVER = Color(80, 80, 130, 220),
    CLOSE_TEXT  = Color(220, 220, 255, 255),
}

surface.CreateFont("control_door_ui_display", { font = "DermaLarge", size = 70, weight = 1000 })
surface.CreateFont("control_door_ui_title",   { font = "DermaLarge", size = 50, weight = 1000 })
surface.CreateFont("control_door_ui_body",    { font = "DermaLarge", size = 45, weight = 0 })
surface.CreateFont("control_door_ui_button",  { font = "DermaLarge", size = 25, weight = 1000 })
surface.CreateFont("control_door_ui_small",   { font = "DermaLarge", size = 20, weight = 0 })

local COLORS = CONTROL_DOOR.UI_CONFIG.Colors
local OVERLAY_ZPOS = 500

--- Dessine un rectangle plein à angles droits entouré d'un liseré.
-- @param x number : position x en pixels.
-- @param y number : position y en pixels.
-- @param w number : largeur en pixels.
-- @param h number : hauteur en pixels.
-- @param bgColor Color : couleur de fond.
-- @param borderColor Color : couleur du liseré.
-- @param borderSize number : épaisseur du liseré en pixels.
-- @return nil
function UI.DrawBorderedRect(x, y, w, h, bgColor, borderColor, borderSize)
    draw.RoundedBox(0, x + borderSize, y + borderSize, w - borderSize * 2, h - borderSize * 2, bgColor)
    surface.SetDrawColor(borderColor)
    surface.DrawOutlinedRect(x, y, w, h, borderSize)
end

--- Retourne le facteur de fondu (0 → 1, ease-out) depuis l'ouverture d'un menu.
-- @param openTime number : instant d'ouverture (SysTime).
-- @param duration number|nil : durée du fondu en secondes (1 par défaut).
-- @return number : facteur entre 0 et 1.
function UI.FadeAlpha(openTime, duration)
    local t = math.Clamp((SysTime() - openTime) / (duration or 1), 0, 1)
    return 1 - (1 - t) ^ 2
end

--- Retourne une copie de la couleur avec son alpha multiplié.
-- @param col Color : couleur d'origine.
-- @param a number : facteur d'alpha entre 0 et 1.
-- @return Color : nouvelle couleur.
function UI.WithAlpha(col, a)
    return Color(col.r, col.g, col.b, math.floor(col.a * a))
end

--- Joue le son natif de clic des boutons.
-- @return nil
function UI.PlayClick()
    surface.PlaySound(CONTROL_DOOR.Sounds.Click)
end

--- Crée l'overlay plein écran d'un menu, avec fond BLUE et fondu d'ouverture.
-- @return Panel : overlay créé ; overlay:GetFade() renvoie le facteur de fondu courant.
function UI.CreateOverlay()
    local overlay = vgui.Create("DPanel")
    overlay:SetPos(0, 0)
    overlay:SetSize(ScrW(), ScrH())
    overlay:SetZPos(OVERLAY_ZPOS)
    overlay:MakePopup()
    overlay.OpenTime = SysTime()
    overlay.GetFade = function(self) return UI.FadeAlpha(self.OpenTime) end
    overlay.Paint = function(self, w, h)
        surface.SetDrawColor(UI.WithAlpha(COLORS.BLUE, self:GetFade()))
        surface.DrawRect(0, 0, w, h)
    end

    return overlay
end

--- Crée le titre d'écran centré en haut d'un overlay.
-- @param overlay Panel : overlay créé par UI.CreateOverlay.
-- @param key string : clé de traduction du titre.
-- @return Panel : panneau du titre.
function UI.CreateTitle(overlay, key)
    local title = vgui.Create("DPanel", overlay)
    title:SetPos(0, ScrH() * 0.03)
    title:SetSize(ScrW(), ScrH() * 0.07)
    title.Paint = function(_, w, h)
        draw.SimpleText(language.GetPhrase(key), "control_door_ui_title", w * 0.5, h * 0.5, UI.WithAlpha(COLORS.WHITE, overlay:GetFade()), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    return title
end

--- Crée le bouton « ◀ Quitter » en haut à gauche d'un overlay.
-- @param overlay Panel : overlay créé par UI.CreateOverlay.
-- @param onClick function : fonction appelée au clic.
-- @return Panel : bouton créé.
function UI.CreateQuitButton(overlay, onClick)
    local label = language.GetPhrase("control_door.ui.quit")
    surface.SetFont("control_door_ui_small")
    local textW = surface.GetTextSize(label)

    local button = vgui.Create("DButton", overlay)
    button:SetPos(ScrW() * 0.01, ScrH() * 0.015)
    button:SetSize(math.max(60, textW + 16), 30)
    button:SetText("")
    button.Paint = function(self, w, h)
        local fade = overlay:GetFade()
        draw.RoundedBox(4, 0, 0, w, h, UI.WithAlpha(self:IsHovered() and COLORS.CLOSE_HOVER or COLORS.CLOSE, fade))
        draw.SimpleText(label, "control_door_ui_small", w * 0.5, h * 0.5, UI.WithAlpha(COLORS.CLOSE_TEXT, fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    button.DoClick = function()
        UI.PlayClick()
        onClick()
    end

    return button
end
