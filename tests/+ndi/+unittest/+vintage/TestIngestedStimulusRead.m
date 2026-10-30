classdef TestIngestedStimulusRead < matlab.unittest.TestCase
%TESTINGESTEDSTIMULUSREAD ndi.daq.metadatareader reads a MIGRATED ingested epoch's stimulus parameters.
%
%   Decided by Jess Haley, 2026-10-26 [ingested stimulus reader finds the
%   body] (did-schema V_eta_go_forward_class_audit.md): get_ingested_document
%   also finds the migrated ingested stimulus file -- the `opaque_body` of the
%   epoch's stimulus-presentation manipulation ([ingested stimulus file is a
%   body of the presentation]) -- by session and epoch, and
%   readmetadata_ingested reads the same .nbf.tgz file. Before it, the lookup
%   asked only the v1 shape and every read came back {} with no error.
%
%   The fixture is migrated, not hand-built: two v1
%   daqmetadatareader_epochdata_ingested documents (epochs t00074 and t00075,
%   each its own parameters, compressed by ndi.compress.compress_metadata as
%   ingest_epochfiles writes them and recorded by location) go through
%   ndi.migrate.internal.ingestedStimulusBodies, and the bodies it returns are
%   written into a V2 (did2) session made by ndi.setup.V2.createSession and
%   opened with the ordinary ndi.session.dir. The test then asks the reader
%   for each epoch's parameters.
%
%   Filtered (never passed) when did2.build, a V2 schema with `entity` or
%   ndi.compress is missing.
%
%   UNVERIFIED: written without MATLAB; the first CI run is the first run.

    properties
        Dir
        Session
        Reader
        Bodies
    end

    methods (TestClassSetup)
        function migrateAndWrite(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.document')), ...
                'did2.build (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                isfile(ndi.v2.schemaFile(schemaPath, 'entity.json')), ...
                'DID_SCHEMA_PATH does not hold a V2 schema with `entity` (did-schema #88)');
            testCase.assumeTrue(~isempty(which('ndi.compress.compress_metadata')), ...
                'ndi.compress (NDI-compress) is not on the path');

            testCase.Dir = tempname;
            mkdir(testCase.Dir);
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
            bytes = fullfile(testCase.Dir, 'bytes');
            mkdir(bytes);
            sid = char(ndi.ido.unique_id());
            testCase.Reader = ndi.daq.metadatareader();
            readerId = testCase.Reader.id();

            f74 = ndi.unittest.vintage.TestIngestedStimulusRead.stimFile(bytes, 'e74', ...
                ndi.unittest.vintage.TestIngestedStimulusRead.params74());
            f75 = ndi.unittest.vintage.TestIngestedStimulusRead.stimFile(bytes, 'e75', ...
                ndi.unittest.vintage.TestIngestedStimulusRead.params75());
            v1 = {ndi.unittest.vintage.TestIngestedStimulusRead.v1Ingested('ing_74', sid, readerId, 't00074', f74), ...
                ndi.unittest.vintage.TestIngestedStimulusRead.v1Ingested('ing_75', sid, readerId, 't00075', f75)};
            presentations = struct('session_id', {sid, sid}, ...
                'epoch_id', {'t00074', 't00075'}, 'id', {'pres_74', 'pres_75'});
            [bodies, consumed, r] = ndi.migrate.internal.ingestedStimulusBodies( ...
                v1, presentations, {});
            testCase.assertEqual(r.converted, 2, 'both v1 documents become bodies');
            testCase.assertEqual(sort(consumed), {'ing_74', 'ing_75'});
            testCase.Bodies = bodies;

            sessionDir = fullfile(testCase.Dir, 'session');
            mkdir(sessionDir);
            testCase.Session = ndi.setup.V2.createSession(sessionDir, 'ingested stimulus', ...
                'SessionId', sid, 'Documents', bodies, 'Validate', false);
        end
    end

    methods (Test)

        function testTheMigratedBodyIsFound(testCase)
            d = testCase.Reader.get_ingested_document({'epochid://t00074'}, testCase.Session);
            testCase.assertNotEmpty(d, 'the migrated ingested stimulus file is found');
            testCase.verifyEqual(d.id(), 'ing_74', 'the body keeps the v1 id');
            testCase.verifyTrue(isfield(d.document_properties, 'data_body'), ...
                'what is found is the data body');
        end

        function testItsParametersReadBackNonEmpty(testCase)
            p = testCase.Reader.readmetadata_ingested({'epochid://t00074'}, testCase.Session);
            want = ndi.unittest.vintage.TestIngestedStimulusRead.params74();
            testCase.assertNotEmpty(p, 'the parameters of a migrated ingested epoch are read');
            p = ndi.unittest.vintage.TestIngestedStimulusRead.asCell(p);
            testCase.assertNumElements(p, numel(want));
            for k = 1:numel(want)
                testCase.verifyEqual(double(p{k}.stimid), want{k}.stimid);
                testCase.verifyEqual(double(p{k}.angle), want{k}.angle);
            end
        end

        function testEachEpochReadsItsOwnFile(testCase)
            p = testCase.Reader.readmetadata_ingested({'epochid://t00075'}, testCase.Session);
            want = ndi.unittest.vintage.TestIngestedStimulusRead.params75();
            p = ndi.unittest.vintage.TestIngestedStimulusRead.asCell(p);
            testCase.assertNumElements(p, numel(want));
            testCase.verifyEqual(double(p{1}.angle), want{1}.angle);
        end

        function testAnEpochPrefixIsNotAMatch(testCase)
            % 't0007' is the start of 't00074' and 't00075': it names neither
            d = testCase.Reader.get_ingested_document({'epochid://t0007'}, testCase.Session);
            testCase.verifyEmpty(d);
            p = testCase.Reader.readmetadata_ingested({'epochid://t0007'}, testCase.Session);
            testCase.verifyEmpty(p);
        end

        function testAnotherReaderDoesNotReadIt(testCase)
            % v1 joined on the reader's daqmetadatareader_id edge; the body
            % names the reader in its description and is joined on it too
            other = ndi.daq.metadatareader();
            d = other.get_ingested_document({'epochid://t00074'}, testCase.Session);
            testCase.verifyEmpty(d);
        end

        function testTheKeyOpensTheDescription(testCase)
            % the writer and the reader share ndi.vintage.ingestedStimulusKey
            b = testCase.Bodies{1};
            key = ndi.vintage.ingestedStimulusKey(ndi.unittest.vintage.TestIngestedStimulusRead.epochOf(b), ...
                testCase.Reader.id());
            testCase.verifyTrue(startsWith(b.data_body.description, [key ' ']));
        end
    end

    methods (Static)

        function p = params74()
            p = {struct('stimid', 1, 'angle', 0), struct('stimid', 2, 'angle', 90)};
        end

        function p = params75()
            p = {struct('stimid', 1, 'angle', 270)};
        end

        function f = stimFile(folder, name, parameters)
            % as ndi.daq.metadatareader/ingest_epochfiles writes it
            base = fullfile(folder, name);
            ndi.compress.compress_metadata(parameters, base);
            f = [base '.nbf.tgz'];
            assert(isfile(f), 'ndi.compress.compress_metadata wrote no %s', f);
        end

        function d = v1Ingested(id, sid, readerId, epochId, file)
            % a v1 daqmetadatareader_epochdata_ingested, data.bin recorded
            % by location (TestIngestedStimulusBodies' Dab fixture, local)
            d = struct();
            d.base = struct('id', id, 'session_id', sid, 'name', '', ...
                'datestamp', '2024-03-22T15:41:56.036Z');
            d.daqmetadatareader_epochdata_ingested = struct();
            d.depends_on = struct('name', 'daqmetadatareader_id', 'value', readerId);
            d.document_class = struct('class_name', 'daqmetadatareader_epochdata_ingested', ...
                'property_list_name', 'daqmetadatareader_epochdata_ingested', 'class_version', 1);
            d.epochid = struct('epochid', epochId);
            [~, uid] = fileparts(file);
            d.files = struct('file_list', {{'data.bin'}}, 'file_info', struct('name', 'data.bin', ...
                'locations', struct('delete_original', 0, 'uid', uid, 'location', file, ...
                'parameters', '', 'location_type', 'file', 'ingest', 0)));
        end

        function c = asCell(p)
            % ndi.compress.expand_metadata hands back a struct array (CI run
            % 40420613743), the same for v1 and migrated documents; compare
            % per stimulus either way
            if isstruct(p)
                c = num2cell(p);
            else
                c = p;
            end
        end

        function e = epochOf(body)
            tok = regexp(body.data_body.description, '^The ingested stimulus file of epoch (\S+):', ...
                'tokens', 'once');
            e = tok{1};
        end
    end
end
