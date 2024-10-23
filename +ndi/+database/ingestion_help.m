classdef ingestion_help
    % A class that provides helper methods for ingesting raw data files into the database
    %
    %
    methods
        function obj = ingestion_help()
            % INGESTION_HELP - helper class with methods to help ingest raw data files
            %
            % OBJ = ndi.database.ingestion_help()
            %

        end; % ingestion_help() creator

        function cname = ingestion_class(ingestion_help_obj)
            % INGESTION_CLASS - the name of the ingestion class for this object
            %
            % CNAME = INGESTION_CLASS(INGESTION_HELP_OBJ)
            %
            % Returns the class name of the object that should be created if this
            % object class is ingested into the database (and won't have access to any raw
            % data).
            %
            % For the base class, this simply returns empty.
            cname = '';
        end; % ingestion_class()

        function [docs_out, doc_ids_remove] = ingest(ingestion_help_obj)
            % INGEST - create new documents that produce the ingestion of an ingestion_help_obj
            %
            % [DOCS_OUT, DOC_IDS_REMOVE] = INGEST(INGESTION_HELP_OBJ)
            %
            % Perform the actions necessary to make a database-ingested representation of
            % an INGESTION_HELP_OBJ object.
            %
            % DOCS_OUT is a cell array of ndi.document objects that comprise the new representation.
            % DOCS_IDS_REMOVE are a cell array of ndi.document id numbers that should be removed
            % (or not copied) from the existing database when creating the ingested version.
            %
            % In the abstract class, an empty cell array is returned for all outputs.
            %
            docs_out = {};
            doc_ids_remove = {};
        end; % ingest()

    end; % methods
end % class

