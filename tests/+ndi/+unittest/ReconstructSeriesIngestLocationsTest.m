classdef ReconstructSeriesIngestLocationsTest < matlab.unittest.TestCase
% RECONSTRUCTSERIESINGESTLOCATIONSTEST - the ingest_locations rebuild step.
%
% Verifies that ndi.cloud.sync.internal.reconstructSeriesIngestLocations
% produces the shape DID-matlab #185's guard is looking for, from the same
% manifest bytes a cloud SyncFiles=true download writes to disk. Targets
% NDI-matlab #958. Uses real manifests (did.file.writeSeriesManifest and
% readSeriesManifest are the round trip), not mocks -- the whole point of
% the fix is that the manifest and the reconstruction agree on uid layout,
% and only a real manifest can prove that.

    properties
        Dir % Per-test working folder (the fixture cleans it up)
    end

    methods (TestMethodSetup)
        function setupWorkingFolder(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.Dir = pwd;
        end
    end

    methods (Access = private)
        function [manifestUid, uids] = writeManifest(testCase, count, presentSlots)
            % Write a manifest into the per-test folder that declares COUNT
            % slots and populates PRESENTSLOTS with real did.ido.unique_id
            % uids. Return the manifest's own uid (since the caller of the
            % SUT resolves the manifest's local path from its uid), and a
            % 1-by-count cellstr matching the manifest's uids -- so tests
            % can compare exactly what was written to what was read back.
            manifestUid = char(did.ido.unique_id());
            uids = repmat({''}, 1, count);
            for i = presentSlots
                uids{i} = char(did.ido.unique_id());
            end
            did.file.writeSeriesManifest(fullfile(testCase.Dir, manifestUid), uids);
        end

        function fi = fileInfoFor(~, seriesName, manifestUid)
            % A minimal file_info struct array with one entry naming the
            % series' manifest.
            fi = struct( ...
                'name',      seriesName, ...
                'locations', struct('uid', manifestUid));
        end

        function si = seriesInfoFor(~, seriesName, count, nPresent)
            si = struct( ...
                'name',      seriesName, ...
                'count',     count, ...
                'n_present', nPresent);
        end
    end

    methods (Test)

        function testReconstructsOneEntryPerPresentSlot(testCase)
            % A manifest with slots 1, 3, 5 populated (5 total) becomes
            % three ingest_locations entries, in order. Absent slots are
            % NOT reconstructed -- the guard only cares that the "present"
            % members can be found, and inventing entries for absent slots
            % would falsely claim locations for uids the manifest never
            % recorded.
            [manifestUid, uids] = testCase.writeManifest(5, [1 3 5]);

            fi = testCase.fileInfoFor('chunkdata.bin', manifestUid);
            si = testCase.seriesInfoFor('chunkdata.bin', 5, 3);

            out = ndi.cloud.sync.internal.reconstructSeriesIngestLocations( ...
                si, fi, testCase.Dir, "ds-42");

            testCase.assertTrue(isfield(out,'ingest_locations'));
            il = out(1).ingest_locations;
            testCase.assertNumElements(il, 3);

            expectedIndices = [1 3 5];
            expectedUids    = uids([1 3 5]);
            for i = 1:3
                testCase.verifyEqual(il(i).index, expectedIndices(i));
                testCase.verifyEqual(il(i).uid, expectedUids{i});
                testCase.verifyEqual(il(i).location_type, 'ndicloud');
                testCase.verifyEqual(il(i).ingest, 0, ...
                    'reconstruction must never trigger an eager download');
                testCase.verifyEqual(il(i).delete_original, 0);
                testCase.verifyEqual(il(i).location, ...
                    sprintf('ndic://ds-42/%s', expectedUids{i}));
            end
        end

        function testLeavesExistingIngestLocationsAlone(testCase)
            % A series that already carries ingest_locations (a doc built
            % locally and never round-tripped, say) is not touched. The
            % reconstruction only fires for the shape the guard rejects.
            [manifestUid, ~] = testCase.writeManifest(3, [1 2 3]);
            fi = testCase.fileInfoFor('chunkdata.bin', manifestUid);

            si = testCase.seriesInfoFor('chunkdata.bin', 3, 3);
            existing = struct('index', 1, 'uid', 'kept', ...
                'location', 'file:///kept', 'location_type', 'file', ...
                'ingest', 1, 'delete_original', 0);
            si.ingest_locations = existing;

            out = ndi.cloud.sync.internal.reconstructSeriesIngestLocations( ...
                si, fi, testCase.Dir, "ds");

            testCase.assertNumElements(out(1).ingest_locations, 1);
            testCase.verifyEqual(out(1).ingest_locations(1).uid, 'kept');
        end

        function testSkipsSeriesWithZeroPresent(testCase)
            % A series that declares no present members has nothing to
            % locate and no manifest slots to read. Leave it as-is; the
            % guard already accepts n_present == 0.
            si = testCase.seriesInfoFor('chunkdata.bin', 3, 0);
            fi = testCase.fileInfoFor('chunkdata.bin', char(did.ido.unique_id()));

            out = ndi.cloud.sync.internal.reconstructSeriesIngestLocations( ...
                si, fi, tempdir(), "ds");

            testCase.verifyFalse(isfield(out,'ingest_locations') && ...
                ~isempty(out(1).ingest_locations), ...
                'a zero-present series should not carry reconstructed entries');
        end

        function testMissingManifestFileLeavesEntryAlone(testCase)
            % SyncFiles could not write the manifest (the download for
            % that one uid failed). The reconstruction skips it silently
            % so DID's guard fires on add_docs -- the honest signal that
            % the download itself was incomplete.
            si = testCase.seriesInfoFor('chunkdata.bin', 4, 4);
            % file_info names a manifest whose file is NOT present on disk.
            fi = testCase.fileInfoFor('chunkdata.bin', char(did.ido.unique_id()));

            out = ndi.cloud.sync.internal.reconstructSeriesIngestLocations( ...
                si, fi, tempdir(), "ds");

            testCase.verifyFalse(isfield(out,'ingest_locations') && ...
                ~isempty(out(1).ingest_locations));
        end

        function testMultipleSeriesReconstructedIndependently(testCase)
            % Two series in the same document each get their own manifest
            % read; neither's reconstruction depends on or affects the
            % other's.
            [m1, u1] = testCase.writeManifest(2, [1 2]);
            [m2, u2] = testCase.writeManifest(3, [2 3]);

            fi(1) = testCase.fileInfoFor('a.bin', m1);
            fi(2) = testCase.fileInfoFor('b.bin', m2);
            si(1) = testCase.seriesInfoFor('a.bin', 2, 2);
            si(2) = testCase.seriesInfoFor('b.bin', 3, 2);

            out = ndi.cloud.sync.internal.reconstructSeriesIngestLocations( ...
                si, fi, testCase.Dir, "ds");

            testCase.assertNumElements(out(1).ingest_locations, 2);
            testCase.assertNumElements(out(2).ingest_locations, 2);
            testCase.verifyEqual({out(1).ingest_locations.uid}, u1([1 2]));
            testCase.verifyEqual({out(2).ingest_locations.uid}, u2([2 3]));
            testCase.verifyEqual([out(2).ingest_locations.index], [2 3], ...
                'the recorded index tracks the manifest slot, not a re-numbering');
        end
    end
end
