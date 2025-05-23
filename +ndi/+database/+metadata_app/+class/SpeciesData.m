classdef SpeciesData < handle
    %SpeciesData A utility class for storing and retrieving information about Species.

    properties
        % A struct array holding information for each species.
        SpeciesList (1,:) ndi.database.metadata_app.class.Species
    end

    methods

        function removeItem(obj, speciesIndex)
            %removeItem Remove the specified species form the list.
            %
            %   Usage:
            %   SpeciesData.removeItem(speciesIndex) removes the species from the
            %   list where speciesIndex is the index in the struct.

            obj.SpeciesList(speciesIndex) = [];
        end

        function updateProperty(obj, name, value, speciesIndex)
            %updateProperty Update the value in a field for the given
            % speciesIndex

            % if numel( obj.SpeciesList ) < speciesIndex
            %     if numel(obj.SpeciesList) == 0
            %         obj.SpeciesList = obj.getDefaultAuthorItem();
            %     else
            %         obj.SpeciesList(end+1:speciesIndex) = deal(obj.getDefaultAuthorItem());
            %     end
            % end
            obj.SpeciesList(speciesIndex).(name) = value;
        end

        function addItem(obj, varargin)
            if nargin == 3
                species = ndi.database.metadata_app.class.Species(varargin{1}, varargin{2});
            else
                species = ndi.database.metadata_app.class.Species(varargin{1}, varargin{2}, varargin{3});
            end
            if (numel(obj.SpeciesList) == 0)
                obj.SpeciesList = species;
            else
                obj.SpeciesList(end + 1) = species;
            end
        end

        function S = getItem(obj, speciesName)
            %getItem Get a struct with species details for the given name
            S = {};
            for i = 1:numel(obj.SpeciesList)
                name = obj.SpeciesList(i).Name;
                % if name is a cell array, get the first element, if not, just use the string
                if iscell(name)
                    name = name{1};
                end
                if strcmp(lower(name),lower(speciesName))
                    S = obj.SpeciesList(i);
                end
            end
        end

        function S = getSpeciesList(obj)
            %getSpeciesList Same as S = SpeciesData.SpeciesList
            S = obj.SpeciesList;
        end

        function setSpeciesList(obj, S)
            %setSpeciesList Same as SpeciesData.SpeciesList = S
            obj.SpeciesList = S;
        end
    end
end
