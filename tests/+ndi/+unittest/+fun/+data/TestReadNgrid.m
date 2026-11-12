classdef TestReadNgrid < matlab.unittest.TestCase
    % TestReadNgrid - ndi.fun.data.readngrid reads what writengrid wrote,
    % from a file path or from a file object, including the read-only file
    % object that ndi.session/database_openbinarydoc returns.

    properties
        Root
    end

    methods (TestMethodSetup)
        function makeRoot(testCase)
            testCase.Root = tempname;
            mkdir(testCase.Root);
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
        end
    end

    methods (Test)

        function testPathRoundTrip2D(testCase)
            x = rand(4, 3);
            f = fullfile(testCase.Root, 'a.ngrid');
            ndi.fun.data.writengrid(x, f, 'double');
            y = ndi.fun.data.readngrid(f, size(x), 'double');
            testCase.verifyEqual(y, x);
        end

        function testPathRoundTripNDimensional(testCase)
            % fread takes only a scalar or a 2-element size, so a 3-D size
            % used to error; the data must come back with their shape.
            x = rand(3, 4, 2);
            f = fullfile(testCase.Root, 'b.ngrid');
            ndi.fun.data.writengrid(x, f, 'double');
            y = ndi.fun.data.readngrid(f, size(x), 'double');
            testCase.verifyEqual(y, x);
        end

        function testStringPathAndIntegerType(testCase)
            x = int16(reshape(1:12, 3, 4));
            f = fullfile(testCase.Root, 'c.ngrid');
            ndi.fun.data.writengrid(x, f, 'int16');
            y = ndi.fun.data.readngrid(string(f), [3 4], 'int16');
            testCase.verifyEqual(double(y), double(x));
        end

        function testUnopenedFileObjectIsOpenedAndClosed(testCase)
            x = rand(5, 2);
            f = fullfile(testCase.Root, 'd.ngrid');
            ndi.fun.data.writengrid(x, f, 'double');
            fo = did.file.readonly_fileobj('fullpathfilename', f);
            testCase.assertLessThan(fo.fid, 0);
            y = ndi.fun.data.readngrid(fo, size(x), 'double');
            testCase.verifyEqual(y, x);
            testCase.verifyLessThan(fo.fid, 0, ...
                'A file object readngrid opened itself should be closed again.');
        end

        function testOpenReadOnlyFileObjectIsReadAndLeftOpen(testCase)
            % The case database_openbinarydoc produces: an already-open
            % did.file.readonly_fileobj. It used to fail because readngrid
            % reopened it with permission 'r', which a read-only file object
            % rejects ('rb' only).
            x = rand(2, 3, 2);
            f = fullfile(testCase.Root, 'e.ngrid');
            ndi.fun.data.writengrid(x, f, 'double');
            fo = did.file.readonly_fileobj('fullpathfilename', f);
            fo = fopen(fo, 'rb');
            testCase.assertGreaterThanOrEqual(fo.fid, 0);
            testCase.addTeardown(@() fclose(fo));
            y = ndi.fun.data.readngrid(fo, size(x), 'double');
            testCase.verifyEqual(y, x);
            testCase.verifyGreaterThanOrEqual(fo.fid, 0, ...
                'A file object that was open on entry belongs to the caller and should be left open.');
        end

        function testDocumentFileThroughOpenBinaryDoc(testCase)
            % End to end: write an ngrid, attach it to a document, add the
            % document to a session, and read it back through
            % database_openbinarydoc.
            sessionPath = fullfile(testCase.Root, 'session');
            mkdir(sessionPath);
            S = ndi.session.dir('readngrid_test', sessionPath);

            x = rand(3, 2, 2);
            f = fullfile(testCase.Root, 'f.ngrid');
            ndi.fun.data.writengrid(x, f, 'double');
            ngridStruct = ndi.fun.data.mat2ngrid(x);
            doc = ndi.document('ontologyImage', ...
                'ontologyImage', struct('ontologyNodes', 'EMPTY:0000000'), ...
                'ngrid', ngridStruct) + S.newdocument();
            doc = doc.add_file('ontologyImage.ngrid', f);
            S.database_add(doc);

            fo = S.database_openbinarydoc(doc, 'ontologyImage.ngrid');
            y = ndi.fun.data.readngrid(fo, doc.document_properties.ngrid.data_dim, ...
                doc.document_properties.ngrid.data_type);
            S.database_closebinarydoc(fo);
            testCase.verifyEqual(y, x);
        end

        function testWrongSizeWarns(testCase)
            x = rand(2, 2);
            f = fullfile(testCase.Root, 'g.ngrid');
            ndi.fun.data.writengrid(x, f, 'double');
            testCase.verifyWarning(@() ndi.fun.data.readngrid(f, [3 3], 'double'), ...
                'READNGRID:incorrectDataSize');
        end

        function testMissingFileErrors(testCase)
            testCase.verifyError(@() ndi.fun.data.readngrid( ...
                fullfile(testCase.Root, 'missing.ngrid'), [2 2]), ...
                'READNGRID:invalidFilePath');
        end

    end
end
