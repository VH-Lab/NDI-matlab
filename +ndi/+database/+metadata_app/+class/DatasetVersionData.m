classdef DatasetVersionData < handle
%AuthorData A utility class for storing and retrieving information about Dataset version.
    
    properties 
        % A struct array holding information for dataset version. See
        % DatasetVersionData.getDefaultDatasetVersionItem for the fields contained in the 
        % struct
        DatasetVersionInfo (:,1) struct
    end

    methods
        function updateProperty(obj, name, value)
        %updateProperty Update the value in a field 

            if numel( obj.DatasetVersionInfo ) == 0
                obj.DatasetVersionInfo = obj.getDefaultDatasetItem();
            end
            obj.DatasetVersionInfo.(name)=value;
        end

        function S = getItem(obj)
        %getAuthorName Get a struct with author details for the given index
            if numel( obj.DatasetVersionInfo ) == 0
                S = obj.getDefaultDatasetItem();
            else
                S = obj.DatasetVersionInfo;
            end
        end

        function S = getDataset(obj)
        %getAuthorList Same as S = authorData.AuthorList
            S = obj.DatasetVersionInfo;
        end

        function setDataset(obj, S)
        %setAuthorList Same as authorData.AuthorList = S
            obj.DatasetVersionInfo = S;
        end
    end

    
    methods (Static)

        function S = getDefaultDatasetItem()
            % Todo: Consider using camelcase (i.e givenName) to conform
            % with openMINDS
            S = struct;
            S.DigitalIdentifier = ''; %Dataset_DOI
            S.License = ndi.database.metadata_app.class.License();
            S.DataType = '';
            S.ExperimentalApproach = ''; 
            S.ReleaseDate = '';
            S.FullDocumentation = '';
            S.ShortName = "original submission";
            S.Technique = '';
            S.VersionIdentifier = '';
            S.VersionInnovation = '';
        end

    end

end


