classdef  didsqlite < ndi.database
    % didsqlite - a database based on sqlite

    properties
        db        % did.sqlitedb
    end

    methods

        function ndi_didsqlite_obj = didsqlite(varargin)
            % ndi.database.implementations.database.didsqlite make a new ndi.database.implementations.database.didsqlite object
            %
            % NDI_DIDSQLITE_OBJ = ndi.database.implementation.database.didsqlite(...
            %     PATH, SESSION_UNIQUE_REFERENCE, COMMAND, ...)
            %
            % Creates a new ndi.database.implementations.database.didsqlite object.
            %
            % COMMAND can either be 'Load' or 'New'. The second argument
            % should be the full pathname of the location where the files
            % should be stored on disk.
            %
            % See also: did.database, did.implementations.sqlitedb
            ndi_didsqlite_obj = ndi_didsqlite_obj@ndi.database(varargin{:});
            database_filename = fullfile(ndi_didsqlite_obj.path, 'did-sqlite.sqlite');
            ndi_didsqlite_obj.db = did.implementations.sqlitedb(database_filename);
            if ~isfolder(ndi_didsqlite_obj.file_directory)
                mkdir(ndi_didsqlite_obj.file_directory);
            end
            bid = ndi_didsqlite_obj.db.all_branch_ids();
            if isempty(bid)
                ndi_didsqlite_obj.db.add_branch('a');
            end
        end % ndi.database.implementations.database.didsqlite()
    end

    methods % public
        function docids = alldocids(ndi_didsqlite_obj)
            % ALLDOCIDS - return all document unique reference numbers for the database
            %
            % DOCIDS = ALLDOCIDS(NDI_DIDSQLITE_OBJ)
            %
            % Return all document unique reference strings as a cell array of strings. If there
            % are no documents, empty is returned.
            %
            docids = ndi_didsqlite_obj.db.get_doc_ids('a');
        end % alldocids()
    end

    methods (Access=protected)

        function [hCleanup, filename] = do_open_database(ndi_didsqlite_obj)
            [hCleanup, filename] = ndi_didsqlite_obj.db.open();
        end

        function ndi_didsqlite_obj = do_add(ndi_didsqlite_obj, ndi_document_obj, add_parameters)
            ndi_didsqlite_obj.db.add_docs(ndi_document_obj,'a');
        end % do_add

        function [ndi_document_obj] = do_read(ndi_didsqlite_obj, ndi_document_id)
            [ndi_document_obj] = ndi_didsqlite_obj.db.get_docs(ndi_document_id);
            % now typecast to ndi.document from did.document
            if iscell(ndi_document_obj)
                for i=1:numel(ndi_document_obj)
                    ndi_document_obj{i} = ndi.document(ndi_document_obj{i});
                end
            else
                ndi_document_obj = ndi.document(ndi_document_obj);
            end
        end % do_read

        function ndi_didsqlite_obj = do_remove(ndi_didsqlite_obj, ndi_document_id)
            ndi_didsqlite_obj.db.remove_docs(ndi_document_id,'a');
        end % do_remove

        function [ndi_document_objs] = do_search(ndi_didsqlite_obj, searchoptions, searchparams)
            if ~isa(searchparams,'ndi.query') & ~isa(searchparams,'did.query')
                error(['We need an ndi.query or did.query']);
            end

            ndi_document_objs = {};
            [doc_ids] = ndi_didsqlite_obj.db.search(searchparams,'a');
            ndi_document_objs = {};
            for i=1:numel(doc_ids)
                ndi_document_objs{i} = ndi_didsqlite_obj.do_read(doc_ids{i});
            end
        end % do_search()

        function [ndi_binarydoc_obj] = do_openbinarydoc(ndi_didsqlite_obj, ndi_document_id, filename)
            function download_file_from_cloud(destPath, sourcePath)
                if startsWith(sourcePath, 'ndic://')
                    cloudPath = split( extractAfter(sourcePath, 'ndic://'), "/" );
                    cloudDatasetId = cloudPath{1};
                    ndiFileUid = cloudPath{2};
    
                    [~, fileUrl, ~] = ndi.cloud.api.datasets.get_file_details(cloudDatasetId, ndiFileUid);
                    %ndi.util.webSaveCurl(destPath, fileUrl,'Verbose',true);
                    websave(destPath,fileUrl);
                else
                    error('NDI:Didsqlite:UnsupportedFileLocationType', ...
                        ['The source path "%s" uses an unsupported file location type. ' ...
                        'Expected a path starting with "ndic://".'], ...
                        sourcePath);
                end
            end
            ndi_binarydoc_obj = ndi_didsqlite_obj.db.open_doc(ndi_document_id, filename, ...
                'customFileHandler', @download_file_from_cloud);
            ndi_binarydoc_obj.fopen(); % should be open but didsqlite does not open it
        end % do_openbinarydoc()

        function [tf, file_path] = check_exist_binarydoc(ndi_didsqlite_obj, ndi_document_id, filename)
            [tf, file_path] = ndi_didsqlite_obj.db.exist_doc(ndi_document_id, filename);
        end % check_exist_binarydoc()

        function [ndi_binarydoc_matfid_obj] = do_closebinarydoc(ndi_didsqlite_obj, ndi_binarydoc_matfid_obj)
            % DO_CLOSEBINARYDOC - close and unlock an NDI_BINARYDOC_MATFID_OBJ
            %
            % NDI_BINARYDOC_OBJ = DO_CLOSEBINARYDOC(NDI_DIDSQLITE_OBJ, NDI_BINARYDOC_MATFID_OBJ, KEY, NDI_DOCUMENT_ID)
            %
            % Close and unlock the binary file associated with NDI_BINARYDOC_OBJ.
            %
            ndi_didsqlite_obj.db.close_doc(ndi_binarydoc_matfid_obj);
        end % do_closebinarydoc()

        function [file_dir] = file_directory(ndi_didsqlite_obj)
            % FILE_DIRECTORY - return the file directory where ingested files are stored
            %
            % FILE_DIR = FILE_DIRECTORY(NDI_DIDSQLITE_OBJ)
            %
            % Return the full path of the directory where binary files for the database documents
            % are stored.
            %
            file_dir = [ndi_didsqlite_obj.path filesep 'files'];
        end % file_directory
    end
end
