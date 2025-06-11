classdef UIBorderType < handle
    % UIBORDERTYPE A mixin class that provides the 'BorderType' property.
    %
    % This is for container components, like panels, that can have different
    % visual border styles.

    properties
        % BorderType - The style of the border drawn around the component.
        %
        % Must be one of 'none', 'line' (default), 'beveledin', 'beveledout',
        % 'etchedin', or 'etchedout'.
        BorderType (1,:) char {mustBeMember(BorderType,{'none','line','beveledin','beveledout','etchedin','etchedout'})} = 'line'
    end

end