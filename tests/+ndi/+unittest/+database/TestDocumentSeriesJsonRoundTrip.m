classdef TestDocumentSeriesJsonRoundTrip < matlab.unittest.TestCase
    % Does a file series survive the JSON encode/decode the cloud upload uses?
    %
    % This suite exists to split one specific question in VH-Lab/NDI-matlab#945:
    % a document uploaded to the cloud comes back DECLARED BUT EMPTY --
    % isFileSeries still says yes, but seriesCount returns 0 where 4 was
    % uploaded. It reproduces identically against prod and against dev, so it
    % is not something the newer API fixes.
    %
    % Three things were ruled out by reading: the download-side rebuild
    % (did.document's constructor guards its reset with ~made_from_struct, so
    % the struct path preserves series_info verbatim), a document cache
    % masking a local failure (did.database caches FILES, not documents), and
    % jsonencodenan itself (a thin wrapper around jsonencode). That leaves the
    % encode/decode pair or the server.
    %
    % These tests are the client half of that split, and they need no
    % credentials and no network, so they run in the fast workflow on every
    % PR rather than only in Cloud CI:
    %
    %   FAIL -> the loss is ours, in encode/decode, and the fix is local
    %   PASS -> the client round trip is clean and the server is dropping or
    %           defaulting the fields, in both environments
    %
    % testStoredFormSurvivesTheJsonRoundTrip is the one that matters most: it
    % strips ingest locations first, which is the form the database stores and
    % therefore the form the upload actually ships.

    properties (Constant)
        MemberCount = 4;
    end

    properties
        MemberPaths (1,:) cell = {}
    end

    methods (TestMethodSetup)
        function setupMembers(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            memberDir = fullfile(pwd, 'level0');
            mkdir(memberDir);
            testCase.MemberPaths = cell(1, testCase.MemberCount);
            for i = 1:testCase.MemberCount
                p = fullfile(memberDir, sprintf('chunk_%04d.bin', i));
                fid = fopen(p, 'w');
                fwrite(fid, uint8(mod((1:16) * i, 251)), 'uint8');
                fclose(fid);
                testCase.MemberPaths{i} = p;
            end
        end
    end

    methods (Access = private)
        function doc = makeSeriesDocument(testCase)
            doc = ndi.document('demoNDISeries', ...
                'base.name', 'json_round_trip_doc', ...
                'demoNDISeries.value', 1, ...
                'base.session_id', did.ido.unique_id());
            doc = doc.addFileSeries('chunkdata.bin', testCase.MemberPaths);
        end

        function rebuilt = jsonRoundTrip(~, props)
            % Exactly the pair the cloud path uses: the upload encodes with
            % did.datastructures.jsonencodenan, the download rehydrates and
            % decodes before handing the struct to ndi.document.
            encoded  = did.datastructures.jsonencodenan(props);
            decoded  = jsondecode(ndi.util.rehydrateJSONNanNull(encoded));
            rebuilt  = ndi.document(decoded);
        end
    end

    methods (Test)

        function testTheDocumentStartsWithFourMembers(testCase)
            % Sanity: if this fails, nothing below means anything.
            doc = testCase.makeSeriesDocument();
            [n, nPresent] = doc.seriesCount('chunkdata.bin');
            testCase.verifyEqual(n, testCase.MemberCount);
            testCase.verifyEqual(nPresent, testCase.MemberCount);
        end

        function testSeriesCountSurvivesTheJsonRoundTrip(testCase)
            doc = testCase.makeSeriesDocument();
            rebuilt = testCase.jsonRoundTrip(doc.document_properties);

            testCase.onFailure(@() disp(rebuilt.document_properties.files));
            testCase.verifyTrue(rebuilt.isFileSeries('chunkdata.bin'), ...
                'the series declaration did not survive encode/decode');
            [n, nPresent] = rebuilt.seriesCount('chunkdata.bin');
            testCase.verifyEqual(n, testCase.MemberCount, ...
                'count did not survive the JSON round trip');
            testCase.verifyEqual(nPresent, testCase.MemberCount, ...
                'n_present did not survive the JSON round trip');
        end

        function testStoredFormSurvivesTheJsonRoundTrip(testCase)
            % The form that is actually shipped. The database stores the
            % stripped properties, and stripping is supposed to empty
            % ingest_locations and nothing else -- did.document's own
            % TestDocumentFileSeries/testAccessorIsEmptyOnAStoredDocument
            % asserts a stored document "still knows the series and its size".
            %
            % If this one fails while the test above passes, the culprit is
            % the empty ingest_locations struct array: jsonencode renders an
            % empty struct array as [], and what comes back may no longer be
            % shaped like series_info.
            doc = testCase.makeSeriesDocument();
            stored = did.document.stripSeriesIngestLocations(doc.document_properties);
            rebuilt = testCase.jsonRoundTrip(stored);

            testCase.onFailure(@() disp(rebuilt.document_properties.files));
            testCase.verifyTrue(rebuilt.isFileSeries('chunkdata.bin'), ...
                'the series declaration did not survive strip + encode/decode');
            [n, nPresent] = rebuilt.seriesCount('chunkdata.bin');
            testCase.verifyEqual(n, testCase.MemberCount, ...
                'count did not survive strip + JSON round trip -- this is NDI-matlab#945, client side');
            testCase.verifyEqual(nPresent, testCase.MemberCount, ...
                'n_present did not survive strip + JSON round trip -- this is NDI-matlab#945, client side');
        end

        function testStrippingAloneKeepsTheCount(testCase)
            % Isolates stripping from the JSON, so a failure here says the
            % problem is stripSeriesIngestLocations rather than the encoding.
            doc = testCase.makeSeriesDocument();
            stored = ndi.document( ...
                did.document.stripSeriesIngestLocations(doc.document_properties));
            [n, nPresent] = stored.seriesCount('chunkdata.bin');
            testCase.verifyEqual(n, testCase.MemberCount);
            testCase.verifyEqual(nPresent, testCase.MemberCount);
        end


        function testSeriesSurvivesTheBatchEncodingTheUploadActuallyUses(testCase)
            % The tests above encode ONE properties struct. The upload does
            % not. ndi.cloud.upload.internal.zip_documents_for_upload builds a
            % CELL ARRAY of every document's properties and encodes that in
            % one call:
            %
            %   document_properties_array = cellfun(@(x) x.document_properties, ...
            %       documentList, 'UniformOutput', false);
            %   jsonStr = did.datastructures.jsonencodenan(document_properties_array);
            %
            % A cell array becomes a JSON array of objects, and jsondecode
            % gives back a struct array when the objects agree on their fields
            % and a cell array when they do not. That reshaping is a real
            % opportunity to lose a nested struct, and none of the single
            % document tests above would see it. The test dataset uploads three
            % documents of mixed type, so mix them here too.
            seriesDoc = testCase.makeSeriesDocument();
            otherA = ndi.document('demoNDI', 'base.name', 'other_a', ...
                'base.session_id', did.ido.unique_id());
            otherB = ndi.document('demoNDI', 'base.name', 'other_b', ...
                'base.session_id', did.ido.unique_id());

            documentList = {otherA, seriesDoc, otherB};
            propsArray = cellfun(@(x) did.document.stripSeriesIngestLocations( ...
                x.document_properties), documentList, 'UniformOutput', false);

            encoded = did.datastructures.jsonencodenan(propsArray);
            decoded = jsondecode(ndi.util.rehydrateJSONNanNull(encoded));
            if isstruct(decoded), decoded = num2cell(decoded); end

            testCase.fatalAssertEqual(numel(decoded), 3, ...
                'the batch did not decode back into three documents');

            rebuilt = cellfun(@(x) ndi.document(x), decoded, 'UniformOutput', false);
            names = cellfun(@(d) string(d.document_properties.base.name), rebuilt);
            k = find(names == "json_round_trip_doc", 1);
            testCase.fatalAssertNotEmpty(k, ...
                'the series document did not survive the batch round trip at all');

            testCase.onFailure(@() disp(rebuilt{k}.document_properties.files));
            testCase.verifyTrue(rebuilt{k}.isFileSeries('chunkdata.bin'), ...
                'the series declaration did not survive the batch encoding');
            [n, nPresent] = rebuilt{k}.seriesCount('chunkdata.bin');
            testCase.verifyEqual(n, testCase.MemberCount, ...
                'count did not survive the batch encoding the upload uses');
            testCase.verifyEqual(nPresent, testCase.MemberCount, ...
                'n_present did not survive the batch encoding the upload uses');
        end

    end
end
