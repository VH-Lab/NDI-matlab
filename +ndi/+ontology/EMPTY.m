% Location: +ndi/+ontology/EMPTY.m
classdef EMPTY < ndi.ontology
% EMPTY - NDI Ontology object for a local experimental ontology (EMPTY).
%   Inherits from ndi.ontology and implements lookupTermOrID for EMPTY
%   by reading from a local .obo file.
%
%   This class demonstrates how to integrate ontologies stored in local
%   OBO format files.

    properties (Constant)
        % Define the ontology prefix for this specific ontology
        ONTOLOGY_PREFIX = 'EMPTY';

        % Define the relative path to the OBO file from CommonFolder
        OBO_FILE_SUBPATH = fullfile('controlled_vocabulary', 'empty.obo');
    end

    properties (Access = private)
        OboFilePath % Full path to the OBO file
    end

    methods
        function obj = EMPTY()
            % EMPTY - Constructor for the EMPTY ontology object.
            % Implicitly calls the superclass constructor ndi.ontology().
            % It also resolves the full path to the OBO file.

            % Construct the full path to the OBO file
            try
                commonFolder = ndi.common.PathConstants.CommonFolder();
                obj.OboFilePath = fullfile(commonFolder, obj.OBO_FILE_SUBPATH);
            catch ME
                error('ndi:ontology:EMPTY:PathError', ...
                    'Could not determine CommonFolder or construct path to EMPTY OBO file: %s', ME.message);
            end

            if ~isfile(obj.OboFilePath)
                warning('ndi:ontology:EMPTY:FileNotFound', ...
                    'The EMPTY OBO file was not found at the expected location: %s. Lookups will fail.', obj.OboFilePath);
            end
        end % constructor

        function [id, name, definition, synonyms, shortName] = lookupTermOrID(obj, term_or_id_or_name_fragment)
            % LOOKUPTERMORID - Looks up a term in the local EMPTY.obo file.
            %
            %   [ID, NAME, DEFINITION, SYNONYMS, SHORTNAME] = lookupTermOrID(OBJ, TERM_OR_ID_OR_NAME_FRAGMENT)
            %
            %   Overrides the base class method. It uses the static helper
            %   ndi.ontology.lookupOBOFile to parse and search the OBO file.
            %
            %   The input TERM_OR_ID_OR_NAME_FRAGMENT is the part of the original
            %   lookup string after the 'EMPTY:' prefix has been removed (e.g.,
            %   '00000090' for an ID, or 'Behavioral measurement' for a name).
            %
            %   See also: ndi.ontology.lookup (static dispatcher),
            %             ndi.ontology.lookupOBOFile (static helper)

            if isempty(obj.OboFilePath) || ~isfile(obj.OboFilePath)
                 error('ndi:ontology:EMPTY:LookupFailed_NoFile', ...
                    'Cannot perform lookup. The EMPTY OBO file path is not set or file does not exist: %s', obj.OboFilePath);
            end

            try
                % Call the static helper from the base class
                [id, name, definition, synonyms, shortName] = ndi.ontology.lookupOBOFile(...
                    obj.OboFilePath, ...
                    obj.ONTOLOGY_PREFIX, ...
                    term_or_id_or_name_fragment);
            catch ME
                % Check if the error is from the OBO lookup itself (e.g., term not found)
                % or a more fundamental parsing/file error.
                if strcmp(ME.identifier, 'ndi:ontology:lookupOBOFile:TermNotFound') || ...
                   strcmp(ME.identifier, 'ndi:ontology:lookupOBOFile:InvalidInput')
                    % These are expected "not found" type errors, rethrow to be caught by main lookup
                    rethrow(ME);
                else
                    % More serious error (e.g., file parsing, path issue)
                    baseME = MException('ndi:ontology:EMPTY:LookupFailed', ...
                        'EMPTY.obo lookup failed for input "%s".', term_or_id_or_name_fragment);
                    baseME = addCause(baseME, ME);
                    throw(baseME);
                end
            end
        end % function lookupTermOrID

    end % methods

end % classdef EMPTY

