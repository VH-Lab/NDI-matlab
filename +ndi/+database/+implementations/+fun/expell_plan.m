function [to_delete_list] = expell_plan(ndi_document_obj, ingestion_directory)
    % EXPELL_PLAN - prepare to remove files from an ndi_document file_info from a database
    %
    % [TO_DELETE_LIST] = ndi.database.implementations.fun.expell_plan(NDI_DOCUMENT_OBJ, INGESTION_DIRECTORY)
    %
    % Plan to expell all of the files from an ndi.document NDI_DOCUMENT_OBJ from the directory INGESTION_DIRECTORY.
    %
    % A list of files (full path) to be deleted is returned in the cell array TO_DELETE_LIST.
    %
    % See also: ndi.database.implementations.fun.ingest_plan
    %

    to_delete_list = {};

    if isfield(ndi_document_obj.document_properties,'files'),
        if isfield(ndi_document_obj.document_properties.files,'file_info'),
            for i=1:numel(ndi_document_obj.document_properties.files.file_info),
                locs = ndi_document_obj.document_properties.files.file_info(i).locations;
                for j=1:numel(locs),
                    if locs(j).ingest,
                        to_delete_list{end+1} = [ingestion_directory filesep ...
                            locs(j).uid];
                        if ~isfile(to_delete_list{end}),
                            error(['File to delete does not exist: ' to_delete_list{end}]);
                        end;
                    end;
                end;
            end;
        end;
    end;
