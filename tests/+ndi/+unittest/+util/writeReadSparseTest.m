classdef writeReadSparseTest < matlab.unittest.TestCase
    % WRITEREADSPARSETEST - Unit tests for ndi.util.writeSparse / ndi.util.readSparse
    %
    % Description:
    %   Tests that ndi.util.writeSparse and ndi.util.readSparse correctly
    %   round-trip 2-D and N-dimensional sparse arrays through the NDI sparse
    %   array binary format ('.ndisparse'), and that the on-disk bytes match the
    %   documented, language-independent layout.
    %
    %   To guard against the writer and reader sharing the same bug, several
    %   tests assert against hard-coded expected values, and one test reads a
    %   fixture whose bytes were produced by an independent implementation (a
    %   Python reference writer) so a successful read is a true cross-language
    %   check.
    %

    properties
        testDir
    end

    methods (TestMethodSetup)
        function createTestDir(testCase)
            testCase.testDir = tempname;
            mkdir(testCase.testDir);
        end
    end

    methods (TestMethodTeardown)
        function removeTestDir(testCase)
            if exist(testCase.testDir, 'dir')
                rmdir(testCase.testDir, 's');
            end
        end
    end

    methods (Test)

        function test2DSparseRoundTrip(testCase)
            % A 2-D sparse matrix round-trips exactly and comes back sparse.
            A = sparse([1 3 3],[1 2 4],[10 20 30.5],3,4);
            f = fullfile(testCase.testDir,'a.ndisparse');
            ndi.util.writeSparse(f, A);
            B = ndi.util.readSparse(f);
            testCase.verifyTrue(issparse(B), 'A 2-D array should read back as sparse.');
            testCase.verifyEqual(full(B), full(A), ...
                '2-D sparse values and shape should round-trip exactly.');
        end

        function test2DFullDropsZeros(testCase)
            % A full matrix is stored by its structural nonzeros; zeros are dropped.
            A = [10 0 0 0; 0 0 0 0; 0 20 0 30.5];
            f = fullfile(testCase.testDir,'b.ndisparse');
            ndi.util.writeSparse(f, A);
            [subs,vals,sz] = ndi.util.readSparse(f);
            testCase.verifyEqual(sz, [3 4], 'Shape should be preserved.');
            testCase.verifyEqual(size(subs,1), 3, 'Only the 3 nonzeros should be stored.');
            B = ndi.util.readSparse(f);
            testCase.verifyEqual(full(B), A, 'Reconstructed dense array should match.');
        end

        function testCOOOutputForm(testCase)
            % The [SUBS,VALS,SZ] output form returns 1-based subscripts.
            A = sparse([1 3 3],[1 2 4],[10 20 30.5],3,4);
            f = fullfile(testCase.testDir,'c.ndisparse');
            ndi.util.writeSparse(f, A);
            [subs,vals,sz] = ndi.util.readSparse(f);
            testCase.verifyEqual(sz, [3 4]);
            % subscripts sorted by column-major find() order: (1,1),(3,2),(3,4)
            testCase.verifyEqual(sortrows([subs vals]), ...
                sortrows([1 1 10; 3 2 20; 3 4 30.5]), ...
                '1-based subscripts and values must match FIND output.');
        end

        function testNDRoundTrip(testCase)
            % A 3-D array via the COO struct form round-trips.
            subs = [1 1 1; 1 2 3; 2 3 4]; % 1-based
            vals = [1; 5; -7.25];
            sz = [2 3 4];
            f = fullfile(testCase.testDir,'nd.ndisparse');
            ndi.util.writeSparse(f, subs, vals, sz);
            out = ndi.util.readSparse(f);
            testCase.verifyTrue(isstruct(out), 'An N-D (N>2) array should read back as a struct.');
            testCase.verifyEqual(out.size, sz);
            testCase.verifyEqual(sortrows([out.subs out.vals]), ...
                sortrows([subs vals]), 'N-D subscripts/values must round-trip.');
        end

        function testExplicitZeroPreservedInCOO(testCase)
            % In the COO form, an explicit zero value is preserved (not dropped).
            subs = [1 1; 2 2];
            vals = [0; 5];
            sz = [2 2];
            f = fullfile(testCase.testDir,'z.ndisparse');
            ndi.util.writeSparse(f, subs, vals, sz);
            [s2,v2] = ndi.util.readSparse(f);
            testCase.verifyEqual(size(s2,1), 2, ...
                'Both entries, including the explicit zero, should be stored.');
            testCase.verifyEqual(sortrows([s2 v2]), sortrows([subs vals]));
        end

        function testEmpty(testCase)
            % An all-zero matrix stores zero entries and round-trips.
            A = sparse(5,7);
            f = fullfile(testCase.testDir,'e.ndisparse');
            ndi.util.writeSparse(f, A);
            [subs,vals,sz] = ndi.util.readSparse(f);
            testCase.verifyEqual(sz, [5 7]);
            testCase.verifyEqual(size(subs,1), 0, 'No entries should be stored.');
            testCase.verifyEmpty(vals);
            B = ndi.util.readSparse(f);
            testCase.verifyEqual(nnz(B), 0);
            testCase.verifyEqual(size(B), [5 7]);
        end

        function testHeaderBytes(testCase)
            % The on-disk header matches the documented layout.
            A = sparse([1 3 3],[1 2 4],[10 20 30.5],3,4);
            f = fullfile(testCase.testDir,'h.ndisparse');
            ndi.util.writeSparse(f, A);
            fid = fopen(f,'r','l'); c = onCleanup(@() fclose(fid));
            magic = fread(fid,8,'uint8=>uint8')';
            testCase.verifyEqual(char(magic), 'NDISPARS', 'Magic string must be NDISPARS.');
            testCase.verifyEqual(fread(fid,1,'uint32=>double'), 1, 'Version must be 1.');
            testCase.verifyEqual(fread(fid,1,'uint32=>double'), 2, 'ndims must be 2.');
            testCase.verifyEqual(fread(fid,2,'uint64=>double')', [3 4], 'Shape must be [3 4].');
            testCase.verifyEqual(fread(fid,1,'uint64=>double'), 3, 'nnz must be 3.');
        end

        function testReadsIndependentFixture(testCase)
            % Read a file whose bytes were produced by an independent (Python)
            % writer of the same format. A successful read is a cross-language check.
            % Represents a 3x4 array with (1-based) (1,1)=10, (3,2)=20, (3,4)=30.5.
            bytes = uint8([ ...
                78, 68, 73, 83, 80, 65, 82, 83, 1, 0, 0, 0, 2, 0, 0, 0, ...
                3, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, ...
                3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, ...
                2, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, ...
                0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, ...
                3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 36, 64, ...
                0, 0, 0, 0, 0, 0, 52, 64, 0, 0, 0, 0, 0, 128, 62, 64]);
            f = fullfile(testCase.testDir,'fixture.ndisparse');
            fid = fopen(f,'w','l'); fwrite(fid, bytes, 'uint8'); fclose(fid);
            B = ndi.util.readSparse(f);
            expected = sparse([1 3 3],[1 2 4],[10 20 30.5],3,4);
            testCase.verifyEqual(full(B), full(expected), ...
                'File from an independent writer must decode to the expected array.');
        end

        function testWriteThenIndependentByteCheck(testCase)
            % writeSparse output must equal the independently-constructed fixture bytes.
            A = sparse([1 3 3],[1 2 4],[10 20 30.5],3,4);
            f = fullfile(testCase.testDir,'wb.ndisparse');
            ndi.util.writeSparse(f, A);
            fid = fopen(f,'r','l'); actual = fread(fid,Inf,'uint8=>uint8')'; fclose(fid);
            expected = uint8([ ...
                78, 68, 73, 83, 80, 65, 82, 83, 1, 0, 0, 0, 2, 0, 0, 0, ...
                3, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, ...
                3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, ...
                2, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, ...
                0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, ...
                3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 36, 64, ...
                0, 0, 0, 0, 0, 0, 52, 64, 0, 0, 0, 0, 0, 128, 62, 64]);
            testCase.verifyEqual(actual, expected, ...
                'Bytes written must match the documented, language-independent layout.');
        end

        function testBadMagicErrors(testCase)
            f = fullfile(testCase.testDir, 'bad.ndisparse');
            fid = fopen(f,'w','l'); fwrite(fid, uint8(1:64), 'uint8'); fclose(fid);
            testCase.verifyError(@() ndi.util.readSparse(f), 'ndi:util:readSparse:badMagic', ...
                'A file without the NDISPARS magic should raise badMagic.');
        end

        function testWriteSubsBoundsError(testCase)
            f = fullfile(testCase.testDir, 'oob.ndisparse');
            testCase.verifyError(@() ndi.util.writeSparse(f, [1 5], 3, [2 2]), ...
                'ndi:util:writeSparse:subsOutOfBounds', ...
                'A subscript beyond the declared size should raise an error.');
        end

    end
end
