function [source_filename_list, destination_filename_list, to_delete_list] = ingest_plan(ndi_document_obj, ingestion_directory)
    % INGEST_PLAN - ingest files from an ndi_document file_info into a database
    %
    % [SOURCE_FILENAME_LIST, DESTINATION_FILENAME_LIST, TO_DELETE_LIST] = ...
    %   ndi.database.implementations.fun.ingest_plan(NDI_DOCUMENT_OBJ, INGESTION_DIRECTORY)
    %
    % Plan to ingest all of the files from an ndi.document NDI_DOCUMENT_OBJ into the directory INGESTION_DIRECTORY.
    % The source files to be copied are returned in a cell array SOURCE_FILENAME_LIST, and the
    % corresponding destination where each file should be copied is returned in a cell array
    % DESINATION_FILENAME_LIST.
    %
    % A list of files (full path) to be deleted after successful addition of the document to the
    % database is returned in the cell array TO_DELETE_LIST.
    %
    % See also: ndi.database.implementations.fun.ingest
    %

    source_filename_list = {};
    destination_filename_list = {};

    to_delete_list = {};

    if isfield(ndi_document_obj.document_properties,'files')
        if isfield(ndi_document_obj.document_properties.files,'file_info')
            for i=1:numel(ndi_document_obj.document_properties.files.file_info)
                locs = ndi_document_obj.document_properties.files.file_info(i).locations;
                for j=1:numel(locs)
                    if locs(j).ingest
                        source_filename_list{end+1} = locs(j).location;
                        destination_filename_list{end+1} = [ingestion_directory filesep ...
                            locs(j).uid];
                        if ~isfile(source_filename_list{end})
                            error(['File to ingest does not exist: ' source_filename_list{end}]);
                        end;
                        if isfile(destination_filename_list{end})
                            error(['Destination file already exists: ' destination_filename_list{end} ]);
                        end;
                    end;
                    if locs(j).delete_original
                        to_delete_list{end+1} = locs(j).location;
                    end;
                end;
            end;
        end;
    end;
