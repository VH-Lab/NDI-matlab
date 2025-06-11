classdef UIItems < handle
    % UIITEMS A mixin class that provides the 'Items' property.
    %
    % This is for components that display a list of choices, such as
    % listboxes, dropdowns, and context menus.

    properties
        % Items - A cell array of strings to display as choices.
        %
        % NOTE: This property MUST be a column cell array of character vectors,
        % e.g., {'Choice 1'; 'Choice 2'}. This strictness ensures reliable
        % serialization to and from a single delimited string.
        Items (:,1) cell = {}
    end

end