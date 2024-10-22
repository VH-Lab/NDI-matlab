classdef  matlabdumbjsondb2 < ndi.database
% matlabdumbjsondb2 - with enhanced file management

    properties
        db        % vlt.file.dumbjsondb object
    end

    methods

        function ndi_matlabdumbjsondb_obj = matlabdumbjsondb2(varargin)
        % ndi.database.implementations.database.matlabdumbjsondb make a new ndi.database.implementations.database.matlabdumbjsondb object
        % 
        % NDI_MATLABDUMBJSONDB_OBJ = ndi.database.implementation.database.matlabdumbjsondb(...
        %     PATH, SESSION_UNIQUE_REFERENCE, COMMAND, ...)
        %
        % Creates a new ndi.database.implementations.database.matlabdumbjsondb object.
        %
        % COMMAND can either be 'Load' or 'New'. The second argument
        % should be the full pathname of the location where the files
        % should be stored on disk.
        %
        % See also: vlt.file.dumbjsondb, vlt.file.dumbjsondb/DUMBJSONDB
            ndi_matlabdumbjsondb_obj = ndi_matlabdumbjsondb_obj@ndi.database(varargin{:});
            ndi_matlabdumbjsondb_obj.db = vlt.file.dumbjsondb(varargin{3:end},...
                'dirname','dumbjsondb','unique_object_id_field','base.id');
            if ~isfolder(ndi_matlabdumbjsondb_obj.file_directory),
                mkdir(ndi_matlabdumbjsondb_obj.file_directory);
            end;
        end; % ndi.database.implementations.database.matlabdumbjsondb()

    end 

    methods, % public
        function docids = alldocids(ndi_matlabdumbjsondb_obj)
            % ALLDOCIDS - return all document unique reference numbers for the database
            %
            % DOCIDS = ALLDOCIDS(NDI_MATLABDUMBJSONDB_OBJ)
            %
            % Return all document unique reference strings as a cell array of strings. If there
            % are no documents, empty is returned.
            %
                docids = ndi_matlabdumbjsondb_obj.db.alldocids();
        end; % alldocids()
    end;

    methods (Access=protected),

        function ndi_matlabdumbjsondb_obj = do_add(ndi_matlabdumbjsondb_obj, ndi_document_obj, add_parameters)
            namevaluepairs = {};
            fn = fieldnames(add_parameters);

            [source_files,dest_files,to_delete_files] = ndi.database.implementations.fun.ingest_plan(...
                ndi_document_obj, ndi_matlabdumbjsondb_obj.file_directory());

            ndi_matlabdumbjsondb_obj.db = ndi_matlabdumbjsondb_obj.db.add(ndi_document_obj.document_properties, namevaluepairs{:});

            [b,msg] = ndi.database.implementations.fun.ingest(source_files,dest_files,to_delete_files);
        end; % do_add

        function [ndi_document_obj] = do_read(ndi_matlabdumbjsondb_obj, ndi_document_id);
            [doc] = ndi_matlabdumbjsondb_obj.db.read(ndi_document_id,0); % all versions are 0
            if isempty(doc),
                ndi_document_obj = [];
            else,
                ndi_document_obj = ndi.document(doc);
            end;
        end; % do_read

        function ndi_matlabdumbjsondb_obj = do_remove(ndi_matlabdumbjsondb_obj, ndi_document_id)
            % need to read document to delete files
            ndi_doc = ndi_matlabdumbjsondb_obj.do_read(ndi_document_id);
            if isempty(ndi_doc), 
                to_delete_list = {};
            else,
                [to_delete_list] = ndi.database.implementations.fun.expell_plan(ndi_doc, ...
                        ndi_matlabdumbjsondb_obj.file_directory);
            end;
            ndi_matlabdumbjsondb_obj = ndi_matlabdumbjsondb_obj.db.remove(ndi_document_id);
            [b,msg] = ndi.database.implementations.fun.expell(to_delete_list);
        end; % do_remove

        function [ndi_document_objs] = do_search(ndi_matlabdumbjsondb_obj, searchoptions, searchparams)
            if isa(searchparams,'ndi.query'),
                searchparams = searchparams.to_searchstructure;
                if 0, % display
                    disp('search params');
                    for i=1:numel(searchparams),
                        searchparams(i),
                        searchparams(i).param1,
                        searchparams(i).param2,
                    end
                end;
            end;
            ndi_document_objs = {};
            [docs] = ndi_matlabdumbjsondb_obj.db.search(searchoptions, searchparams);
            for i=1:numel(docs),
                ndi_document_objs{i} = ndi.document(docs{i});
            end;
        end; % do_search()

        function [ndi_binarydoc_obj] = do_openbinarydoc(ndi_matlabdumbjsondb_obj, ndi_document_id, filename)
            ndi_binarydoc_obj = [];

            ndi_doc = ndi_matlabdumbjsondb_obj.do_read(ndi_document_id);
            filename = ndi.database.implementations.fun.doc2ingesteddbfilename(ndi_doc, filename);
            fullfilename = [ndi_matlabdumbjsondb_obj.file_directory filesep filename];

            fid = fopen(fullfilename,'r','ieee-le');
            if fid>0,
                [fullfilename,permission,machineformat,encoding] = fopen(fid);
                ndi_binarydoc_obj = ndi.database.implementations.binarydoc.matfid('fid',fid,...
                    'fullpathfilename',fullfilename, 'machineformat',machineformat,...
                    'permission',permission, 'doc_unique_id', ndi_document_id, 'key', '');
                ndi_binarydoc_obj.frewind(); % move to beginning of the file
            end
        end; % do_binarydoc()

        function [ndi_binarydoc_matfid_obj] = do_closebinarydoc(ndi_matlabdumbjsondb_obj, ndi_binarydoc_matfid_obj)
            % DO_CLOSEBINARYDOC - close and unlock an NDI_BINARYDOC_MATFID_OBJ
            %
            % NDI_BINARYDOC_OBJ = DO_CLOSEBINARYDOC(NDI_MATLABDUMBJSONDB_OBJ, NDI_BINARYDOC_MATFID_OBJ, KEY, NDI_DOCUMENT_ID)
            %
            % Close and unlock the binary file associated with NDI_BINARYDOC_OBJ.
            %    
                ndi_binarydoc_matfid_obj.fclose(); 
        end; % do_closebinarydoc()

        function [file_dir] = file_directory(ndi_matlabdumbjsondb_obj)
            % FILE_DIRECTORY - return the file directory where ingested files are stored
            % 
            % FILE_DIR = FILE_DIRECTORY(NDI_MATLABDUMBJSONDB_OBJ)
            %
            % Return the full path of the directory where binary files for the database documents
            % are stored.
            %
                parent_dir = fileparts(ndi_matlabdumbjsondb_obj.db.paramfilename);
                file_dir = [parent_dir filesep 'files'];
        end; % file_directory
    end;
end


