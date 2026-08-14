classdef TestVintageMap < matlab.unittest.TestCase
%TESTVINTAGEMAP The vintage-aware read layer, without a database.
%
%   `ndi.vintage` is what lets NDI's object layer find and construct its
%   documents after V_eta renamed their classes, edges and fields. These
%   tests build documents by hand -- no session, no sqlite, no corpus -- so
%   they run everywhere and fail for one reason at a time.
%
%   WHAT THEY ARE GUARDING AGAINST, stated once. Every failure this layer
%   exists to fix was SILENT: `ndi.query('','isa','daqsystem')` against a
%   migrated session matched nothing, the loop over the results ran zero
%   times, and `daqsystem_load` returned {} exactly as it would for a
%   session with no daq systems. So the assertions below are mostly about
%   NOT-EMPTY and about the v1 path being untouched -- a regression here
%   reads as an empty session, not as an error.
%
%   See also: ndi.vintage.map, ndi.vintage.isaQuery,
%             ndi.vintage.objectClass, ndi.vintage.edge, ndi.vintage.field.

    methods (Test)

        function testTheMapDeclaresItsSizeAndIsWellFormed(testCase)
            % DENOMINATOR FIRST. A map that silently lost a row produces
            % exactly the empty-session symptom this package exists to fix,
            % so the count is asserted rather than assumed -- and it is the
            % count MATLAB's own `struct()` trap would have destroyed
            % (struct('fields',{cell(0,2)}) yields a 0x2 EMPTY struct array,
            % which is why map.m assigns field by field).
            m = ndi.vintage.map();
            testCase.verifyEqual(numel(m), 5, sprintf( ...
                ['ndi.vintage.map declares %d concept(s); this test was ' ...
                 'written against 5 (daqsystem, filenavigator, ' ...
                 'daqmetadatareader, syncgraph, syncrule)'], numel(m)));
            for i = 1:numel(m)
                testCase.verifyNotEmpty(m(i).concept);
                testCase.verifyNotEmpty(m(i).eta_class);
                testCase.verifyEqual(size(m(i).edges, 2), 2, ...
                    sprintf('%s: edges must be N-by-2', m(i).concept));
                testCase.verifyEqual(size(m(i).fields, 2), 2, ...
                    sprintf('%s: fields must be N-by-2', m(i).concept));
                % A renamed class whose object key has no home in V_eta
                % would be unconstructable, which is the whole point.
                testCase.verifyNotEmpty(m(i).object_edge, ...
                    sprintf('%s: no V_eta object-class edge', m(i).concept));
            end
        end

        function testTheDecomposedClassesAreNotInTheMap(testCase)
            % `element` and `pyraview` are DECOMPOSED, not renamed -- one
            % document becomes five. Adding a row for either would claim a
            % one-to-one correspondence that does not exist and would make
            % `isa element` match a `subject`, which is every subject in the
            % session. This asserts the absence so a later "just add a row"
            % has to argue with a test.
            testCase.verifyEmpty(ndi.vintage.entryFor('element'), ...
                'element is decomposed by V_eta, not renamed');
            testCase.verifyEmpty(ndi.vintage.entryFor('pyraview'), ...
                'pyraview is decomposed by V_eta, not renamed');
            % ...and the classes V_eta leaves alone need no row either.
            testCase.verifyEmpty(ndi.vintage.entryFor('session'));
            testCase.verifyEmpty(ndi.vintage.entryFor('subject'));
            testCase.verifyEmpty(ndi.vintage.entryFor('daqreader'));
        end

        function testIsaQueryAsksForBothVintages(testCase)
            q = ndi.vintage.isaQuery('daqsystem');
            testCase.verifyClass(q, 'ndi.query');
            ss = q.searchstructure;
            % One `or` term whose halves are the two class names. Asserting
            % the NAMES rather than the structure shape keeps this readable
            % if did.query ever flattens differently.
            txt = jsonencode(ss);
            testCase.verifySubstring(txt, 'daqsystem');
            testCase.verifySubstring(txt, 'acquisition_system');
        end

        function testIsaQueryOnAnUnrenamedConceptIsUnchanged(testCase)
            % The safety property that lets every call site switch over
            % without auditing: a concept with no map row must produce
            % exactly the query the caller would have written.
            q = ndi.vintage.isaQuery('subject');
            plain = ndi.query('', 'isa', 'subject', '');
            testCase.verifyEqual(numel(q.searchstructure), 1);
            testCase.verifyEqual(q.searchstructure(1).operation, ...
                plain.searchstructure(1).operation);
            testCase.verifyEqual(q.searchstructure(1).param1, ...
                plain.searchstructure(1).param1);
        end

        function testEdgeNamesTranslateOnlyForEtaDocuments(testCase)
            v1  = ndi.unittest.vintage.TestVintageMap.doc('daqsystem');
            eta = ndi.unittest.vintage.TestVintageMap.doc('acquisition_system');

            testCase.verifyEqual( ...
                ndi.vintage.edgeName(v1, 'daqreader_id'), 'daqreader_id', ...
                'a v1 document must be read exactly as before');
            testCase.verifyEqual( ...
                ndi.vintage.edgeName(eta, 'daqreader_id'), 'reader_id');
            testCase.verifyEqual( ...
                ndi.vintage.edgeName(eta, 'filenavigator_id'), ...
                'epoch_file_pattern_id');
            testCase.verifyEqual( ...
                ndi.vintage.edgeName(eta, 'daqmetadatareader_id'), ...
                'acquisition_metadata_reader');
            % An edge with no row passes through untouched.
            testCase.verifyEqual( ...
                ndi.vintage.edgeName(eta, 'something_else_id'), ...
                'something_else_id');
        end

        function testFieldReadsAcrossBothBlockAndFieldRenames(testCase)
            v1blk = struct();
            v1blk.fileparameters = '{''a.rhd''}';
            v1blk.epochprobemap_class = 'ndi.epoch.epochprobemap_daqsystem';
            v1 = ndi.unittest.vintage.TestVintageMap.doc( ...
                'filenavigator', 'filenavigator', v1blk);
            [val, found] = ndi.vintage.field(v1, 'epochprobemap_class');
            testCase.verifyTrue(found);
            testCase.verifyEqual(val, 'ndi.epoch.epochprobemap_daqsystem');

            etablk = struct();
            etablk.data_file_pattern = {'a.rhd'};
            etablk.epoch_map_format = 'ndi.epoch.epochprobemap_daqsystem';
            eta = ndi.unittest.vintage.TestVintageMap.doc( ...
                'epoch_file_pattern', 'epoch_file_pattern', etablk);
            % BOTH halves move: the BLOCK is epoch_file_pattern and the
            % FIELD is epoch_map_format. A translation that fixed only one
            % would read nothing and report `found` false.
            [val2, found2] = ndi.vintage.field(eta, 'epochprobemap_class');
            testCase.verifyTrue(found2, ...
                'the V_eta field did not resolve through both renames');
            testCase.verifyEqual(val2, 'ndi.epoch.epochprobemap_daqsystem');

            % Absence is DATA, not a fault: v1 leaves fileparameters empty
            % for a navigator with no pattern, so `found` must be false
            % rather than an error.
            [~, found3] = ndi.vintage.field(eta, 'fileparameters');
            testCase.verifyFalse(found3);
        end

        function testTheV1ObjectClassPathIsByteForByteTheOldOne(testCase)
            % ndi_document2ndi_object's inline read moved into
            % ndi.vintage.objectClass. If the v1 branch changed at all,
            % every unmigrated session in existence changes with it.
            v1 = ndi.unittest.vintage.TestVintageMap.doc('daqsystem', ...
                'daqsystem', struct('ndi_daqsystem_class', 'ndi.daq.system.mfdaq'));
            % No session is needed on the v1 path, and passing [] proves it:
            % a v1 document must not require a database round trip.
            testCase.verifyEqual( ...
                ndi.vintage.objectClass(v1, []), 'ndi.daq.system.mfdaq');
        end

        function testAMissingObjectClassIsNamedRatherThanEmpty(testCase)
            v1 = ndi.unittest.vintage.TestVintageMap.doc('daqsystem', ...
                'daqsystem', struct('something', 'else'));
            testCase.verifyError(@() ndi.vintage.objectClass(v1, []), ...
                'NDI:vintage:noObjectClassField');

            % ...and a V_eta document with no software edge says which edge
            % is missing rather than constructing nothing.
            eta = ndi.unittest.vintage.TestVintageMap.doc('acquisition_system');
            testCase.verifyError(@() ndi.vintage.objectClass(eta, []), ...
                'NDI:vintage:noSoftwareEdge');
        end

    end

    methods (Static, Access = private)

        function d = doc(className, blockName, blockStruct)
            % A minimal ndi.document of a named class, optionally carrying
            % one property block. Built from a struct so these tests need no
            % schema on the path.
            %
            % THE BLOCK IS PASSED IN RATHER THAN ASSIGNED AFTERWARDS because
            % `document_properties` is SetAccess=protected on both
            % ndi.document and did.document -- a test cannot reach into a
            % constructed document to add a block.
            % Built by field assignment, not by struct() with cell/struct
            % values -- struct() unwraps a cell argument into a struct
            % ARRAY, and an empty one silently yields an empty document.
            dc = struct();
            dc.class_name = className;
            dc.class_version = '1.0.0';
            dc.superclasses = struct('class_name', {}, 'class_version', {});
            dc.schema_version = '';

            s = struct();
            s.document_class = dc;
            s.base = struct('id', 'test_id_0001', 'session_id', 'test_sess', ...
                'name', '', 'datestamp', '2024-01-01T00:00:00.000Z');
            s.depends_on = struct('name', {}, 'value', {});
            if nargin >= 3
                s.(blockName) = blockStruct;
            end
            d = ndi.document(s);
        end

    end

end
