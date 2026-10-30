classdef TestOntologyRowsCarried < matlab.unittest.TestCase
%TESTONTOLOGYROWSCARRIED Unit tests for ndi.migrate.internal.ontologyRowsCarried.
%   Pure struct logic: no database, no schema, no converter.
%
%   Decided by Jess Haley, 2026-10-30 [table rows carried as v1] (did-schema
%   V_eta_go_forward_class_audit.md): the generic migration carries every v1
%   `ontologyTableRow` whole as v1; it resolves no subject and fans out no
%   statements, because a row does not state which entity each column is
%   about. NDI's second pass therefore no longer resolves a row's subject
%   (the removed ndi.migrate.internal.ontologyRowSubjects); it counts the rows.
%
%   These tests replace TestOntologyRowSubjects, which pinned the resolution.
%   The row shapes are the ones it used (a `document_id` edge naming a subject,
%   a SubjectDocumentIdentifier cell, a SubjectLocalIdentifier cell, a plate
%   row with no subject), and each is now expected to be CARRIED: counted as a
%   table row under its own id, with no subject added and nothing emitted.
%
%   STATUS: authored without local MATLAB; run in CI only.
%
%   Run with:  runtests('ndi.unittest.migrate.TestOntologyRowsCarried')

    methods (Test)

        function testEmptyInputStillReportsItsDenominators(testCase)
            report = ndi.migrate.internal.ontologyRowsCarried({}, {});
            testCase.verifyEqual(report.v1_bodies_inspected, 0);
            testCase.verifyEqual(report.documents_inspected, 0);
            testCase.verifyEqual(report.v1_ontology_rows, 0);
            testCase.verifyEqual(report.rows_carried, 0);
            testCase.verifyEqual(report.rows_not_carried, 0);
        end

        function testEveryRowShapeIsCarried(testCase)
            % A row naming a subject by edge, by document-id cell, by local
            % identifier, and a plate row naming none: all four are carried.
            [v1, mig] = mixedCorpus();
            report = ndi.migrate.internal.ontologyRowsCarried(v1, mig);
            testCase.verifyEqual(report.v1_bodies_inspected, 4);
            testCase.verifyEqual(report.documents_inspected, numel(mig));
            testCase.verifyEqual(report.v1_ontology_rows, 4);
            testCase.verifyEqual(report.rows_carried, 4);
            testCase.verifyEqual(report.rows_not_carried, 0);
            testCase.verifyEmpty(report.rows_not_carried_ids);
        end

        function testARowWithAResolvableSubjectIsNotResolved(testCase)
            % INVERTED from TestOntologyRowSubjects' route-1 test, which
            % expected a plan carrying a `subject_id` edge. The subject is in
            % the batch, and the row is still only counted as carried: the
            % report holds no plan and no resolution counter.
            [v1, mig] = babuRow();
            report = ndi.migrate.internal.ontologyRowsCarried(v1, mig);
            testCase.verifyEqual(report.rows_carried, 1);
            testCase.verifyFalse(isfield(report, 'resolved'));
            testCase.verifyFalse(isfield(report, 'rows_planned'));
        end

        function testInputsAreNotChanged(testCase)
            [v1, mig] = haleyWorm();
            v1Before = v1;
            migBefore = mig;
            ndi.migrate.internal.ontologyRowsCarried(v1, mig);
            testCase.verifyEqual(v1, v1Before);
            testCase.verifyEqual(mig, migBefore);
        end

        function testCarriedV1SpellingCounts(testCase)
            % At the end of ndi.migrate.local a carried row is its v1 body,
            % class `ontologyTableRow`; before that it is `ontology_table_row`.
            [v1, ~] = dabrowskaRow();
            mig = {migratedDoc('row_dab', 'sess_dab', 'ontologyTableRow')};
            report = ndi.migrate.internal.ontologyRowsCarried(v1, mig);
            testCase.verifyEqual(report.rows_carried, 1);
            testCase.verifyEqual(report.rows_not_carried, 0);
        end

        function testARowMissingFromTheMigratedSetIsReported(testCase)
            % A row that is not a table row in the migrated set (converted,
            % or lost) is counted and named, never read as carried.
            [v1, ~] = haleyPlate();
            mig = {migratedDoc('row_plate', 'sess_jh', 'observation'), ...
                   migratedDoc('other', 'sess_jh', 'ontology_table_row')};
            report = ndi.migrate.internal.ontologyRowsCarried(v1, mig);
            testCase.verifyEqual(report.v1_ontology_rows, 1);
            testCase.verifyEqual(report.rows_carried, 0);
            testCase.verifyEqual(report.rows_not_carried, 1);
            testCase.verifyEqual(report.rows_not_carried_ids, {'row_plate'});
        end

        function testRawJsonBodiesAreRead(testCase)
            [v1, mig] = babuRow();
            raw = {jsonencode(v1{1})};
            report = ndi.migrate.internal.ontologyRowsCarried(raw, mig);
            testCase.verifyEqual(report.v1_ontology_rows, 1);
            testCase.verifyEqual(report.rows_carried, 1);
        end

        function testOtherClassesAreNotCounted(testCase)
            v1 = {migratedDoc('subj_1', 'sess', 'subject')};
            mig = {migratedDoc('subj_1', 'sess', 'entity')};
            report = ndi.migrate.internal.ontologyRowsCarried(v1, mig);
            testCase.verifyEqual(report.v1_bodies_inspected, 1);
            testCase.verifyEqual(report.v1_ontology_rows, 0);
            testCase.verifyEqual(report.rows_carried, 0);
            testCase.verifyEqual(report.rows_not_carried, 0);
        end

    end
end

% ===================== fixtures ==========================================

function [v1, mig] = babuRow()
% A row whose subject is the `document_id` edge (+setup/+conv/+babu/import.m
% passes 'DependencyVariable','SubjectDocumentIdentifier').
row = v1Row('row_babu', 'sess_babu', ...
    'CElegansChemotaxisAssayMeasurement_McCutcheonIndex', ...
    struct('CElegansChemotaxisAssayMeasurement_McCutcheonIndex', 0.42));
row.depends_on = struct('name', 'document_id', 'value', 'subj_babu');
v1 = {row};
mig = { ...
    migratedDoc('row_babu', 'sess_babu', 'ontology_table_row'), ...
    migratedSubject('subj_babu', 'sess_babu', 'worm_01')};
end

function [v1, mig] = haleyWorm()
% A row holding a SubjectDocumentIdentifier cell.
row = v1Row('row_worm', 'sess_jh', ...
    'SubjectLocalIdentifier,SubjectDocumentIdentifier', ...
    struct('SubjectLocalIdentifier', 'worm_1017@haley', ...
           'SubjectDocumentIdentifier', 'subj_worm'));
v1 = {row};
mig = { ...
    migratedDoc('row_worm', 'sess_jh', 'ontology_table_row'), ...
    migratedSubject('subj_worm', 'sess_jh', 'worm_1017@haley')};
end

function [v1, mig] = haleyPlate()
% A row about a bacterial plate: it names no subject.
row = v1Row('row_plate', 'sess_jh', ...
    'BacterialPlateIdentifier,BacterialOD600Label', ...
    struct('BacterialPlateIdentifier', '0901', 'BacterialOD600Label', '10.00'));
v1 = {row};
mig = {migratedDoc('row_plate', 'sess_jh', 'ontology_table_row')};
end

function [v1, mig] = dabrowskaRow()
% A row holding only a SubjectLocalIdentifier cell.
lid = 'A123_1@dabrowska-lab.rosalindfranklin.edu';
row = v1Row('row_dab', 'sess_dab', ...
    'SubjectLocalIdentifier,ElevatedPlusMaze_OpenArmTotalEntries', ...
    struct('SubjectLocalIdentifier', lid, ...
           'ElevatedPlusMaze_OpenArmTotalEntries', 7));
v1 = {row};
mig = { ...
    migratedDoc('row_dab', 'sess_dab', 'ontology_table_row'), ...
    migratedSubject('subj_dab', 'sess_dab', lid)};
end

function [v1, mig] = mixedCorpus()
[v1a, miga] = babuRow();
[v1b, migb] = haleyWorm();
[v1c, migc] = haleyPlate();
[v1d, migd] = dabrowskaRow();
v1  = [v1a,  v1b,  v1c,  v1d];
mig = [miga, migb, migc, migd];
end

function b = v1Row(id, sessionId, variableNames, data)
% A did_v1 ontologyTableRow body, in the NDI template's shape.
b = struct();
b.document_class = struct('class_name', 'ontologyTableRow', ...
    'class_version', '1', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1'}));
b.depends_on = struct('name', 'document_id', 'value', '');
b.base = struct('id', id, 'session_id', sessionId, ...
    'name', 'ontologyTableRow', 'datestamp', '2024-01-01T00:00:00.000Z');
b.ontologyTableRow = struct( ...
    'names', variableNames, ...
    'variableNames', variableNames, ...
    'ontologyNodes', variableNames, ...
    'data', data);
end

function s = migratedDoc(id, sessionId, className)
s = struct();
s.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}), ...
    'schema_version', 'did_v2');
s.depends_on = struct('name', {}, 'document_id', {});
s.base = struct('id', id, 'session_id', sessionId, ...
    'name', className, 'datestamp', '2024-01-01T00:00:00.000Z');
end

function s = migratedSubject(id, sessionId, localId)
s = migratedDoc(id, sessionId, 'entity');
s.entity = struct('type', struct('node', '', 'name', 'organism'), ...
    'local_identifier', localId);
end
