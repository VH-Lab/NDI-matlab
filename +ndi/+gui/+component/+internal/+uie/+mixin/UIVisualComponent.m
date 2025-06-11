classdef UIVisualComponent < handle
    % UIVISUALCOMPONENT A mixin for describing visual UI properties.
    properties
        Position (1,4) {mustBeNumeric} = [0 0 100 22]
        Units (1,:) char {mustBeMember(Units,{'pixels','normalized','inches','centimeters','points','characters'})} = 'pixels'
        BackgroundColor {ndi.validators.mustBeValidColor(BackgroundColor)} = [0.94 0.94 0.94]
        Layout (1,1) ndi.gui.component.internal.uie.mixin.UILayout = ndi.gui.component.internal.uie.mixin.UILayout('Row',[],'Column',[])
        Tooltip (1,:) char = ''
    end
end