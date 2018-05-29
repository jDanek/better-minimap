ConfigGui = {}
local ConfigGui_mt = Class(ConfigGui, ScreenElement)

function ConfigGui:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = ConfigGui_mt
    end
    local self = ScreenElement:new(target, custom_mt)
    self.returnScreenName = ""
    return self
end

function ConfigGui:onOpen()
    ConfigGui:superClass().onOpen(self);

    self:setSelectedFreq(BM.selectedRefreshFreq);
end

function ConfigGui:onClose()
    ConfigGui:superClass().onClose(self)
end

function ConfigGui:onClickBack()
    ConfigGui:superClass().onClickBack(self)
end

function ConfigGui:onClickOk()
    ConfigGui:superClass().onClickOk(self)

    BM:setAlpha(self.stateAlpha:getIsChecked());
    BM:changeFreq(self.selectedFreq:getState());

    self:onClickBack()
end

function ConfigGui:setHelpBoxText(text)
    self.ingameMenuHelpBoxText:setText(text)
    self.ingameMenuHelpBox:setVisible(text ~= "")
end

function ConfigGui:onFocusElement(element)
    if (element.toolTip ~= nil) then
        self:setHelpBoxText(element.toolTip)
    end ;
end;

function ConfigGui:onLeaveElement(element)
    self:setHelpBoxText("")
end;

function ConfigGui:setSelectedFreq(index)
    self.selectedFreq:setState(index, false);
end;

function ConfigGui:onChangeFreq(element)
    self.selectedFreq = element
    local freq = {}
    for i = 1, BM.refreshFreqCounter, 1 do
        freq[i] = tostring(BM.refreshFreq[i]) .. "s"
    end
    element:setTexts(freq)
end;

function ConfigGui:onToggleAlpha(element)
    self.stateAlpha = element;
end;


