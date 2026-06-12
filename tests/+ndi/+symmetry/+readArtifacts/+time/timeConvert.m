classdef timeConvert < matlab.unittest.TestCase
    % timeConvert (readArtifacts/time) - verify the time_convert symmetry
    % artifacts written by both languages.
    %
    %   Two checks, each skipping (assumption failure -> Incomplete, not a
    %   failure) when the required artifact is absent:
    %
    %     * testMatlabArtifactsReproduce: re-run the scenario and confirm the
    %       current time_convert reproduces the recorded matlabArtifacts outputs
    %       (a cross-run regression guard, independent of Python).
    %     * testMatlabPythonSymmetry: assert MATLAB's out_* values match
    %       Python's pythonArtifacts for the same cases.
    %
    %   ⚠️ AUTHORED WITHOUT A MATLAB RUNTIME — VALIDATE BEFORE RELYING ON IT.
    %   Run the matching makeArtifacts/time test first to populate the artifact.

    properties (Constant)
        RelPath = fullfile('time', 'timeConvert', 'testTimeConvertArtifacts', ...
            'timeConvertCases.json');
    end

    methods (Test)

        function testMatlabArtifactsReproduce(testCase)
            mlFile = ndi.symmetry.readArtifacts.time.timeConvert.artifactFile('matlabArtifacts');
            testCase.assumeTrue(isfile(mlFile), ...
                ['matlabArtifacts time_convert artifact missing (run ' ...
                 'makeArtifacts/time/timeConvert first). Skipping.']);

            recorded = ndi.symmetry.readArtifacts.time.timeConvert.loadCases(mlFile);

            sessionPath = [tempname() '_ndi_sym_time_read'];
            mkdir(sessionPath);
            session = ndi.session.dir('symref', sessionPath);
            fresh = ndi.symmetry.readArtifacts.time.timeConvert.indexCases( ...
                ndi.symmetry.time.scenario.runCases(session));

            testCase.verifyEqual(sort(string(recorded.keys())), sort(string(fresh.keys())), ...
                'Recorded and freshly computed MATLAB cases differ.');
            ndi.symmetry.readArtifacts.time.timeConvert.compareMaps(testCase, recorded, fresh, 'MATLAB recorded vs fresh');
        end

        function testMatlabPythonSymmetry(testCase)
            mlFile = ndi.symmetry.readArtifacts.time.timeConvert.artifactFile('matlabArtifacts');
            pyFile = ndi.symmetry.readArtifacts.time.timeConvert.artifactFile('pythonArtifacts');
            testCase.assumeTrue(isfile(mlFile), 'matlabArtifacts time_convert artifact missing. Skipping.');
            testCase.assumeTrue(isfile(pyFile), 'pythonArtifacts time_convert artifact missing. Skipping.');

            ml = ndi.symmetry.readArtifacts.time.timeConvert.loadCases(mlFile);
            py = ndi.symmetry.readArtifacts.time.timeConvert.loadCases(pyFile);
            testCase.verifyEqual(sort(string(ml.keys())), sort(string(py.keys())), ...
                'MATLAB and Python ran different time_convert cases.');
            ndi.symmetry.readArtifacts.time.timeConvert.compareMaps(testCase, ml, py, 'MATLAB vs Python');
        end
    end

    methods (Static)

        function f = artifactFile(sourceType)
            f = fullfile(tempdir(), 'NDI', 'symmetryTest', sourceType, ...
                ndi.symmetry.readArtifacts.time.timeConvert.RelPath);
        end

        function m = loadCases(file)
            % LOADCASES - return a containers.Map from caseKey -> case struct.
            raw = fileread(file);
            payload = jsondecode(raw);
            cases = payload.cases;
            if isstruct(cases)
                cases = num2cell(cases);   % struct array -> cell of structs
            end
            m = ndi.symmetry.readArtifacts.time.timeConvert.indexCells(cases);
        end

        function m = indexCases(structArray)
            m = ndi.symmetry.readArtifacts.time.timeConvert.indexCells(num2cell(structArray));
        end

        function m = indexCells(cellOfStructs)
            m = containers.Map('KeyType', 'char', 'ValueType', 'any');
            for i = 1:numel(cellOfStructs)
                c = cellOfStructs{i};
                m(ndi.symmetry.readArtifacts.time.timeConvert.caseKey(c)) = c;
            end
        end

        function k = caseKey(c)
            k = strjoin({ ...
                ndi.symmetry.readArtifacts.time.timeConvert.txt(c.in_ref), ...
                ndi.symmetry.readArtifacts.time.timeConvert.txt(c.in_clock), ...
                ndi.symmetry.readArtifacts.time.timeConvert.txt(c.in_epoch), ...
                ndi.symmetry.readArtifacts.time.timeConvert.num(c.in_time), ...
                ndi.symmetry.readArtifacts.time.timeConvert.txt(c.out_ref), ...
                ndi.symmetry.readArtifacts.time.timeConvert.txt(c.out_clock)}, '|');
        end

        function compareMaps(testCase, a, b, label)
            keysA = a.keys();
            for i = 1:numel(keysA)
                key = keysA{i};
                ca = a(key);
                cb = b(key);
                % out_time: both empty/null -> equal; else numeric within tol
                ta = ndi.symmetry.readArtifacts.time.timeConvert.numval(ca.out_time);
                tb = ndi.symmetry.readArtifacts.time.timeConvert.numval(cb.out_time);
                if isnan(ta) || isnan(tb)
                    testCase.verifyEqual(isnan(ta), isnan(tb), ...
                        sprintf('%s out_time null mismatch for %s', label, key));
                else
                    testCase.verifyLessThan(abs(ta - tb), 1e-6, ...
                        sprintf('%s out_time mismatch for %s', label, key));
                end
                testCase.verifyEqual( ...
                    ndi.symmetry.readArtifacts.time.timeConvert.txt(ca.out_epoch), ...
                    ndi.symmetry.readArtifacts.time.timeConvert.txt(cb.out_epoch), ...
                    sprintf('%s out_epoch mismatch for %s', label, key));
                testCase.verifyEqual( ...
                    ndi.symmetry.readArtifacts.time.timeConvert.txt(ca.msg), ...
                    ndi.symmetry.readArtifacts.time.timeConvert.txt(cb.msg), ...
                    sprintf('%s msg mismatch for %s', label, key));
            end
        end

        function s = txt(v)
            % Normalize a text/null field (char, string, or [] from JSON null).
            if isempty(v) || (isstring(v) && all(ismissing(v)))
                s = '<null>';
            else
                s = char(string(v));
            end
        end

        function s = num(v)
            s = sprintf('%.9g', double(v));
        end

        function x = numval(v)
            if isempty(v)
                x = NaN;
            else
                x = double(v);
            end
        end
    end
end
