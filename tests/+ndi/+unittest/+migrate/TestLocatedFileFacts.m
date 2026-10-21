classdef TestLocatedFileFacts < matlab.unittest.TestCase
    % TESTLOCATEDFILEFACTS ndi.migrate.internal.locatedFileFacts.
    %
    %   Decided by Jess Haley, 2026-10-21: migrated recordings link their
    %   epoch files as data bodies by location; a file named but absent is
    %   still recorded by location. The DID batch pass writes those bodies
    %   without size or checksum (it reads documents, not a disk); this pass
    %   fills both for a file that IS on this computer, as
    %   ndi.setup.V2.recordingDocuments does for a native recording, and
    %   counts an absent one without changing it. Self-contained: structs and
    %   a temp file, no database or session.

    properties
        Root
    end

    methods (TestMethodSetup)
        function makeDir(testCase)
            testCase.Root = tempname();
            mkdir(testCase.Root);
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
        end
    end

    methods (Test)
        function testAPresentFileGetsSizeAndMD5(testCase)
            p = fullfile(testCase.Root, 't00001.rhd');
            fid = fopen(p, 'w'); fwrite(fid, uint8(1:10)); fclose(fid);
            [out, rep] = ndi.migrate.internal.locatedFileFacts({locatedBody('b1', p)});
            testCase.verifyEqual(rep.bodies_by_location, 1);
            testCase.verifyEqual(rep.files_present, 1);
            testCase.verifyEqual(rep.changed_ids, {'b1'});
            testCase.verifyEqual(out{1}.data_body.size_bytes, 10);
            testCase.verifyEqual(out{1}.data_body.content_hash, ndi.fun.file.MD5(p));
            testCase.verifyEqual(out{1}.data_body.hash_algorithm, 'MD5');
        end

        function testAnAbsentFileIsCountedAndLeftAsRecorded(testCase)
            p = fullfile(testCase.Root, 'not_here.rhd');
            b = locatedBody('b2', p);
            [out, rep] = ndi.migrate.internal.locatedFileFacts({b});
            testCase.verifyEqual(rep.files_absent, 1);
            testCase.verifyEmpty(rep.changed_ids);
            testCase.verifyEqual(out{1}, b);
        end

        function testAnIngestedOrCloudMemberIsNotTouched(testCase)
            b = locatedBody('b3', 'ndic://ds/u1');
            b.files.file_info.locations.location_type = 'ndicloud';
            [~, rep] = ndi.migrate.internal.locatedFileFacts({b});
            testCase.verifyEqual(rep.bodies_by_location, 0);
        end
    end
end

function b = locatedBody(id, path)
b = struct();
b.document_class = struct('class_name', 'opaque_body');
b.base = struct('id', id);
b.data_body = struct('filename', 'f', 'content_hash', '');
b.files = struct('file_list', {{'body_data_0'}}, 'file_info', struct('name', 'body_data_0', ...
    'locations', struct('delete_original', 0, 'uid', 'u', 'location', path, ...
    'parameters', '', 'location_type', 'file', 'ingest', 0)));
end
