classdef TestV1AttachedFile < matlab.unittest.TestCase
%TESTV1ATTACHEDFILE ndi.migrate.internal.v1AttachedFile: where a v1 document's
%   attached file is on this computer -- the session's file store
%   (<.ndi>/files/<uid>, where the legacy backend copied the bytes on add),
%   else the recorded location, else not here. The same lookup order as
%   ndi.migrate.internal.settleIngestedFiles. The second pass uses it to read
%   presentation_time.bin (Decided by Jess Haley, 2026-10-22 [presentation
%   times from the file]).

    properties
        Root
    end

    methods (TestMethodSetup)
        function makeSession(testCase)
            testCase.Root = tempname;
            mkdir(fullfile(testCase.Root, '.ndi', 'files'));
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
        end
    end

    methods (Test)
        function testTheStoreIsFoundFirst(testCase)
            ndiDir = fullfile(testCase.Root, '.ndi');
            uid = 'abc123';
            writeBytes(fullfile(ndiDir, 'files', uid));
            src = fullfile(testCase.Root, 'elsewhere.bin');
            writeBytes(src);
            b = body('presentation_time.bin', uid, src);
            [p, st] = ndi.migrate.internal.v1AttachedFile(b, 'presentation_time.bin', ndiDir);
            testCase.verifyEqual(st, 'store');
            testCase.verifyEqual(p, fullfile(ndiDir, 'files', uid));
        end

        function testTheRecordedLocationIsTheFallback(testCase)
            ndiDir = fullfile(testCase.Root, '.ndi');
            src = fullfile(testCase.Root, 'elsewhere.bin');
            writeBytes(src);
            b = body('presentation_time.bin', 'notinstore', src);
            [p, st] = ndi.migrate.internal.v1AttachedFile(b, 'presentation_time.bin', ndiDir);
            testCase.verifyEqual(st, 'source');
            testCase.verifyEqual(p, src);
        end

        function testListedButAbsentIsSaid(testCase)
            ndiDir = fullfile(testCase.Root, '.ndi');
            b = body('presentation_time.bin', 'gone', '/no/such/path/x.bin');
            [p, st] = ndi.migrate.internal.v1AttachedFile(b, 'presentation_time.bin', ndiDir);
            testCase.verifyEqual(st, 'not on this computer');
            testCase.verifyEmpty(p);
            % a file_list entry with no file_info is listed, and also not here
            b2 = struct('files', struct('file_list', {{'presentation_time.bin'}}));
            [p2, st2] = ndi.migrate.internal.v1AttachedFile(b2, 'presentation_time.bin', ndiDir);
            testCase.verifyEqual(st2, 'not on this computer');
            testCase.verifyEmpty(p2);
        end

        function testAnotherNameIsNotDeclared(testCase)
            ndiDir = fullfile(testCase.Root, '.ndi');
            b = body('data.bin', 'u', '');
            [p, st] = ndi.migrate.internal.v1AttachedFile(b, 'presentation_time.bin', ndiDir);
            testCase.verifyEqual(st, 'not declared');
            testCase.verifyEmpty(p);
            [~, st2] = ndi.migrate.internal.v1AttachedFile(struct('base', struct()), ...
                'presentation_time.bin', ndiDir);
            testCase.verifyEqual(st2, 'not declared');
        end

        function testAnUnsafeUidIsNeverJoinedOntoAPath(testCase)
            ndiDir = fullfile(testCase.Root, '.ndi');
            writeBytes(fullfile(testCase.Root, 'escape.bin'));
            b = body('presentation_time.bin', '../../escape.bin', '');
            [p, st] = ndi.migrate.internal.v1AttachedFile(b, 'presentation_time.bin', ndiDir);
            testCase.verifyEqual(st, 'not on this computer');
            testCase.verifyEmpty(p);
        end
    end
end

function b = body(name, uid, location)
% the v1 `files` block as NDI writes it (did.document add_file): file_list
% and file_info {name, locations {uid, location, location_type, ingest, ...}}
loc = struct('delete_original', 1, 'uid', uid, 'location', location, ...
    'parameters', '', 'location_type', 'file', 'ingest', 1);
b = struct();
b.base = struct('id', 'doc_1');
b.files = struct('file_list', {{name}}, ...
    'file_info', struct('name', name, 'locations', loc));
end

function writeBytes(f)
fid = fopen(f, 'w');
fwrite(fid, uint8(1:8));
fclose(fid);
end
