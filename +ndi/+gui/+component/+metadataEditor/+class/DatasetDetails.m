% DatasetDetails.m (in +ndi/+gui/+component/+metadataEditor/+class/)
classdef DatasetDetails < ndi.util.StructSerializable
    %DATASETDETAILS Represents the core descriptive details of a dataset.
    %   Inherits from ndi.util.StructSerializable for common conversion methods.

    properties
        Description (1,:) char = '' % The abstract of the dataset
        FullName (1,:) char = ''
        ShortName (1,:) char = ''
        Comment (1,:) char = '' % Added new property
    end

    % Constructor, toStruct, toAlphaNumericStruct, and fromStruct are inherited.

    methods (Static)
        function obj = fromAlphaNumericStruct(alphaS_in, options)
            %FROMALPHANUMERICSTRUCT Creates DatasetDetails object(s) from an AlphaNumericStruct array.
            arguments
                alphaS_in struct {ndi.validators.mustBeAlphaNumericStruct(alphaS_in)}
                options.errorIfFieldNotPresent (1,1) logical = false
            end
            
            if isempty(alphaS_in)
                obj = feval(mfilename('class')).empty(size(alphaS_in));
                return;
            end
            
            % The allowedFields should include all properties of this class plus inherited ones.
            allowedFields = properties(feval(mfilename('class')));
            ndi.util.StructSerializable.validateStructArrayFields(alphaS_in, allowedFields, options.errorIfFieldNotPresent);

            obj_cell = cell(size(alphaS_in));
            
            for i = 1:numel(alphaS_in)
                newObj = feval(mfilename('class'));
                currentAlphaStruct = alphaS_in(i);

                if isfield(currentAlphaStruct, 'Description')
                    newObj.Description = currentAlphaStruct.Description;
                end
                if isfield(currentAlphaStruct, 'FullName')
                    newObj.FullName = currentAlphaStruct.FullName;
                end
                if isfield(currentAlphaStruct, 'ShortName')
                    newObj.ShortName = currentAlphaStruct.ShortName;
                end
                if isfield(currentAlphaStruct, 'Comment') % Added logic for Comment
                    newObj.Comment = currentAlphaStruct.Comment;
                end
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