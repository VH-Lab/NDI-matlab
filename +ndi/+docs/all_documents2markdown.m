function t = all_documents2markdown(varargin)
    % ALL_DOCUMENTS2MARKDOWN - write all NDI document types to documentation folder
    %
    %
    %

    spaces = 6; % used to be 4 when there was only one tool in the suite
    input_path = ndi.common.PathConstants.DocumentFolder;

    output_path=[ndi.common.PathConstants.RootFolder filesep 'docs' filesep 'NDI-matlab' filesep 'documents' filesep];
    doc_output_path = ['NDI-matlab/documents' filesep];
    doc_path = [''];
    write_yml = 1;

    vlt.data.assign(varargin{:});

    if input_path(end)~=filesep,
        input_path(end+1) = filesep;
    end;
    
    t = [];

    d = dir([input_path filesep '*.json']);

    for i=1:numel(d),
        [doc_path d(i).name],
        if strcmp([doc_path d(i).name],'ndi_validate_config.json'),
            continue;
        end; % special file        
        doc = ndi.document([d(i).name(1:end-5)]); % drop .json
        [md,info] = ndi.docs.document2markdown(doc);
        [input_path filesep d(i).name],
        vlt.file.createpath([output_path info.localurl]);
        vlt.file.str2text([output_path info.localurl],md);
        t = cat(2,t,[repmat(' ',1,spaces) '- ' info.localurl(1:end-3) ...
            ' : ''' [doc_output_path info.localurl] '''' newline]);
    end;

    folders = vlt.file.dirlist_trimdots(dir([input_path]));

    for i=1:numel(folders),
        t = cat(2,t,[repmat(' ',1,spaces) '- ' folders{i} ':' newline]);
        tnew = ndi.docs.all_documents2markdown(...
            'spaces',spaces+2,...
            'input_path',[input_path folders{i} filesep],...
            'output_path',[output_path folders{i} filesep],...
            'doc_output_path',[doc_output_path folders{i} filesep],...
            'doc_path',[doc_path folders{i} filesep ],...
            'write_yml',0);
        t = cat(2,t,tnew);
    end;

    if write_yml,
        vlt.file.str2text([output_path filesep 'documents.yml'],t);
    end;
