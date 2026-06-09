classdef readNPYTest < matlab.unittest.TestCase
    % READNPYTEST - Unit tests for ndi.util.readNPY
    %
    % Description:
    %   Tests that ndi.util.readNPY correctly parses NumPy .npy files across the
    %   dtypes, dimensionalities, byte orders, and memory orders it claims to
    %   support, and that it errors appropriately on invalid or unsupported input.
    %
    %   The tests do not depend on Python or the npy-matlab toolbox. Each .npy file
    %   is synthesized in this test class by a small, self-contained writer
    %   (localWriteNPY, below) that emits the .npy header and raw bytes directly.
    %   The writer and the reader-under-test are independent implementations, so a
    %   successful round-trip is a meaningful check. To guard against both sharing
    %   the same bug, several tests also assert against hard-coded expected arrays.
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

        function test1DInt64(testCase)
            % A 1-D int64 array round-trips and is returned as a column vector.
            expected = int64([0; 1; 2; 100; -5; 2^40]);
            f = testCase.writeFile('int64_1d.npy', expected(:).', 'int64', '<', false);
            data = ndi.util.readNPY(f);
            testCase.verifyEqual(data, expected, ...
                'int64 1-D values should round-trip exactly.');
            testCase.verifyEqual(class(data), 'int64', 'Class should be int64.');
            testCase.verifyEqual(size(data), [6 1], ...
                'A 1-D NumPy array should be returned as an Nx1 column vector.');
        end

        function testFloat32Values(testCase)
            % float32 values round-trip and come back as single.
            expected = single([1.5 -2.25 0 3.0 100.125]);
            f = testCase.writeFile('f32.npy', expected, 'single', '<', false);
            data = ndi.util.readNPY(f);
            testCase.verifyEqual(data, expected(:), ...
                'float32 values should round-trip exactly (powers-of-two fractions).');
            testCase.verifyEqual(class(data), 'single', 'Class should be single.');
        end

        function testFloat64Values(testCase)
            expected = double([pi; -exp(1); 0; 1e-12; 1e12]);
            f = testCase.writeFile('f64.npy', expected.', 'double', '<', false);
            data = ndi.util.readNPY(f);
            testCase.verifyEqual(data, expected, ...
                'float64 values should round-trip exactly.');
            testCase.verifyEqual(class(data), 'double', 'Class should be double.');
        end

        function testBooleanDtype(testCase)
            % bool arrays come back as a MATLAB logical.
            expected = logical([1 0 1 1 0]);
            f = testCase.writeFile('bool.npy', expected, 'bool', '|', false);
            data = ndi.util.readNPY(f);
            testCase.verifyEqual(data, expected(:), ...
                'boolean values should round-trip.');
            testCase.verifyTrue(islogical(data), 'Class should be logical.');
        end

        function testUnsignedIntegers(testCase)
            expected = uint8([0; 1; 127; 128; 255]);
            f = testCase.writeFile('u8.npy', expected.', 'uint8', '|', false);
            data = ndi.util.readNPY(f);
            testCase.verifyEqual(data, expected, 'uint8 values should round-trip.');
            testCase.verifyEqual(class(data), 'uint8', 'Class should be uint8.');
        end

        function test2DCOrder(testCase)
            % A 2-D C-ordered array keeps its NumPy shape in MATLAB.
            % Hard-coded expected array guards against a circular writer/reader bug.
            expected = int32([1 2 3; 4 5 6]); % NumPy shape (2,3)
            f = testCase.writeFile('i32_2d_c.npy', expected, 'int32', '<', false);
            [data, shp] = ndi.util.readNPY(f);
            testCase.verifyEqual(size(data), [2 3], ...
                'NumPy (2,3) should become MATLAB 2x3.');
            testCase.verifyEqual(data, expected, ...
                'C-ordered 2-D contents must match element-for-element.');
            testCase.verifyEqual(shp, [2 3], 'Returned shape should be the NumPy shape.');
        end

        function test2DFortranOrder(testCase)
            % The same logical array stored Fortran-ordered must read back identically.
            expected = int32([1 2 3; 4 5 6]); % NumPy shape (2,3), F-order on disk
            f = testCase.writeFile('i32_2d_f.npy', expected, 'int32', '<', true);
            data = ndi.util.readNPY(f);
            testCase.verifyEqual(size(data), [2 3], ...
                'Fortran-ordered array should still report shape 2x3.');
            testCase.verifyEqual(data, expected, ...
                'Fortran-ordered contents must match the C-ordered logical array.');
        end

        function test3DCOrder(testCase)
            % 3-D array (mimics kilosort templates.npy: nTemplates x nSamples x nChannels).
            expected = zeros(2,3,4);
            expected(:) = 1:24; % arbitrary but distinct values
            expected = double(expected);
            f = testCase.writeFile('f64_3d.npy', expected, 'double', '<', false);
            [data, shp] = ndi.util.readNPY(f);
            testCase.verifyEqual(size(data), [2 3 4], ...
                'NumPy (2,3,4) should become MATLAB 2x3x4.');
            testCase.verifyEqual(data, expected, ...
                '3-D C-ordered contents must match including axis order.');
            testCase.verifyEqual(shp, [2 3 4], 'Returned shape should be (2,3,4).');
        end

        function testBigEndian(testCase)
            % Big-endian float64 must be decoded correctly.
            expected = double([1.0; 2.0; -3.5; 256.0]);
            f = testCase.writeFile('be_f64.npy', expected.', 'double', '>', false);
            data = ndi.util.readNPY(f);
            testCase.verifyEqual(data, expected, ...
                'Big-endian float64 values should decode to the same numbers.');
        end

        function testLittleVsBigEndianAgree(testCase)
            % The same values written LE and BE must read back identical.
            vals = int16([1 256 -1 1000 -32768]);
            fLE = testCase.writeFile('le.npy', vals, 'int16', '<', false);
            fBE = testCase.writeFile('be.npy', vals, 'int16', '>', false);
            dLE = ndi.util.readNPY(fLE);
            dBE = ndi.util.readNPY(fBE);
            testCase.verifyEqual(dLE, dBE, ...
                'Little- and big-endian encodings of the same data must agree.');
            testCase.verifyEqual(dLE, vals(:), 'And both must equal the original values.');
        end

        function testOptionalOutputs(testCase)
            % SHAPE and DTYPE outputs are populated.
            expected = single([1 2; 3 4]);
            f = testCase.writeFile('outs.npy', expected, 'single', '<', false);
            [~, shp, dtype] = ndi.util.readNPY(f);
            testCase.verifyEqual(shp, [2 2], 'Shape output should be (2,2).');
            testCase.verifyEqual(dtype, '<f4', 'Dtype output should be the NumPy descr string.');
        end

        function testScalar(testCase)
            % A 0-d array (empty shape tuple) reads as a scalar.
            f = testCase.writeFile('scalar.npy', 42, 'double', '<', false, true);
            data = ndi.util.readNPY(f);
            testCase.verifyEqual(data, 42, 'A 0-d array should read as a scalar value.');
        end

        function testVersion2Header(testCase)
            % A version 2.0 header (4-byte header length) must parse.
            expected = int32([7 8 9]);
            f = testCase.writeFile('v2.npy', expected, 'int32', '<', false, false, 2);
            data = ndi.util.readNPY(f);
            testCase.verifyEqual(data, expected(:), ...
                'Version 2.0 .npy files should parse correctly.');
        end

        function testBadMagicErrors(testCase)
            % A file without the NumPy magic string should error with our identifier.
            f = fullfile(testCase.testDir, 'notnpy.npy');
            fid = fopen(f,'w');
            fwrite(fid, uint8(1:32), 'uint8');
            fclose(fid);
            testCase.verifyError(@() ndi.util.readNPY(f), 'ndi:util:readNPY:badMagic', ...
                'A non-.npy file should raise the badMagic error.');
        end

        function testUnsupportedDtypeErrors(testCase)
            % An object dtype ('|O...') is not supported and should error.
            f = testCase.writeRawHeader('obj.npy', '|O8', '(3,)', false, 1);
            testCase.verifyError(@() ndi.util.readNPY(f), 'ndi:util:readNPY:unsupportedDtype', ...
                'Object dtype should raise the unsupportedDtype error.');
        end

    end

    methods % helpers (independent .npy writer used only for testing)

        function fname = writeFile(testCase, name, matlabArray, dtypeName, endianChar, fortranOrder, isScalar, version)
            % Write matlabArray to a .npy file using the local writer and return the path.
            if nargin < 7, isScalar = false; end
            if nargin < 8, version = 1; end
            fname = fullfile(testCase.testDir, name);
            ndi.unittest.util.readNPYTest.localWriteNPY(fname, matlabArray, dtypeName, ...
                endianChar, fortranOrder, isScalar, version);
        end

        function fname = writeRawHeader(testCase, name, descr, shapeStr, fortran, nbytes)
            % Write a .npy file with an arbitrary descr (used to test unsupported dtypes).
            % Emits nbytes zero bytes of "data" after the header.
            fname = fullfile(testCase.testDir, name);
            if fortran, fo = 'True'; else, fo = 'False'; end
            headerStr = ['{''descr'': ''' descr ''', ''fortran_order'': ' fo ...
                ', ''shape'': ' shapeStr ', }'];
            ndi.unittest.util.readNPYTest.emitNPY(fname, headerStr, uint8(zeros(1,nbytes)), 1);
        end

    end

    methods (Static)

        function localWriteNPY(fname, matlabArray, dtypeName, endianChar, fortranOrder, isScalar, version)
            % Independent .npy writer for tests. Maps a MATLAB array to NumPy bytes.

            % map MATLAB/dtype name to a NumPy typecode and fwrite precision
            switch dtypeName
                case 'int8',   tc = 'i1'; prec = 'int8';
                case 'uint8',  tc = 'u1'; prec = 'uint8';
                case 'int16',  tc = 'i2'; prec = 'int16';
                case 'uint16', tc = 'u2'; prec = 'uint16';
                case 'int32',  tc = 'i4'; prec = 'int32';
                case 'uint32', tc = 'u4'; prec = 'uint32';
                case 'int64',  tc = 'i8'; prec = 'int64';
                case 'uint64', tc = 'u8'; prec = 'uint64';
                case 'single', tc = 'f4'; prec = 'single';
                case 'double', tc = 'f8'; prec = 'double';
                case 'bool',   tc = 'b1'; prec = 'uint8';
                otherwise, error('localWriteNPY: unsupported dtypeName %s', dtypeName);
            end

            % bool single-byte types use '|' (not-applicable) byte order
            if strcmp(tc,'b1') || endianChar=='|'
                descrEndian = '|';
                machine = 'l';
            else
                descrEndian = endianChar;
                if endianChar=='<', machine = 'l'; else, machine = 'b'; end
            end
            descr = [descrEndian tc];

            % build the shape tuple string in NumPy (row-major) order
            if isScalar
                shapeStr = '()';
                flat = double(matlabArray);
            else
                npyShape = size(matlabArray);
                % MATLAB stores column-major; NumPy shape equals MATLAB size here
                % because the reader maps NumPy (a,b,c) -> MATLAB a x b x c.
                if isvector(matlabArray)
                    npyShape = numel(matlabArray); % treat any 1xN or Nx1 vector as 1-D length N
                end
                if isscalar(npyShape)
                    shapeStr = ['(' num2str(npyShape) ',)'];
                else
                    shapeStr = ['(' strjoin(arrayfun(@num2str, npyShape, ...
                        'UniformOutput', false), ', ') ')'];
                end

                % flatten in the requested memory order
                if fortranOrder
                    flat = matlabArray(:); % column-major == Fortran order
                else
                    % C order: reverse-permute then flatten
                    nd = ndims(matlabArray);
                    flat = reshape(permute(matlabArray, nd:-1:1), [], 1);
                end
            end

            if strcmp(tc,'b1')
                flat = uint8(flat~=0);
            end

            if fortranOrder, fo = 'True'; else, fo = 'False'; end
            headerStr = ['{''descr'': ''' descr ''', ''fortran_order'': ' fo ...
                ', ''shape'': ' shapeStr ', }'];

            ndi.unittest.util.readNPYTest.emitNPYData(fname, headerStr, flat, prec, machine, version);
        end

        function emitNPYData(fname, headerStr, flat, prec, machine, version)
            % Write magic + version + header + numeric data with the given precision/endianness.
            fid = fopen(fname, 'w', machine);
            c = onCleanup(@() fclose(fid));
            ndi.unittest.util.readNPYTest.writeHeaderBytes(fid, headerStr, version);
            fwrite(fid, flat, prec);
        end

        function emitNPY(fname, headerStr, dataBytes, version)
            % Write magic + version + header + raw uint8 data bytes.
            fid = fopen(fname, 'w', 'l');
            c = onCleanup(@() fclose(fid));
            ndi.unittest.util.readNPYTest.writeHeaderBytes(fid, headerStr, version);
            fwrite(fid, dataBytes, 'uint8');
        end

        function writeHeaderBytes(fid, headerStr, version)
            % Emit the NumPy magic string, version, and padded header dictionary.
            fwrite(fid, [uint8(hex2dec('93')) uint8('NUMPY')], 'uint8');
            fwrite(fid, uint8(version), 'uint8'); % major
            fwrite(fid, uint8(0), 'uint8');       % minor

            % header must be padded with spaces so that
            % (magic+version+lenfield+header) is a multiple of 64, terminated by \n
            if version==1
                lenFieldBytes = 2;
            else
                lenFieldBytes = 4;
            end
            preLen = 6 + 2 + lenFieldBytes; % magic(6)+version(2)+lenfield
            totalUnpadded = preLen + numel(headerStr) + 1; % +1 for trailing \n
            padTo = ceil(totalUnpadded/64)*64;
            nPad = padTo - totalUnpadded;
            fullHeader = [headerStr repmat(' ',1,nPad) char(10)];

            % The header-length field is ALWAYS little-endian in the .npy format,
            % regardless of the array's data byte order. Write it as explicit
            % little-endian bytes so it is independent of how the file was opened.
            hlen = numel(fullHeader);
            if version==1
                lenBytes = uint8([bitand(hlen,255), bitand(bitshift(hlen,-8),255)]);
            else
                lenBytes = uint8([bitand(hlen,255), bitand(bitshift(hlen,-8),255), ...
                    bitand(bitshift(hlen,-16),255), bitand(bitshift(hlen,-24),255)]);
            end
            fwrite(fid, lenBytes, 'uint8');
            fwrite(fid, fullHeader, 'char');
        end

    end
end
