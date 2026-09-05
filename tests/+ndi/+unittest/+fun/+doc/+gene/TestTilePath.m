classdef TestTilePath < matlab.unittest.TestCase
    % TestTilePath - the memo behind ndi.fun.doc.gene.tilePath.
    %
    % A tile's local path is remembered so that panning back over ground
    % already covered costs an isfile check rather than a document read, a
    % location resolve and -- on a cloud-backed session -- a retrieval.
    %
    % What has to be true for that to be safe, and is what this asserts:
    % the remembered path must be the SAME path the database would hand
    % back, it must be CHECKED rather than trusted so a vanished file is
    % re-fetched instead of returned, and two files of one document must
    % not collide.

    properties
        session
        pyr
        tileDoc
        tileName
    end

    methods (TestMethodSetup)
        function build(testCase)
            d = fullfile(tempname, 'tilepath');
            mkdir(d);
            testCase.addTeardown(@() rmdir(fileparts(d), 's'));
            % The memo is persistent, so it outlives one test. Every test
            % starts from empty or they would read each other's entries.
            ndi.fun.doc.gene.tilePath('clear');
            testCase.addTeardown(@() ndi.fun.doc.gene.tilePath('clear'));

            S = ndi.session.dir('tilepath', d);
            sub = ndi.document('subject', 'base.session_id', S.id(), ...
                'subject.local_identifier', 'tilepath@vhlab');
            S.database_add(sub);
            gl = ndi.fun.doc.gene.makeGeneList(S, ...
                {'ENST0001','ENST0002'}, {'a','b'});
            [p, tiles] = ndi.fun.doc.gene.makePyramid(S, ...
                [1000; 1005], [2000; 2003], [0; 1], [2; 3], gl, ...
                'binSizes', [1 2], 'grid', 2, 'subjectID', sub.id());
            testCase.session = S;
            testCase.pyr = p;
            testCase.tileDoc = tiles{1};
            names = testCase.tileDoc.current_file_list();
            testCase.assertNotEmpty(names, 'The fixture must store a tile.');
            testCase.tileName = names{1};
        end
    end

    methods (Test)

        function testReturnsAReadablePath(testCase)
            p = ndi.fun.doc.gene.tilePath(testCase.session, ...
                testCase.tileDoc, testCase.tileName);
            testCase.verifyTrue(isfile(p));
            t = ndi.fun.doc.gene.readTileFile(p);
            testCase.verifyTrue(isfield(t, 'n_pixels'));
        end

        function testTheSecondCallAgreesWithTheFirst(testCase)
            % The memo must not answer with a different file than the
            % database would. That is the whole premise: the database names
            % a cached file by its immutable uid, so the path cannot change
            % meaning.
            a = ndi.fun.doc.gene.tilePath(testCase.session, ...
                testCase.tileDoc, testCase.tileName);
            b = ndi.fun.doc.gene.tilePath(testCase.session, ...
                testCase.tileDoc, testCase.tileName);
            testCase.verifyEqual(b, a);

            bd = testCase.session.database_openbinarydoc( ...
                testCase.tileDoc, testCase.tileName);
            direct = bd.fullpathfilename;
            testCase.session.database_closebinarydoc(bd);
            testCase.verifyEqual(a, direct, ...
                'The memo must return what the database returns.');
        end

        function testAVanishedFileIsFetchedAgainRatherThanReturned(testCase)
            % The one way a memo can be wrong. The remembered path is
            % checked, so an evicted file costs a fetch instead of handing
            % back something that no longer resolves.
            p = ndi.fun.doc.gene.tilePath(testCase.session, ...
                testCase.tileDoc, testCase.tileName);
            moved = [p '.moved'];
            movefile(p, moved);
            testCase.addTeardown(@() testCase.restore(moved, p));
            testCase.verifyFalse(isfile(p));

            again = ndi.fun.doc.gene.tilePath(testCase.session, ...
                testCase.tileDoc, testCase.tileName);
            testCase.verifyTrue(isfile(again), ...
                'A vanished file must be fetched again, not returned.');
        end

        function testTwoFilesOfOneDocumentDoNotCollide(testCase)
            % The key is document id AND filename. Keying on the document
            % alone would give every tile of a level the first tile's
            % bytes -- a picture that renders perfectly and is wrong.
            names = testCase.tileDoc.current_file_list();
            if numel(names) < 2
                testCase.assumeFail('Fixture stores only one tile.');
            end
            a = ndi.fun.doc.gene.tilePath(testCase.session, testCase.tileDoc, names{1});
            b = ndi.fun.doc.gene.tilePath(testCase.session, testCase.tileDoc, names{2});
            testCase.verifyNotEqual(a, b);
        end

        function testClearEmptiesTheMemo(testCase)
            ndi.fun.doc.gene.tilePath(testCase.session, ...
                testCase.tileDoc, testCase.tileName);
            ndi.fun.doc.gene.tilePath('clear');
            % Nothing observable to assert beyond it still working: a
            % cleared memo must refetch rather than error.
            p = ndi.fun.doc.gene.tilePath(testCase.session, ...
                testCase.tileDoc, testCase.tileName);
            testCase.verifyTrue(isfile(p));
        end

        function testMissingArgumentsAreNamed(testCase)
            testCase.verifyError(@() ndi.fun.doc.gene.tilePath(testCase.session), ...
                'NDI:gene:tilePath:nargin');
        end

        function testViewportStillMatchesADirectRead(testCase)
            % The readers now go through the memo. Their output must not
            % have moved: the same rectangle, read twice, through a warm
            % memo and a cold one.
            a = ndi.fun.doc.gene.readViewport(testCase.session, ...
                testCase.pyr, 1, [], []);
            ndi.fun.doc.gene.tilePath('clear');
            b = ndi.fun.doc.gene.readViewport(testCase.session, ...
                testCase.pyr, 1, [], []);
            testCase.verifyEqual(b, a);
            testCase.verifyGreaterThan(sum(a(:)), 0, ...
                'The fixture must put counts in this level.');
        end

    end

    methods (Access = private)
        function restore(~, moved, original)
            if isfile(moved) && ~isfile(original)
                movefile(moved, original);
            end
        end
    end
end
