classdef SpeciesData < handle
%SpeciesData A utility class for storing and retrieving information about Species.
    
    properties 
        % A struct array holding information for each species. 
        SpeciesList (:,1) struct
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
        %speciesIndex

            % if numel( obj.SpeciesList ) < speciesIndex
            %     if numel(obj.SpeciesList) == 0
            %         obj.SpeciesList = obj.getDefaultAuthorItem();
            %     else
            %         obj.SpeciesList(end+1:speciesIndex) = deal(obj.getDefaultAuthorItem());
            %     end
            % end
            obj.SpeciesList(speciesIndex).(name) = value;
        end

        function addItem(obj, name, synonym, ontologyIdentifier)
            S = struct;
            S.Name = name;
            S.Synonym = synonym;
            S.OntologyIdentifier = ontologyIdentifier;
            
            if (numel(obj.SpeciesList) == 0)
                obj.SpeciesList = S;
            else
                obj.SpeciesList(end + 1) = S;
            end

        end
   
        function S = getItem(obj, speciesIndex)
        %getItem Get a struct with species details for the given index
            if numel( obj.SpeciesList ) >= speciesIndex
                S = obj.SpeciesList(speciesIndex);                
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