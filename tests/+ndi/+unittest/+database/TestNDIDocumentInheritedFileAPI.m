classdef TestNDIDocumentInheritedFileAPI < matlab.unittest.TestCase
    % The file-API methods ndi.document no longer defines for itself.
    %
    % Step 1 of VH-Lab/NDI-matlab#940 made ndi.document a subclass of
    % did.document but kept every override, so nothing was actually
    % inherited yet. This covers the ones that have since been retired:
    % they were untested in NDI (remove_file had no caller at all), so
    % without these the suite would pass whether or not the inherited
    % versions behave like the deleted ones.

    properties
        tempDir
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.tempDir = pwd;
        end
    end

    methods
        function p = writeFile(testCase, name)
            p = fullfile(testCase.tempDir, name);
            fid = fopen(p, 'w');
            fprintf(fid, 'some data');
            fclose(fid);
        end

        function definingClass = definerOf(~, methodName)
            mc = meta.class.fromName('ndi.document');
            k = find(strcmp({mc.MethodList.Name}, methodName), 1);
            if isempty(k)
                definingClass = '';
            else
                definingClass = mc.MethodList(k).DefiningClass.Name;
            end
        end
    end

    methods (Test)

        % ---- what is inherited ---------------------------------------

        function testTheseMethodsComeFromDidDocument(testCase)
            % If someone re-adds an override, this says so directly rather
            % than leaving the behaviour tests below to imply it.
            testCase.verifyEqual(testCase.definerOf('remove_file'), 'did.document');
            testCase.verifyEqual(testCase.definerOf('reset_file_info'), 'did.document');
        end

        % ---- reset_file_info -----------------------------------------

        function testFreshDocumentHasSeededFileInfo(testCase)
            % did.document's add_file assumes files.file_info exists. A
            % document built from a definition has to arrive with it.
            doc = ndi.document('demoNDI', 'demoNDI.value', 5);
            testCase.assertTrue(isfield(doc.document_properties, 'files'));
            testCase.verifyTrue(isfield(doc.document_properties.files, 'file_info'));
            testCase.verifyEmpty(doc.document_properties.files.file_info);
        end

        function testResetFileInfoClearsAddedFiles(testCase)
            doc = ndi.document('demoNDI', 'demoNDI.value', 5);
            doc = doc.add_file('filename1.ext', testCase.writeFile('a.txt'), ...
                'ingest', 0, 'delete_original', 0);
            testCase.assertNotEmpty(doc.document_properties.files.file_info);

            doc = doc.reset_file_info();
            testCase.verifyEmpty(doc.document_properties.files.file_info);
        end

        function testResetFileInfoLeavesTheDeclarationAlone(testCase)
            % file_list says which names the class accepts; resetting the
            % instance's file records must not touch it.
            doc = ndi.document('demoNDI', 'demoNDI.value', 5);
            before = doc.document_properties.files.file_list;
            doc = doc.reset_file_info();
            testCase.verifyEqual(doc.document_properties.files.file_list, before);
        end

        function testResetFileInfoIsSafeOnADocumentWithoutFiles(testCase)
            % base has no files field at all; reset must return quietly.
            doc = ndi.document('base');
            testCase.assertFalse(isfield(doc.document_properties, 'files'));
            doc = doc.reset_file_info();
            testCase.verifyFalse(isfield(doc.document_properties, 'files'));
        end

        % ---- remove_file ---------------------------------------------

        function testRemoveFileRemovesTheName(testCase)
            doc = ndi.document('demoNDI', 'demoNDI.value', 5);
            doc = doc.add_file('filename1.ext', testCase.writeFile('a.txt'), ...
                'ingest', 0, 'delete_original', 0);
            doc = doc.remove_file('filename1.ext');
            testCase.verifyEmpty(doc.document_properties.files.file_info);
        end

        function testRemoveFileByLocationRemovesOnlyThatLocation(testCase)
            % Two locations for one name: removing one leaves the other, and
            % leaves the name itself in place.
            locA = testCase.writeFile('a.txt');
            locB = testCase.writeFile('b.txt');
            doc = ndi.document('demoNDI', 'demoNDI.value', 5);
            doc = doc.add_file('filename1.ext', locA, 'ingest', 0, 'delete_original', 0);
            doc = doc.add_file('filename1.ext', locB, 'ingest', 0, 'delete_original', 0);
            testCase.assertNumElements(doc.document_properties.files.file_info, 1);
            testCase.assertNumElements(doc.document_properties.files.file_info(1).locations, 2);

            doc = doc.remove_file('filename1.ext', locA);
            remaining = doc.document_properties.files.file_info(1).locations;
            testCase.verifyNumElements(remaining, 1);
            testCase.verifyEqual(remaining(1).location, locB);
        end

        function testRemoveFileErrorsForANameNotInTheFileList(testCase)
            doc = ndi.document('demoNDI', 'demoNDI.value', 5);
            % is_in_file_list rejects it with error(msg), which carries no
            % identifier, so match any MException rather than an id.
            testCase.verifyError(@() doc.remove_file('notdeclared.ext'), ...
                ?MException, ...
                'removing an undeclared name should be rejected');
        end

        function testRemoveFileIsQuietWhenThereIsNoFileInfo(testCase)
            % Nothing was added, so there is nothing to remove. The default
            % is to say nothing about it.
            doc = ndi.document('demoNDI', 'demoNDI.value', 5);
            doc = doc.remove_file('filename1.ext');
            testCase.verifyEmpty(doc.document_properties.files.file_info);
        end

        function testRemoveFileCanBeAskedToComplainInstead(testCase)
            doc = ndi.document('demoNDI', 'demoNDI.value', 5);
            testCase.verifyError( ...
                @() doc.remove_file('filename1.ext', [], 'ErrorIfNoFileInfo', true), ...
                ?MException);
        end

    end
end
