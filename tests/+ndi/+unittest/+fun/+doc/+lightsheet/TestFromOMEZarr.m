classdef TestFromOMEZarr < matlab.unittest.TestCase
    % TestFromOMEZarr - end-to-end ingest against a synthetic OME-Zarr.
    %
    % Uses ndr.test.format.omezarr.makeExampleFixture (the NDR fixture
    % also used by NDR's own tests) which writes a metadata-only
    % dual-pyramid store: mean + max with shared level 0. When NDR is
    % not installed on the test path, the tests filter rather than fail;
    % this suite is about the NDI side, not the fixture builder.

    properties
        session
        subjectID
        fixtureDir
    end

    methods (TestMethodSetup)
        function build(testCase)
            if ~exist('ndr.test.format.omezarr.makeExampleFixture', 'file')
                testCase.assumeFail(['NDR fixture builder not on path; ' ...
                    'skipping end-to-end OME-Zarr ingest tests.']);
            end
            d = fullfile(tempname, 'fromome');
            mkdir(d);
            testCase.addTeardown(@() rmdir(fileparts(d), 's'));
            S = ndi.session.dir('fromome', d);
            sub = ndi.document('subject', 'base.session_id', S.id(), ...
                'subject.local_identifier', 'lightsheet@vhlab');
            S.database_add(sub);
            testCase.session = S;
            testCase.subjectID = sub.id();
            testCase.fixtureDir = ndr.test.format.omezarr.makeExampleFixture();
            testCase.addTeardown(@() rmdir(fileparts(testCase.fixtureDir), 's'));
        end
    end

    methods (Test)

        function testWritesOneParentAndFiveLevels(testCase)
            [pdoc, lds, info] = ndi.fun.doc.lightsheet.fromOMEZarr( ...
                testCase.session, testCase.fixtureDir, ...
                'subjectID', testCase.subjectID);
            testCase.verifyClass(pdoc, 'ndi.document');
            % mean + max with shared level 0 -> 5 unique paths.
            testCase.verifyEqual(numel(lds), 5);
            testCase.verifyTrue(info.sharedLevel0);
            testCase.verifyEqual(sort(info.reductions(:).'), {'max','mean'});
        end

        function testMissingSubjectIDIsRefused(testCase)
            testCase.verifyError(@() ndi.fun.doc.lightsheet.fromOMEZarr( ...
                testCase.session, testCase.fixtureDir), ...
                'NDI:lightsheet:fromOMEZarr:noSubject');
        end

        function testMissingStoreErrors(testCase)
            testCase.verifyError(@() ndi.fun.doc.lightsheet.fromOMEZarr( ...
                testCase.session, '/no/such/store.ome.zarr', ...
                'subjectID', testCase.subjectID), ...
                'NDI:lightsheet:fromOMEZarr:noSuchStore');
        end

        function testNonZarrDirectoryRefused(testCase)
            d = fullfile(tempname, 'not_a_zarr');
            mkdir(d);
            testCase.addTeardown(@() rmdir(fileparts(d), 's'));
            testCase.verifyError(@() ndi.fun.doc.lightsheet.fromOMEZarr( ...
                testCase.session, d, 'subjectID', testCase.subjectID), ...
                'NDI:lightsheet:fromOMEZarr:notOMEZarr');
        end

        function testPyramidNamesFilter(testCase)
            % Restricting to `mean` alone means only that pyramid is
            % ingested. Its level 0 is not shared with anything, so no
            % dedupe (3 levels: 0, mean/1, mean/2).
            [~, lds, info] = ndi.fun.doc.lightsheet.fromOMEZarr( ...
                testCase.session, testCase.fixtureDir, ...
                'subjectID', testCase.subjectID, ...
                'pyramidNames', {'mean'});
            testCase.verifyEqual(numel(lds), 3);
            testCase.verifyFalse(info.sharedLevel0);
        end

        function testUnknownPyramidNameErrors(testCase)
            testCase.verifyError(@() ndi.fun.doc.lightsheet.fromOMEZarr( ...
                testCase.session, testCase.fixtureDir, ...
                'subjectID', testCase.subjectID, ...
                'pyramidNames', {'nope'}), ...
                'NDI:lightsheet:fromOMEZarr:noNamedPyramid');
        end

        function testSourceFileIDReused(testCase)
            % Passing an explicit sourceFileID keeps a caller-created
            % fileReference rather than making a new one.
            src = ndi.fun.doc.lightsheet.makeSourceFile( ...
                testCase.session, testCase.fixtureDir);
            testCase.session.database_add(src);
            [~, ~, info] = ndi.fun.doc.lightsheet.fromOMEZarr( ...
                testCase.session, testCase.fixtureDir, ...
                'subjectID', testCase.subjectID, ...
                'sourceFileID', src.id());
            testCase.verifyEqual(info.sourceFileID, src.id());
        end

        function testTileBudgetForwardedToLevels(testCase)
            % A tiny budget forces chunks smaller than the source
            % zarr's chunks -- proof that fromOMEZarr forwards the
            % option and makePyramid re-chooses per level.
            budget = 512;    % bytes, tiny
            [~, lds] = ndi.fun.doc.lightsheet.fromOMEZarr( ...
                testCase.session, testCase.fixtureDir, ...
                'subjectID', testCase.subjectID, ...
                'tileBudgetBytes', budget);
            for k = 1:numel(lds)
                p = lds{k}.document_properties.lightsheetZarrLevel;
                bytes = prod(p.chunks) * 2;  % uint16
                testCase.verifyLessThanOrEqual(bytes, 2 * budget, ...
                    'per-tile bytes should track the budget');
            end
        end

    end
end
