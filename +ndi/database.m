classdef database
    % A (primarily abstract) database class for NDI that stores and manages virtual documents (NoSQL database)
    %
    % 
    %
    % 

    properties (SetAccess=protected,GetAccess=public)
        path % The file system or remote path to the database
        session_unique_reference % The reference string for the database
    end % properties

    methods (Access = ?ndi.session)
        function [hCleanup, filename] = open(ndi_database_obj)
            % OPEN - Open a database connection
            [hCleanup, filename] = ndi_database_obj.do_open_database(); % Calls protected method
        end
    end

    methods
        function ndi_database_obj = database(varargin)
            % ndi.database - create a new ndi.database
            %
            % NDI_DATABASE_OBJ = ndi.database(PATH, REFERENCE)
            %
            % Creates a new ndi.database object with data path PATH
            % and reference REFERENCE.
            %
            
            path = '';
            session_unique_reference = '';

            if nargin>0,
                path = varargin{1};
            end
            if nargin>1,
                session_unique_reference = varargin{2};
            end

            ndi_database_obj.path = path;
            ndi_database_obj.session_unique_reference = session_unique_reference;
        end % ndi.database

        function ndi_document_obj = newdocument(ndi_database_obj, document_type)
            % NEWDOCUMENT - obtain a new/blank ndi.document object that can be used with a ndi.database
            % 
            % NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_DATABASE_OBJ [, DOCUMENT_TYPE])
            %
            % Creates a new/blank ndi.document document object that can be used with this
            % ndi.database.
            %
                if nargin<2,
                    document_type = 'base';
                end;
                ndi_document_obj = ndi.document(document_type, ...
                        'session_unique_refrence', ndi_database_obj.session_unique_reference);
        end % newdocument

        function ndi_database_obj = add(ndi_database_obj, ndi_document_obj, varargin)
            % ADD - add an ndi.document to the database at a given path
            %
            % NDI_DATABASE_OBJ = ADD(NDI_DATABASE_OBJ, NDI_DOCUMENT_OBJ, DBPATH, ...)
            %
            % Adds the document NDI_DOCUMENT_OBJ to the database NDI_DATABASE_OBJ.
            %
            % This function also accepts name/value pairs that modify its behavior:
            % Parameter (default)      | Description
            % -------------------------------------------------------------------------
            % 'Update'  (1)            | If document exists, update it. If 0, an error is 
            %                          |   generated if a document with the same ID exists
            % 
            % See also: vlt.data.namevaluepair 
                Update = 1;
                vlt.data.assign(varargin{:});
                add_parameters = vlt.data.var2struct('Update');
                ndi_database_obj = do_add(ndi_database_obj, ndi_document_obj, add_parameters);
        end % add()

        function [ndi_document_obj] = read(ndi_database_obj, ndi_document_id)
            % READ - read an ndi.document from an ndi.database at a given db path
            %
            % NDI_DOCUMENT_OBJ = READ(NDI_DATABASE_OBJ, NDI_DOCUMENT_ID, [VERSION]) 
            %
            % Read the ndi.document object with the document ID specified by NDI_DOCUMENT_ID. If VERSION
            % is provided (an integer) then only the version that is equal to VERSION is returned.
            % Otherwise, the latest version is returned.
            %
            % If there is no ndi.document object with that ID, then empty is returned ([]).
            %
                [ndi_document_obj] = do_read(ndi_database_obj, ndi_document_id);
        end % read()

        function [ndi_binarydoc_obj] = openbinarydoc(ndi_database_obj, ndi_document_or_id, filename)
            % OPENBINARYDOC - open and lock an ndi.database.binarydoc that corresponds to a document id
            %
            % [NDI_BINARYDOC_OBJ] = OPENBINARYDOC(NDI_DATABASE_OBJ, NDI_DOCUMENT_OR_ID, FILENAME])
            %
            % Return the open ndi.database.binarydoc object and VERSION that corresponds to an ndi.document and
            % the requested version (the latest version is used if the argument is omitted).
            % NDI_DOCUMENT_OR_ID can be either the document id of an ndi.document or an ndi.document object itsef.
            %
            % Note that this NDI_BINARYDOC_OBJ must be closed and unlocked with ndi.database/CLOSEBINARYDOC.
            % The locked nature of the binary doc is a property of the database, not the document, which is why
            % the database is needed.
            % 
                if isa(ndi_document_or_id,'ndi.document'),
                    ndi_document_id = ndi_document_or_id.id();
                else,
                    ndi_document_id = ndi_document_or_id;
                end;
                [ndi_document_obj] = ndi_database_obj.read(ndi_document_id);
                ndi_binarydoc_obj = do_openbinarydoc(ndi_database_obj, ndi_document_id, filename);
        end; % openbinarydoc

        function [tf, file_path] = existbinarydoc(ndi_database_obj, ndi_document_or_id, filename)
            % EXISTBINARYDOC - check if a binary doc exists for a given document id
            %
            % [TF, FILE_PATH] = EXISTBINARYDOC(NDI_DATABASE_OBJ, NDI_DOCUMENT_OR_ID, FILENAME)
            %
            %  Return a boolean flag (TF) indicating if a binary document 
            %  exists for an ndi.document and, if it exists, the full file 
            %  path (FILE_PATH) to the file where the binary data is stored.
            
            if isa(ndi_document_or_id,'ndi.document'),
                ndi_document_id = ndi_document_or_id.id();
            else
                ndi_document_id = ndi_document_or_id;
            end
            [tf, file_path] = check_exist_binarydoc(ndi_database_obj, ndi_document_id, filename);
        end % existbinarydoc

        function [ndi_binarydoc_obj] = closebinarydoc(ndi_database_obj, ndi_binarydoc_obj)
            % CLOSEBINARYDOC - close and unlock an ndi.database.binarydoc 
            %
            % [NDI_BINARYDOC_OBJ] = CLOSEBINARYDOC(NDI_DATABASE_OBJ, NDI_BINARYDOC_OBJ)
            %
            % Close and lock an NDI_BINARYDOC_OBJ. The NDI_BINARYDOC_OBJ must be unlocked in the
            % database, which is why it is necessary to call this function through the database.
            %
                ndi_binarydoc_obj = do_closebinarydoc(ndi_database_obj, ndi_binarydoc_obj);
        end; % closebinarydoc

        function ndi_database_obj = remove(ndi_database_obj, ndi_document_id)
            % REMOVE - remove a document from an ndi.database
            %
            % NDI_DATABASE_OBJ = REMOVE(NDI_DATABASE_OBJ, NDI_DOCUMENT_ID) 
            %     or
            % NDI_DATABASE_OBJ = REMOVE(NDI_DATABASE_OBJ, NDI_DOCUMENT) 
            %
            % Removes the ndi.document object with the 'document unique reference' equal
            % to NDI_DOCUMENT_OBJ_ID. 
            %
            % If an ndi.document is passed, then the NDI_DOCUMENT_ID is extracted using
            % ndi.document/DOC_UNIQUE_ID. If a cell array of ndi.document is passed instead, then
            % all of the documents are removed.
            %
                if isempty(ndi_document_id),
                    return; % nothing to do
                end;

                ndi_document_id_list = {};
                
                if ~iscell(ndi_document_id),
                    ndi_document_id = {ndi_document_id};
                end;
                
                for i=1:numel(ndi_document_id)
                    if isa(ndi_document_id{i}, 'ndi.document'),
                        ndi_document_id_list{end+1} = ndi_document_id{i}.id();
                    else,
                        ndi_document_id_list{end+1} = ndi_document_id{i};
                    end;
                end;

                for i=1:numel(ndi_document_id_list),
                    do_remove(ndi_database_obj, ndi_document_id_list{i});
                end;
        end % remove()

        function docids = alldocids(ndi_database_obj)
            % ALLDOCIDS - return all document unique reference numbers for the database
            %
            % DOCIDS = ALLDOCIDS(NDI_DATABASE_OBJ)
            %
            % Return all document unique reference strings as a cell array of strings. If there
            % are no documents, empty is returned.
            %
                docids = {}; % needs to be overridden
        end; % alldocids()

        function clear(ndi_database_obj, areyousure)
            % CLEAR - remove/delete all records from an ndi.database
            % 
            % CLEAR(NDI_DATABASE_OBJ, [AREYOUSURE])
            %
            % Removes all documents from the vlt.file.dumbjsondb object.
            % 
            % Use with care. If AREYOUSURE is 'yes' then the
            % function will proceed. Otherwise, it will not.
            %
            % See also: ndi.database/REMOVE

                if nargin<2,
                    areyousure = 'no';
                end;
                if strcmpi(areyousure,'Yes')
                    ids = ndi_database_obj.alldocids;
                    for i=1:numel(ids), 
                        ndi_database_obj.remove(ids{i}); % remove the entry
                    end
                else,
                    disp(['Not clearing because user did not indicate he/she is sure.']);
                end;
        end % clear

        function [ndi_document_objs] = search(ndi_database_obj, searchparams)
            % SEARCH - search for an ndi.document from an ndi.database
            %
            % [DOCUMENT_OBJS] = SEARCH(NDI_DATABASE_OBJ, {'PARAM1', VALUE1, 'PARAM2', VALUE2, ... })
            %
            % Searches metadata parameters PARAM1, PARAM2, etc of NDS_DOCUMENT entries within an NDI_DATABASE_OBJ.
            % If VALUEN is a string, then a regular expression is evaluated to determine the match. If VALUEN is not
            % a string, then the items must match exactly.
            % If PARAMN1 begins with a dash, then VALUEN indicates the value of one of these special parameters:
            %
            % This function returns a cell array of ndi.document objects. If no documents match the
            % query, then an empty cell array ({}) is returned.  
            % 
                searchOptions = {};
                [ndi_document_objs] = ndi_database_obj.do_search(searchOptions,searchparams);
        end % search()

    end % methods ndi.database

    methods (Access=protected)
        function ndi_database_obj = do_add(ndi_database_obj, ndi_document_obj, add_parameters)
        end % do_add
        function [ndi_document_obj] = do_read(ndi_database_obj, ndi_document_id);
        end % do_read
        function ndi_document_obj = do_remove(ndi_database_obj, ndi_document_id)
        end % do_remove
        function [ndi_document_objs] = do_search(ndi_database_obj, searchoptions, searchparams) 
        end % do_search()
        function [ndi_binarydoc_obj] = do_openbinarydoc(ndi_database_obj, ndi_document_id) 
        end % do_openbinarydoc()
        function [tf, file_path] = check_exist_binarydoc(ndi_database_obj, ndi_document_id) 
        end % do_openbinarydoc()
        function [ndi_binarydoc_obj] = do_closebinarydoc(ndi_database_obj, ndi_binarydoc_obj) 
        end % do_closebinarydoc()
        function do_open_database(ndi_database_obj)
        end
    end % Methods (Access=Protected) protected methods
end % classdef


