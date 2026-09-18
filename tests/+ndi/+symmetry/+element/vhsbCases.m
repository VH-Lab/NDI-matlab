classdef vhsbCases
    % vhsbCases - shared VHSB round-trip battery, identical in both languages
    %
    %   Python counterpart: tests/symmetry/element/vhsb_cases.py
    %
    %   WHY THIS BATTERY DOES NOT COMPARE A JSON ARTIFACT
    %   Every other symmetry battery here writes each language's RESULTS to
    %   JSON and compares the two files. VHSB is different: the binary IS the
    %   contract. NDI-matlab and NDI-python both store an element's epoch as
    %   epoch_binary_data.vhsb, and what has to hold is that each language can
    %   read what the other WROTE.
    %
    %   So each side writes its cases as real .vhsb files, and the read side
    %   opens BOTH languages' files and checks them against values it computes
    %   locally from the case list below. Nothing but the binary crosses the
    %   language boundary -- no float is ever serialized to text and parsed
    %   back -- so an exact equality assertion means what it says.
    %
    %   WHY EVERY VALUE IS AN EXACT BINARY FRACTION
    %   The times are quarter-integers, halves and powers of two, each exactly
    %   representable in double in both languages. So == is the right
    %   comparison and a mismatch is a real difference rather than a
    %   formatting artifact. A case built from (0:99)/1000 would not have that
    %   property.
    %
    %   WHAT THE SHRINKING-INTERVAL CASE PINS
    %   shrinkingInterval is the one shape whose X_constantinterval the two
    %   languages disagreed about. This repository's dependency
    %   vhlab-toolbox-matlab tested max(diff(diff(x)))<1e-7 on the SIGNED
    %   second difference, so an all-negative one passed and a series whose
    %   interval shrinks was recorded as constant-interval;
    %   vhlab-toolbox-python already took abs and was right. This battery
    %   deliberately left the shape out while that was true, because an
    %   allow-listed entry would have gone red the moment the bug was fixed --
    %   the wrong reward for fixing it. It is fixed
    %   (VH-Lab/vhlab-toolbox-matlab#145, PR #147; mirrored in
    %   VH-Lab/vhlab-toolbox-python#23), so the case is in, and it is the only
    %   one here that tells the two rules apart: remove the abs on either side
    %   and this case alone goes red.
    %
    %   /!\ AUTHORED WITHOUT A MATLAB RUNTIME -- validate before relying on it.
    %
    %   See also: ndi.symmetry.makeArtifacts.element.vhsbRoundTrip,
    %     ndi.symmetry.readArtifacts.element.vhsbRoundTrip

    properties (Constant)
        IndexFile = 'vhsbIndex.json';
    end

    methods (Static)

        function names = caseNames()
            % CASENAMES - case names in a stable (sorted) order.
            names = sort({ ...
                'largeMagnitude', 'markedPointProcess', 'multiChannel', ...
                'negativeTimes', 'regularInterval', 'shrinkingInterval', ...
                'singleSample', 'threeSamples', 'twoSamples'});
        end

        function [x, y, note] = expected(name)
            % EXPECTED - the (times, data) a case is built from, and why.
            switch name
                case 'regularInterval'
                    x = (0:99)' * 0.25;
                    y = (0:99)';
                    note = ['100 evenly spaced samples: X_constantinterval is 1, ' ...
                        'and reading with +/-Inf bounds must return all 100.'];
                case 'markedPointProcess'
                    x = [0.125; 0.25; 0.375; 0.5; 0.75; 1.0; 1.5];
                    y = [1; 2; 1; 3; 2; 1; 3];
                    note = ['The ensemble case: irregular times that ARE the data, ' ...
                        'with the neuron column index as the mark.'];
                case 'singleSample'
                    x = 0.5;
                    y = 42;
                    note = 'One sample; both header guards leave the flags at 0.';
                case 'twoSamples'
                    x = [0.25; 0.75];
                    y = [7; 9];
                    note = ['Two samples. This raised inside Python''s vhsb_write ' ...
                        'until VH-Lab/vhlab-toolbox-python#21; MATLAB''s ' ...
                        'numel(x)>3 guard never reaches the empty max().'];
                case 'threeSamples'
                    x = [0; 0.25; 0.5];
                    y = [1; 2; 3];
                    note = ['The n=3 boundary: X_increment is computed (numel>2) ' ...
                        'but X_constantinterval is not (numel>3), so the flag ' ...
                        'stays 0 with an increment of 0.25.'];
                case 'shrinkingInterval'
                    x = [0; 1; 1.5; 1.75];
                    y = [1; 2; 3; 4];
                    note = ['Intervals 1, 0.5, 0.25 -- shrinking, so ' ...
                        'X_constantinterval must be 0 even though ' ...
                        'X_increment is a median of 0.5 that describes none ' ...
                        'of them. The reproduction from ' ...
                        'VH-Lab/vhlab-toolbox-matlab#145: this repository''s ' ...
                        'dependency wrote 1 here until PR #147 took abs() of ' ...
                        'the second difference.'];
                case 'negativeTimes'
                    x = [-1.5; -0.5; 0; 0.5; 1.5];
                    y = [1; 2; 3; 4; 5];
                    note = 'Times spanning zero and negative, with widening intervals.';
                case 'multiChannel'
                    x = [0; 0.25; 0.5; 0.75];
                    y = [1 2; 3 4; 5 6; 7 8];
                    note = 'Two data columns per sample, to pin Y_dim and the stride.';
                case 'largeMagnitude'
                    x = [1048576; 1048576.25; 1048576.5; 1048576.75; 1048577];
                    y = [1; 2; 3; 4; 5];
                    note = ['Times near 2^20 with a quarter-unit step: exactly ' ...
                        'representable, but far enough from zero that a float32 ' ...
                        'store would lose the step.'];
                otherwise
                    error('ndi:symmetry:element:vhsbCases:unknownCase', ...
                        'Unknown VHSB case ''%s''.', name);
            end
            x = double(x);
            y = double(y);
        end

        function names = writeCases(destDir)
            % WRITECASES - write every case as <name>.vhsb into DESTDIR, plus the index.
            if isfolder(destDir)
                rmdir(destDir, 's');
            end
            mkdir(destDir);

            names = ndi.symmetry.element.vhsbCases.caseNames();
            for i = 1:numel(names)
                [x, y] = ndi.symmetry.element.vhsbCases.expected(names{i});
                fname = fullfile(destDir, [names{i} '.vhsb']);
                vlt.file.custom_file_formats.vhsb_write(fname, x, y, 'use_filelock', 0);
            end

            payload = struct('schemaVersion', 1, 'language', 'matlab', ...
                'cases', {reshape(names, 1, [])});
            jsonStr = jsonencode(payload, 'PrettyPrint', true);
            fid = fopen(fullfile(destDir, ndi.symmetry.element.vhsbCases.IndexFile), 'w');
            if fid < 0
                error('ndi:symmetry:element:vhsbCases:cannotWriteIndex', ...
                    'Could not write the VHSB index file.');
            end
            fwrite(fid, unicode2native(jsonStr, 'UTF-8'), 'uint8');
            fclose(fid);
        end

        function problems = compare(name, file)
            % COMPARE - check one written case against the local expectation.
            %
            %   Returns a 1xN cellstr of problems; empty means it matched.
            %
            %   vhsb_read returns [DATA, TIMES] -- data first. Unpacked here
            %   once so no caller has to remember the order.
            problems = {};
            [wantX, wantY] = ndi.symmetry.element.vhsbCases.expected(name);

            header = vlt.file.custom_file_formats.vhsb_readheader(file);
            [gotY, gotX] = vlt.file.custom_file_formats.vhsb_read(file, -Inf, Inf);
            gotX = double(gotX(:));
            gotY = double(gotY);
            if size(gotY, 1) ~= numel(gotX) && numel(gotY) == numel(wantY)
                gotY = reshape(gotY, size(wantY));
            end

            if numel(gotX) ~= numel(wantX)
                problems{end+1} = sprintf('times length %d ~= %d', numel(gotX), numel(wantX));
            elseif ~isequal(gotX, wantX(:))
                problems{end+1} = sprintf('times differ: %s ~= %s', ...
                    mat2str(gotX(:)', 17), mat2str(wantX(:)', 17));
            end

            if numel(gotY) ~= numel(wantY)
                problems{end+1} = sprintf('data length %d ~= %d', numel(gotY), numel(wantY));
            elseif ~isequal(reshape(gotY, size(wantY)), wantY)
                problems{end+1} = sprintf('data differ: %s ~= %s', ...
                    mat2str(gotY(:)', 17), mat2str(wantY(:)', 17));
            end

            if double(header.num_samples) ~= size(wantX, 1)
                problems{end+1} = sprintf('num_samples %d ~= %d', ...
                    double(header.num_samples), size(wantX, 1));
            end

            wantFlag = ndi.symmetry.element.vhsbCases.expectedConstantInterval(wantX);
            if double(header.X_constantinterval) ~= wantFlag
                problems{end+1} = sprintf('X_constantinterval %d ~= %d', ...
                    double(header.X_constantinterval), wantFlag);
            end
        end

        function flag = expectedConstantInterval(x)
            % EXPECTEDCONSTANTINTERVAL - the flag vhsb_write should have written.
            %
            %   MATLAB's rule: computed only when numel(x) > 3, else 0. The
            %   comparison takes ABS of the second difference, which is what
            %   both toolboxes do now -- see VH-Lab/vhlab-toolbox-matlab#145.
            %   Every case here but shrinkingInterval gives the same answer
            %   under the old signed rule; that one is what separates them.
            %
            %   The flag is compared as well as the values because it decides
            %   how a WINDOWED read selects samples, and the two languages
            %   wrote different flags for the same input until
            %   VH-Lab/vhlab-toolbox-python#21 and #145.
            x = double(x(:));
            if numel(x) <= 3
                flag = 0;
            else
                flag = double(max(abs(diff(diff(x)))) < 1e-7);
            end
        end

        function payload = loadIndex(file)
            % LOADINDEX - read an index JSON written by either language.
            fid = fopen(file, 'r');
            if fid < 0
                error('ndi:symmetry:element:vhsbCases:cannotReadIndex', ...
                    'Could not read %s.', file);
            end
            cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
            bytes = fread(fid, inf, '*uint8');
            clear cleaner;
            payload = jsondecode(native2unicode(reshape(bytes, 1, []), 'UTF-8'));
        end

    end % methods (Static)
end % classdef
