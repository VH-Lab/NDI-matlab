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
            testCase.verifyEqual(numel(m), 7, sprintf( ...
                ['ndi.vintage.map declares %d concept(s); this test was ' ...
                 'written against 7 (daqsystem, filenavigator, ' ...
                 'daqmetadatareader, daqreader, syncgraph, syncrule, ' ...
                 'element)'], numel(m)));
            for i = 1:numel(m)
                testCase.verifyNotEmpty(m(i).concept);
                testCase.verifyNotEmpty(m(i).eta_class);
                testCase.verifyEqual(size(m(i).edges, 2), 2, ...
                    sprintf('%s: edges must be N-by-2', m(i).concept));
                testCase.verifyEqual(size(m(i).fields, 2), 2, ...
                    sprintf('%s: fields must be N-by-2', m(i).concept));
                % A renamed class whose object key has no home in V_eta
                % would be unconstructable, which is the whole point.
                % Every concept must say WHERE its object class lives --
                % an edge to a software entity, or an inbound assertion.
                % A row with neither is unconstructable.
                testCase.verifyTrue( ...
                    ~isempty(m(i).object_edge) || ~isempty(m(i).object_assertion), ...
                    sprintf('%s: no V_eta object-class locator', m(i).concept));
            end
        end

        function testOnlyElementDeclinesToBridgeIsa(testCase)
            % THIS ASSERTION WAS INVERTED, and the reason it changed is
            % worth more than the assertion. It used to say `element` had
            % no map row at all, on the reasoning that a decomposed class
            % cannot be mapped. That was the wrong axis: `element` -> 5
            % documents and `daqsystem` -> 2 documents are the same shape,
            % a ROOT carrying the preserved v1 base.id plus satellites, and
            % the element migrator preserves the id exactly as the others
            % do ("becomes a `subject` with its id PRESERVED").
            %
            % What actually distinguishes element is that its root class is
            % SHARED. `acquisition_system` is a class NDI uses for nothing
            % else, so `isa` bridges cleanly; `subject` is not, so bridging
            % would return every animal as an element. That is the property
            % this test pins.
            m = ndi.vintage.map();
            nonBridging = {m(~[m.isa_bridges]).concept};
            testCase.verifyEqual(nonBridging, {'element'}, ...
                ['exactly one concept should decline to bridge `isa`, and ' ...
                 'it is `element` -- its V_eta class `subject` is shared ' ...
                 'with real specimens']);

            entry = ndi.vintage.entryFor('element');
            testCase.verifyNotEmpty(entry, 'element must have a map row');
            testCase.verifyEqual(entry.eta_class, 'subject');
            testCase.verifyNotEmpty(entry.object_assertion, ...
                'element''s object class comes from an inbound assertion');

            % pyraview stays out, and for a reason that is NOT cardinality:
            % it is not an NDI object type at all. Of the 91 NDI templates
            % only 8 declare an `ndi_*_class` field and pyraview is not
            % among them -- its documents are data, reached through an
            % element, so there is no object to reconstruct.
            testCase.verifyEmpty(ndi.vintage.entryFor('pyraview'), ...
                'pyraview is not an NDI object type');
            testCase.verifyEmpty(ndi.vintage.entryFor('session'), ...
                'V_eta renames neither session nor its class');

            % `subject` IS NOW A MAPPED NAME, and this assertion says so
            % rather than being deleted. It used to assert the opposite,
            % which was true until `element` gained a row whose eta_class
            % is `subject` -- so asking the map about `subject` now returns
            % the element row.
            %
            % That is safe ONLY because of `isa_bridges`. Every other
            % consumer does the right thing with it by construction: field
            % reads resolve to the `subject` block either way, the row
            % declares no edges, and objectClass on a real specimen fails
            % with "this subject was never an element" -- which is correct,
            % an animal is not an object NDI can rebuild. The one place it
            % WOULD matter is isaQuery, and the flag stops it there.
            [subjEntry, subjVintage] = ndi.vintage.entryFor('subject');
            testCase.verifyNotEmpty(subjEntry, ...
                'subject resolves to the element row via its eta_class');
            testCase.verifyEqual(subjEntry.concept, 'element');
            testCase.verifyEqual(subjVintage, 'V_eta');
            testCase.verifyFalse(subjEntry.isa_bridges, ...
                ['the element row must not bridge -- it is the only thing ' ...
                 'keeping `subject` being a mapped name harmless']);
        end

        function testDaqreaderIsMappedBecauseTheNAMESURVIVINGIsNotTheTest(testCase)
            % THIS ASSERTION USED TO SAY THE OPPOSITE, and the inversion is
            % the point. `daqreader` was left out of the map on the
            % reasoning that V_eta "keeps the class name and keeps
            % ndi_daqreader_class as a field" -- both true of
            % schemas/V_eta/stable/daqreader.json, which is the v1
            % TOMBSTONE, and neither true of a migrated document. The
            % migrator emits `acquisition_reader`
            % (+migrators_j/daqreader.m:159).
            %
            % So the test is not "is the name still in V_eta" but "what
            % does the migrator emit", and it is written that way round
            % here so the old reasoning cannot come back.
            [entry, vintage] = ndi.vintage.entryFor('acquisition_reader');
            testCase.verifyNotEmpty(entry, ...
                ['acquisition_reader is unmapped -- ndi.daq.system follows ' ...
                 'reader_id to one of these and needs its object class']);
            testCase.verifyEqual(vintage, 'V_eta');
            testCase.verifyEqual(entry.concept, 'daqreader');
            testCase.verifyEqual(entry.object_edge, 'software_id');
        end

        function testIsaQueryRefusesToBridgeElement(testCase)
            % The consequence of the flag, asserted where a caller would
            % feel it. If this ever OR-s `subject` in, `getelements` starts
            % returning every animal in the session -- and because that
            % WIDENS the result nothing errors, so this is the only place
            % it would be caught.
            q = ndi.vintage.isaQuery('element');
            txt = jsonencode(q.searchstructure);
            testCase.verifySubstring(txt, 'element');
            testCase.verifyEmpty(strfind(txt, 'subject'), ...
                ['isaQuery(''element'') reaches `subject`; every specimen ' ...
                 'in the session would come back as an element']);
        end

        function testIsaQueryAsksForBothVintages(testCase)
            q = ndi.vintage.isaQuery('daqsystem');
            % `did.query` IS the right expectation and `ndi.query` is not,
            % because of an asymmetry inside did.query that this test found
            % by asserting the wrong one first:
            %
            %     and(A,B)   C = A;              <- keeps A's subclass
            %     or(A,B)    C = did.query('');  <- builds a BASE object
            %
            % So OR-ing two ndi.query objects yields a did.query. That is
            % harmless everywhere it lands -- ndi.session/database_search
            % takes {'ndi.query','did.query'}, and so do both database
            % backends' do_search -- so the requirement is did.query, and
            % demanding ndi.query would be this test inventing a constraint
            % the system does not have.
            testCase.verifyTrue(isa(q, 'did.query'));
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

            % Absence is DATA, not a fault: v1 leaves these empty for a
            % navigator with no pattern, so `found` must be false rather
            % than an error.
            %
            % THE FIELD ASKED FOR HERE MATTERS, and the first version of
            % this test got it wrong in a way worth keeping a note about:
            % it asked for `fileparameters` and expected false. But
            % `fileparameters` MAPS to `data_file_pattern`, which the block
            % above does carry -- so `found` was correctly true and the
            % test was asserting that the translation had failed. The right
            % probe is a field whose V_eta counterpart is genuinely absent:
            % `epochprobemap_fileparameters` -> `epoch_map_pattern`, which
            % this block does not set.
            [~, found3] = ndi.vintage.field(eta, 'epochprobemap_fileparameters');
            testCase.verifyFalse(found3, ...
                'a field absent from the block must report found=false');

            % ...and the mapped-and-present case is asserted alongside it,
            % so "false" here can never be produced by a translation that
            % simply stopped working.
            [val4, found4] = ndi.vintage.field(eta, 'fileparameters');
            testCase.verifyTrue(found4, ...
                'fileparameters -> data_file_pattern did not resolve');
            testCase.verifyEqual(val4, {'a.rhd'});
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
