classdef DatasetData < handle
%AuthorData A utility class for storing and retrieving information about Dataset.
    
    properties 
        % A struct array holding information for dataset. See
        % DatasetData.getDefaultAuthorItem for the fields contained in the 
        % struct
        DatasetInfo (:,1) struct
    end

    methods
        function updateProperty(obj, name, value)
        %updateProperty Update the value in a field 

            if numel( obj.DatasetInfo ) == 0
                obj.DatasetInfo = obj.getDefaultDatasetItem();
            end
            obj.DatasetInfo.(name)=value;
        end

        function S = getItem(obj)
        %getAuthorName Get a struct with author details for the given index
            if numel( obj.DatasetInfo ) == 0
                S = obj.getDefaultDatasetItem();
            else
                S = obj.DatasetInfo;
            end
        end

        function S = getDataset(obj)
        %getAuthorList Same as S = authorData.AuthorList
            S = obj.DatasetInfo;
        end

        function setDataset(obj, S)
        %setAuthorList Same as authorData.AuthorList = S
            obj.DatasetInfo = S;
        end
    end

    
    methods (Static)

        function S = getDefaultDatasetItem()
            % Todo: Consider using camelcase (i.e givenName) to conform
            % with openMINDS
            S = struct;
            S.Author = '';
            S.Description = ''; %Abstract
            S.FullName = ''; %Dataset Branch Title
            S.Custodian = '';
            S.DigitalIdentifier = ''; %Dataset_DOI
            S.HasVersion = '';
            S.ShortName = '';
        end

    end

end