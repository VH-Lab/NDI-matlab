% AuthorData.m (in +ndi/+gui/+component/+metadataEditor/+class/)
classdef AuthorData < ndi.util.StructSerializable
    %AUTHORDATA Represents data for a single author, including contact info and affiliations.
    %   Inherits from ndi.util.StructSerializable for common conversion methods.

    properties
        givenName (1,:) char = ''
        familyName (1,:) char = ''
        authorRole cell {ndi.validators.mustBeCellArrayOfText(authorRole)} = {}
        contactInformation (1,1) ndi.gui.component.metadataEditor.class.ContactInformation
        digitalIdentifier (1,1) ndi.gui.component.metadataEditor.class.AuthorDigitalIdentifier
        affiliation (1,:) ndi.gui.component.metadataEditor.class.Organization
    end

    methods
        function obj = AuthorData()
            %AUTHORDATA Construct an instance of this class.
            %   Initializes handle object properties to ensure every new
            %   AuthorData object gets its own, distinct child object instances.
            
            obj.contactInformation = ndi.gui.component.metadataEditor.class.ContactInformation();
            obj.digitalIdentifier = ndi.gui.component.metadataEditor.class.AuthorDigitalIdentifier();
            % Corrected: Initialize affiliation as a 1x0 empty array of Organization objects
            obj.affiliation = ndi.gui.component.metadataEditor.class.Organization.empty(1,0);
        end
    end

    methods (Static)
        function obj = fromAlphaNumericStruct(alphaS_in, options)
            %FROMALPHANUMERICSTRUCT Creates AuthorData object(s) from an AlphaNumericStruct array.
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

                if isfield(currentAlphaStruct, 'givenName')
                    newObj.givenName = currentAlphaStruct.givenName;
                end
                if isfield(currentAlphaStruct, 'familyName')
                    newObj.familyName = currentAlphaStruct.familyName;
                end
                if isfield(currentAlphaStruct, 'CellStrDelimiter')
                    newObj.CellStrDelimiter = currentAlphaStruct.CellStrDelimiter;
                end

                if isfield(currentAlphaStruct, 'authorRole')
                    if ischar(currentAlphaStruct.authorRole) && ~isempty(currentAlphaStruct.authorRole)
                        tempRoles = strsplit(currentAlphaStruct.authorRole, newObj.CellStrDelimiter);
                        newObj.authorRole = tempRoles(~cellfun('isempty',strtrim(tempRoles))); 
                    end
                end

                if isfield(currentAlphaStruct, 'contactInformation') && isstruct(currentAlphaStruct.contactInformation)
                    newObj.contactInformation = ndi.gui.component.metadataEditor.class.ContactInformation.fromAlphaNumericStruct(currentAlphaStruct.contactInformation, 'errorIfFieldNotPresent', options.errorIfFieldNotPresent);
                end
                
                if isfield(currentAlphaStruct, 'digitalIdentifier') && isstruct(currentAlphaStruct.digitalIdentifier)
                    newObj.digitalIdentifier = ndi.gui.component.metadataEditor.class.AuthorDigitalIdentifier.fromAlphaNumericStruct(currentAlphaStruct.digitalIdentifier, 'errorIfFieldNotPresent', options.errorIfFieldNotPresent);
                end
                
                if isfield(currentAlphaStruct, 'affiliation') && isstruct(currentAlphaStruct.affiliation)
                    % Corrected: Pass the entire struct array to the Organization factory method
                    newObj.affiliation = ndi.gui.component.metadataEditor.class.Organization.fromAlphaNumericStruct(currentAlphaStruct.affiliation, 'errorIfFieldNotPresent', options.errorIfFieldNotPresent);
                end
                
                obj_cell{i} = newObj;
            end
            
            obj = [obj_cell{:}];
            obj = reshape(obj, size(alphaS_in));
        end
    end
end