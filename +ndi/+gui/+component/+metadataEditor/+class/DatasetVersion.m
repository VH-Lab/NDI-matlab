% DatasetVersion.m (in +ndi/+gui/+component/+metadataEditor/+class/)
classdef DatasetVersion < ndi.util.StructSerializable
    %DATASETVERSION Represents a single version of a dataset, with metadata and funding.
    %   Inherits from ndi.util.StructSerializable for common conversion methods.

    properties
        Accessibility (1,:) char = ''
        DataType (1,:) cell {ndi.validators.mustBeCellArrayOfText(DataType)} = {}
        DigitalIdentifier (1,:) char = ''
        EthicsAssessment (1,:) char = ''
        ExperimentalApproach (1,:) cell {ndi.validators.mustBeCellArrayOfText(ExperimentalApproach)} = {}
        License (1,1) ndi.gui.component.metadataEditor.class.License
        ReleaseDate (1,1) datetime = NaT
        ShortName (1,:) char = ''
        Technique (1,:) cell {ndi.validators.mustBeCellArrayOfText(Technique)} = {}
        VersionIdentifier (1,:) char = ''
        VersionInnovation (1,:) char = ''
        Funding (1,:) ndi.gui.component.metadataEditor.class.FundingItem
    end

    methods
        function obj = DatasetVersion()
            %DATASETVERSION Construct an instance of this class.
            %   Initializes handle object properties to ensure every new
            %   DatasetVersion object gets its own, distinct child object instances.
            
            obj.License = ndi.gui.component.metadataEditor.class.License();
            obj.Funding = ndi.gui.component.metadataEditor.class.FundingItem.empty(1,0);
        end
    end

    methods (Static)
        function obj = fromAlphaNumericStruct(alphaS_in, options)
            %FROMALPHANUMERICSTRUCT Creates DatasetVersion object(s) from an AlphaNumericStruct array.
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

                % --- Populate char and datetime properties ---
                if isfield(currentAlphaStruct, 'Accessibility'), newObj.Accessibility = currentAlphaStruct.Accessibility; end
                if isfield(currentAlphaStruct, 'DigitalIdentifier'), newObj.DigitalIdentifier = currentAlphaStruct.DigitalIdentifier; end
                if isfield(currentAlphaStruct, 'EthicsAssessment'), newObj.EthicsAssessment = currentAlphaStruct.EthicsAssessment; end
                if isfield(currentAlphaStruct, 'ShortName'), newObj.ShortName = currentAlphaStruct.ShortName; end
                if isfield(currentAlphaStruct, 'VersionIdentifier'), newObj.VersionIdentifier = currentAlphaStruct.VersionIdentifier; end
                if isfield(currentAlphaStruct, 'VersionInnovation'), newObj.VersionInnovation = currentAlphaStruct.VersionInnovation; end
                if isfield(currentAlphaStruct, 'CellStrDelimiter'), newObj.CellStrDelimiter = currentAlphaStruct.CellStrDelimiter; end
                
                if isfield(currentAlphaStruct, 'ReleaseDate') && ~isempty(currentAlphaStruct.ReleaseDate)
                    try
                        newObj.ReleaseDate = datetime(currentAlphaStruct.ReleaseDate, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''', 'TimeZone', 'UTC');
                    catch
                        warning('Could not parse ReleaseDate string: %s. Leaving as NaT.', currentAlphaStruct.ReleaseDate);
                    end
                end

                % --- Populate cell array properties from delimited strings ---
                cellProps = {'DataType', 'ExperimentalApproach', 'Technique'};
                for j = 1:numel(cellProps)
                    propName = cellProps{j};
                    if isfield(currentAlphaStruct, propName)
                        if ischar(currentAlphaStruct.(propName)) && ~isempty(currentAlphaStruct.(propName))
                            tempList = strsplit(currentAlphaStruct.(propName), newObj.CellStrDelimiter);
                            newObj.(propName) = tempList(~cellfun('isempty',strtrim(tempList))); 
                        end
                    end
                end
                
                % --- Populate nested StructSerializable objects ---
                if isfield(currentAlphaStruct, 'License') && isstruct(currentAlphaStruct.License)
                    newObj.License = ndi.gui.component.metadataEditor.class.License.fromAlphaNumericStruct(currentAlphaStruct.License, 'errorIfFieldNotPresent', options.errorIfFieldNotPresent);
                end
                
                if isfield(currentAlphaStruct, 'Funding') && isstruct(currentAlphaStruct.Funding)
                    newObj.Funding = ndi.gui.component.metadataEditor.class.FundingItem.fromAlphaNumericStruct(currentAlphaStruct.Funding, 'errorIfFieldNotPresent', options.errorIfFieldNotPresent);
                end
                
                obj_cell{i} = newObj;
            end
            
            obj = [obj_cell{:}];
            obj = reshape(obj, size(alphaS_in));
        end
    end
end