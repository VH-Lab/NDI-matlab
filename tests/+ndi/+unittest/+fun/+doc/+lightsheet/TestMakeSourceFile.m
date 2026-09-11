classdef TestMakeSourceFile < matlab.unittest.TestCase
    % TestMakeSourceFile - describe (fileReference) vs attach (generic_file).
    %
    % Mirrors +gene's TestGeneFromFiles source-file coverage, but for the
    % OME-Zarr case: source stores are directory trees, and describing
    % rather than attaching is the default so a 100 GB tree does not get
    % copied alongside the pyramid summarising it. Checksum is taken
    % over .zattrs (small, identifies the multiscales layout uniquely)
    % rather than every chunk in the tree.

    properties
        session
    end

    methods (TestMethodSetup)
        function build(testCase)
            d = fullfile(tempname, 'srcfile');
            mkdir(d);
            testCase.addTeardown(@() rmdir(fileparts(d), 's'));
            testCase.session = ndi.session.dir('srcfile', d);
        end
    end

    methods (Access = private)
        function f = aFile(testCase, name, contents)
            f = fullfile(tempname, name);
            mkdir(fileparts(f));
            testCase.addTeardown(@() rmdir(fileparts(f), 's'));
            fid = fopen(f, 'w'); fwrite(fid, contents); fclose(fid);
        end

        function d = aZarrStore(testCase, name)
            d = fullfile(tempname, name);
            mkdir(d);
            testCase.addTeardown(@() rmdir(fileparts(d), 's'));
            zattrs = fullfile(d, '.zattrs');
            fid = fopen(zattrs, 'w');
            fwrite(fid, '{"multiscales":[{"name":"raw","axes":[]}]}');
            fclose(fid);
        end
    end

    methods (Test)

        function testFileDescribeMakesFileReference(testCase)
            f = testCase.aFile('a.bin', 'abcdef');
            doc = ndi.fun.doc.lightsheet.makeSourceFile(testCase.session, f);
            testCase.verifyEqual( ...
                doc.document_properties.document_class.class_name, ...
                'fileReference');
            r = doc.document_properties.fileReference;
            testCase.verifyEqual(r.filename, 'a.bin');
            testCase.verifyEqual(r.fileSize, 6);
            testCase.verifyNotEmpty(r.checksum);
            testCase.verifyEqual(r.checksumAlgorithm, 'MD5');
            testCase.verifyEmpty(doc.current_file_list(), ...
                'describing must not attach the file');
        end

        function testFileAttachMakesGenericFile(testCase)
            f = testCase.aFile('a.bin', 'abcdef');
            doc = ndi.fun.doc.lightsheet.makeSourceFile( ...
                testCase.session, f, 'attachFile', true);
            testCase.verifyEqual( ...
                doc.document_properties.document_class.class_name, ...
                'generic_file');
            files = doc.current_file_list();
            testCase.verifyEqual(numel(files), 1);
            testCase.verifyEqual(char(files{1}), 'generic_file.ext');
        end

        function testDirectoryDescribeChecksumsZattrs(testCase)
            d = testCase.aZarrStore('vol.ome.zarr');
            doc = ndi.fun.doc.lightsheet.makeSourceFile(testCase.session, d);
            r = doc.document_properties.fileReference;
            testCase.verifyEqual(r.filename, 'vol.ome.zarr');
            testCase.verifyNotEmpty(r.checksum);
            testCase.verifyEqual(r.checksumAlgorithm, 'MD5');
            % fileSize is 0 for a directory (only for plain files).
            testCase.verifyEqual(r.fileSize, 0);
        end

        function testAttachingADirectoryIsRefused(testCase)
            d = testCase.aZarrStore('vol.ome.zarr');
            testCase.verifyError(@() ndi.fun.doc.lightsheet.makeSourceFile( ...
                testCase.session, d, 'attachFile', true), ...
                'NDI:lightsheet:makeSourceFile:cannotAttachDirectory');
        end

        function testMissingPathErrors(testCase)
            testCase.verifyError(@() ndi.fun.doc.lightsheet.makeSourceFile( ...
                testCase.session, '/no/such/thing.zarr'), ...
                'NDI:lightsheet:makeSourceFile:noSuchPath');
        end

        function testChecksumFalseLeavesFieldEmpty(testCase)
            f = testCase.aFile('nochk.bin', 'x');
            doc = ndi.fun.doc.lightsheet.makeSourceFile( ...
                testCase.session, f, 'checksum', false);
            r = doc.document_properties.fileReference;
            testCase.verifyEmpty(r.checksum);
            testCase.verifyEmpty(r.checksumAlgorithm);
        end

        function testDescribedDocIsAValidDocument(testCase)
            % The regression test that started this whole file: a
            % described document has to validate against its schema. A
            % fileReference has no `file` slot, so this is why the
            % class was chosen over generic_file.
            f = testCase.aFile('valid.txt', 'hi');
            doc = ndi.fun.doc.lightsheet.makeSourceFile(testCase.session, f);
            testCase.verifyWarningFree(@() ...
                testCase.session.database_add(doc));
        end

    end
end
