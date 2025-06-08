classdef UIDropdown < ndi.gui.component.internal.uie.UIElement & ...
                       ndi.gui.component.internal.uie.UIVisualComponent & ...
                       ndi.gui.component.internal.uie.UITextComponent & ...
                       ndi.gui.component.internal.uie.UIInteractiveComponent & ...
                       ndi.gui.component.internal.uie.UIValue & ...
                       ndi.gui.component.internal.uie.UIValueChangedFcn
    % UIDROPDOWN Describes a dropdown (pop-up menu) UI component.

    properties
        % Items - A cell array of strings to display as choices in the dropdown.
        %
        % NOTE: This property MUST be a cell array of character vectors.
        Items (:,1) cell = {}
        
        % Editable - Controls whether the user can type a custom value.
        %
        % Must be either 'on' or 'off' (default).
        Editable (1,:) char {mustBeMember(Editable,{'on','off'})} = 'off'
    end
    
    % Note: The 'Value' property (inherited) holds the currently selected item.
    
    methods (Static)
        function obj = fromAlphaNumericStruct(className, alphaS_in, options)
            % FROMALPHANUMERICSTRUCT Create a UIDropdown from an alphanumeric struct.
            %
            % This method overrides the base class implementation to provide custom
            % handling for the 'Items' property.
            arguments
                className (1,1) string
                alphaS_in (1,1) struct
                options.errorIfFieldNotPresent (1,1) logical = false
                options.dispatch (1,1) logical = true
            end
            
            S_in = alphaS_in;
            
            if isfield(S_in, 'Items') && (ischar(S_in.Items) || isstring(S_in.Items))
                items_str = char(S_in.Items);
                if isempty(items_str)
                    items_cell = {};
                else
                    % Assuming default delimiter from StructSerializable
                    items_cell = strsplit(items_str, ', ');
                end

                if isrow(items_cell)
                    S_in.Items = items_cell'; % Enforce column vector
                else
                    S_in.Items = items_cell;
                end
            end
            
            % Call the base class's method with dispatch turned OFF to perform the final conversion.
            obj = fromAlphaNumericStruct@ndi.util.StructSerializable(className, S_in, ...
                'errorIfFieldNotPresent', options.errorIfFieldNotPresent, ...
                'dispatch', false);
        end
    end
end