function newDocStruct = set_file_info(docStruct,mode,filepath)
    % SET_FILE_INFO - set file info parameters for different modes
    %
    % NEWDOCSTRUCT = SET_FILE_INFO(DOCSTRUCT, MODE, FILEPATH)
    %
    % Given a document structure downloaded from ndi.cloud.api.documents.get_document,
    % set the 'delete_original' and 'ingest' fields as appropriate to the mode.
    %
    % The MODE can be 'local' or 'hybrid'. If MODE is 'local', then
    %   'delete_original' and 'ingest' are set to 1. Otherwise,
    %   the are set to 0.
    %
    % FILEPATH is the location of any locally downloaded files (for 'local' MODE).
    %

    newDocStruct = docStruct;

    if isfield(docStruct,'files')
        if isfield(docStruct.files,'file_info')
            for i=1:numel(docStruct.files.file_info)
                switch mode
                    case 'local'
                        mydoc = ndi.document(docStruct);
                        mydoc.reset_file_info();
                        for j=1:numel(docStruct.files.file_info)
                            file_uid = docStruct.files.file_info(j).locations(1).uid;
                            filename = docStruct.files.file_info(j).name;
                            file_location = fullfile(filepath,file_uid);
                            mydoc = mydoc.add_file(filename,file_location);
                        end;
                        newDocStruct = struct(mydoc.document_properties);
                    otherwise
                        for j=1:numel(docStruct.files.file_info(i).locations)
                            newDocStruct.files.file_info(i).locations(j).delete_original = 0;
                            newDocStruct.files.file_info(i).locations(j).ingest = 0;
                        end;
                end;
            end;
        end;
    end;
