% FundingItem.m (in +ndi/+gui/+component/+metadataEditor/+class/)
classdef FundingItem < ndi.util.StructSerializable
    %FUNDINGITEM Represents a single funding source with an organization, title, and identifier.
    %   Inherits from ndi.util.StructSerializable for common conversion methods.

    properties
        Organization (1,1) ndi.gui.component.metadataEditor.class.Organization
        Identifier (1,:) char = ''
        Title (1,:) char = ''
    end

    methods
        function obj = FundingItem()
            %FUNDINGITEM Construct an instance of this class.
            %   Initializes handle object properties here to ensure every new
            %   FundingItem object gets its own, distinct Organization instance.
            
            obj.Organization = ndi.gui.component.metadataEditor.class.Organization();
        end
    end

    methods (Static)
        function obj = fromAlphaNumericStruct(alphaS_in, options)
            %FROMALPHANUMERICSTRUCT Creates FundingItem object(s) from an AlphaNumericStruct array.
            arguments
                alphaS_in struct {ndi.validators.mustBeAlphaNumericStruct(alphaS_in)}
                options.errorIfFieldNotPresent (1,1) logical = false
            end
            
            if isempty(alphaS_in)
                obj = feval(mfilename('class')).empty(size(alphaS_in));
                return;
            end
            
            allowedFields = properties(feval(mfilename('class')));
            ndi.util.StructSerializable.validateStructArrayFields(alphaS_in, allowedFields, options.errorIfFieldNotPresent);

            obj_cell = cell(size(alphaS_in));
            
            for i = 1:numel(alphaS_in)
                newObj = feval(mfilename('class'));
                currentAlphaStruct = alphaS_in(i);

                if isfield(currentAlphaStruct, 'Identifier')
                    newObj.Identifier = currentAlphaStruct.Identifier;
                end
                if isfield(currentAlphaStruct, 'Title')
                    newObj.Title = currentAlphaStruct.Title;
                end
                if isfield(currentAlphaStruct, 'CellStrDelimiter')
                    newObj.CellStrDelimiter = currentAlphaStruct.CellStrDelimiter;
                end

                if isfield(currentAlphaStruct, 'Organization')
                    if isstruct(currentAlphaStruct.Organization)
                        newObj.Organization = ndi.gui.component.metadataEditor.class.Organization.fromAlphaNumericStruct(currentAlphaStruct.Organization, 'errorIfFieldNotPresent', options.errorIfFieldNotPresent);
                    end
                end
                
                obj_cell{i} = newObj;
            end
            
            obj = [obj_cell{:}];
            obj = reshape(obj, size(alphaS_in));
        end
    end
end