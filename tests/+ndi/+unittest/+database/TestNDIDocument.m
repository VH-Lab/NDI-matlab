classdef TestNDIDocument < matlab.unittest.TestCase
    % TestNDIDocument - Unittest for core NDI document and session database functionality
    %
    % Description:
    %   This test class verifies the basic Input/Output operations of the NDI
    %   database within a session. It covers:
    %   - Creating new documents (ndi.session.newdocument)
    %   - Adding binary file attachments to a document (ndi.document.add_file)
    %   - Adding documents to the database (ndi.session.database_add)
    %   - Searching for documents (ndi.session.database_search)
    %   - Reading binary data from a document (ndi.session.database_openbinarydoc)
    %   - Removing documents from the database (ndi.session.database_rm)

    properties
        testDir
        binaryFile
    end

    methods (TestClassSetup)
        % This method runs once before any tests are executed.
        function setupOnce(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            
            % Define the test directory and create it if it doesn't exist.
            testCase.testDir = fullfile(fixture.Folder, 'exp1_eg_unittest');
            if ~isfolder(testCase.testDir)
                mkdir(testCase.testDir)
            end
            testCase.binaryFile = fullfile(testCase.testDir, 'myfile.bin');
                        
            % Capure mksqlite initialization message
            C = evalc( "mksqlite('version sql')" ); %#ok<NASGU>
        end
    end

    methods (TestClassTeardown)
        % This method runs once after all tests have been executed.
        function teardownOnce(testCase)
            % Clean up the binary file created during the test.
            if exist(testCase.binaryFile, 'file')
                delete(testCase.binaryFile);
            end
        end
    end

    methods (TestMethodSetup)
        % This method runs before each test to ensure the database is clean.
        function setupTest(testCase)
            testCase.cleanupDemoDocuments();
        end
    end

    methods (TestMethodTeardown)
        % This method runs after each test to ensure the database is clean.
        function teardownTest(testCase)
            testCase.cleanupDemoDocuments();
        end
    end

    methods (Test)
        % --- The Main Test Method --- %
        function testDocumentCreationAndIO(testCase)
            % This test covers the entire create-add-search-read workflow.
            
            % 1. Get a session handle
            E = ndi.session.dir('exp1', testCase.testDir);

            % 2. Create a new document object
            doc = E.newdocument('demoNDI', ...
                'base.name', 'Demo document', ...
                'demoNDI.value', 5);
            
            % 3. Create a binary file with known data
            myfid = fopen(testCase.binaryFile, 'w', 'ieee-le');
            testCase.addTeardown(@() fclose(myfid)); % Ensures file is closed even if test fails
            testCase.verifyGreaterThan(myfid, 0, ['Unable to open file: ' testCase.binaryFile]);
            
            original_data = 0:9;
            fwrite(myfid, char(original_data), 'char');

            % 4. Add the file reference to the document and add to database
            doc = doc.add_file('filename1.ext', testCase.binaryFile);
            E.database_add(doc);
            
            % 5. Verify searching for the document
            testCase.log(matlab.unittest.Verbosity.Verbose, 'Verifying document searching...');

            % 5a. Search by a specific field value
            doc_search1 = E.database_search(ndi.query('demoNDI.value', 'exact_number', 5, ''));
            testCase.verifyNumElements(doc_search1, 1, 'Did not find exactly one document when searching by value.');
            
            % 5b. Search by the document type ('isa')
            doc_search2 = E.database_search(ndi.query('', 'isa', 'demoNDI', ''));
            testCase.verifyNumElements(doc_search2, 1, 'Did not find exactly one document when searching by type.');
            
            % 6. Verify reading binary data from the document
            testCase.log(matlab.unittest.Verbosity.Verbose, 'Verifying binary data reading...');
            doc_to_read = doc_search2{1};
            
            binarydoc = E.database_openbinarydoc(doc_to_read, 'filename1.ext');
            testCase.addTeardown(@() E.database_closebinarydoc(binarydoc)); % Ensure binary doc is closed
            
            data_read = double(binarydoc.fread(10, 'char'))';
            E.database_closebinarydoc(binarydoc); % Close it now
            
            testCase.verifyEqual(data_read, original_data, ...
                'The data read from the binary file did not match the data written.');
        end
    end
    
    methods (Access = private)
        % Helper function to clean up any test documents from the database.
        function cleanupDemoDocuments(testCase)
            E = ndi.session.dir('exp1', testCase.testDir);
            
            % Search for any documents of type 'demoNDI'
            docs_to_remove = E.database_search(ndi.query('', 'isa', 'demoNDI', ''));
            
            % If any are found, remove them
            if ~isempty(docs_to_remove)
                E.database_rm(docs_to_remove);
            end
        end
    end
end