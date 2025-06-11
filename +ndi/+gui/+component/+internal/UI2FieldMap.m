classdef UI2FieldMap
    % UI2FIELDMAP - A class for mapping a UI property to a data field path.
    %
    % This class defines a single, one-way mapping from a property of a UI
    % component (like its 'Value' or 'Text') to a specific, potentially nested,
    % field within a data structure. It is a key component of the data-binding
    % framework for the TabController.
    %
    % See also: ndi.gui.components.internal.UITagProperties

    properties
        % The property of the UI component to link (e.g., 'Value', 'Text', 'Visible').
        % This is the name of the property on the MATLAB uicontrol object that
        % will be read from or written to.
        UIProperty (1,:) char = 'Value'

        % The dot-delimited path in the data struct (e.g., 'mydata.name').
        % This string specifies the location within the 'data' struct where the
        % value should be retrieved from or stored to.
        dataField (1,:) char = ''

        % Defines the selection context for the dataField.
        % If dataField points to a field within an array of structs (e.g., 'people.email'),
        % SelectionMap provides the index into that array. It can be a fixed integer
        % (like 1) or a char/string path to another field in the data struct that
        % holds the current index (e.g., "selection.person_index").
        SelectionMap {mustBeValidSelectionMap(SelectionMap)}
    end

    methods
        function obj = UI2FieldMap(args)
            % UI2FIELDMAP - Construct an instance of the UI2FieldMap class.
            %
            % This constructor uses repeating name-value pair arguments to allow for
            % flexible object creation.
            %
            % Example:
            %   % Create a map that links a label's 'Text' property to the 'name'
            %   % field of the currently selected person in a list.
            %   map = ndi.gui.components.internal.UI2FieldMap(...
            %           "UIProperty", "Text", ...
            %           "dataField", "persons.name", ...
            %           "SelectionMap", "current_selection_index");
            
            arguments (Repeating)
                args.name (1,1) string % The name of the property to set.
                args.value             % The value to assign to the property.
            end

            % Loop through the provided name-value pairs
            for i = 1:numel(args)
                propName = args(i).name;
                propValue = args(i).value;
                
                if isprop(obj, propName)
                    obj.(propName) = propValue;
                else
                    error('UI2FieldMap:InvalidPropertyName', ...
                        'Invalid property name: "%s"', propName);
                end
            end
        end
    end
end

% --- Validation function ---
function mustBeValidSelectionMap(a)
    % This function validates that the input for SelectionMap is either
    % empty, a scalar integer, a character row vector, or a string scalar.
    if ~( isempty(a) || (isnumeric(a) && isscalar(a) && (fix(a)==a)) || (ischar(a) && size(a,1)<=1) || (isstring(a) && isscalar(a)) )
        error(['Property ''SelectionMap'' must be empty, a scalar integer, ' ...
               'a character row vector, or a string scalar.']);
    end
end
