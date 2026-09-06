classdef TestNDIDocumentInheritedFileAPI < matlab.unittest.TestCase
    % ndi.document's file API now that most of it comes from did.document.
    %
    % Step 1 of VH-Lab/NDI-matlab#940 made ndi.document a subclass of
    % did.document but kept every override, so nothing was actually
    % inherited yet. This covers what has changed since: reset_file_info and
    % remove_file, now inherited outright, and add_file, now a thin override
    % that adds only NDI's ndic:// location type before delegating.
    %
    % None of it was tested in NDI before -- remove_file had no caller at
    % all, and nothing anywhere exercised an ndic:// location through
    % add_file -- so without these the suite would pass whether or not the
    % inherited versions behave like the ones they replaced.

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

        % ---- add_file, which is a thin override ----------------------

        function testAddFileIsStillDefinedByNdiDocument(testCase)
            % The counterpart to the assertion above: add_file must NOT be
            % inherited, because did.document has no notion of ndic://.
            testCase.verifyEqual(testCase.definerOf('add_file'), 'ndi.document');
        end

        function testLocalFileIngestsAndDeletesByDefault(testCase)
            doc = ndi.document('demoNDI', 'demoNDI.value', 5);
            doc = doc.add_file('filename1.ext', testCase.writeFile('a.txt'));
            loc = doc.document_properties.files.file_info(1).locations(1);
            testCase.verifyEqual(loc.location_type, 'file');
            testCase.verifyEqual(loc.ingest, 1);
            testCase.verifyEqual(loc.delete_original, 1);
        end

        function testUrlNeitherIngestsNorDeletesByDefault(testCase)
            doc = ndi.document('demoNDI', 'demoNDI.value', 5);
            doc = doc.add_file('filename1.ext', 'https://example.com/a.txt');
            loc = doc.document_properties.files.file_info(1).locations(1);
            testCase.verifyEqual(loc.location_type, 'url');
            testCase.verifyEqual(loc.ingest, 0);
            testCase.verifyEqual(loc.delete_original, 0);
        end

        function testNdicLocationGetsTheNdicloudDefaults(testCase)
            % The whole reason ndi.document still overrides add_file. Inherit
            % did.document's and this location reads as a local file: ingest 1
            % and delete_original 1, against a path that does not exist.
            doc = ndi.document('demoNDI', 'demoNDI.value', 5);
            doc = doc.add_file('filename1.ext', ...
                'ndic://abc123/4126945b0315ec90_c0d16626cae2dacf');
            loc = doc.document_properties.files.file_info(1).locations(1);
            testCase.verifyEqual(loc.location_type, 'ndicloud');
            testCase.verifyEqual(loc.ingest, 0);
            testCase.verifyEqual(loc.delete_original, 0);
        end

        function testAnExplicitValueBeatsTheNdicDefault(testCase)
            doc = ndi.document('demoNDI', 'demoNDI.value', 5);
            doc = doc.add_file('filename1.ext', 'ndic://abc123/deadbeef_cafef00d', ...
                'ingest', 1, 'location_type', 'url');
            loc = doc.document_properties.files.file_info(1).locations(1);
            testCase.verifyEqual(loc.location_type, 'url');
            testCase.verifyEqual(loc.ingest, 1);
            testCase.verifyEqual(loc.delete_original, 0, ...
                'the one default not overridden should still come from ndic://');
        end

        function testNdicDetectionIgnoresCaseAndSurroundingSpace(testCase)
            doc = ndi.document('demoNDI', 'demoNDI.value', 5);
            doc = doc.add_file('filename1.ext', '  NDIC://abc123/deadbeef_cafef00d  ');
            loc = doc.document_properties.files.file_info(1).locations(1);
            testCase.verifyEqual(loc.location_type, 'ndicloud');
            testCase.verifyEqual(loc.location, 'NDIC://abc123/deadbeef_cafef00d', ...
                'add_file should store the location stripped');
        end

        function testAddFileGivesEachLocationAUid(testCase)
            % The uid is what the cloud file map and the ndic:// location are
            % keyed on, so a missing or repeated one is not cosmetic.
            doc = ndi.document('demoNDI', 'demoNDI.value', 5);
            doc = doc.add_file('filename1.ext', testCase.writeFile('a.txt'));
            doc = doc.add_file('filename1.ext', testCase.writeFile('b.txt'));
            uids = {doc.document_properties.files.file_info(1).locations.uid};
            testCase.verifyNumElements(uids, 2);
            testCase.verifyNotEmpty(uids{1});
            testCase.verifyNotEmpty(uids{2});
            testCase.verifyNotEqual(uids{1}, uids{2});
        end

        function testAddFileErrorsForANameNotInTheFileList(testCase)
            doc = ndi.document('demoNDI', 'demoNDI.value', 5);
            testCase.verifyError( ...
                @() doc.add_file('notdeclared.ext', testCase.writeFile('a.txt')), ...
                ?MException);
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
