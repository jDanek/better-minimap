BM = {};
BM.moddir = g_currentModDirectory;
BM.modName = g_currentModName;
BM.mapEvents = {};

-- refresh frequence (in sec)
BM.refreshFreq = {}
BM.refreshFreq[1] = 15;
BM.refreshFreq[2] = 30;
BM.refreshFreq[3] = 45;
BM.refreshFreq[4] = 60;
BM.refreshFreqCounter = 4;


-- minimap sizes {width, height}
BM.sizeDefinition = {};
BM.sizeDefinition[1] = { 456, 350 }; -- normal size
BM.sizeDefinition[2] = { 800, 350 }; -- wide size
BM.sizeDefinition[3] = { 800, 600 }; -- larger size

source(Utils.getFilename("src/gui/ConfigGui.lua", BM.moddir));

function BM:init(width)
    self.overlayPosX = 0.003;
    self.overlayPosY = 0.005;
    self.overlayWidth = width or 1 / 3;
    self.pixelWidth = self.overlayWidth / 1024.0;
    self.pixelHeight = self.pixelWidth * g_screenAspectRatio;
    self.screenOffsetX = self.overlayPosX + (92 * self.pixelWidth);
    self.screenOffsetY = self.overlayPosY + (46 * self.pixelHeight);
    self.zoomFactor = 0.0007;
    -- set default map size
    self.mapWidth = self.sizeDefinition[1][1] * self.pixelWidth;
    self.mapHeight = self.sizeDefinition[1][2] * self.pixelHeight;
end;

function BM:loadMap(name)
    self.showBetterMinimap = false;
    self.showModHelp = false;
    self.needUpdateFruitOverlay = true;
    self.isFullScreen = false;

    self.showState = 0;
    self.timer = 0;

    self.centerXPos = 0.5;
    self.centerZPos = 0.5;
    self.isPanning = false;
    self.visWidth = 0.3;

    self.selectedSizeDefinition = 1;
    self.selectedRefreshFreq = 4;
    self.toggleAlpha = false;

    -- config gui
    self.ConfigGui = ConfigGui:new()
    g_gui:loadGui(Utils.getFilename("src/gui/ConfigGui.xml", BM.moddir), "ConfigGui", self.ConfigGui)

    -- counting fruits (need for right switching map mode)
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
    if not self.showBetterMinimap then
        self.showBetterMinimap = true;
        g_currentMission.ingameMap:setVisible(false);
        self.activate();
    end ;

    local ingameMap = g_currentMission.ingameMap;

    if g_gui:getIsGuiVisible() and g_gui.currentGuiName == "InGameMenu" then
        self.needUpdateFruitOverlay = true;
    end ;

    if self.timer < (self.refreshFreq[self.selectedRefreshFreq] * 1000) then
        self.timer = self.timer + dt;
    else
        self.needUpdateFruitOverlay = true;
    end ;

    if self.showBetterMinimap and g_gui.currentGui == nil then

        g_currentMission:addHelpButtonText(g_i18n:getText("input_BM_TOGGLE_HELP"), InputBinding.BM_TOGGLE_HELP, nil, GS_PRIO_HIGH);
        if (InputBinding.hasEvent(InputBinding.BM_TOGGLE_HELP)) then
            self.showModHelp = not self.showModHelp;
        end ;

        self:renderModHelp();

        if (InputBinding.hasEvent(InputBinding.BM_TOGGLE_GUI)) then
            if self.ConfigGui.isOpen then
                self.ConfigGui:onClickBack()
            elseif g_gui.currentGui == nil then
                g_gui:showGui("ConfigGui")
            end
        end ;

        if (InputBinding.hasEvent(InputBinding.BM_RELOAD)) then
            self.needUpdateFruitOverlay = true;
        end ;

        if (InputBinding.hasEvent(InputBinding.BM_NEXT)) then
            self.showState = self.showState + 1;
            if self.showState > (self.numberOfFruitPages + 2) then
                self.showState = 0
            end ;
            if self.showState ~= 0 then
                self.needUpdateFruitOverlay = true;
            end ;
        end ;

        if (InputBinding.hasEvent(InputBinding.BM_PREV)) then
            self.showState = self.showState - 1;
            if self.showState < 0 then
                self.showState = (self.numberOfFruitPages + 2);
            end ;
            if self.showState ~= 0 then
                self.needUpdateFruitOverlay = true;
            end ;
        end ;

        if (InputBinding.hasEvent(InputBinding.TOGGLE_MAP_SIZE)) then
            -- reload field states if change size map
            self.needUpdateFruitOverlay = true;
            -- toggle fullscreen mode
            self.isFullScreen = not self.isFullScreen;
            if (self.isFullScreen) then
                self.mapWidth, self.mapHeight = ingameMap.maxMapWidth, ingameMap.maxMapHeight;
                self.alpha = 0.7;
            else
                self:renderSelectedMinimap();
            end ;
        end ;

        if (InputBinding.hasEvent(InputBinding.BM_TOGGLE_ALPHA)) then
            self.toggleAlpha = not self.toggleAlpha;
            self:renderSelectedMinimap();
        end ;

        if not self.isFullScreen then
            if (InputBinding.hasEvent(InputBinding.BM_CHANGE_SIZE)) then
                self.selectedSizeDefinition = self.selectedSizeDefinition + 1;
                if self.selectedSizeDefinition > 3 then
                    self.selectedSizeDefinition = 1
                end ;
                self:renderSelectedMinimap();
            end ;
            if (InputBinding.isPressed(InputBinding.BM_ZOOM_IN)) then
                ingameMap:zoom(-self.zoomFactor * dt);
                self.visWidth = ingameMap.mapVisWidthMin;
            end ;
            if (InputBinding.isPressed(InputBinding.BM_ZOOM_OUT)) then
                ingameMap:zoom(self.zoomFactor * dt);
                self.visWidth = ingameMap.mapVisWidthMin;
            end ;
        end ;

        if (self.needUpdateFruitOverlay) then
            self.needUpdateFruitOverlay = false;
            self:generateFruitOverlay();
        end ;
    end ;
end;

function BM:draw()
    if (self.showBetterMinimap) then

        local ingameMap = g_currentMission.ingameMap;

        ingameMap:zoom(0);
        IngameMap.iconZoom = ingameMap.maxIconZoom;

        ingameMap:updatePlayerPosition();
        ingameMap:setPosition(self.screenOffsetX, self.screenOffsetY);
        ingameMap:setSize(self.mapWidth, self.mapHeight);

        if (self.isFullScreen) then
            ingameMap.mapVisWidthMin = 1;
        else
            ingameMap.mapVisWidthMin = self.visWidth;
        end ;

        ingameMap.centerXPos = ingameMap.normalizedPlayerPosX;
        ingameMap.centerZPos = ingameMap.normalizedPlayerPosZ;

        local leftBorderReached, rightBorderReached, topBorderReached, bottomBorderReached = ingameMap:drawMap(self.alpha)
        local foliageOverlay = g_inGameMenu.foliageStateOverlay;

        if self.showState ~= 0 and getIsFoliageStateOverlayReady(foliageOverlay) then
            setOverlayUVs(foliageOverlay, unpack(ingameMap.mapUVs));
            renderOverlay(foliageOverlay, BM.screenOffsetX, BM.screenOffsetY, self.mapWidth, self.mapHeight);
        end ;

        self:renderMapMode();

        ingameMap:renderHotspots(leftBorderReached, rightBorderReached, topBorderReached, bottomBorderReached, false, self.isFullScreen);
        ingameMap:renderPlayerArrows(false, leftBorderReached, rightBorderReached, topBorderReached, bottomBorderReached, true);
        ingameMap:renderHotspots(leftBorderReached, rightBorderReached, topBorderReached, bottomBorderReached, true, self.isFullScreen);
        ingameMap:renderPlayersCoordinates();
        ingameMap:drawLatencyToServer();
        ingameMap:drawInputBinding();
    end ;
end;

function BM:activate()
    if not g_inGameMenu.mapSelectorMapping then
        g_inGameMenu:setupMapOverview();
    end ;
end;

function BM:deactivate()
    local ingameMap = g_currentMission.ingameMap;
    ingameMap:resetSettings();
end;

function BM:renderModHelp()
    if g_gameSettings:getValue("showHelpMenu") then
        if (self.showModHelp) then
            g_currentMission:addHelpButtonText(g_i18n:getText("input_BM_NEXT"), InputBinding.BM_NEXT, nil, GS_PRIO_HIGH);
            g_currentMission:addHelpButtonText(g_i18n:getText("input_BM_PREV"), InputBinding.BM_PREV, nil, GS_PRIO_HIGH);
            g_currentMission:addHelpButtonText(g_i18n:getText("input_BM_RELOAD"), InputBinding.BM_RELOAD, nil, GS_PRIO_HIGH);
            g_currentMission:addHelpButtonText(g_i18n:getText("input_BM_ZOOM_IN"), InputBinding.BM_ZOOM_IN, nil, GS_PRIO_HIGH);
            g_currentMission:addHelpButtonText(g_i18n:getText("input_BM_ZOOM_OUT"), InputBinding.BM_ZOOM_OUT, nil, GS_PRIO_HIGH);
            g_currentMission:addHelpButtonText(g_i18n:getText("input_BM_CHANGE_SIZE"), InputBinding.BM_CHANGE_SIZE, nil, GS_PRIO_HIGH);
            g_currentMission:addHelpButtonText(g_i18n:getText("input_BM_TOGGLE_ALPHA"), InputBinding.BM_TOGGLE_ALPHA, nil, GS_PRIO_HIGH);
        end ;

    end
end;

function BM:renderMapMode()
    setTextAlignment(RenderText.ALIGN_LEFT);
    setTextBold(false);
    setTextColor(1, 1, 1, 1);
    -- time to refresh
    renderText(self.screenOffsetX + 0.003, self.screenOffsetY + 0.007, 0.013, "[" .. math.ceil((self.refreshFreq[self.selectedRefreshFreq]) - (self.timer / 1000)) .. "]");
    -- map mode info (more fruits = more pages)
    local modeInfo = g_i18n:getText("BM_MapMode_S" .. self.showState);
    if (self.numberOfFruitPages > 1) then
        if (self.showState == 0) then
            -- default ;)
        elseif (self.showState > 0) and (self.showState < self.numberOfFruitPages + 1) then
            modeInfo = g_i18n:getText("BM_MapMode_S1") .. " " .. self.showState;
        else
            modeInfo = g_i18n:getText("BM_MapMode_S" .. (self.showState - (self.numberOfFruitPages - 1)))
        end ;
    end ;
    renderText(self.screenOffsetX, self.screenOffsetY - 0.02, 0.015, g_i18n:getText("BM_MapMode") .. " " .. modeInfo);
    setTextAlignment(RenderText.ALIGN_LEFT); -- reset
end;

function BM:renderSelectedMinimap()
    self.mapWidth = self.sizeDefinition[self.selectedSizeDefinition][1] * self.pixelWidth;
    self.mapHeight = self.sizeDefinition[self.selectedSizeDefinition][2] * self.pixelHeight;
    self.alpha = self.toggleAlpha and 0.7 or 1;
    self.visWidth = 0.3;
end;

function BM:generateFruitOverlay()
    local origState = g_inGameMenu.mapOverviewSelector.state;
    g_inGameMenu.mapOverviewSelector.state = self.showState;
    g_inGameMenu:generateFruitOverlay();
    g_inGameMenu.mapOverviewSelector.state = origState;
    self.timer = 0;

end;

--[[
Methods for integration config
]]

function BM:forceMapUpdate()
    self.timer=0;
end;

function BM:changeFreq(state)
    self.selectedRefreshFreq = state;
end;

function BM:setAlpha(state)
    self.toggleAlpha = state;
end

BM:init();
addModEventListener(BM);