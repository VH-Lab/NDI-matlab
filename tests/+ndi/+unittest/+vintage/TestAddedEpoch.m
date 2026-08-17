classdef TestAddedEpoch < matlab.unittest.TestCase
%TESTADDEDEPOCH The added-epoch reader, over all three storage shapes.
%
%   `ndi.vintage.addedEpoch` is what `ndi.element.loadaddedepochs` calls for
%   every candidate document, and the three shapes it must read are all
%   live at once: what NDI WRITES today (v1 `epoch_clock` + `t0_t1`), what
%   the V_delta restructure produced (`element_epoch.clocks`), and what the
%   V_eta migrator emits (`acquisition_epoch.clocks`).
%
%   WHY THESE ARE HAND-BUILT DOCUMENTS AND NOT A CORPUS RUN. The failure
%   this closes was invisible on every corpus we have, because a corpus
%   contains only what the MIGRATOR wrote -- never what NDI wrote after the
%   reader changed. The v1 round trip (addepoch -> loadaddedepochs) has no
%   corpus and cannot have one; it needs a document built by hand. The
%   migrated half IS covered end to end by
%   `ndi.unittest.migrate.TestMigrateLocalEta20211116`, and these tests are
%   the fast, one-reason-at-a-time layer under it.
%
%   THE SYMPTOM EACH SHAPE PRODUCED BEFORE THIS EXISTED, so a regression is
%   recognisable:
%     v1      -> an ERROR, "Unrecognized field name 'clocks'"
%     V_delta -> correct (the one shape the old reader handled)
%     V_eta   -> SILENCE. The `isfield(...,'element_epoch')` gate failed,
%                the loop ran zero times, and every derived element
%                reported no epochs at all.
%
%   See also: ndi.vintage.addedEpoch, ndi.vintage.map, ndi.element.

    methods (Test)

        % ===================== the shape NDI writes ====================

        function testTheV1ShapeNDIWritesTodayIsRead(testCase)
            % ndi.element.addepoch writes exactly this (element.m:424-427),
            % and the reader on this branch could not read it. The values
            % are the ones a real document carries: measured on corpus
            % 20211116, all 252 element_epoch documents have a single
            % `dev_local_time` clock and a flat two-element t0_t1.
            d = ndi.unittest.vintage.TestAddedEpoch.epochDoc('element_epoch', ...
                'element_epoch', struct('epoch_clock', 'dev_local_time', ...
                                        't0_t1', [0; 427.39195]), 't00013');
            [epochId, ec, t0t1, found, shape] = ndi.vintage.addedEpoch(d);
            testCase.verifyTrue(found, ...
                'the v1 shape -- what NDI itself writes -- was not read');
            testCase.verifyEqual(shape, 'v1');
            testCase.verifyEqual(epochId, 't00013');
            testCase.verifyEqual(numel(ec), 1);
            testCase.verifyEqual(ec{1}.type, 'dev_local_time');
            testCase.verifyEqual(t0t1{1}, [0 427.39195], 'AbsTol', 1e-9);
        end

        function testAMultiClockV1DocumentTakesColumnsAsClocks(testCase)
            % THE ORIENTATION, pinned. Two implementations agree that v1
            % `t0_t1` is 2-by-N with COLUMNS as clocks -- `origin/main`
            % element.m indexes `t0_t1(:,k)`, and DID-matlab
            % +migrators/element_epoch.m canonicalises the same way. A
            % third description (the `clocks` field documentation on
            % acquisition_epoch.json) says row-wise and is not followed.
            %
            % NOTHING IN REACH EXERCISES THIS: 0 of the 252 element_epoch
            % documents in 20211116 have a comma in `epoch_clock`. So this
            % test is the only thing holding the orientation, and if it
            % ever disagrees with a real multi-clock document the document
            % wins -- read the two sources above before changing it.
            d = ndi.unittest.vintage.TestAddedEpoch.epochDoc('element_epoch', ...
                'element_epoch', ...
                struct('epoch_clock', 'dev_local_time,exp_global_time', ...
                       't0_t1', [0 738553.4082; 3599.69855 738553.4498]), ...
                't00001');
            [~, ec, t0t1, found] = ndi.vintage.addedEpoch(d);
            testCase.verifyTrue(found);
            testCase.verifyEqual(numel(ec), 2);
            testCase.verifyEqual(ec{1}.type, 'dev_local_time');
            testCase.verifyEqual(ec{2}.type, 'exp_global_time');
            testCase.verifyEqual(t0t1{1}, [0 3599.69855], 'AbsTol', 1e-9);
            testCase.verifyEqual(t0t1{2}, [738553.4082 738553.4498], ...
                'AbsTol', 1e-6);
        end

        function testANamedClockWithNoTimeColumnIsSkippedNotPadded(testCase)
            % A fabricated [0 0] extent reads as a real epoch of zero
            % length and would reach the epoch table as data. Refusing the
            % clock loses a name; padding invents an interval.
            d = ndi.unittest.vintage.TestAddedEpoch.epochDoc('element_epoch', ...
                'element_epoch', ...
                struct('epoch_clock', 'dev_local_time,exp_global_time', ...
                       't0_t1', [0; 12.5]), 't00002');
            [~, ec, t0t1, found] = ndi.vintage.addedEpoch(d);
            testCase.verifyTrue(found, ...
                'the clock that DOES have times should still be returned');
            testCase.verifyEqual(numel(ec), 1, ...
                'the unmatched clock name was padded instead of skipped');
            testCase.verifyEqual(ec{1}.type, 'dev_local_time');
            testCase.verifyEqual(t0t1{1}, [0 12.5], 'AbsTol', 1e-9);
        end

        % ===================== the two `clocks` shapes =================

        function testTheVDeltaClocksShapeIsStillRead(testCase)
            % Kept by team decision rather than reverted (NDI-matlab
            % bcc6b4e14). This is the one shape the old reader handled, so
            % it is the regression guard on the rewrite.
            d = ndi.unittest.vintage.TestAddedEpoch.epochDoc('element_epoch', ...
                'element_epoch', struct('clocks', ...
                    struct('name', 'dev_local_time', 't0', 0, 't1', 900.5)), ...
                't00007');
            [epochId, ec, t0t1, found, shape] = ndi.vintage.addedEpoch(d);
            testCase.verifyTrue(found);
            testCase.verifyEqual(shape, 'clocks');
            testCase.verifyEqual(epochId, 't00007');
            testCase.verifyEqual(ec{1}.type, 'dev_local_time');
            testCase.verifyEqual(t0t1{1}, [0 900.5], 'AbsTol', 1e-9);
        end

        function testTheMigratedVEtaDocumentIsReadRatherThanSkipped(testCase)
            % THE ASSERTION THIS FILE EXISTS FOR. The block is
            % `acquisition_epoch`, which is what DID-matlab
            % +migrators_j/element_epoch.m renames `element_epoch` to, and
            % it is what the old `isfield(...,'element_epoch')` gate
            % skipped without a word.
            d = ndi.unittest.vintage.TestAddedEpoch.epochDoc( ...
                'acquisition_epoch', 'acquisition_epoch', ...
                struct('clocks', struct('name', 'dev_local_time', ...
                                        't0', 0, 't1', 427.39195)), 't00013');
            [epochId, ec, t0t1, found, shape] = ndi.vintage.addedEpoch(d);
            testCase.verifyTrue(found, ...
                ['a migrated acquisition_epoch document was not read -- ' ...
                 'this is the silent-empty-epoch-table failure']);
            testCase.verifyEqual(shape, 'V_eta');
            testCase.verifyEqual(epochId, 't00013');
            testCase.verifyEqual(ec{1}.type, 'dev_local_time');
            testCase.verifyEqual(t0t1{1}, [0 427.39195], 'AbsTol', 1e-9);
        end

        function testAMultiEntryClocksArrayKeepsItsOrder(testCase)
            entries = struct('name', {'dev_local_time', 'exp_global_time'}, ...
                             't0', {0, 738553.4082}, ...
                             't1', {3599.69855, 738553.4498});
            d = ndi.unittest.vintage.TestAddedEpoch.epochDoc( ...
                'acquisition_epoch', 'acquisition_epoch', ...
                struct('clocks', entries), 't00001');
            [~, ec, t0t1, found] = ndi.vintage.addedEpoch(d);
            testCase.verifyTrue(found);
            testCase.verifyEqual(numel(ec), 2);
            testCase.verifyEqual(ec{2}.type, 'exp_global_time');
            testCase.verifyEqual(t0t1{2}, [738553.4082 738553.4498], ...
                'AbsTol', 1e-6);
        end

        % ===================== what must NOT be read ===================

        function testANonEpochDocumentIsRefusedQuietly(testCase)
            % `load_all_element_docs` returns the element document itself
            % and every other document depending on it, so "not an epoch
            % record" is the ordinary case and must be an answer, not an
            % error.
            d = ndi.unittest.vintage.TestAddedEpoch.epochDoc('element', ...
                'element', struct('name', 'leftcortex_16', 'type', 'spikes'), '');
            [epochId, ec, t0t1, found, shape] = ndi.vintage.addedEpoch(d);
            testCase.verifyFalse(found);
            testCase.verifyEmpty(epochId);
            testCase.verifyEmpty(ec);
            testCase.verifyEmpty(t0t1);
            testCase.verifyEmpty(shape);
        end

        function testAnEpochBlockWithNoEpochIdIsRefused(testCase)
            % A record with a blank id joins nothing: `buildepochtable`
            % intersects on epoch_id, so admitting it would add a row that
            % silently matches no underlying epoch. Refusing names the
            % malformed document instead.
            d = ndi.unittest.vintage.TestAddedEpoch.epochDoc('element_epoch', ...
                'element_epoch', struct('epoch_clock', 'dev_local_time', ...
                                        't0_t1', [0; 10]), '');
            [epochId, ~, ~, found] = ndi.vintage.addedEpoch(d);
            testCase.verifyFalse(found);
            testCase.verifyEmpty(epochId);
        end

        function testABlockWithNeitherShapeIsRefusedRatherThanErroring(testCase)
            d = ndi.unittest.vintage.TestAddedEpoch.epochDoc('element_epoch', ...
                'element_epoch', struct('something', 'else'), 't00013');
            [~, ~, ~, found] = ndi.vintage.addedEpoch(d);
            testCase.verifyFalse(found);
        end

        % ===================== the class-name trap =====================

        function testAOneepochDocumentIsFoundByItsBlockNotItsClass(testCase)
            % `ndi.element.addepoch` writes an `element_epoch` BLOCK into a
            % document whose CLASS is `oneepoch` (element.m:429-433). The
            % code this replaces located the block by presence and so
            % caught these; a rewrite that keyed on the class name would
            % drop them, and no corpus in reach holds one to notice.
            d = ndi.unittest.vintage.TestAddedEpoch.epochDoc('oneepoch', ...
                'element_epoch', struct('epoch_clock', 'dev_local_time', ...
                                        't0_t1', [0; 55]), 't00099');
            [epochId, ~, ~, found, shape] = ndi.vintage.addedEpoch(d);
            testCase.verifyTrue(found, ...
                'a `oneepoch` document was dropped -- the block is what identifies it');
            testCase.verifyEqual(epochId, 't00099');
            testCase.verifyEqual(shape, 'v1');
        end

        % ===================== the map row =============================

        function testTheIsaQueryAsksForBothEpochClasses(testCase)
            % +element/timeseries.m searches for the epoch document whose
            % .vhsb readtimeseries then opens. `isa element_epoch` alone
            % finds nothing in a migrated session.
            % `searchstructure` + jsonencode is TestVintageMap's idiom for
            % this, and it asserts the NAMES rather than the structure
            % shape so a did.query that flattens differently still passes.
            q = ndi.vintage.isaQuery('element_epoch');
            txt = jsonencode(q.searchstructure);
            testCase.verifySubstring(txt, 'element_epoch');
            testCase.verifySubstring(txt, 'acquisition_epoch');
        end

    end

    methods (Static, Access = private)

        function d = epochDoc(className, blockName, blockStruct, epochId)
            % A minimal ndi.document with a named class, one property block
            % and an `epochid` block. Same constraint as TestVintageMap.doc:
            % `document_properties` is SetAccess=protected, so every block
            % has to be present before construction.
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
            s.(blockName) = blockStruct;
            % An EMPTY epochId still gets a block, so the "blank id" test
            % exercises the id check rather than the block check -- two
            % different refusals that must not arrive as one.
            s.epochid = struct('epochid', epochId);
            d = ndi.document(s);
        end

    end

end
