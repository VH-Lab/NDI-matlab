% Folder: +ndi/+setup/+NDIMaker/
classdef imageDocMaker < handle
    %imageDocMaker Creates and manages NDI documents for image data linked to ontology terms.
    %   This class is responsible for generating NDI 'ontologyImage' documents.
    %   These documents link image data to specific ontology terms.

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

        function [doc, inDatabase] = createOntologyImageDoc(obj, ontologyTableRowDoc, ontologyNodes, imageData, options)
            %CREATEONTOLOGYIMAGEDOC Creates a single NDI 'ontologyImage' document.
            %   DOC = CREATEONTOLOGYIMAGEDOC(OBJ, ONTOLOGYTABLEROWDOC, ONTOLOGYNODES, IMAGEDATA, OPTIONS)
            %
            %   This method constructs an NDI document for image data. The document
            %   is of type 'ontologyImage', which includes 'ngrid' properties to describe
            %   the image data dimensions and type. It also contains the specified
            %   ontology node identifiers.
            %
            %   A critical feature of the 'ontologyImage' document is its dependency on
            %   an 'ontologyTableRow' document. This links the image to a specific row
            %   of tabular data, providing essential context.
            %
            %   The image data itself is written to a binary '.ngrid' file, which is
            %   associated with the NDI document.
            %
            %   Inputs:
            %       obj: An instance of the imageDocMaker class.
            %       ontologyTableRowDoc: The parent 'ndi.document' of type 'ontologyTableRow'
            %                          that this image is associated with.
            %       ontologyNodes: A string or cellstr of ontology node ID(s) (e.g., "UBERON:3373")
            %                      that describe the image content. These nodes must be present
            %                      in the parent 'ontologyTableRowDoc'.
            %       imageData: A numeric matrix representing the image data to be stored.
            %
            %   Optional Name-Value Arguments:
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
                ontologyTableRowDoc {mustBeA(ontologyTableRowDoc, 'ndi.document')}
                ontologyNodes {mustBeText}
                imageData {mustBeNumeric}
                options.Overwrite (1,1) logical = false
            end

            % --- Input Validation ---
            if ~strcmp(ontologyTableRowDoc.document_properties.document_class.class_name, 'ontologyTableRow')
                error('imageDocMaker:InvalidInput', 'Input document must be of type ontologyTableRow.');
            end

            % Ensure ontologyNodes is a cellstr and create a canonical representation
            ontologyNodes = cellstr(ontologyNodes);
            parentOntologyNodes = split(ontologyTableRowDoc.document_properties.ontologyTableRow.ontologyNodes, ',');
            if ~all(ismember(ontologyNodes, parentOntologyNodes))
                error('imageDocMaker:NodeNotFound', ...
                'One or more provided ontologyNodes are not found in the parent ontologyTableRow document.');
            end

            % Create a canonical (sorted, comma-separated) string for querying and storage
            nodes_canonical_string = join(sort(ontologyNodes), ',');
            nodes_canonical_string = nodes_canonical_string{1};

            % --- Search for Existing Document ---
            query = ndi.query('depends_on.name', 'exact_string', 'ontologyTableRow_id') & ...
                    ndi.query('depends_on.value', 'exact_string', ontologyTableRowDoc.id()) & ...
                    ndi.query('ontologyImage.ontologyNodes', 'exact_string', nodes_canonical_string);
            doc_old = obj.session.database_search(query);

            % --- Handle Overwrite Logic ---
            if numel(doc_old) > 1
                error('imageDocMaker:NonUniqueDocument',...
                    'The query for this image returned multiple documents; the database may be inconsistent.');
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
            % Create the new document object to get its unique ID and path
            doc = obj.session.newdocument('ontologyImage');

            % Prepare the 'ngrid' properties from the imageData
            img_info = whos('imageData');
            ngrid_struct = struct(...
                'data_size', img_info.bytes / numel(imageData), ...
                'data_type', class(imageData), ...
                'data_dim', size(imageData), ...
                'coordinates', [] ... % Per schema, this exists but is not used here
            );

            % Prepare the 'ontologyImage' properties
            ontologyImage_struct = struct('ontologyNodes', nodes_canonical_string);

            % Write the image data to the associated ngrid file
            filepath = doc.get_fullpath('ontologyImage.ngrid');
            try
                fid = fopen(filepath, 'w');
                fwrite(fid, imageData, class(imageData));
                fclose(fid);
            catch ME
                error('imageDocMaker:FileWriteError', ...
                    'Could not write to file "%s". Error: %s', filepath, ME.message);
            end

            % Add all properties and dependencies to the document
            doc.document_properties.ngrid = ngrid_struct;
            doc.document_properties.ontologyImage = ontologyImage_struct;
            doc = doc.set_dependency_value('ontologyTableRow_id', ontologyTableRowDoc.id());
            
            % The calling function is responsible for adding the document to the database,
            % typically in a batch operation.
        end % createOntologyImageDoc
    end % methods
end % classdef imageDocMaker