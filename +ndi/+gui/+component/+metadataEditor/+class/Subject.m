% Subject.m (in +ndi/+gui/+component/+metadataEditor/+class/)
classdef Subject < ndi.util.StructSerializable
    %SUBJECT Represents a single subject, with species, strain, and other information.
    %   Inherits from ndi.util.StructSerializable for common conversion methods.

    properties
        SubjectName (1,:) char = ''
        BiologicalSexList (1,:) cell {ndi.validators.mustBeCellArrayOfText(BiologicalSexList)} = {}
        SpeciesList (1,:) ndi.gui.component.metadataEditor.class.Species
        StrainList (1,:) ndi.gui.component.metadataEditor.class.Strain
        SessionIdentifier (1,:) char = ''
    end

    methods
        function obj = Subject()
            %SUBJECT Construct an instance of this class.
            %   Initializes handle object array properties to be empty arrays
            %   of the correct object type.
            
            obj.SpeciesList = ndi.gui.component.metadataEditor.class.Species.empty(1,0);
            obj.StrainList = ndi.gui.component.metadataEditor.class.Strain.empty(1,0);
        end
    end

    methods (Static)
        function obj = fromAlphaNumericStruct(alphaS_in, options)
            %FROMALPHANUMERICSTRUCT Creates Subject object(s) from an AlphaNumericStruct array.
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

                if isfield(currentAlphaStruct, 'SubjectName')
                    newObj.SubjectName = currentAlphaStruct.SubjectName;
                end
                if isfield(currentAlphaStruct, 'SessionIdentifier')
                    newObj.SessionIdentifier = currentAlphaStruct.SessionIdentifier;
                end
                if isfield(currentAlphaStruct, 'CellStrDelimiter')
                    newObj.CellStrDelimiter = currentAlphaStruct.CellStrDelimiter;
                end

                if isfield(currentAlphaStruct, 'BiologicalSexList')
                    if ischar(currentAlphaStruct.BiologicalSexList) && ~isempty(currentAlphaStruct.BiologicalSexList)
                        tempList = strsplit(currentAlphaStruct.BiologicalSexList, newObj.CellStrDelimiter);
                        newObj.BiologicalSexList = tempList(~cellfun('isempty',strtrim(tempList))); 
                    end
                end

                if isfield(currentAlphaStruct, 'SpeciesList') && isstruct(currentAlphaStruct.SpeciesList)
                    newObj.SpeciesList = ndi.gui.component.metadataEditor.class.Species.fromAlphaNumericStruct(currentAlphaStruct.SpeciesList, 'errorIfFieldNotPresent', options.errorIfFieldNotPresent);
                end
                
                if isfield(currentAlphaStruct, 'StrainList') && isstruct(currentAlphaStruct.StrainList)
                    newObj.StrainList = ndi.gui.component.metadataEditor.class.Strain.fromAlphaNumericStruct(currentAlphaStruct.StrainList, 'errorIfFieldNotPresent', options.errorIfFieldNotPresent);
                end
                
                obj_cell{i} = newObj;
            end
            
            obj = [obj_cell{:}];
            obj = reshape(obj, size(alphaS_in));
        end
    end
end