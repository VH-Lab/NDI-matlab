% file: +ndi/+setup/+NDIMaker/TreatmentCreator.m
classdef (Abstract) TreatmentCreator < handle
%TREATMENTCREATOR Abstract base class for creating NDI treatment tables.
%
%   This abstract class defines the standard interface for generating a table
%   of treatment information from a broader dataset information table.
%
%   Subclasses must implement the 'create' method to define lab-specific
%   logic for interpreting the datasetInfoTable and constructing a valid
%   treatment table. This treatment table can then be passed to other NDI
%   functions to create NDI 'treatment', 'treatment_drug', or 'treatment_virus'
%   documents.

    methods (Abstract)
        % CREATE - Generates a treatment table from a dataset information table.
        %
        %   TREATMENTTABLE = CREATE(OBJ, DATASETINFOTABLE)
        %
        %   This method must be implemented by all subclasses. It takes a
        %   dataset information table as input and returns a new table that
        %   is formatted for creating NDI treatment documents.
        %
        %   Inputs:
        %       obj (ndi.setup.NDIMaker.TreatmentCreator) - The instance of the creator class.
        %       datasetInfoTable (table) - A MATLAB table containing all necessary
        %                                  metadata to determine treatments for subjects.
        %
        %   Outputs:
        %       treatmentTable (table) - A MATLAB table that MUST contain the following columns:
        %           'treatmentType'     : (string/char) Must be one of "treatment", "treatment_drug", or "treatment_virus".
        %           'treatment'         : (string/char) The name of the treatment, prefixed with its ontology.
        %           'stringValue'       : (string/char) A string value for the treatment.
        %           'numericValue'      : (numeric) A numeric value for the treatment.
        %           'subjectIdentifier' : (string/char) The local identifier for the subject.
        %           'sessionPath'       : (string/char) The path for the session.
        %
        %       If any row has a 'treatmentType' of "treatment_drug", the table MUST also include these columns
        %       (use missing values like NaN or "" for rows of other types):
        %           'location_ontologyNode'      : (string/char) The ontology node for the drug location.
        %           'location_name'              : (string/char) The common name of the location.
        %           'mixture_table'              : (string/char) A serialized table of mixture components.
        %           'administration_onset_time'  : (string/char) ISO 8601 formatted datetime.
        %           'administration_offset_time' : (string/char) ISO 8601 formatted datetime.
        %           'administration_duration'    : (numeric) Duration of the administration.
        %
        %       If any row has a 'treatmentType' of "treatment_virus", the table MUST also include these columns:
        %           'virus_OntologyName'         : (string/char)
        %           'virus_name'                 : (string/char)
        %           'virusLocation_OntologyName' : (string/char)
        %           'virusLocation_name'         : (string/char)
        %           'virus_AdministrationDate'   : (string/char)
        %           'virus_AdministrationPND'    : (numeric)
        %           'dilution'                   : (numeric)
        %           'diluent_OntologyName'       : (string/char)
        %           'diluent_name'               : (string/char)
        %
        treatmentTable = create(obj, datasetInfoTable);
    end % abstract methods

    methods (Static, Access = protected)
        function T = initialize_treatment_table()
            % INITIALIZE_TREATMENT_TABLE - Creates an empty table with all required columns for all treatment types.
            %
            % This function provides a standard, empty table structure that subclasses can use
            % as a starting point.
            %
            varNames = { ...
                'treatmentType', 'treatment', 'stringValue', 'numericValue', 'subjectIdentifier', 'sessionPath', ...
                'location_ontologyNode', 'location_name', 'mixture_table', 'administration_onset_time', ...
                'administration_offset_time', 'administration_duration', ...
                'virus_OntologyName', 'virus_name', 'virusLocation_OntologyName', 'virusLocation_name', ...
                'virus_AdministrationDate', 'virus_AdministrationPND', 'dilution', ...
                'diluent_OntologyName', 'diluent_name' ...
            };
            varTypes = { ...
                'string', 'string', 'string', 'double', 'string', 'string', ...
                'string', 'string', 'string', 'string', 'string', 'double', ...
                'string', 'string', 'string', 'string', 'string', 'string', 'double', 'string', 'string' ...
            };
            T = table('Size', [0 numel(varNames)], 'VariableTypes', varTypes, 'VariableNames', varNames);
        end
    end % protected static methods

end % classdef
