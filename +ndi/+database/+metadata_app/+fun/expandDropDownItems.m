function [items, itemsData] = expandDropDownItems(items, itemsData, schemaName)
%expandDropDownItems Expands a dropdown list by adding default and new options.
%
%   [items, itemsData] = expandDropDownItems(items, itemsData, schemaName)
%   takes an existing cell array of dropdown items (items) and their
%   corresponding data (itemsData), and expands it by adding default options.
%   The default options include selecting an existing item and creating a
%   new item with a specified schema name.
%
%   Input Arguments:
%   - items: Existing cell array of dropdown items.
%   - itemsData: Corresponding data for each item in items.
%   - schemaName: Name of the schema for new items.
%
%   Output Arguments:
%   - items: Updated cell array with added default options.
%   - itemsData: Updated data array with corresponding default values.

    % Todo:
    % Add option to add select
    % Add option to add create
    % Possibly add option for editing items...

    items = [ ...
        sprintf("<select a %s>", schemaName); ...
        sprintf("<create a new %s>", schemaName); ...
        items ];

    itemsData = [...
        missing; ...
        "create new"; ...
        itemsData ];
end