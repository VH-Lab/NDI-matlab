classdef UIContextMenu < ndi.util.StructSerializable
    % UICONTEXTMENU Describes a context menu (right-click menu).
    %
    % This class holds the descriptive properties for a context menu, including
    % the text for each menu item and the names of the callback functions
    % that should be executed when those items are clicked.

    properties
        % Tag - A string to identify this context menu object.
        Tag (1,:) char = ''

        % Items - A cell array of strings for each menu item's label.
        Items (:,1) cell = {}
        
        % Callbacks - A cell array of callback function names.
        %
        % This cell array should have the same number of elements as 'Items'.
        % Each entry is a character vector with the name of a public method
        % in the TabController that will be executed when the corresponding
        % menu item is clicked.
        Callbacks (:,1) cell = {}
    end
    
    methods (Static)
        function obj = fromAlphaNumericStruct(className, alphaS_in, options)
            % FROMALPHANUMERICSTRUCT Create a UIContextMenu from an alphanumeric struct.
            %
            % This override handles the conversion of 'Items' and 'Callbacks'
            % from delimited strings back to cell arrays.
            arguments
                className (1,1) string
                alphaS_in (1,1) struct
                options.errorIfFieldNotPresent (1,1) logical = false
                options.dispatch (1,1) logical = true
            end
            
            S_in = alphaS_in;
            
            % Handle 'Items' property
            if isfield(S_in, 'Items') && (ischar(S_in.Items) || isstring(S_in.Items))
                items_str = char(S_in.Items);
                if isempty(items_str), S_in.Items = {}; else, S_in.Items = strsplit(items_str, ', ')'; end
            end
            
            % Handle 'Callbacks' property
            if isfield(S_in, 'Callbacks') && (ischar(S_in.Callbacks) || isstring(S_in.Callbacks))
                cb_str = char(S_in.Callbacks);
                if isempty(cb_str), S_in.Callbacks = {}; else, S_in.Callbacks = strsplit(cb_str, ', ')'; end
            end
            
            % Call the base class's method with dispatch turned OFF
            obj = fromAlphaNumericStruct@ndi.util.StructSerializable(className, S_in, ...
                'errorIfFieldNotPresent', options.errorIfFieldNotPresent, ...
                'dispatch', false);
        end
    end
end