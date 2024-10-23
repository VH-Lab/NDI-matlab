classdef Species < handle
    %Species A  class for Species.

    properties
        Name
        Synonym
        OntologyIdentifier
        uuid
        Definition
        Description
    end

    methods
        function obj = Species(name, ontologyIdentifier, synonym)
            obj.Name = name;
            obj.OntologyIdentifier = ontologyIdentifier;
            if nargin > 2
                obj.Synonym = synonym;
            else
                obj.Synonym = '';
            end
        end

        function updateProperty(obj, name, value)
            obj.(name)=value;
        end

        function property = getProperty(obj, name)
            property = obj.(name);
        end

        function uuid = getUuid(object)
            temp = strsplit(object.getProperty('OntologyIdentifier'), '_');
            uuid = temp(2);
        end

        function str = toString(obj)
            str = obj.Name;
        end

        function equal = isEqual(obj, species)
            if (isfield(species, 'OntologyIdentifier') && obj.getProperty('OntologyIdentifier') == species.getProperty('OntologyIdentifier'))
                equal = 1;
            else
                equal = 0;
            end
        end

        function instances = convertToOpenMinds(obj)
            instances = openminds.controlledterms.Species.empty;
            for i = 1:numel(obj)
                instance = openminds.controlledterms.Species();
                instance.name = obj.Name;
                instance.synonym = obj.Synonym;
                if ~isempty(obj.Definition)
                    instance.definition = obj.Definition;
                end
                if ~isempty(obj.Description)
                    instance.description = obj.Description;
                end
                instance.preferredOntologyIdentifier = obj.OntologyIdentifier;
                instances = [instances, instance]; %#ok<AGROW>
            end

        end

        function s = toStruct(obj)
            props = properties(obj);
            s = struct();
            for i = 1:length(props)
                propName = props{i};
                propValue = obj.(propName);
                if isempty(propValue)
                    obj.(propName) = '';
                else
                    s.(propName) = propValue;
                end
            end
        end


    end
    methods (Static)
        function obj = fromStruct(s)
            obj = ndi.database.metadata_app.class.Species(s.Name, s.OntologyIdentifier, s.Synonym);
            props = fieldnames(s);
            for i = 1:length(props)
                propName = props{i};
                propValue = s.(propName);
                obj.(propName) = propValue;
            end
        end
    end
end