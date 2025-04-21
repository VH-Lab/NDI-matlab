function [items, itemsData] = expandDropDownItems(items, itemsData, schemaName, options)
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

    %   Note: itemsOptions will be displayed in the dropdown, itemsDataOptions
    %   will be the values of the control when a selection is made.

    % Todo:
    % Add option to add select
    % Add option to add create
    % Possibly add option for editing items...

    arguments
        items
        itemsData
        schemaName
        options.AddSelectOption (1,1) logical = false
        options.AddCreateOption (1,1) logical = false
        options.AddManageOption (1,1) logical = false
    end

    [itemsOptions, itemsDataOptions] = deal(string.empty);

    if options.AddSelectOption
        itemsOptions = sprintf("<select a %s>", schemaName);
        itemsDataOptions = [itemsDataOptions; missing];
    end

    if options.AddCreateOption
        itemsOptions = [itemsOptions; sprintf("<create a new %s>", schemaName)];
        itemsDataOptions = [itemsDataOptions; "create new"];
    end

    if options.AddManageOption
        itemsOptions = [itemsOptions; sprintf("<manage %s>", schemaName)];
        itemsDataOptions = [itemsDataOptions; "manage"];
    end

    items = [ itemsOptions; items];
    itemsData = [itemsDataOptions; itemsData ];
end
