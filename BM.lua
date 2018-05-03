BM = {};
BM.moddir = g_currentModDirectory;
BM.modName = g_currentModName;
if BM.moddir:sub(-1) ~= '/' then
    BM.moddir = BM.moddir .. '/';
end ;

BM.refreshFreq = 60000;

BM.mapEvents = {};
BM.panFactor = 0.0007;
BM.zoomFactor = 0.0007;

function BM:init(width)
    self.overlayPosX = 0.003;
    self.overlayPosY = 0.005;
    self.overlayWidth = width or 1 / 3;
    self.pixelWidth = self.overlayWidth / 1024.0;
    self.pixelHeight = self.pixelWidth * g_screenAspectRatio;
    self.screenOffsetX = self.overlayPosX + (92 * self.pixelWidth); -- 92
    self.screenOffsetY = self.overlayPosY + (46 * self.pixelHeight); --46
    self.screenWidth = 456 * self.pixelWidth;
    self.screenHeight = 350 * self.pixelHeight;
end;

function BM:loadMap(name)
    self.showMap = false;
    self.isActive = false;
    self.showState = 0;
    self.needUpdate = true;
    self.timer = 0;
    self.fullScreen = false;
    self.centerXPos = 0.5;
    self.centerZPos = 0.5;
    self.isPanning = false;
    self.visWidth = 0.3;
    self.mapWidth, self.mapHeight = self.screenWidth, self.screenHeight;
end;

function BM:deleteMap()
    self:hide();
end;

function BM:mouseEvent(posX, posY, isDown, isUp, button)
end;

function BM:keyEvent(unicode, sym, modifier, isDown)
end;

function BM:show()
    self.showMap = true;
    g_currentMission.ingameMap:setVisible(false);
    self:activate();
end;

function BM:hide()
    self:deactivate();
    self.showMap = false;
    g_currentMission.ingameMap:setVisible(true);
end;

function BM:update(dt)
    if not self.showMap then
        self:show();
    end ;

    local ingameMap = g_currentMission.ingameMap;

    if g_gui:getIsGuiVisible() and g_gui.currentGuiName == "InGameMenu" then
        self.needUpdate = true;
    end ;

    if self.timer < self.refreshFreq then
        self.timer = self.timer + dt;
    else
        self.needUpdate = true;
    end ;

    if self.isActive and g_gui.currentGui == nil then

        if InputBinding.hasEvent(InputBinding.BM_NEXT) then
            self.showState = self.showState + 1;
            if self.showState > 3 then
                self.showState = 0
            end ;
            if self.showState ~= 0 then
                self:generateFruitOverlay();
            end ;
        end ;

        if InputBinding.hasEvent(InputBinding.BM_RELOAD) then
            self:generateFruitOverlay();
        end ;

        if InputBinding.hasEvent(InputBinding.BM_PREV) then
            self.showState = self.showState - 1;
            if self.showState < 0 then
                self.showState = 3
            end ;
            if self.showState ~= 0 then
                self:generateFruitOverlay();
            end ;
        end ;

        if InputBinding.hasEvent(InputBinding.TOGGLE_MAP_SIZE) then
            -- reload field states if maximized map
            self:generateFruitOverlay();

            self.fullScreen = not self.fullScreen;
            if self.fullScreen then
                self.mapWidth, self.mapHeight = ingameMap.maxMapWidth,
                ingameMap.maxMapHeight;
                self.alpha = 0.7;
            else
                self.mapWidth, self.mapHeight = self.screenWidth, self.screenHeight;
                self.alpha = 1;
            end ;
        end ;

        if not self.fullScreen then
            if InputBinding.isPressed(InputBinding.BM_MAP_ZOOM_IN) then
                ingameMap:zoom(-self.zoomFactor * dt);
                self.visWidth = ingameMap.mapVisWidthMin;
            end ;
            if InputBinding.isPressed(InputBinding.BM_MAP_ZOOM_OUT) then
                ingameMap:zoom(self.zoomFactor * dt);
                self.visWidth = ingameMap.mapVisWidthMin;
            end ;
        end ;

        if self.needUpdate then
            self.needUpdate = false;
            self:generateFruitOverlay();
        end ;
    end ;
end;

function BM:draw()
    if self.isActive then

        local ingameMap = g_currentMission.ingameMap;

        ingameMap:zoom(0);
        IngameMap.iconZoom = ingameMap.maxIconZoom;

        ingameMap:updatePlayerPosition();
        ingameMap:setPosition(self.screenOffsetX, self.screenOffsetY);
        ingameMap:setSize(self.mapWidth, self.mapHeight);

        if self.fullScreen then
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
            renderOverlay(foliageOverlay, BM.screenOffsetX, BM.screenOffsetX, self.mapWidth, self.mapHeight);
        end ;

        ingameMap:renderHotspots(leftBorderReached, rightBorderReached, topBorderReached, bottomBorderReached, false, self.fullScreen);
        ingameMap:renderPlayerArrows(false, leftBorderReached, rightBorderReached, topBorderReached, bottomBorderReached, true);
        ingameMap:renderHotspots(leftBorderReached, rightBorderReached, topBorderReached, bottomBorderReached, true, self.fullScreen);
        ingameMap:renderPlayersCoordinates();
        ingameMap:drawLatencyToServer();
        ingameMap:drawInputBinding();
    end ;
end;

function BM:activate()
    self.isActive = true;
    self.fullScreen = false;
    if not g_inGameMenu.mapSelectorMapping then
        g_inGameMenu:setupMapOverview();
    end ;
end;

function BM:deactivate()
    self.isActive = false;
    local ingameMap = g_currentMission.ingameMap;
    ingameMap:resetSettings();
end;

function BM:generateFruitOverlay()
    local origState = g_inGameMenu.mapOverviewSelector.state;
    g_inGameMenu.mapOverviewSelector.state = self.showState;
    g_inGameMenu:generateFruitOverlay();
    g_inGameMenu.mapOverviewSelector.state = origState;
    self.timer = 0;
end;

BM:init();
addModEventListener(BM);