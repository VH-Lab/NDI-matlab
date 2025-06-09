classdef TestNDIDocumentPersistence < matlab.unittest.TestCase
    % TestNDIDocumentPersistence - A parameterized test for the NDI object persistence lifecycle.
    %
    % Description:
    %   This class verifies that various core NDI objects can be correctly saved to
    %   the session database as documents and then perfectly reconstructed. It replaces
    %   multiple separate test scripts with a single, powerful, parameterized test.

    properties (TestParameter)
        % This parameter provides the class name of the object to be tested.
        % The test method 'testGenericObjectLifecycle' will be run once for each entry.
        className = ndi.unittest.database.TestNDIDocumentPersistence.getObjectClassNamesToTest();
    end

    properties
        testDir
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            testCase.testDir = [ndi.common.PathConstants.ExampleDataFolder filesep 'exp1_eg_unittest'];
            if ~isfolder(testCase.testDir)
                mkdir(testCase.testDir);
            end
        end
    end

    methods (TestMethodSetup)
        % This runs before each test to ensure the database is clean.
        function setupTest(testCase)
            E = ndi.session.dir('exp1', testCase.testDir);
            fprintf('Cleaning up database for next test...\n');
            
            % Clean up all possible document types created by these tests
            doc_types = {'syncrule','syncgraph','filenavigator','daqsystem','daqreader'};
            for i = 1:numel(doc_types)
                docs = E.database_search(ndi.query('', 'isa', doc_types{i}, ''));
                if ~isempty(docs), E.database_rm(docs); end
            end
        end
    end

    methods (Test)
        function testGenericObjectLifecycle(testCase, className)
            % This parameterized test runs the full create->save->load->verify lifecycle
            % for a generic NDI object that has a no-argument constructor.
            
            E = ndi.session.dir('exp1', testCase.testDir);
            
            fprintf('Testing lifecycle for class: %s\n', className);
            
            % 1. Create the original object
            if strcmp(className, 'ndi.time.syncgraph')
                % Special case for syncgraph, which requires the session in its constructor
                original_obj = ndi.time.syncgraph(E);
                original_obj = original_obj.addrule(ndi.time.syncrule.filematch());
            elseif contains(className, 'ndi.file.navigator')
                % Special case for filenavigator, which requires the session
                original_obj = feval(className, E, '.*\.rhd\>');
            else
                original_obj = feval(className); % e.g., ndi.time.syncrule.filematch()
            end
            
            % 2. Create its document(s) and add to the database
            obj_docs = original_obj.newdocument();
            E.database_add(obj_docs);
            
            % 3. Search for the document to ensure it was added
            found_docs = E.database_search(original_obj.searchquery());
            testCase.verifyNumElements(found_docs, 1, ...
                ['Did not find exactly one document for class ' className ' after adding.']);
            
            % 4. Reconstruct the object from the document
            reconstructed_obj = ndi.database.fun.ndi_document2ndi_object(found_docs{1}, E);
            
            % 5. Verify the reconstructed object is equal to the original
            testCase.verifyTrue(logical(eq(reconstructed_obj, original_obj)), ...
                ['Reconstructed object of class ' className ' did not match the original.']);
        end

        function testDaqSystemLifecycle(testCase)
            % A dedicated test for DAQ systems, as their creation is more complex.
            E = ndi.session.dir('exp1', testCase.testDir);
            E.daqsystem_clear(); % Ensure no devices exist at the start

            devlist = ndi.setup.daq.system.listDaqSystemNames('vhlab');
            testCase.verifyNotEmpty(devlist, 'Could not find any VHLab DAQ system definitions to test.');

            for i=1:numel(devlist)
                fprintf('Testing lifecycle for DAQ system: %s\n', devlist{i});
                
                % 1. Add the DAQ system using the configuration helper
                daqSystemConfig = ndi.setup.DaqSystemConfiguration.fromLabDevice('vhlab', devlist{i});
                E_with_dev = daqSystemConfig.addToSession(E);
                original_daqsys = E_with_dev.daqsystem_load('name', devlist{i});
                
                % 2. Search for its document
                ds_doc = E_with_dev.database_search(original_daqsys.searchquery());
                testCase.verifyNumElements(ds_doc, 1, ...
                    ['Did not find exactly 1 document for daqsystem ' devlist{i}]);

                % 3. Reconstruct from the document
                reconstructed_daqsys = ndi.database.fun.ndi_document2ndi_object(ds_doc{1}, E_with_dev);
                
                % 4. Verify equality
                testCase.verifyTrue(eq(reconstructed_daqsys, original_daqsys), ...
                    ['Reconstructed daqsystem ' devlist{i} ' did not match the original.']);

                % Clean up this device before testing the next one
                E.daqsystem_rm(original_daqsys);
            end
        end
    end

    methods (Static)
        % This helper method gathers all class names from the various test scripts.
        function classNames = getObjectClassNamesToTest()
            sync_and_time = { ...
                'ndi.time.syncrule.filematch',...
                'ndi.time.syncgraph',...
                };
            filenav = { ...
                'ndi.file.navigator',...
                'ndi.file.navigator.epochdir',...
                };
            daqreader = { ...
                'ndi.daq.reader',...
                'ndi.daq.reader.mfdaq', ...
                'ndi.daq.reader.mfdaq.cedspike2', ...
                'ndi.daq.reader.mfdaq.intan', ...
                'ndi.daq.reader.mfdaq.spikegadgets', ...
                'ndi.setup.daq.reader.mfdaq.stimulus.vhlabvisspike2', ...
                };

            classNames = [sync_and_time, filenav, daqreader];
        end
    end
end