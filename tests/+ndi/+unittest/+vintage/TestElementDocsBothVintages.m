classdef TestElementDocsBothVintages < matlab.unittest.TestCase
%TESTELEMENTDOCSBOTHVINTAGES getelements lists v1 and migrated elements together.
%
%   FOUND ON THE B CORPUS END-TO-END, 2026-10-27 (NDI-matlab runs
%   40526060983, 40529178519, 40529154431):
%
%       Error using vertcat
%       Dimensions of arrays being concatenated are not consistent.
%       Error in ndi.session/getelements (line 886)
%           doc = [doc(:); ndi.vintage.elementSubjectDocs(ndi_session_obj)];
%
%   DID-matlab's migration now carries B's 134 sorted-unit `element`
%   documents unchanged as v1 (carry-062), while B's other elements migrate
%   to `subject` documents. So the session holds BOTH vintages, which
%   getelements already unions: the v1 hits from `isa element` came back as
%   a column (doc(:)) and ndi.vintage.elementSubjectDocs returned a ROW
%   (docs{end+1}). A column of N >= 1 under a row of M >= 2 does not
%   concatenate. Before the carry, N was 0 and MATLAB drops an empty
%   operand, so the mismatch never showed.
%
%   These tests need no database, no schema and no DID-matlab: the session
%   is ndi.unittest.vintage.FakeSearchSession, and the documents are the
%   structs ndi.v2.props and ndi.v2.edgeIds already read.
%
%   UNVERIFIED: written without MATLAB; test-eta-migrate-e2e.yml is the
%   first run.

    methods (Test)

        function testMigratedElementsComeBackAsAColumn(testCase)
            S = testCase.session({testCase.v1Element('v1_unit_1')}, ...
                {'eta_el_1', 'eta_el_2'});
            eta = ndi.vintage.elementSubjectDocs(S);
            testCase.verifySize(eta, [2 1], ...
                'elementSubjectDocs must return a column so callers can stack it');
            testCase.verifyEqual(testCase.ids(eta), {'eta_el_1'; 'eta_el_2'});
        end

        function testNoMigratedElementsIsAnEmptyColumn(testCase)
            S = testCase.session({testCase.v1Element('v1_unit_1')}, {});
            eta = ndi.vintage.elementSubjectDocs(S);
            testCase.verifySize(eta, [0 1]);
        end

        function testOneCarriedV1AndTwoMigratedStack(testCase)
            % The B shape: carried v1 elements and migrated ones in one
            % session. Two migrated, because one carried and ONE migrated
            % stacked even before the fix ([1x1; 1x1] is consistent).
            carried = testCase.v1Element('v1_unit_1');
            S = testCase.session({carried}, {'eta_el_1', 'eta_el_2'});
            doc = testCase.getelementsDocs(S);
            testCase.verifySize(doc, [3 1]);
            testCase.verifyEqual(testCase.ids(doc), ...
                {'v1_unit_1'; 'eta_el_1'; 'eta_el_2'});
            testCase.verifyEqual(doc{1}, carried, ...
                'the carried v1 element is returned as stored, not converted');
        end

        function testOneCarriedV1AndOneMigratedStack(testCase)
            carried = testCase.v1Element('v1_unit_1');
            S = testCase.session({carried}, {'eta_el_1'});
            doc = testCase.getelementsDocs(S);
            testCase.verifyEqual(testCase.ids(doc), {'v1_unit_1'; 'eta_el_1'});
            testCase.verifyEqual(doc{1}, carried);
        end

        function testSeveralCarriedV1AsARowFromTheDatabaseStack(testCase)
            % database_search may hand back a row; getelements reshapes it.
            S = testCase.session({testCase.v1Element('v1_unit_1'), ...
                testCase.v1Element('v1_unit_2')}, {'eta_el_1', 'eta_el_2'});
            doc = testCase.getelementsDocs(S);
            testCase.verifyEqual(testCase.ids(doc), ...
                {'v1_unit_1'; 'v1_unit_2'; 'eta_el_1'; 'eta_el_2'});
        end

        function testTheOldStackingIsTheErrorTheRunRaised(testCase)
            % The defect, pinned: a column stacked over a row of two.
            col = {struct('id', 'a')};
            row = {struct('id', 'b'), struct('id', 'c')};
            testCase.verifyError(@() [col(:); row], ...
                'MATLAB:catenate:dimensionMismatch');
        end

        function testGetelementsAndGetprobesStackColumns(testCase)
            % getelementsDocs below repeats getelements' two searches; this
            % pins that getelements (and getprobes) still stack the way it
            % does, so the copy cannot drift from the code silently.
            src = fileread(which('ndi.session'));
            testCase.verifySubstring(src, 'doc = [doc(:); etaDocs(:)];', ...
                'ndi.session/getelements no longer stacks two columns');
            testCase.verifySubstring(src, ...
                'existing_probes = [existing_probes(:); etaProbes(:)];', ...
                'ndi.session/getprobes no longer stacks two columns');
        end

    end

    methods (Static, Access = private)

        function doc = getelementsDocs(S)
            % The document half of ndi.session/getelements.
            doc = S.database_search(ndi.query('', 'isa', 'element', ''));
            etaDocs = ndi.vintage.elementSubjectDocs(S);
            doc = [doc(:); etaDocs(:)];
        end

        function S = session(v1Docs, etaIds)
            % v1Docs: what `isa element` finds (returned as a ROW, the
            % harder case). etaIds: migrated elements, each a subject plus
            % an inbound `ndi element class` assertion naming it.
            label = ndi.vintage.elementLabel('class');
            assertions = cell(1, numel(etaIds));
            subjects = containers.Map('KeyType', 'char', 'ValueType', 'any');
            for k = 1:numel(etaIds)
                assertions{k} = struct( ...
                    'base', struct('id', ['assert_' etaIds{k}]), ...
                    'statement', struct('variable', struct('name', label)), ...
                    'term', struct('value', struct('name', 'ndi.element.timeseries')), ...
                    'depends_on', struct('name', 'entity_id', 'value', etaIds{k}));
                subjects(etaIds{k}) = struct('base', struct('id', etaIds{k}), ...
                    'document_class', struct('class_name', 'subject'));
            end
            v1Row = reshape(v1Docs, 1, []);
            S = ndi.unittest.vintage.FakeSearchSession( ...
                @(q) ndi.unittest.vintage.TestElementDocsBothVintages.answer( ...
                    q, v1Row, assertions, subjects, label));
        end

        function d = answer(q, v1Row, assertions, subjects, label)
            % Routes by the values a query carries, not by field names, so
            % a path translation in ndi.query cannot misroute it.
            vals = ndi.unittest.vintage.TestElementDocsBothVintages.queryValues( ...
                q.searchstructure);
            hit = vals(cellfun(@(v) isKey(subjects, v), vals));
            if ~isempty(hit)
                d = {subjects(hit{1})};
            elseif any(strcmp(vals, label))
                d = assertions;
            else
                d = v1Row;
            end
        end

        function vals = queryValues(ss)
            vals = {};
            for k = 1:numel(ss)
                for f = {'param1', 'param2'}
                    v = ss(k).(f{1});
                    if ischar(v) || (isstring(v) && isscalar(v))
                        vals{end+1} = char(v); %#ok<AGROW>
                    elseif isstruct(v) && isfield(v, 'param1')
                        vals = [vals, ndi.unittest.vintage.TestElementDocsBothVintages.queryValues(v)]; %#ok<AGROW>
                    end
                end
            end
        end

        function d = v1Element(id)
            d = struct('base', struct('id', id), ...
                'document_class', struct('class_name', 'element'), ...
                'element', struct('name', 'unit', 'reference', 1, ...
                    'type', 'spikes', 'ndi_element_class', 'ndi.neuron'));
        end

        function out = ids(docs)
            out = cellfun(@(d) d.base.id, docs, 'UniformOutput', false);
        end

    end
end
