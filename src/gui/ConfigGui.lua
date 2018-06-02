ConfigGui = {};
local ConfigGui_mt = Class(ConfigGui, ScreenElement);

function ConfigGui:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = ConfigGui_mt;
    end ;
    local self = ScreenElement:new(target, custom_mt);
    self.returnScreenName = "";
    return self;
end

function ConfigGui:onOpen()
    ConfigGui:superClass().onOpen(self);

    self.isVisible:setIsChecked(BM.settings.visible);
    self.help:setIsChecked(BM.settings.help_min);
    self.activeFreq:setState(BM.settings.frequency, false);
    self.activeSizemode:setState(BM.settings.sizeMode, false);
    self.isTransparent:setIsChecked(BM.settings.transparent);
    self.transMode:setState(BM.settings.transMode, false);
end

function ConfigGui:onClose()
    ConfigGui:superClass().onClose(self);
end;

function ConfigGui:onClickBack()
    ConfigGui:superClass().onClickBack(self);
end;

function ConfigGui:onClickOk()
    ConfigGui:superClass().onClickOk(self);

    BM.settings.visible = self.isVisible:getIsChecked();
    BM.settings.help_min = self.help:getIsChecked();
    BM.settings.frequency = self.activeFreq:getState();
    BM.settings.sizeMode = self.activeSizemode:getState();
    BM.settings.transparent = self.isTransparent:getIsChecked();
    BM.settings.transMode = self.transMode:getState();

    -- mapUpdate
    BM.settings.mapUpdate = true;
    -- saveToXML
    BM.settings.saveSettings = true;
    -- close dialog
    self:onClickBack();
end;

function ConfigGui:setHelpBoxText(text)
    self.ingameMenuHelpBoxText:setText(text);
    self.ingameMenuHelpBox:setVisible(text ~= "");
end;

function ConfigGui:onFocusElement(element)
    if (element.toolTip ~= nil) then
        self:setHelpBoxText(element.toolTip);
    end ;
end;

function ConfigGui:onLeaveElement(element)
    self:setHelpBoxText("");
end;

--- Events ---
function ConfigGui:onToggleVisible(element)
    self.isVisible = element;
end;

function ConfigGui:onToggleHelp(element)
    self.help = element;
end;

function ConfigGui:onChangeFrequency(element)
    self.activeFreq = element;
    local freq = {};
    for i = 1, table.getn(BM.const.frequency), 1 do
        freq[i] = tostring(BM.const.frequency[i]) .. "s";
    end
    element:setTexts(freq);
end;

function ConfigGui:onChangeSizemode(element)
    self.activeSizemode = element;
    local sm = {};
    for i = 1, table.getn(BM.const.mapNames), 1 do
        sm[i] = tostring(BM.const.mapNames[i]);
    end
    element:setTexts(sm);
end;

function ConfigGui:onToggleTransparent(element)
    self.isTransparent = element;
end;

function ConfigGui:onChangeTransMode(element)
    self.transMode = element;
    local tm = {};
    for i = 1, table.getn(BM.const.transparent), 1 do
        tm[i] = tostring(BM.const.transparent[i]);
    end
    element:setTexts(tm);
end;


