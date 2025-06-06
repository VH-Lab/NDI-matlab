% Species.m (in +ndi/+gui/+component/+metadataEditor/+class/)
classdef Species < ndi.util.StructSerializable
    %SPECIES Represents a biological species with name, synonyms, and other identifiers.
    %   Inherits from ndi.util.StructSerializable for common conversion methods.

    properties
        Name (1,:) char = ''
        Synonym cell {ndi.validators.mustBeCellArrayOfText(Synonym)} = {}
        OntologyIdentifier (1,:) char = ''
        uuid (1,:) char = ''
        Definition (1,:) char = ''
        Description (1,:) char = ''
    end

    % Constructor, toStruct, toAlphaNumericStruct, and fromStruct are inherited.

    methods (Static)
        function obj = fromAlphaNumericStruct(alphaS_in, options)
            %FROMALPHANUMERICSTRUCT Creates Species object(s) from an AlphaNumericStruct array.
            arguments
                alphaS_in struct {ndi.validators.mustBeAlphaNumericStruct(alphaS_in)}
                options.errorIfFieldNotPresent (1,1) logical = false
            end
            
            if isempty(alphaS_in)
                obj = feval(mfilename('class')).empty(size(alphaS_in));
                return;
            end
            
            % Define allowed fields, which includes all properties of this class plus inherited ones.
            allowedFields = properties(feval(mfilename('class')));
            ndi.util.StructSerializable.validateStructArrayFields(alphaS_in, allowedFields, options.errorIfFieldNotPresent);

            obj_cell = cell(size(alphaS_in));
            
            for i = 1:numel(alphaS_in)
                newObj = feval(mfilename('class')); 
                currentAlphaStruct = alphaS_in(i);

                if isfield(currentAlphaStruct, 'Name')
                    newObj.Name = currentAlphaStruct.Name;
                end
                if isfield(currentAlphaStruct, 'OntologyIdentifier')
                    newObj.OntologyIdentifier = currentAlphaStruct.OntologyIdentifier;
                end
                if isfield(currentAlphaStruct, 'uuid')
                    newObj.uuid = currentAlphaStruct.uuid;
                end
                if isfield(currentAlphaStruct, 'Definition')
                    newObj.Definition = currentAlphaStruct.Definition;
                end
                if isfield(currentAlphaStruct, 'Description')
                    newObj.Description = currentAlphaStruct.Description;
                end
                if isfield(currentAlphaStruct, 'CellStrDelimiter')
                    newObj.CellStrDelimiter = currentAlphaStruct.CellStrDelimiter;
                end

                if isfield(currentAlphaStruct, 'Synonym')
                    if ischar(currentAlphaStruct.Synonym) && ~isempty(currentAlphaStruct.Synonym)
                        % Use the object's delimiter property, which may have been set from the struct
                        tempSynonyms = strsplit(currentAlphaStruct.Synonym, newObj.CellStrDelimiter);
                        % Remove any empty strings that might result from splitting
                        newObj.Synonym = tempSynonyms(~cellfun('isempty',strtrim(tempSynonyms))); 
                    end
                    % If Synonym is an empty char, it correctly results in an empty cell default
                end
                
                obj_cell{i} = newObj;
            end
            
            obj = [obj_cell{:}];
            obj = reshape(obj, size(alphaS_in));
        end
    end
end