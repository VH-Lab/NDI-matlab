classdef TestDid2SqliteHierarchy < matlab.unittest.TestCase
%TESTDID2SQLITEHIERARCHY Can NDI FIND a migrated database, and would it open it?
%
%   These are the cheap half of the read-path question. The expensive half --
%   does a migrated database actually open and read back -- is
%   `ndi.unittest.migrate.TestMigrateLocalEtaPRED/
%   testTheMigratedSessionOpensAndReadsBackThroughNDI`, which needs mksqlite,
%   the assembled V_eta schema set and the PRED corpus, and runs only in
%   test-eta-migrate-e2e.yml.
%
%   WHAT IS LEFT HERE IS EVERYTHING THAT NEEDS NO DATABASE, and it is worth
%   its own file because the coupling it pins is invisible and silent:
%   `ndi.migrate.local` builds its output filename as
%   `[TargetVersion '.sqlite']` while `did2sqlite` states the name NDI looks
%   for. Those live in different packages and nothing but this test makes
%   them agree. If they drift, migration still succeeds, opening still
%   succeeds -- against the OLD database -- and the only symptom is a user
%   reading pre-migration documents believing they are migrated. That is a
%   quiet wrong answer, not an error, so it gets a test that runs everywhere
%   rather than one gated behind a corpus download.
%
%   See also: ndi.database.implementations.database.did2sqlite,
%             ndi.database.fun.databasehierarchyinit,
%             ndi.database.fun.opendatabase.

    methods (Test)

        function testTheHierarchyOffersBothBackendsAndSaysHowMany(testCase)
            % DENOMINATOR FIRST: how many backends the hierarchy declares.
            % A hierarchy that silently lost an entry is a failure this
            % function has already had -- it used to ASSIGN its output
            % twice, so the first entry was dead and no count said so.
            h = ndi.database.fun.databasehierarchyinit();
            testCase.verifyEqual(numel(h), 2, sprintf( ...
                ['databasehierarchyinit declares %d backend(s); this test ' ...
                 'was written against 2 (didsqlite, did2sqlite). A change ' ...
                 'in the count is a change in which backend opens or ' ...
                 'creates a database.'], numel(h)));
            testCase.verifyTrue(all(isfield(h, ...
                {'extension', 'code', 'newcode'})), ...
                'a hierarchy entry is missing one of extension/code/newcode');
        end

        function testOnlyTheLegacyBackendCanCREATEADatabase(testCase)
            % `ndi.database.fun.opendatabase`'s creation loop breaks
            % unconditionally after the FIRST entry, so entry 1 is the only
            % entry whose `newcode` can ever run. Adding a way to OPEN a
            % migrated database must not change what a NEW session is
            % written with -- and because that depends on loop mechanics
            % rather than on anything named, it is asserted here rather
            % than left for the next reader to re-derive.
            h = ndi.database.fun.databasehierarchyinit();
            testCase.verifyNotEmpty(h(1).newcode, ...
                'entry 1 has no newcode, so no new database can be created');
            testCase.verifySubstring(h(1).newcode, 'didsqlite', ...
                ['entry 1 no longer creates a `didsqlite`. New NDI sessions ' ...
                 'would be written with a different backend, which is a ' ...
                 'product decision and not a side effect of teaching NDI to ' ...
                 'read migrated databases.']);
            testCase.verifyEmpty(h(2).newcode, ...
                ['entry 2 (did2sqlite) declares a newcode. It must not: it ' ...
                 'exists to OPEN a migrated database, not to decide that ' ...
                 'new sessions become did2.']);
        end

        function testTheNameNDILooksForIsTheNameTheMIGRATORComposes(testCase)
            % THE COUPLING THIS FILE EXISTS FOR, in two halves.
            %
            % HALF ONE -- the SHAPE of the migrator's filename, read out of
            % its source rather than remembered. This is what could change
            % without anyone thinking about NDI.
            src = fileread(which('ndi.migrate.local'));
            testCase.verifySubstring(src, ...
                'fullfile(ndiDir, [options.TargetVersion ''.sqlite''])', ...
                ['ndi.migrate.local no longer composes its destination as ' ...
                 '<TargetVersion>.sqlite. did2sqlite.DEFAULTFILENAME is ' ...
                 'derived from that shape and is now guessing.']);

            % HALF TWO -- the version pinned. It is V_eta and NOT the
            % option's default (still 'V_delta'), because V_alpha..V_zeta
            % were brainstorm iterations that never held data and V_eta is
            % the first successor intended to. The reasoning is at
            % did2sqlite.DEFAULTFILENAME; this asserts the value so a
            % change has to be deliberate.
            actual = ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME();
            testCase.verifyEqual(actual, 'V_eta.sqlite', sprintf( ...
                ['did2sqlite looks for "%s". If that is no longer the file ' ...
                 'a V_eta migration writes, NDI opens the PRE-migration ' ...
                 'database and reports no error.'], actual));

            h = ndi.database.fun.databasehierarchyinit();
            testCase.verifyEqual(h(2).extension, actual, ...
                ['the hierarchy searches for a different filename than ' ...
                 'did2sqlite opens']);
        end

        function testTheQueryNdiSessionDirUsesSurvivesConversion(testCase)
            % `ndi.session.dir` finds its session document with
            % ndi.query('','isa','session'). If that one query does not
            % convert, a migrated session cannot be opened at all -- so it
            % is checked directly rather than represented by a generic one.
            %
            % NOTE WHY THERE IS NO NEGATIVE CASE HERE. did2sqlite refuses
            % an operator did2 does not implement, and that refusal cannot
            % be provoked through `did.query`: did.query's own
            % `mustBeMember` allow-list is a SUBSET of did2's, so every
            % operator a legacy query can carry is implemented. The refusal
            % is defence against a hand-built searchstructure, and a test
            % that faked one would be testing its own fake.
            q = ndi.query('', 'isa', 'session');
            q2 = ndi.database.implementations.database.did2sqlite.toDid2Query(q);
            testCase.verifyClass(q2, 'did2.query');
            testCase.verifyEqual(numel(q2.searchstructure), 1, ...
                'the one-term session query did not convert to one term');
            testCase.verifyEqual(q2.searchstructure(1).operation, 'isa', ...
                'the operation did not survive conversion');
            testCase.verifyEqual(q2.searchstructure(1).param1, 'session', ...
                'the class name did not survive conversion');
        end

        function testAnAndedQueryKeepsBothTermsInOrder(testCase)
            % Conversion flattens `and` by concatenating searchstructures,
            % which is how both classes represent conjunction. A term
            % dropped here would narrow nothing and silently WIDEN a
            % search -- more documents come back, not fewer, so nothing
            % downstream errors.
            q = and(ndi.query('', 'isa', 'subject'), ...
                    ndi.query('base.name', 'exact_string', 'abc'));
            q2 = ndi.database.implementations.database.did2sqlite.toDid2Query(q);
            testCase.verifyEqual(numel(q2.searchstructure), 2, sprintf( ...
                ['a 2-term conjunction converted to %d term(s); a lost term ' ...
                 'WIDENS the search silently'], numel(q2.searchstructure)));
            testCase.verifyEqual({q2.searchstructure.operation}, ...
                {'isa', 'exact_string'});
        end

        function testANonQueryIsRefusedRatherThanCoerced(testCase)
            testCase.verifyError( ...
                @() ndi.database.implementations.database.did2sqlite.toDid2Query(42), ...
                'NDI:did2sqlite:badQuery');
        end

    end

end
