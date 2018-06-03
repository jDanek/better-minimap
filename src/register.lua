source(Utils.getFilename("src/gui/ConfigGui.lua", g_currentModDirectory));

--- register translations ---
g_isLoaded = false;
if (not g_isLoaded) then
    for k, v in pairs(g_i18n.texts) do
        g_i18n.globalI18N:setText(k, v);
    end ;
    g_isLoaded = true;
end ;

BM = {};
BM.moddir = g_currentModDirectory;
BM.modName = g_currentModName;
BM.mapEvents = {};

--- Constants ---
BM.const = {};
BM.const.settings_file = g_modsDirectory .. "BM_Settings.xml";
BM.const.frequency = { 15, 30, 45, 60 }; -- refresh frequency (in sec)
BM.const.mapSizes = { { 456, 350 }, { 800, 350 }, { 800, 600 } }; -- minimap sizes {width, height}
BM.const.mapNames = { g_i18n:getText("gui_BM_MAPSIZE_N"), g_i18n:getText("gui_BM_MAPSIZE_W"), g_i18n:getText("gui_BM_MAPSIZE_L") };
BM.const.transparent = { 0.3, 0.5, 0.7 };

--- Settings ---
BM.settings = {};
BM.settings.init = false;
BM.settings.mapUpdate = false;
BM.settings.saveSettings = false;
BM.settings.visible = true;
BM.settings.help_min = true;
BM.settings.help_full = false;
BM.settings.fullscreen = false;
BM.settings.frequency = 4;
BM.settings.sizeMode = 1;
BM.settings.transparent = false;
BM.settings.transMode = 3;
BM.settings.state = 0;

--- Better Minimap Methods ---
function BM:init()
    self.overlayPosX = 0.02;
    self.overlayPosY = 0.04;
    self.zoomFactor = 0.0007;
    self.visWidth = 0.3;

    self.pixelWidth = (1 / 3) / 1024.0;
    self.pixelHeight = self.pixelWidth * g_screenAspectRatio;

    -- set default map properties
    self.mapWidth = self.const.mapSizes[self.settings.sizeMode][1] * self.pixelWidth;
    self.mapHeight = self.const.mapSizes[self.settings.sizeMode][2] * self.pixelHeight;
end;

function BM:loadMap(name)
    -- load setttings from xml
    if (not fileExists(self.const.settings_file)) then
        self:saveBMSettings(self.const.settings_file);
    else
        self:loadBMSettings(self.const.settings_file);
    end ;

    self.timer = 0;
    self.needUpdateFruitOverlay = true;
    self.settings.mapUpdate = true;

    -- config gui
    self.ConfigGui = ConfigGui:new()
    g_gui:loadGui(Utils.getFilename("src/gui/ConfigGui.xml", BM.moddir), "ConfigGui", self.ConfigGui)

    -- counting seedable fruits (need for right switching map mode)
    self.numberOfFruits = 0;
    for fruitId in pairs(FruitUtil.fruitTypes) do
        if (FruitUtil.fruitTypes[fruitId].needsSeeding) then
            self.numberOfFruits = self.numberOfFruits + 1;
        end
    end ;
    self.numberOfFruitPages = math.ceil(self.numberOfFruits / 12); -- 12 fruits per page
end;

function BM:deleteMap()
end;

function BM:mouseEvent(posX, posY, isDown, isUp, button)
end;

function BM:keyEvent(unicode, sym, modifier, isDown)
end;

function BM:update(dt)
    -- activate mod if not activated
    if (not self.settings.init) then
        self.settings.init = true;
        g_currentMission.ingameMap.state = IngameMap.STATE_MINIMAP;
        self:show();
    end ;

    -- TARDIS mod compatibility
    if g_modIsLoaded["FS17_TARDIS"] then
        if (g_currentMission.tardisBase.tardisOn ~= nil and self.settings.fullscreen) then
            self:hide();
        else
            g_currentMission.ingameMap.state = IngameMap.STATE_MINIMAP;
            self:show();
        end;
    end;

    local ingameMap = g_currentMission.ingameMap;

    if (g_gui:getIsGuiVisible() and g_gui.currentGuiName == "InGameMenu") then
        self.needUpdateFruitOverlay = true;
    end ;

    if (self.timer < (self.const.frequency[self.settings.frequency] * 1000)) then
        self.timer = self.timer + dt;
    else
        self.needUpdateFruitOverlay = true;
    end ;

    if (self.settings.init and g_gui.currentGui == nil) then

        if (self.settings.help_min) then
            g_currentMission:addHelpButtonText(g_i18n:getText("input_BM_TOGGLE_HELP"), InputBinding.BM_TOGGLE_HELP, nil, GS_PRIO_HIGH);
        end ;

        if (InputBinding.hasEvent(InputBinding.BM_TOGGLE_HELP)) then
            self.settings.help_full = not self.settings.help_full;
        end ;

        self:renderModHelp(); -- ingame key help

        if (InputBinding.hasEvent(InputBinding.BM_SHOW_CONFIG_GUI)) then
            if (g_gui.currentGui == nil) then
                g_gui:showGui("ConfigGui");
            end ;
        end ;

        if (InputBinding.hasEvent(InputBinding.BM_RELOAD)) then
            self.needUpdateFruitOverlay = true;
        end ;

        if (InputBinding.hasEvent(InputBinding.BM_NEXT)) then
            self.settings.state = self.settings.state + 1;
            if (self.settings.state > (self.numberOfFruitPages + 2)) then
                self.settings.state = 0
            end ;
            if (self.settings.state ~= 0) then
                self.needUpdateFruitOverlay = true;
            end ;
        end ;

        if (InputBinding.hasEvent(InputBinding.BM_PREV)) then
            self.settings.state = self.settings.state - 1;
            if (self.settings.state < 0) then
                self.settings.state = (self.numberOfFruitPages + 2);
            end ;
            if (self.settings.state ~= 0) then
                self.needUpdateFruitOverlay = true;
            end ;
        end ;

        if (InputBinding.hasEvent(InputBinding.TOGGLE_MAP_SIZE)) then
            -- reload field states if change size map
            self.needUpdateFruitOverlay = true;
            -- toggle fulscreen
            self.settings.fullscreen = not self.settings.fullscreen;

            g_currentMission.ingameMap.state = self.settings.fullscreen and IngameMap.STATE_MAP or IngameMap.STATE_MINIMAP;

            if (self.settings.fullscreen) then
                self.mapWidth, self.mapHeight = ingameMap.maxMapWidth, ingameMap.maxMapHeight;
                self.alpha = self.const.transparent[self.settings.transMode];
                self.visWidth = ingameMap.mapVisWidthMax;
            else
                self.settings.mapUpdate = true;
            end ;
        end ;

        if (not self.settings.fullscreen) then
            if (InputBinding.isPressed(InputBinding.BM_ZOOM_IN)) then
                ingameMap:zoom(-self.zoomFactor * dt);
                self.visWidth = ingameMap.mapVisWidthMin;
            end ;
            if (InputBinding.isPressed(InputBinding.BM_ZOOM_OUT)) then
                ingameMap:zoom(self.zoomFactor * dt);
                self.visWidth = ingameMap.mapVisWidthMin;
            end ;
        end ;

        -- update overlay
        if (self.needUpdateFruitOverlay) then
            self.needUpdateFruitOverlay = false;
            self:generateFruitOverlay();
        end ;

        -- refresh map properties by settings
        if (self.settings.mapUpdate) then
            self:renderSelectedMinimap();
        end ;

        -- save settings to XML
        if (self.settings.saveSettings and fileExists(self.const.settings_file)) then
            self:saveBMSettings(self.const.settings_file);
        end ;
    end ;
end;

function BM:draw()
    if (self.settings.visible) then

        local ingameMap = g_currentMission.ingameMap;

        ingameMap:zoom(0);
        IngameMap.iconZoom = ingameMap.maxIconZoom;

        ingameMap:updatePlayerPosition();
        ingameMap:setPosition(self.overlayPosX, self.overlayPosY);
        ingameMap:setSize(self.mapWidth, self.mapHeight);

        if (self.settings.fullscreen) then
            ingameMap.mapVisWidthMin = 1;
        else
            ingameMap.mapVisWidthMin = self.visWidth;
        end ;

        ingameMap.centerXPos = ingameMap.normalizedPlayerPosX;
        ingameMap.centerZPos = ingameMap.normalizedPlayerPosZ;

        local leftBorderReached, rightBorderReached, topBorderReached, bottomBorderReached = ingameMap:drawMap(self.alpha)
        local foliageOverlay = g_inGameMenu.foliageStateOverlay;

        if (self.settings.state ~= 0 and getIsFoliageStateOverlayReady(foliageOverlay)) then
            setOverlayUVs(foliageOverlay, unpack(ingameMap.mapUVs));
            renderOverlay(foliageOverlay, self.overlayPosX, self.overlayPosY, self.mapWidth, self.mapHeight);
        end ;

        self:renderMapMode();

        ingameMap:renderHotspots(leftBorderReached, rightBorderReached, topBorderReached, bottomBorderReached, false, self.settings.fullscreen);
        ingameMap:renderPlayerArrows(false, leftBorderReached, rightBorderReached, topBorderReached, bottomBorderReached, true);
        ingameMap:renderHotspots(leftBorderReached, rightBorderReached, topBorderReached, bottomBorderReached, true, self.settings.fullscreen);
        ingameMap:renderPlayersCoordinates();
        ingameMap:drawLatencyToServer();
        ingameMap:drawInputBinding();
    end ;
end;

function BM:activate()
    if (not g_inGameMenu.mapSelectorMapping) then
        g_inGameMenu:setupMapOverview();
    end ;
end;

function BM:deactivate()
    local ingameMap = g_currentMission.ingameMap;
    ingameMap:resetSettings();
end;

function BM:show()
    self.settings.visible = true;
    g_currentMission.ingameMap:setVisible(false);
    self:activate();
end;

function BM:hide()
    self.settings.visible = false;
    self:deactivate();
    g_currentMission.ingameMap:setVisible(true);
end;

function BM:renderModHelp()
    if g_gameSettings:getValue("showHelpMenu") then
        if (self.settings.help_full) then
            g_currentMission:addHelpButtonText(g_i18n:getText("input_BM_SHOW_CONFIG_GUI"), InputBinding.BM_SHOW_CONFIG_GUI, nil, GS_PRIO_HIGH);
            g_currentMission:addHelpButtonText(g_i18n:getText("input_BM_NEXT"), InputBinding.BM_NEXT, nil, GS_PRIO_HIGH);
            g_currentMission:addHelpButtonText(g_i18n:getText("input_BM_PREV"), InputBinding.BM_PREV, nil, GS_PRIO_HIGH);
            g_currentMission:addHelpButtonText(g_i18n:getText("input_BM_RELOAD"), InputBinding.BM_RELOAD, nil, GS_PRIO_HIGH);
            g_currentMission:addHelpButtonText(g_i18n:getText("input_BM_ZOOM_IN"), InputBinding.BM_ZOOM_IN, nil, GS_PRIO_HIGH);
            g_currentMission:addHelpButtonText(g_i18n:getText("input_BM_ZOOM_OUT"), InputBinding.BM_ZOOM_OUT, nil, GS_PRIO_HIGH);
        end ;
    end ;
end;

function BM:renderMapMode()
    setTextAlignment(RenderText.ALIGN_LEFT);
    setTextBold(false);
    setTextColor(1, 1, 1, 1);
    -- time to refresh
    if (self.settings.state ~= 0) then
        renderText(self.overlayPosX + 0.003, self.overlayPosY + 0.007, 0.013, "[" .. math.ceil((self.const.frequency[self.settings.frequency]) - (self.timer / 1000)) .. "]");
    end ;
    -- map mode info (more fruits = more pages)
    local modeInfo = g_i18n:getText("BM_MapMode_S" .. self.settings.state);
    if (self.numberOfFruitPages > 1) then
        if (self.settings.state == 0) then
            -- default ;)
        elseif (self.settings.state > 0) and (self.settings.state < self.numberOfFruitPages + 1) then
            modeInfo = g_i18n:getText("BM_MapMode_S1") .. " " .. self.settings.state;
        else
            modeInfo = g_i18n:getText("BM_MapMode_S" .. (self.settings.state - (self.numberOfFruitPages - 1)))
        end ;
    end ;
    renderText(self.overlayPosX, self.overlayPosY - 0.02, 0.015, g_i18n:getText("BM_MapMode") .. " " .. modeInfo);
    setTextAlignment(RenderText.ALIGN_LEFT); -- reset
end;

function BM:renderSelectedMinimap()
    self.mapWidth = self.const.mapSizes[self.settings.sizeMode][1] * self.pixelWidth;
    self.mapHeight = self.const.mapSizes[self.settings.sizeMode][2] * self.pixelHeight;
    self.alpha = self.settings.transparent and self.const.transparent[self.settings.transMode] or 1;
    self.visWidth = 0.3;
    -- mapupdate
    self.settings.mapUpdate = false;
end;

function BM:generateFruitOverlay()
    local origState = g_inGameMenu.mapOverviewSelector.state;
    g_inGameMenu.mapOverviewSelector.state = self.settings.state;
    g_inGameMenu:generateFruitOverlay();
    g_inGameMenu.mapOverviewSelector.state = origState;
    self.timer = 0;
end;

function BM:saveBMSettings(fileName)
    local xml = createXMLFile("BetterMinimap", fileName, "BetterMinimap");
    setXMLBool(xml, "BetterMinimap.visible", self.settings.visible);
    setXMLBool(xml, "BetterMinimap.help", self.settings.help_min);
    setXMLInt(xml, "BetterMinimap.frequency", self.settings.frequency);
    setXMLInt(xml, "BetterMinimap.sizeMode", self.settings.sizeMode);
    setXMLBool(xml, "BetterMinimap.transparency", self.settings.transparent);
    setXMLInt(xml, "BetterMinimap.transMode", self.settings.transMode);
    saveXMLFile(xml);
    delete(xml);
end;

function BM:loadBMSettings(fileName)
    local xml = loadXMLFile("BetterMinimap", fileName);
    self.settings.visible = Utils.getNoNil(getXMLBool(xml, "BetterMinimap.visible"), self.settings.visible);
    self.settings.help_min = Utils.getNoNil(getXMLBool(xml, "BetterMinimap.help"), self.settings.help_min);
    self.settings.frequency = Utils.getNoNil(getXMLInt(xml, "BetterMinimap.frequency"), self.settings.frequency);
    self.settings.sizeMode = Utils.getNoNil(getXMLInt(xml, "BetterMinimap.sizeMode"), self.settings.sizeMode);
    self.settings.transparent = Utils.getNoNil(getXMLBool(xml, "BetterMinimap.transparency"), self.settings.transparent);
    self.settings.transMode = Utils.getNoNil(getXMLInt(xml, "BetterMinimap.transMode"), self.settings.transMode);
    delete(xml);
end;

BM:init();
addModEventListener(BM);