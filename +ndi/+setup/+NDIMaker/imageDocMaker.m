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
                image {mustBeMatrix}
                ontologyNodes {mustBeText}
                options.Overwrite (1,1) logical = false
                options.ontologyTableRow_id {mustBeText} = ''
            end

            % Ensure that ontologyNodes are in the correct format (comma-seperated)
            ontologyNodes = cellstr(ontologyNodes);
            for i = 1:numel(ontologyNodes)
                ontologyNodes{i} = ndi.ontology.lookup(ontologyNodes{i});
            end
            ontologyNodes = join(sort(ontologyNodes), ',');
            ontologyNodes = ontologyNodes{1};
            
            % --- Search for Existing Document ---
            % Base query on the ontology nodes
            query = ndi.query('ontologyImage.ontologyNodes', 'exact_string', ontologyNodes);
            
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
            
            % 1. Collect metadata into structs
            ngrid_struct = ndi.fun.data.mat2ngrid(image);
            ontologyImage_struct = struct('ontologyNodes', ontologyNodes);

            % 2. Make the NDI document object, passing metadata structs as name-value pairs
            doc = ndi.document('ontologyImage', ...
                'ontologyImage', ontologyImage_struct, ...
                'ngrid', ngrid_struct) + obj.session.newdocument();
            
            % 3. Set dependencies if any
            if ~isempty(options.ontologyTableRow_id)
                doc = doc.set_dependency_value('ontologyTableRow_id', options.ontologyTableRow_id);
            end

            % 4. Write the data to a binary file
            filepath = ndi.file.temp_name;
            try
                ndi.fun.data.writengrid(image, filepath, ngrid_struct.data_type);
            catch ME
                error('imageDocMaker:FileWriteError', ...
                    'Could not write to file "%s". Error: %s', filepath, ME.message);
            end

            % 5. Add the file reference to the document
            doc = doc.add_file('ontologyImage.ngrid', filepath);
            
        end % createOntologyImageDoc

        function docs = array2imageDocs(obj, imageArray, ontologyNodes, options)
            %ARRAY2IMAGEDOCS Converts each image in a cell array into an NDI 'ontologyImage' document.
            %   DOCS = ARRAY2IMAGEDOCS(OBJ, IMAGEARRAY, ONTOLOGYNODES, OPTIONS)
            %
            %   This method iterates through each image in the input 'imageArray'.
            %   For each image, it calls `obj.createOntologyImageDoc` to generate
            %   an NDI document of type 'ontologyImage'. The resulting documents
            %   are collected into a cell array and added to the database in a batch.
            %
            %   Inputs:
            %       obj: An instance of the imageDocMaker class.
            %       imageArray: A cell array of numeric matrices. Each matrix is an image.
            %       ontologyNodes: A string or cellstr of ontology node ID(s) applied to ALL images.
            %
            %   Optional Name-Value Arguments:
            %       Overwrite: Flag passed to `createOntologyImageDoc`. Controls whether
            %                  existing documents should be overwritten. Default: false.
            %       OntologyTableRow_ids: A cell array of 'ontologyTableRow' document IDs.
            %                             The number of elements must match 'imageArray'. Each ID
            %                             is passed to the corresponding call of `createOntologyImageDoc`.
            %
            %   Outputs:
            %       docs: A cell array with the same number of elements as 'imageArray'.
            %             Each cell contains the NDI document object (ndi.document)
            %             created by `createOntologyImageDoc` for the corresponding image.
            %
            %   See also: imageDocMaker.createOntologyImageDoc, ndi.gui.component.ProgressBarWindow
            arguments
                obj
                imageArray {mustBeA(imageArray, 'cell')}
                ontologyNodes {mustBeText}
                options.Overwrite (1,1) logical = false
                options.OntologyTableRow_ids {mustBeA(options.OntologyTableRow_ids, 'cell')} = {}
            end

            % --- Input Validation ---
            if ~isempty(options.OntologyTableRow_ids) && numel(imageArray) ~= numel(options.OntologyTableRow_ids)
                error('imageDocMaker:InputSizeMismatch', ...
                    'The number of images in imageArray (%d) must match the number of IDs in OntologyTableRow_ids (%d).', ...
                    numel(imageArray), numel(options.OntologyTableRow_ids));
            end
            
            % --- Processing ---
            numImages = numel(imageArray);
            docs = cell(numImages, 1);
            inDatabase = false(numImages, 1);
            
            % Create progress bar
            progressBar = ndi.gui.component.ProgressBarWindow('Import Dataset','Overwrite',false);
            progressBar = progressBar.addBar('Label', 'Creating Ontology Image Document(s)',...
                'Tag', 'ontologyImage');
            
            onePercent = ceil(numImages / 100);

            for i = 1:numImages
                % Skip if current cell is empty
                if isempty(imageArray{i})
                    continue
                end

                % Determine the ontologyTableRow_id for the current image
                current_id = '';
                if ~isempty(options.OntologyTableRow_ids)
                    current_id = options.OntologyTableRow_ids{i};
                end

                % Create the ontologyImage document for the current image
                [docs{i}, inDatabase(i)] = obj.createOntologyImageDoc(imageArray{i}, ontologyNodes, ...
                    'Overwrite', options.Overwrite, 'ontologyTableRow_id', current_id);

                % Update progress bar periodically
                if mod(i, onePercent) == 0 || onePercent == 1
                    progressBar = progressBar.updateBar('ontologyImage', i / numImages);
                end
            end

            % Add all newly created documents to the database at once for efficiency
            newDocs = docs(~inDatabase & cellfun(@(d) ~isempty(d),docs));
            if ~isempty(newDocs)
                obj.session.database_add(newDocs);
            end

            % Complete progress bar
            progressBar.updateBar('ontologyImage', 1);
        end % array2imageDocs

    end % methods
end % classdef imageDocMaker