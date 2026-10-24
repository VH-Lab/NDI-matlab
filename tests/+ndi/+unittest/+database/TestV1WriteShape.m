classdef TestV1WriteShape < matlab.unittest.TestCase
%TESTV1WRITESHAPE probe_location and treatment are written into a v1 database in the v1 shape.
%
%   Decided by Jess Haley, 2026-10-23 [compat write layer removed]: the
%   ndi.compat write layer, which wrote reshaped probe_location and
%   treatment documents into v1 databases, is removed; v1 data is written
%   as v1. VH-Lab/NDI-matlab#1055.
%
%   The removed layer moved probe_location.{ontology_name, name} to
%   probe_location.location.{node, name} and treatment.name to
%   treatment.treatment_name.name on every ndi.database/add and
%   ndi.document/write, and rewrote queries on those paths. The v1
%   templates (ndi_common/database_documents/probe/probe_location.json,
%   treatment.json) carry {ontology_name, name} and
%   {ontologyName, name, numeric_value, string_value}; these tests check
%   that exactly that is stored, read back and found.

    properties
        Root
        Session
        SubjectId
        ProbeId
    end

    methods (TestMethodSetup)
        function makeSession(testCase)
            testCase.Root = tempname;
            mkdir(testCase.Root);
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
            testCase.Session = ndi.session.dir('v1_write', testCase.Root);
            subject = ndi.subject('mouse@lab.org', 'a test subject');
            subdoc = subject.newdocument();
            testCase.Session.database_add(subdoc);
            testCase.SubjectId = subdoc.id();
            probe = ndi.element(testCase.Session, 'probe_1', 1, 'n-trode', [], 0, ...
                testCase.SubjectId);
            testCase.ProbeId = probe.id();
        end
    end

    methods (Test)

        function testProbeLocationIsStoredInTheV1Shape(testCase)
            d = ndi.document('probe_location', ...
                'probe_location.ontology_name', 'UBERON:0002436', ...
                'probe_location.name', 'primary visual cortex') + testCase.Session.newdocument();
            d = d.set_dependency_value('probe_id', testCase.ProbeId);
            testCase.Session.database_add(d);

            p = testCase.storedProperties(d.id());
            testCase.verifyEqual(p.probe_location.ontology_name, 'UBERON:0002436');
            testCase.verifyEqual(p.probe_location.name, 'primary visual cortex');
            testCase.verifyFalse(isfield(p.probe_location, 'location'), ...
                'no reshaped probe_location.location block is written');
            testCase.verifyEqual(sort(fieldnames(p.probe_location)), ...
                sort({'ontology_name'; 'name'}), 'the v1 template''s fields, no more');

            % and a query on the v1 path finds it
            found = testCase.Session.database_search( ...
                ndi.query('probe_location.ontology_name', 'exact_string', 'UBERON:0002436', ''));
            testCase.verifyNumElements(found, 1);
        end

        function testTreatmentIsStoredInTheV1Shape(testCase)
            t = ndi.document('treatment', ...
                'treatment.ontologyName', 'CHEBI:15377', ...
                'treatment.name', 'water', ...
                'treatment.string_value', 'ad libitum') + testCase.Session.newdocument();
            t = t.set_dependency_value('subject_id', testCase.SubjectId);
            testCase.Session.database_add(t);

            p = testCase.storedProperties(t.id());
            testCase.verifyEqual(p.treatment.ontologyName, 'CHEBI:15377');
            testCase.verifyEqual(p.treatment.name, 'water', ...
                'treatment.name used to be moved to treatment.treatment_name.name');
            testCase.verifyEqual(p.treatment.string_value, 'ad libitum');
            testCase.verifyFalse(isfield(p.treatment, 'treatment_name'), ...
                'no reshaped treatment.treatment_name block is written');

            found = testCase.Session.database_search( ...
                ndi.query('treatment.name', 'exact_string', 'water', ''));
            testCase.verifyNumElements(found, 1);
        end

        function testDocumentWriteExportsTheV1Shape(testCase)
            d = ndi.document('probe_location', ...
                'probe_location.ontology_name', 'UBERON:0001880', ...
                'probe_location.name', 'BNST') + testCase.Session.newdocument();
            t = ndi.document('treatment', 'treatment.ontologyName', 'CHEBI:15377', ...
                'treatment.name', 'water') + testCase.Session.newdocument();
            prefix = fullfile(testCase.Root, 'export');
            d.write([prefix '_pl']);
            t.write([prefix '_tr']);
            pl = jsondecode(fileread([prefix '_pl.json']));
            tr = jsondecode(fileread([prefix '_tr.json']));
            testCase.verifyEqual(pl.probe_location.ontology_name, 'UBERON:0001880');
            testCase.verifyEqual(pl.probe_location.name, 'BNST');
            testCase.verifyFalse(isfield(pl.probe_location, 'location'));
            testCase.verifyEqual(tr.treatment.name, 'water');
            testCase.verifyFalse(isfield(tr.treatment, 'treatment_name'));
        end
    end

    methods
        function p = storedProperties(testCase, id)
            % read the document back from disk, through a fresh open of the
            % session, so nothing cached in memory answers
            warnState = warning('off', 'NDI:V2:v1DocumentsPresent');
            restore = onCleanup(@() warning(warnState));
            S2 = ndi.session.dir('v1_write', testCase.Root);
            clear restore
            got = S2.database_search(ndi.query('base.id', 'exact_string', id, ''));
            testCase.assertNumElements(got, 1);
            p = got{1}.document_properties;
        end
    end
end
