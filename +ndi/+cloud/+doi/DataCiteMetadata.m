classdef DataCiteMetadata
    properties
        doi (1,:) char = ""
        url (1,:) char = ""
        event (1,:) char = "publish"
        creators (1,:) struct = struct('name', "")
        titles (1,:) struct = struct('title', "")
        publisher (1,:) char = ""
        publicationYear (1,1) double = year(datetime('now'))
        types (1,1) struct = struct('resourceTypeGeneral', 'Dataset')
        schemaVersion (1,:) char = "http://datacite.org/schema/kernel-4"
    end

    methods
        function obj = DataCiteMetadata(init)
            % Constructor that optionally takes a struct for initialization
            if nargin == 1
                props = fieldnames(init);
                for i = 1:numel(props)
                    if isprop(obj, props{i})
                        obj.(props{i}) = init.(props{i});
                    end
                end
            end
        end

        function metadata = toStruct(obj)
            % Convert the object to a structure following DataCite API format
            metadata = struct( ...
                'type', 'dois', ...
                'attributes', struct( ...
                    'doi', obj.doi, ...
                    'url', obj.url, ...
                    'event', obj.event, ...
                    'creators', obj.creators, ...
                    'titles', obj.titles, ...
                    'publisher', obj.publisher, ...
                    'publicationYear', obj.publicationYear, ...
                    'types', obj.types, ...
                    'schemaVersion', obj.schemaVersion ...
                ) ...
            );
        end

        function jsonStr = toJSON(obj)
            % Convert to DataCite-compliant JSON
            metadataStruct = struct('data', obj.toStruct());
            jsonStr = jsonencode(metadataStruct, 'PrettyPrint', true);
        end
    end
end
