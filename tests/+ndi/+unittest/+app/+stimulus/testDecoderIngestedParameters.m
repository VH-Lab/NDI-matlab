classdef testDecoderIngestedParameters < ndi.unittest.session.buildSession
    % TESTDECODERINGESTEDPARAMETERS - stimulus parameters read from ingested data
    %
    % For raw data, ndi.daq.metadatareader/readmetadata returns a cell array of
    % parameter structures. Ingested data are read back through
    % readmetadata_ingested, and the expanded metadata can come back as a struct
    % array instead, which made ndi.app.stimulus.decoder/parse_stimuli fail with
    % "Brace indexing is not supported for variables of this type."

    methods (Test)

        function testReadMetadataIngestedReturnsCell(testCase)
            % Ingested metadata come back in the same form as raw metadata:
            % a cell array with one structure per stimulus
            S = testCase.Session;
            tsvfile = fullfile(S.path(), 'stims.tsv');
            fid = fopen(tsvfile, 'wt');
            testCase.assertGreaterThan(fid, 0);
            fprintf(fid, 'stimid\tangle\n1\t0\n2\t90\n');
            fclose(fid);

            mdr = ndi.daq.metadatareader('stims\.tsv');
            raw = mdr.readmetadata({tsvfile});
            testCase.assertClass(raw, 'cell');
            testCase.assertNumElements(raw, 2);

            d = mdr.ingest_epochfiles({tsvfile}, 'epoch_1');
            S.database_add(mdr.newdocument());
            S.database_add(d);

            ingested = mdr.readmetadata_ingested({'epochid://epoch_1'}, S);
            testCase.verifyClass(ingested, 'cell');
            testCase.verifyNumElements(ingested, 2);
            testCase.verifyTrue(isstruct(ingested{2}));
            testCase.verifyEqual(double(ingested{2}.angle), 90);
        end

        function testParseStimuliAcceptsStructArrayParameters(testCase)
            % parse_stimuli writes one stimulus per element of a struct array
            % of parameters, as it does for a cell array
            S = testCase.Session;
            subj = S.database_search(ndi.query('', 'isa', 'subject', ''));
            testCase.assertNotEmpty(subj);
            elementId = subj{1}.id(); % an id that exists, for the dependency

            data.stimid = [1; 2; 1; 2];
            data.parameters = struct('stimid', {1, 2}, 'angle', {0, 90}); % 1x2 struct array
            t.stimon = [1; 2; 3; 4];
            t.stimoff = t.stimon + 0.5;
            t.stimopenclose = [t.stimon - 0.1, t.stimoff + 0.1];
            timeref.clocktype = ndi.time.clocktype('dev_local_time');

            stim.id = @() elementId;
            stim.epochtable = @() struct('epoch_id', 'stim_epoch_1');
            stim.readtimeseriesepoch = @(varargin) deal(data, t, timeref);

            app = ndi.app.stimulus.decoder(S);
            newdocs = app.parse_stimuli(stim);

            testCase.assertNumElements(newdocs, 1);
            sp = newdocs{1}.document_properties.stimulus_presentation;
            testCase.verifyNumElements(sp.stimuli, 2);
            testCase.verifyEqual(sp.stimuli(2).parameters.angle, 90);
            testCase.verifyEqual(sp.presentation_order(:), data.stimid);
        end
    end
end
