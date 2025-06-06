% License.m (in +ndi/+gui/+component/+metadataEditor/+class/)
classdef License < ndi.util.StructSerializable
    %LICENSE Represents a software or data license.
    %   Inherits from ndi.util.StructSerializable for common conversion methods.

    properties
        FullName (1,:) char {mustBeMember(FullName, ...
            {'', ...
             'Creative Commons Attribution 4.0 International', ...
             'Creative Commons Attribution-ShareAlike 4.0 International', ...
             'Creative Commons Attribution-NonCommercial 4.0 International', ...
             'Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International', ...
             'Creative Commons Attribution-NoDerivatives 4.0 International', ...
             'Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International'})} = ''

        LegalCode (1,:) char {mustBeMember(LegalCode, ...
            {'', ...
             'https://creativecommons.org/licenses/by/4.0/legalcode', ...
             'https://creativecommons.org/licenses/by-sa/4.0/legalcode', ...
             'https://creativecommons.org/licenses/by-nc/4.0/legalcode', ...
             'https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode', ...
             'https://creativecommons.org/licenses/by-nd/4.0/legalcode', ...
             'https://creativecommons.org/licenses/by-nc-nd/4.0/legalcode'})} = ''

        ShortName (1,:) char {mustBeMember(ShortName, ...
            {'', 'CC BY 4.0', 'CC BY-SA 4.0', 'CC BY-NC 4.0', 'CC BY-NC-SA 4.0', ...
             'CC BY-ND 4.0', 'CC BY-NC-ND 4.0'})} = ''
    end

    % Constructor, toStruct, toAlphaNumericStruct, and fromStruct are inherited.

    methods (Static)
        function obj = fromAlphaNumericStruct(alphaS_in, options)
            %FROMALPHANUMERICSTRUCT Creates License object(s) from an AlphaNumericStruct array.
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

                if isfield(currentAlphaStruct, 'FullName')
                    newObj.FullName = currentAlphaStruct.FullName;
                end
                if isfield(currentAlphaStruct, 'LegalCode')
                    newObj.LegalCode = currentAlphaStruct.LegalCode;
                end
                if isfield(currentAlphaStruct, 'ShortName')
                    newObj.ShortName = currentAlphaStruct.ShortName;
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