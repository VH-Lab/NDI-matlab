% Organization.m (in +ndi/+gui/+component/+metadataEditor/+class/)
classdef Organization < ndi.util.StructSerializable
    %ORGANIZATION Represents an organization with a full name and a digital identifier.
    %   Inherits from ndi.util.StructSerializable for common conversion methods.

    properties
        fullName (1,:) char = ''
        DigitalIdentifier (1,1) ndi.gui.component.metadataEditor.class.OrganizationDigitalIdentifier
    end

    methods
        function obj = Organization()
            %ORGANIZATION Construct an instance of this class.
            %   Initializes handle object properties here to ensure every new
            %   Organization object gets its own, distinct DigitalIdentifier instance.
            
            obj.DigitalIdentifier = ndi.gui.component.metadataEditor.class.OrganizationDigitalIdentifier();
        end
    end

    methods (Static)
        function obj = fromAlphaNumericStruct(alphaS_in, options)
            %FROMALPHANUMERICSTRUCT Creates Organization object(s) from an AlphaNumericStruct array.
            arguments
                alphaS_in struct {ndi.validators.mustBeAlphaNumericStruct(alphaS_in)}
                options.errorIfFieldNotPresent (1,1) logical = false
            end
            
            if isempty(alphaS_in)
                obj = feval(mfilename('class')).empty(size(alphaS_in));
                return;
            end
            
            % Updated: allowedFields now includes the inherited CellStrDelimiter
            allowedFields = {'fullName', 'DigitalIdentifier', 'CellStrDelimiter'};
            ndi.util.StructSerializable.validateStructArrayFields(alphaS_in, allowedFields, options.errorIfFieldNotPresent);
            
            obj_cell = cell(size(alphaS_in));
            
            for i = 1:numel(alphaS_in)
                newObj = feval(mfilename('class')); 
                currentAlphaStruct = alphaS_in(i);

                if isfield(currentAlphaStruct, 'fullName')
                    newObj.fullName = currentAlphaStruct.fullName;
                end

                if isfield(currentAlphaStruct, 'DigitalIdentifier')
                    if isstruct(currentAlphaStruct.DigitalIdentifier)
                        newObj.DigitalIdentifier = ndi.gui.component.metadataEditor.class.OrganizationDigitalIdentifier.fromAlphaNumericStruct(currentAlphaStruct.DigitalIdentifier, 'errorIfFieldNotPresent', options.errorIfFieldNotPresent);
                    end
                end
                
                % Updated: Populate the inherited CellStrDelimiter property
                if isfield(currentAlphaStruct, 'CellStrDelimiter')
                    newObj.CellStrDelimiter = currentAlphaStruct.CellStrDelimiter;
                end

                obj_cell{i} = newObj;
            end
            
            obj = [obj_cell{:}];
            obj = reshape(obj, size(alphaS_in));
        end
    end
end