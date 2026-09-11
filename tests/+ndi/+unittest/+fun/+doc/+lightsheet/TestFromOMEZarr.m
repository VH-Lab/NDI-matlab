classdef TestFromOMEZarr < matlab.unittest.TestCase
    % TestFromOMEZarr - end-to-end ingest against a synthetic OME-Zarr.
    %
    % The fixture is a metadata-only dual-pyramid store (mean + max
    % sharing level 0) written in the test setup itself, so this suite
    % does not depend on NDR being installed. NDR is still the source
    % of truth for reading OME-Zarr; when NDR is present we call it
    % here as ingest does. When NDR is not on the path, every test
    % filters rather than failing.

    properties
        session
        subjectID
        fixtureDir
    end

    methods (TestMethodSetup)
        function build(testCase)
            % `exist(pkg.fun, 'file')` returns 0 for package functions
            % even when they resolve, so guard on `which` instead.
            if isempty(which('ndr.format.omezarr.listPyramids'))
                testCase.assumeFail(['NDR reader not on path; skipping ' ...
                    'end-to-end OME-Zarr ingest tests.']);
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
            testCase.fixtureDir = writeSyntheticZarr(testCase);
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

% ---------------------------------------------------------------------

function fixtureDir = writeSyntheticZarr(testCase)
% Write a metadata-only OME-Zarr with a mean + max ladder sharing '0'.
% Directory layout:
%   <fixtureDir>/.zattrs                (multiscales, both pyramids)
%   <fixtureDir>/0/.zarray              (shared level 0)
%   <fixtureDir>/mean/1/.zarray
%   <fixtureDir>/mean/2/.zarray
%   <fixtureDir>/max/1/.zarray
%   <fixtureDir>/max/2/.zarray
%
% No chunk bytes; fromOMEZarr is metadata-only.
    parent = tempname;
    mkdir(parent);
    testCase.addTeardown(@() rmdir(parent, 's'));
    fixtureDir = fullfile(parent, 'example.zarr');
    mkdir(fixtureDir);

    dtype  = '<u2';
    shape0 = [1 8 8 10];
    shape1 = [1 4 4 5];
    shape2 = [1 2 2 3];
    chunks = [1 4 4 4];

    writeZArray(fullfile(fixtureDir, '0'),           shape0, chunks, dtype);
    mkdir(fullfile(fixtureDir, 'mean'));
    writeZArray(fullfile(fixtureDir, 'mean', '1'),   shape1, chunks, dtype);
    writeZArray(fullfile(fixtureDir, 'mean', '2'),   shape2, chunks, dtype);
    mkdir(fullfile(fixtureDir, 'max'));
    writeZArray(fullfile(fixtureDir, 'max', '1'),    shape1, chunks, dtype);
    writeZArray(fullfile(fixtureDir, 'max', '2'),    shape2, chunks, dtype);

    axes = { ...
        struct('name', 'c', 'type', 'channel'), ...
        struct('name', 'z', 'type', 'space', 'unit', 'micrometer'), ...
        struct('name', 'y', 'type', 'space', 'unit', 'micrometer'), ...
        struct('name', 'x', 'type', 'space', 'unit', 'micrometer') };

    meanDatasets = { ...
        dataset('0',      [1 4 4 4]), ...
        dataset('mean/1', [1 8 8 8]), ...
        dataset('mean/2', [1 16 16 16]) };
    maxDatasets = { ...
        dataset('0',      [1 4 4 4]), ...
        dataset('max/1',  [1 8 8 8]), ...
        dataset('max/2',  [1 16 16 16]) };

    multiscales = { ...
        struct('name', 'mean', 'type', 'box', ...
               'axes', {axes}, 'datasets', {meanDatasets}), ...
        struct('name', 'max',  'type', 'max', ...
               'axes', {axes}, 'datasets', {maxDatasets}) };

    writeJSON(fullfile(fixtureDir, '.zattrs'), ...
        struct('multiscales', {multiscales}));
end

function writeZArray(dir, shape, chunks, dtype)
    mkdir(dir);
    meta = struct( ...
        'zarr_format', 2, ...
        'shape',       shape, ...
        'chunks',      chunks, ...
        'dtype',       dtype, ...
        'compressor',  [], ...
        'fill_value',  0, ...
        'order',       'C', ...
        'filters',     [], ...
        'dimension_separator', '/');
    writeJSON(fullfile(dir, '.zarray'), meta);
end

function d = dataset(pathStr, scale)
    d = struct('path', pathStr, ...
        'coordinateTransformations', {{ ...
            struct('type', 'scale', 'scale', scale) }});
end

function writeJSON(f, s)
    txt = jsonencode(s);
    fid = fopen(f, 'w');
    fwrite(fid, txt);
    fclose(fid);
end
