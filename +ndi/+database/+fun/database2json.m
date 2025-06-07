function database2json(S, output_path)
    % DATABASE2JSON - output contents of an ndi.session database to JSON files
    %
    % DATABASE2JSON(S, OUTPUT_PATH)
    %
    % Finds all documents in the database of an ndi.session object S
    % and writes them to the folder OUTPUT_PATH (full path).
    %

    d = S.database_search(ndi.query('base.id','regexp','(.*)'));

    for i=1:numel(d)
        [i numel(d)],

        if isfield(d{i}.document_properties,'files')
            for f=1:numel(d{i}.document_properties.files.file_list)
                bfile = S.database_openbinarydoc(d{i},d{i}.document_properties.files.file_list{f}),
                [parentdir,filename_here] = fileparts(bfile.fullpathfilename);
                d{i} = d{i}.add_file(d{i}.document_properties.files.file_list{f},filename_here,...
                    'ingest',1,'delete_original',0,'location_type','file','uid',filename_here);
            end
        end

        j = vlt.data.jsonencodenan(d{i}.document_properties);
        vlt.file.str2text([output_path filesep d{i}.document_properties.base.id '.json'],j);
    end
