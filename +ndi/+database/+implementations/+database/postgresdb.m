classdef  postgresdb < ndi.database

    properties
        db          % Stores PostgreSQL database
        dbname        % Used to specify name of Postgres database
    end

    methods

        function ndi_postgresdb_obj = ndi.database.postgresdb(varargin)
            % ndi.database.postgresdb make a new ndi.database.postgresdb object
            %
            % NDI_POSTGRESDB_OBJ = ndi.database.postgresdb(PATH, SESSION_UNIQUE_REFERENCE, COMMAND, ...)
            %
            % Creates a new ndi.database.postgresdb object.
            %
            % Assumes metadata is stored in [dbname].public.documents
            %
            % COMMAND can either be 'Load' or 'New'. The second argument
            % should be the full pathname of the location where the files
            % should be stored on disk.

            assert(nargin==3 ,"Need 3 variables as input: name of database, username, and password")
            disp(varargin);
            dbname = varargin{1};
            username = varargin{2};
            password = varargin{3};

            %             ndi_postgresdb_obj = ndi_postgresdb_obj@ndi.database(varargin{:});
            %             disp('pgobj:')
            %             disp(ndi_postgresdb_obj)
            %
            %             disp('objdb:')
            %                ndi_postgresdb_obj.db = vlt.file.dumbjsondb(varargin{3:end},...
            %                  'dirname','dumbjsondb','unique_object_id_field','ndi_document.id');

            conn = database(dbname,username,password);
            ndi_postgresdb_obj.db = conn;
            ndi_postgresdb_obj.dbname = dbname;

            disp(ndi_postgresdb_obj.db)
        end % ndi_postgresdb_obj()

    end

    methods, % public
        function docids = alldocids(ndi_postgresdb_obj)
            % ALLDOCIDS - return all document unique reference numbers for the database
            %
            %
            % DOCIDS = ALLDOCIDS(NDI_POSTGRESDB_OBJ, DBNAME)
            %
            % Return all document unique reference strings as a cell array of strings. If there
            % are no documents, empty is returned.
            %
            % NOTE: Requires Database name as input and Assuming data is stored in public.documents
            % docid_query = "SELECT id FROM " + ndi_postgresdb_obj.dbname + ".public.documents"
            % data = select(ndi_postgresdb_obj.db,docid_query);

            table = sqlread(ndi_postgresdb_obj.db, 'public.documents');
            docids = table.id;
        end; % alldocids()

        function sqlquery = ndiquery_to_sql(ndi_postgresdb_obj, ndiquery)
            % Translates an ndiquery into a SQL command
            % Assumes input is a ndiquery converted to struct
            % Assumes params are correct
            %
            % q = ndi.query('ndi_document.id','exact_string','ABCD','')
            % (This means: find all documents that have a field ndi_document.id that exactly matches the string 'ABCD')
            % q = ndi.query('list','exact_string','abc','')
            %
            % Example SQL query:
            % SELECT data ->> 'list' AS list
            % FROM dbname.public.documents
            % WHERE data ->> 'list' LIKE ('%abc%')

            assert(isa(ndiquery, 'struct'), "ndi.query not a struct")
            assert(isfield(ndiquery, 'operation'), "ndi.query object has no operation")
            assert(isfield(ndiquery, 'param1'), "ndi.query object has no param1")
            assert(isfield(ndiquery, 'param2'), "ndi.query object has no param2")
            field = ndiquery.field
            param1 = ndiquery.param1
            param2 = ndiquery.param2


            % Basic structure of a SQL query
            % Assumes metadata is stored in 'data':
            % Outside of the id, all meta must be accessed through
            % 'data'
            select = "SELECT ";
            not_id = 0;
            if ~strcmp(ndiquery.field, "id")
                select = select + "data ->> '" + field + "' AS " + field
                not_id = 1;
            else
                select = select + "id"

            end

            from = "FROM " + ndi_postgresdb_obj.dbname + ".public.documents";
            where = "WHERE";

            % Translate the ndi
            switch ndiquery.operation
                case 'regexp'
                    % are there any regular expression matches between
                    % the field value and 'param1'?
                    %
                    % expects correct SQL regular expression

                    where = where + " " + field + " " + param1

                case 'exact_string'
                    % is the field value an exact string match for 'param1'?
                    if not_id
                        where = where + " data->>'" + field + "' = '" + param1 + "'";
                    else
                        where = where + " " + field + " = '" + param1 + "'";
                    end


                case 'contains_string'
                    % is the field value a char array that contains 'param1'?
                    where = where + " data ->> '" + field + "' LIKE '%" + param1 + "%'";

                case 'exact_number'
                    % is the field value exactly 'param1' (same size and values)?
                    if not_id
                        where = where + " (data->>'" + field + "')::NUMERIC = " + param1;
                    else
                        where = where + " (data'" + field + "')::NUMERIC = " + param1;
                    end


                case 'lessthan'
                    % is the field value less than 'param1' (and comparable size)
                    if not_id
                        where = where + " (data->>'" + field + "')::NUMERIC < " + param1;
                    else
                        where = where + " (data'" + field + "')::NUMERIC < " + param1;
                    end

                case 'lessthaneq'
                    % is the field value less than or equal to 'param1' (and comparable size)
                    if not_id
                        where = where + " (data->>'" + field + "')::NUMERIC <= " + param1;
                    else
                        where = where + " (data'" + field + "')::NUMERIC <= " + param1;
                    end

                case 'greaterthan'
                    % is the field value greater than 'param1' (and comparable size)
                    if not_id
                        where = where + " (data->>'" + field + "')::NUMERIC > " + param1;
                    else
                        where = where + " (data'" + field + "')::NUMERIC > " + param1;
                    end


                case 'greaterthaneq'
                    % is the field value greater than or equal to 'param1' (and comparable size)
                    if not_id
                        where = where + " (data->>'" + field + "')::NUMERIC >= " + param1;
                    else
                        where = where + " (data'" + field + "')::NUMERIC >= " + param1;
                    end


                case 'has_field'
                    % is the field present? (no role for 'param1' or 'param2')
                    % find all documents that have that field
                    if not_id
                        where = where + " LENGTH(data ->> '" + field + "') > 0";
                    else
                        where = where + " LENGTH('" + field + "') > 0";
                    end


                case 'hasanysubfield_contains_string'
                    % Is the field value an array of structs or cell array of structs
                    % such that any has a field named 'param1' with a string that
                    % TODO contains the string in 'param2'?
                    % Note: Assumed it cannot be ID
                    % where = where +

                case 'or'
                    % are any of the searchstruct elements specified in 'param1' true?
                    % searchstruct can be an array of searches
                    % param1 is an array of search structs
                    % do AND of all of these entries
                    % TODO
                    for i = 1:length(param1)
                        % first one
                        if i==1
                            where = where + " AND (version = '" + i + "'";
                        else
                            where = where + " OR version = '" + i + "'";
                        end

                    end
                    where = where + ")";


                case 'isa'
                    % is 'param1' either a superclass or the document class itself of the ndi.document?
                    % ndi.document is the field?
                    % TODO

                case 'depends_on'
                    % does the document depend on an item with name 'param1' and value 'param2'?
                    % field is document?
                    % TODO do key value pair have to be in different columns, can't have both in one column for sql?

                otherwise
                    disp("error: invalid operation")


            end
            sqlquery = select + " " + from + " " + where
        end; % ndiquery_to_sql

    end;

    methods (Access=protected),

        function new_db = do_add(ndi_postgresdb_obj, ndi_document_obj, add_parameters)
            % sqlwrite procedure to insert Matlab data into a database
            % table
            %
            %             ndi_document_obj = table(30,500000,1000,25,"Rubik's Cube", ...
            %             'VariableNames',{'productNumber' 'stockNumber' ...
            %             'supplierNumber' 'unitCost' 'productDescription'});
            %
            %             sqlwrite(conn,tablename,data)

            % Note: add_paramters is unused, and it is assumed the data is in
            % public.documents
            %

            tablename = 'public.documents'
            sqlwrite(ndi_postgresdb_obj.db, tablename, ndi_document_obj)
            new_db = ndi_postgresdb_obj

        end; % do_add


        function [ndi_document_obj, version] = do_read(ndi_postgresdb_obj, ndi_document_id, version);
            % reads and shows a document from the database with the unique ndi document ID
            % expects a version, reading the latest by default

            sqlquery = "SELECT * FROM public.documents WHERE id = '" + ndi_document_id + "'"

            % First check if versions column exists in the table
            table = sqlread(ndi_postgresdb_obj.db, 'public.documents');
            Exist_Column = strcmp('version', table.Properties.VariableNames);
            vercol_exists = Exist_Column(Exist_Column==1)
            class(vercol_exists)

            % TODO: version feature

            if vercol_exists
                sqlquery = sqlquery + " AND version = '" + version + "'";



            end
            disp(sqlquery)
            ndi_document_obj = select(ndi_postgresdb_obj.db, sqlquery)

        end; % do_read


        function ndi_postgresdb_obj = do_remove(ndi_postgresdb_obj, ndi_document_id, versions)
            % removes a document from the database with the unique ndi document ID
            % expects versions as a column in the table

            sqlquery = "DELETE FROM public.documents WHERE id = '" + ndi_document_id + "'"

            if ~isempty(versions)

                for i = 1:length(versions)
                    % first one
                    if i==1
                        sqlquery = sqlquery + " AND (version = '" + i + "'";
                    else
                        sqlquery = sqlquery + " OR version = '" + i + "'";
                    end
                end
                sqlquery = sqlquery + ")"

            end

            execute(ndi_postgresdb_obj.db, sqlquery)

        end; % do_remove



        function [data, versions] = do_search(ndi_postgresdb_obj, searchoptions, searchparams)
            % Takes in a list of search paramaters (an array of
            % search op
            %
            % Note: searchoptions is not used

            assert( isa(searchparams,'ndi.query'), "search params are not valid")
            searchparams = searchparams.to_searchstructure;
            if 0, % display
                disp('search params');
                for i=1:numel(searchparams),
                    searchparams(i),
                    searchparams(i).param1,
                    searchparams(i).param2,
                end
            end;
            sql_query = ndiquery_to_sql(ndi_postgresdb_obj, searchparams)
            data = select(ndi_postgresdb_obj.db, sql_query)

            table = sqlread(ndi_postgresdb_obj.db, 'public.documents');
            Exist_Column = strcmp('version', table.Properties.VariableNames);
            vercol_exists = Exist_Column(Exist_Column==1)
            versions = []

            % TODO: version feature
            %             if vercol_exists && ~isempty(version)
            %                 select(ndi_postgresdb_obj.db, sql_query)
            %                 versions =
            %             end


            %             ndi_document_objs = {};
            %             [docs,doc_versions] = ndi_postgresdb_obj.db.search(searchoptions, searchparams);
            %             for i=1:numel(docs),
            %                 ndi_document_objs{i} = ndi.document(docs{i});
        end;

    end; % do_search()

    %         function [ndi_binarydoc_obj, key] = do_openbinarydoc(ndi_matlabdumbjsondb_obj, ndi_document_id, version)
    %             ndi_binarydoc_obj = [];
    %             [fid, key] = ndi_matlabdumbjsondb_obj.db.openbinaryfile(ndi_document_id, version);
    %             if fid>0,
    %                 [filename,permission,machineformat,encoding] = fopen(fid);
    %                 ndi_binarydoc_obj = ndi.database.implementations.binarydoc.matfid('fid',fid,'fullpathfilename',filename,...
    %                     'machineformat',machineformat,'permission',permission, 'doc_unique_id', ndi_document_id, 'key', key);
    %                 ndi_binarydoc_obj.frewind(); % move to beginning of the file
    %             end
    %         end; % do_binarydoc()

    %         function [ndi_binarydoc_matfid_obj] = do_closebinarydoc(ndi_matlabdumbjsondb_obj, ndi_binarydoc_matfid_obj)
    %             % DO_CLOSEBINARYDOC - close and unlock an NDI_BINARYDOC_MATFID_OBJ
    %             %
    %             % NDI_BINARYDOC_OBJ = DO_CLOSEBINARYDOC(NDI_MATLABDUMBJSONDB_OBJ, NDI_BINARYDOC_MATFID_OBJ, KEY, NDI_DOCUMENT_ID)
    %             %
    %             % Close and unlock the binary file associated with NDI_BINARYDOC_OBJ.
    %             %
    %                 ndi_matlabdumbjsondb_obj.db.closebinaryfile(ndi_binarydoc_matfid_obj.fid, ...
    %                     ndi_binarydoc_matfid_obj.key, ndi_binarydoc_matfid_obj.doc_unique_id);
    %                 ndi_binarydoc_matfid_obj.fclose();
    %         end; % do_closebinarydoc()
    %    end;
end
