classdef TestSettleIngestedFiles < matlab.unittest.TestCase
    % TESTSETTLEINGESTEDFILES ndi.migrate.internal.settleIngestedFiles.
    %
    %   A v1 document records its files as they were when first added
    %   (`ingest` 1, from a path that is usually gone, `delete_original` 1);
    %   the legacy backend already copied the bytes to <.ndi>/files/<uid>.
    %   did2.database.sqlitedb ingests on add and refuses a missing source,
    %   so before the migration adds a document this pass points each
    %   ingested location at the bytes v1 already stored, and records one
    %   whose bytes are nowhere by reference. Self-contained: no database,
    %   no session, no corpus -- the files are written to a temp folder.
    %   The integration (a real did2 add over a real corpus) is
    %   TestMigrateLocalEta20211116, whose 473 file-carrying documents
    %   failed the whole migration with did2:database:ingestSourceMissing
    %   before this pass existed.

    properties
        Root
        NdiDir
    end

    methods (TestMethodSetup)
        function makeDirs(testCase)
            testCase.Root = tempname();
            testCase.NdiDir = fullfile(testCase.Root, '.ndi');
            mkdir(fullfile(testCase.NdiDir, 'files'));
            mkdir(fullfile(testCase.Root, 'elsewhere'));
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
        end
    end

    methods (Test)

        function testBytesInTheStoreAreUsedInPlace(testCase)
            writeBytes(fullfile(testCase.NdiDir, 'files', 'uid_a'), uint8(1:4));
            docs = {fileDoc('d1', 'data', '/gone/tmp/a.bin', 'uid_a')};
            [out, r] = ndi.migrate.internal.settleIngestedFiles(docs, testCase.NdiDir);
            L = theLocation(out{1});
            testCase.verifyEqual(char(L.location), fullfile(testCase.NdiDir, 'files', 'uid_a'));
            testCase.verifyEqual(double(L.ingest), 1, 'still ingested: the store holds it');
            testCase.verifyEqual(double(L.delete_original), 0);
            testCase.verifyEqual([r.documents r.ingestLocations r.inStore r.atSource r.missing], ...
                [1 1 1 0 0]);
        end

        function testBytesAtTheRecordedLocationAreLeftForDid2ToIngest(testCase)
            src = fullfile(testCase.Root, 'elsewhere', 'b.bin');
            writeBytes(src, uint8(5:7));
            docs = {fileDoc('d2', 'data', src, 'uid_b')};
            [out, r] = ndi.migrate.internal.settleIngestedFiles(docs, testCase.NdiDir);
            L = theLocation(out{1});
            testCase.verifyEqual(char(L.location), src);
            testCase.verifyEqual(double(L.ingest), 1);
            testCase.verifyEqual(double(L.delete_original), 0, ...
                'a migration never deletes the user''s file');
            testCase.verifyTrue(isfile(src));
            testCase.verifyEqual([r.inStore r.atSource r.missing], [0 1 0]);
        end

        function testBytesNowhereAreRecordedByReferenceAndWarned(testCase)
            docs = {fileDoc('d3', 'data', '/gone/tmp/c.bin', 'uid_c')};
            [out, r] = testCase.verifyWarning( ...
                @() ndi.migrate.internal.settleIngestedFiles(docs, testCase.NdiDir), ...
                'NDI:migrate:ingestedFileMissing');
            L = theLocation(out{1});
            testCase.verifyEqual(double(L.ingest), 0, 'not ingested: there is nothing to copy');
            testCase.verifyEqual(char(L.location), fullfile(testCase.NdiDir, 'files', 'uid_c'), ...
                'by reference at the store path, so it reads once the bytes are put there');
            testCase.verifyEqual(char(L.uid), 'uid_c');
            testCase.verifyEqual([r.ingestLocations r.missing r.changedDocuments], [1 1 1]);
            testCase.verifyNumElements(r.missingExamples, 1);
        end

        function testDocumentsWithoutFilesAreCountedAndUntouched(testCase)
            plain = did2.document(baseStruct('d4'));
            byRef = fileDoc('d5', 'raw', '/somewhere/raw.bin', 'uid_r', 0);
            [out, r] = ndi.migrate.internal.settleIngestedFiles({plain, byRef}, testCase.NdiDir);
            testCase.verifyEqual(out{1}.toStruct(), plain.toStruct());
            testCase.verifyEqual(out{2}.toStruct(), byRef.toStruct(), ...
                'a location that was never ingested is not this pass''s business');
            testCase.verifyEqual([r.documents r.documentsWithFiles r.ingestLocations r.changedDocuments], ...
                [2 1 0 0]);
        end

        function testCellShapedFileInfoIsHandled(testCase)
            % jsondecode of heterogeneous entries gives cells, not struct arrays.
            writeBytes(fullfile(testCase.NdiDir, 'files', 'uid_e'), uint8(9));
            s = baseStruct('d6');
            s.files = struct('file_list', {{'x', 'y'}});
            s.files.file_info = { ...
                struct('name', 'x', 'locations', {{loc('/gone/x', 'uid_e', 1)}}), ...
                struct('name', 'y', 'locations', loc('/gone/y', 'uid_f', 1), 'extra', 1)};
            [out, r] = testCase.verifyWarning( ...
                @() ndi.migrate.internal.settleIngestedFiles({did2.document(s)}, testCase.NdiDir), ...
                'NDI:migrate:ingestedFileMissing');
            s1 = out{1}.toStruct();
            fi = s1.files.file_info;
            testCase.verifyEqual(char(fi{1}.locations{1}.location), ...
                fullfile(testCase.NdiDir, 'files', 'uid_e'));
            testCase.verifyEqual(double(fi{2}.locations.ingest), 0);
            testCase.verifyEqual([r.ingestLocations r.inStore r.missing], [2 1 1]);
        end

        function testAnUnsafeUidIsLeftForDid2ToRefuse(testCase)
            docs = {fileDoc('d7', 'data', '/gone/z', '../escape')};
            [out, r] = ndi.migrate.internal.settleIngestedFiles(docs, testCase.NdiDir);
            testCase.verifyEqual(out{1}.toStruct(), docs{1}.toStruct());
            testCase.verifyEqual([r.ingestLocations r.unsafeUid r.missing], [1 1 0]);
        end

    end
end

function s = baseStruct(id)
s = struct();
s.base = struct('id', id, 'session_id', 'sess', ...
    'creation_timestamp', '2026-10-21T00:00:00Z');
s.document_class = struct('class_name', 'demo', 'class_version', '1', ...
    'superclasses', {{}});
s.depends_on = struct('name', {}, 'value', {});
end

function L = loc(location, uid, ingest)
L = struct('delete_original', 1, 'uid', uid, 'location', location, ...
    'parameters', '', 'location_type', 'file', 'ingest', ingest);
end

function d = fileDoc(id, name, location, uid, ingest)
if nargin < 5, ingest = 1; end
s = baseStruct(id);
s.files = struct('file_list', {{name}}, ...
    'file_info', struct('name', name, 'locations', loc(location, uid, ingest)));
d = did2.document(s);
end

function L = theLocation(doc)
s = doc.toStruct();
L = s.files.file_info(1).locations(1);
end

function writeBytes(p, bytes)
fid = fopen(p, 'w');
fwrite(fid, bytes, 'uint8');
fclose(fid);
end
