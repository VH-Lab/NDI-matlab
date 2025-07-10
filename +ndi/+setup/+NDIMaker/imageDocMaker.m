% Folder: +ndi/+setup/+NDIMaker/
classdef imageDocMaker < handle
    %imageDocMaker Creates and manages NDI documents for image data linked to ontology terms.
    %   This class is responsible for generating NDI 'ontologyImage' documents.
    %   These documents link image data to specific ontology terms and can optionally
    %   establish a dependency on an 'ontologyTableRow' document, which provides
    %   broader data context.

    properties (Access = public)
        session % The NDI session object (e.g., ndi.session.dir or ndi.database.dir) where documents will be added.
    end

    methods
        function obj = imageDocMaker(session)
            %IMAGEDOCMAKER Constructor for this class.
            %   Initializes the imageDocMaker and associates it with the
            %   provided NDI session.
            %
            %   Inputs:
            %       session: An NDI session object (e.g., an instance of
            %                ndi.session.dir or ndi.database.dir).
            %
            %   Outputs:
            %       obj: An instance of the imageDocMaker class.
            %
            %   Example:
            %       session = ndi.session.dir('/path/to/my/session');
            %       docMaker = ndi.setup.NDIMaker.imageDocMaker(session);
            %
            arguments
                session {mustBeA(session,{'ndi.session.dir','ndi.database.dir'})}
            end
            obj.session = session;
        end % constructor imageDocMaker

        function [doc, inDatabase] = createOntologyImageDoc(obj, image, ontologyNodes, options)
            %CREATEONTOLOGYIMAGEDOC Creates a single NDI 'ontologyImage' document.
            %   DOC = CREATEONTOLOGYIMAGEDOC(OBJ, IMAGE, ONTOLOGYNODES, OPTIONS)
            %
            %   This method constructs an NDI document for image data. The document
            %   is of type 'ontologyImage', which includes 'ngrid' properties to describe
            %   the image data dimensions and type. It also contains the specified
            %   ontology node identifiers.
            %
            %   The image data itself is written to a binary '.ngrid' file, which is
            %   associated with the NDI document.
            %
            %   Inputs:
            %       obj: An instance of the imageDocMaker class.
            %       image: A numeric matrix representing the image data to be stored.
            %       ontologyNodes: A string or cellstr of ontology node ID(s) (e.g., "UBERON:3373")
            %                      that describe the image content.
            %
            %   Optional Name-Value Arguments:
            %       ontologyTableRow_id: The document ID of a parent 'ontologyTableRow' document.
            %                            If provided, a dependency will be created.
            %                            If empty (default), no dependency is added.
            %       Overwrite: Controls behavior if a matching document is found.
            %                   - true: The existing document and its associated .ngrid file
            %                           are removed, and a new one is created.
            %                   - false (default): The existing document is returned, and no
            %                                      new document is created.
            %
            %   Outputs:
            %       doc: The NDI document object (ndi.document) of type 'ontologyImage'.
            %            This will be the newly created document or the existing document
            %            if found and 'options.Overwrite' is false.
            %       inDatabase: A logical flag that is true if the document already
            %                   existed in the database and 'options.Overwrite' was false.
            %
            %   See also: ndi.document, ndi.query, ndi.setup.NDIMaker.tableDocMaker
            %
            arguments
                obj
                image {mustBeNumeric}
                ontologyNodes {mustBeText}
                options.Overwrite (1,1) logical = false
                options.ontologyTableRow_id {mustBeText} = ''
            end

            % --- Input Validation & Preparation ---
            % Create a canonical (sorted, comma-separated) string for querying and storage
            nodes_canonical_string = join(sort(cellstr(ontologyNodes)), ',');
            nodes_canonical_string = nodes_canonical_string{1};

            % --- Search for Existing Document ---
            % Base query on the ontology nodes
            query = ndi.query('ontologyImage.ontologyNodes', 'exact_string', nodes_canonical_string);
            
            % If an ontologyTableRow_id is provided, add it to the query to find a unique document
            if ~isempty(options.ontologyTableRow_id)
                query = query & ndi.query('depends_on.name', 'exact_string', 'ontologyTableRow_id') & ...
                              ndi.query('depends_on.value', 'exact_string', options.ontologyTableRow_id);
            else
                warning('imageDocMaker:NoDepenencies','Each image should be linked to another document such as an ontologyTableRow.');
            end
            
            doc_old = obj.session.database_search(query);

            % --- Handle Overwrite Logic ---
            if numel(doc_old) > 1
                % If no ID was provided, this can happen if multiple docs share the same nodes
                % but have different dependencies (or none). The user must provide the ID to disambiguate.
                error('imageDocMaker:NonUniqueDocument',...
                    'The query returned multiple documents. Provide an ontologyTableRow_id to specify which document to use.');
            end

            inDatabase = false;
            if isscalar(doc_old)
                if options.Overwrite
                    obj.session.database_rm(doc_old{1});
                else
                    doc = doc_old{1};
                    inDatabase = true;
                    return;
                end
            end

            % --- Create New Document ---
            doc = obj.session.newdocument('ontologyImage');

            % Prepare the 'ngrid' properties from the image data
            img_info = whos('image');
            ngrid_struct = struct(...
                'data_size', img_info.bytes / numel(image), ...
                'data_type', class(image), ...
                'data_dim', size(image), ...
                'coordinates', [] ...
            );

            % Prepare the 'ontologyImage' properties
            ontologyImage_struct = struct('ontologyNodes', nodes_canonical_string);

            % Write the image data to the associated ngrid file
            filepath = doc.get_fullpath('ontologyImage.ngrid');
            try
                fid = fopen(filepath, 'w');
                fwrite(fid, image, class(image));
                fclose(fid);
            catch ME
                error('imageDocMaker:FileWriteError', ...
                    'Could not write to file "%s". Error: %s', filepath, ME.message);
            end

            % Add properties and optional dependency to the document
            doc.document_properties.ngrid = ngrid_struct;
            doc.document_properties.ontologyImage = ontologyImage_struct;

            if ~isempty(options.ontologyTableRow_id)
                doc = doc.set_dependency_value('ontologyTableRow_id', options.ontologyTableRow_id);
            end
            
        end % createOntologyImageDoc
    end % methods
end % classdef imageDocMaker