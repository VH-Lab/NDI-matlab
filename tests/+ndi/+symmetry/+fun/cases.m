classdef cases
    % cases - shared, self-describing ndi.fun symmetry battery
    %
    %   MATLAB counterpart of the Python tests/symmetry battery for
    %   ndi.fun.file.pathSafeName / ndi.fun.file.elementDirectoryName and
    %   ndi.fun.stimulus.whatVaries / ndi.fun.stimulus.whatIsConstant.
    %
    %   Both language ports run the SAME case list -- each case identified by an
    %   ASCII case NAME, and each pathSafeName input specified as a vector of
    %   Unicode scalar values so neither language has to trust a source-file
    %   encoding -- through their own real implementation, then write the
    %   recorded outputs to
    %
    %     <tempdir>/NDI/symmetryTest/<matlabArtifacts|pythonArtifacts>/fun/
    %              <className>/<testName>/<file>.json
    %
    %   The on-disk schema is documented in
    %   tests/+ndi/+symmetry/FUN_CASES_SCHEMA.md. READ THAT FILE before changing
    %   anything here: the integrator reconciles the two languages against it.
    %
    %   This mirrors ndi.symmetry.time.scenario, which plays the same role for
    %   the syncgraph/time_convert battery.
    %
    %   WHY VALUES ARE COMPARED AS RENDERED STRINGS
    %   whatVaries returns MATLAB-native values (numeric row vectors, cell
    %   arrays, char). Comparing those against Python lists/str across a JSON
    %   round trip is where symmetry tests usually rot. Instead each side renders
    %   every value with the SAME small, language-neutral grammar (see RENDER)
    %   and the two sides compare plain strings. The grammar deliberately does
    %   NOT distinguish a MATLAB cell array from a MATLAB struct array from a
    %   numeric vector -- Python has one list type for all three, so a grammar
    %   that told them apart could never match. The MATLAB-side input shape is
    %   recorded separately in each case's SHAPE field.
    %
    %   /!\ AUTHORED WITHOUT A MATLAB RUNTIME -- every expected value in this
    %   file is derived by reading the implementation source branch by branch,
    %   not by executing MATLAB. VALIDATE BEFORE RELYING ON IT.
    %
    %   See also: ndi.symmetry.makeArtifacts.fun.pathSafeName,
    %     ndi.symmetry.makeArtifacts.fun.whatVaries,
    %     ndi.symmetry.readArtifacts.fun.pathSafeName,
    %     ndi.symmetry.readArtifacts.fun.whatVaries,
    %     ndi.symmetry.time.scenario

    methods (Static)

        % ----------------------------------------------------------------
        % canonical value rendering
        % ----------------------------------------------------------------

        function s = render(v)
            % RENDER - canonical, language-neutral string form of a value.
            %
            %   number scalar   -> sprintf('%.12g'), or NaN / Inf / -Inf
            %   logical scalar  -> 'true' / 'false'
            %   text            -> 'the text' (wrapped in single quotes)
            %   SEQUENCE        -> '[e1, e2]' -- a cell array, a struct array,
            %                      a string array, or a numeric/logical array
            %                      that is not scalar. Empty -> '[]'.
            %   MAPPING         -> '{key: value, ...}' -- a scalar struct, with
            %                      KEYS SORTED so that field order cannot make
            %                      the two languages disagree.
            %   anything else   -> '<classname>'
            %
            %   Only vectors are used by this battery. A 2-D numeric matrix
            %   would render in MATLAB's column-major order and Python's
            %   row-major order -- do not put one in a case.
            if ischar(v)
                if isempty(v)
                    s = '''''';
                elseif size(v,1) > 1
                    s = '<charmatrix>';
                else
                    s = ['''' v ''''];
                end
            elseif isstring(v)
                if isscalar(v)
                    if ismissing(v)
                        s = '<missing>';
                    else
                        s = ['''' char(v) ''''];
                    end
                else
                    s = ndi.symmetry.fun.cases.renderSequence(v);
                end
            elseif iscell(v)
                s = ndi.symmetry.fun.cases.renderSequence(v);
            elseif isstruct(v)
                if numel(v) == 1
                    fn = sort(fieldnames(v));
                    parts = cell(1, numel(fn));
                    for i = 1:numel(fn)
                        parts{i} = [fn{i} ': ' ndi.symmetry.fun.cases.render(v.(fn{i}))];
                    end
                    s = ['{' ndi.symmetry.fun.cases.joinParts(parts, ', ') '}'];
                else
                    s = ndi.symmetry.fun.cases.renderSequence(v);
                end
            elseif islogical(v)
                if isscalar(v)
                    if v
                        s = 'true';
                    else
                        s = 'false';
                    end
                else
                    s = ndi.symmetry.fun.cases.renderSequence(v);
                end
            elseif isnumeric(v)
                if isscalar(v)
                    s = ndi.symmetry.fun.cases.numToken(v);
                else
                    s = ndi.symmetry.fun.cases.renderSequence(v);
                end
            else
                s = ['<' class(v) '>'];
            end
        end % render

        function s = renderSequence(v)
            % RENDERSEQUENCE - render V as a sequence, whatever container it is.
            %
            %   Use this for any value that is semantically a LIST even when
            %   MATLAB happens to hand it back as a scalar -- notably
            %   whatVaries' 'values' field, which is the list of distinct values
            %   a parameter takes and collapses to a bare scalar when there is
            %   only one of them. Python would return a one-element list there,
            %   so rendering the MATLAB scalar as '5' instead of '[5]' would be
            %   a spurious mismatch.
            n = numel(v);
            parts = cell(1, n);
            for i = 1:n
                if iscell(v)
                    parts{i} = ndi.symmetry.fun.cases.render(v{i});
                else
                    parts{i} = ndi.symmetry.fun.cases.render(v(i));
                end
            end
            s = ['[' ndi.symmetry.fun.cases.joinParts(parts, ', ') ']'];
        end % renderSequence

        function t = numToken(x)
            % NUMTOKEN - canonical decimal token for one real number.
            %
            %   The non-finite tokens are spelled out because MATLAB's %g gives
            %   'NaN'/'Inf' while Python's gives 'nan'/'inf'; the schema fixes
            %   the MATLAB spelling and the Python side must match it.
            x = double(x);
            if isnan(x)
                t = 'NaN';
            elseif isinf(x)
                if x > 0
                    t = 'Inf';
                else
                    t = '-Inf';
                end
            else
                t = sprintf('%.12g', x);
            end
        end % numToken

        function s = joinParts(parts, sep)
            % JOINPARTS - strjoin that is defined for an empty cell.
            if isempty(parts)
                s = '';
            else
                s = strjoin(parts, sep);
            end
        end % joinParts

        % ----------------------------------------------------------------
        % unicode helpers
        %
        % MATLAB char arrays hold UTF-16 code units, so a character above
        % U+FFFF occupies TWO chars and pathSafeName maps it to TWO '-'.
        % Python strings hold Unicode scalar values, so a naive port emits ONE
        % '-'. That divergence is why the astral cases are in this battery --
        % these helpers let both sides start from the same neutral codepoint
        % vector and record both counts.
        % ----------------------------------------------------------------

        function cp = codepoints(s)
            % CODEPOINTS - Unicode scalar values of a MATLAB char row vector.
            %
            %   Combines surrogate pairs, so numel(CODEPOINTS(S)) is what
            %   Python's len() reports while numel(char(S)) is MATLAB's UTF-16
            %   code-unit count.
            u = double(char(s));
            cp = zeros(1, numel(u));
            n = 0;
            i = 1;
            while i <= numel(u)
                c = u(i);
                isHigh = (c >= 55296) && (c <= 56319);
                hasLow = (i < numel(u)) && (u(i+1) >= 56320) && (u(i+1) <= 57343);
                n = n + 1;
                if isHigh && hasLow
                    cp(n) = 65536 + (c - 55296) * 1024 + (u(i+1) - 56320);
                    i = i + 2;
                else
                    cp(n) = c;
                    i = i + 1;
                end
            end
            cp = cp(1:n);
        end % codepoints

        function s = fromCodepoints(cp)
            % FROMCODEPOINTS - build a MATLAB char row vector from Unicode
            % scalar values, by way of UTF-8. Going through native2unicode
            % avoids having to hand MATLAB a bare surrogate code unit.
            bytes = zeros(1, 0);
            for i = 1:numel(cp)
                c = double(cp(i));
                if c < 128
                    b = c;
                elseif c < 2048
                    b = [192 + floor(c/64), 128 + mod(c,64)];
                elseif c < 65536
                    b = [224 + floor(c/4096), 128 + mod(floor(c/64),64), 128 + mod(c,64)];
                else
                    b = [240 + floor(c/262144), 128 + mod(floor(c/4096),64), ...
                        128 + mod(floor(c/64),64), 128 + mod(c,64)];
                end
                bytes = [bytes b]; %#ok<AGROW>
            end
            if isempty(bytes)
                s = '';
            else
                s = native2unicode(uint8(bytes), 'UTF-8');
            end
            s = reshape(char(s), 1, []);
        end % fromCodepoints

        % ----------------------------------------------------------------
        % pathSafeName battery
        % ----------------------------------------------------------------

        function defs = pathSafeNameDefs()
            % PATHSAFENAMEDEFS - the pathSafeName / elementDirectoryName cases.
            %
            %   Each case carries CP, the input as Unicode scalar values (the
            %   authoritative, encoding-independent input spec that Python uses
            %   too), and EXPECTEDNAME, the MATLAB-reference output derived by
            %   reading src/ndi/+ndi/+fun/+file/pathSafeName.m branch by branch.
            %   EXPECTEDUTF16UNITS is numel() of the MATLAB char array.
            txt = @(c) ndi.symmetry.fun.cases.codepoints(c);

            defs = struct([]);
            k = 0;

            % --- degenerate / passthrough ---------------------------------
            k = k + 1;
            defs(k).name = 'emptyString';
            defs(k).cp = zeros(1,0);
            defs(k).expectedStatus = 'ok';
            defs(k).expectedName = 'x';
            defs(k).expectedUtf16Units = 0;
            defs(k).note = 'an empty result becomes ''x''';

            k = k + 1;
            defs(k).name = 'portablePassthrough';
            defs(k).cp = txt('ctx_1-a.dat');
            defs(k).expectedStatus = 'ok';
            defs(k).expectedName = 'ctx_1-a.dat';
            defs(k).expectedUtf16Units = 11;
            defs(k).note = 'already inside [A-Za-z0-9._-]';

            % --- the element-string bug this sanitizer exists for ----------
            k = k + 1;
            defs(k).name = 'elementBarSeparator';
            defs(k).cp = txt('probe | 1');
            defs(k).expectedStatus = 'ok';
            defs(k).expectedName = 'probe_-_1';
            defs(k).expectedUtf16Units = 9;
            defs(k).note = 'ndi.element/elementstring form; ''|'' is illegal on Windows';

            k = k + 1;
            defs(k).name = 'elementBarSeparatorUnderscored';
            defs(k).cp = txt('ctx_|_1');
            defs(k).expectedStatus = 'ok';
            defs(k).expectedName = 'ctx_-_1';
            defs(k).expectedUtf16Units = 7;
            defs(k).note = 'the pathSafeName docstring example';

            % --- whitespace and control characters -> '_' ------------------
            k = k + 1;
            defs(k).name = 'singleSpace';
            defs(k).cp = txt(' ');
            defs(k).expectedStatus = 'ok';
            defs(k).expectedName = '_';
            defs(k).expectedUtf16Units = 1;
            defs(k).note = 'space maps to ''_'', so the result is not empty';

            k = k + 1;
            defs(k).name = 'tabAndNewline';
            defs(k).cp = [97 9 98 10 99];
            defs(k).expectedStatus = 'ok';
            defs(k).expectedName = 'a_b_c';
            defs(k).expectedUtf16Units = 5;
            defs(k).note = 'control characters below 32 map to ''_''';

            k = k + 1;
            defs(k).name = 'deleteControlChar';
            defs(k).cp = [97 127 98];
            defs(k).expectedStatus = 'ok';
            defs(k).expectedName = 'a_b';
            defs(k).expectedUtf16Units = 3;
            defs(k).note = 'DEL (127) is the one control character above 31';

            % --- everything else outside the portable set -> '-' -----------
            k = k + 1;
            defs(k).name = 'windowsForbiddenChars';
            defs(k).cp = txt('a<b>c:d"e/f\g|h?i*j');
            defs(k).expectedStatus = 'ok';
            defs(k).expectedName = 'a-b-c-d-e-f-g-h-i-j';
            defs(k).expectedUtf16Units = 19;
            defs(k).note = 'the nine characters Windows forbids outright';

            % --- trailing dots ---------------------------------------------
            k = k + 1;
            defs(k).name = 'trailingDots';
            defs(k).cp = txt('report...');
            defs(k).expectedStatus = 'ok';
            defs(k).expectedName = 'report';
            defs(k).expectedUtf16Units = 9;
            defs(k).note = 'Windows silently strips trailing dots';

            k = k + 1;
            defs(k).name = 'allDots';
            defs(k).cp = txt('...');
            defs(k).expectedStatus = 'ok';
            defs(k).expectedName = 'x';
            defs(k).expectedUtf16Units = 3;
            defs(k).note = 'the dot strip runs BEFORE the empty check';

            k = k + 1;
            defs(k).name = 'leadingDot';
            defs(k).cp = txt('.hidden');
            defs(k).expectedStatus = 'ok';
            defs(k).expectedName = '.hidden';
            defs(k).expectedUtf16Units = 7;
            defs(k).note = 'base name before the first dot is empty, so no reserved prefix';

            % --- Windows reserved device names -----------------------------
            k = k + 1;
            defs(k).name = 'reservedCON';
            defs(k).cp = txt('CON');
            defs(k).expectedStatus = 'ok';
            defs(k).expectedName = '_CON';
            defs(k).expectedUtf16Units = 3;
            defs(k).note = '';

            k = k + 1;
            defs(k).name = 'reservedLowerCon';
            defs(k).cp = txt('con');
            defs(k).expectedStatus = 'ok';
            defs(k).expectedName = '_con';
            defs(k).expectedUtf16Units = 3;
            defs(k).note = 'reserved names are matched case-insensitively';

            k = k + 1;
            defs(k).name = 'reservedCOM1';
            defs(k).cp = txt('COM1');
            defs(k).expectedStatus = 'ok';
            defs(k).expectedName = '_COM1';
            defs(k).expectedUtf16Units = 4;
            defs(k).note = '';

            k = k + 1;
            defs(k).name = 'reservedLPT9';
            defs(k).cp = txt('LPT9');
            defs(k).expectedStatus = 'ok';
            defs(k).expectedName = '_LPT9';
            defs(k).expectedUtf16Units = 4;
            defs(k).note = 'top of the LPT range';

            k = k + 1;
            defs(k).name = 'reservedWithExtension';
            defs(k).cp = txt('CON.txt');
            defs(k).expectedStatus = 'ok';
            defs(k).expectedName = '_CON.txt';
            defs(k).expectedUtf16Units = 7;
            defs(k).note = 'reserved with or without an extension';

            k = k + 1;
            defs(k).name = 'reservedTrailingDot';
            defs(k).cp = txt('com1.');
            defs(k).expectedStatus = 'ok';
            defs(k).expectedName = '_com1';
            defs(k).expectedUtf16Units = 5;
            defs(k).note = 'the dot strip runs first, so this becomes reserved';

            k = k + 1;
            defs(k).name = 'notReservedCOM0';
            defs(k).cp = txt('COM0');
            defs(k).expectedStatus = 'ok';
            defs(k).expectedName = 'COM0';
            defs(k).expectedUtf16Units = 4;
            defs(k).note = 'COM0 and LPT0 are NOT reserved';

            % --- unicode ---------------------------------------------------
            k = k + 1;
            defs(k).name = 'bmpUnicodeAccent';
            defs(k).cp = [97 233 98];                 % a U+00E9 b
            defs(k).expectedStatus = 'ok';
            defs(k).expectedName = 'a-b';
            defs(k).expectedUtf16Units = 3;
            defs(k).note = 'inside the BMP: one code unit, one ''-''';

            k = k + 1;
            defs(k).name = 'astralUnicodeEmoji';
            defs(k).cp = [97 128512 98];              % a U+1F600 b
            defs(k).expectedStatus = 'ok';
            defs(k).expectedName = 'a--b';
            defs(k).expectedUtf16Units = 4;
            defs(k).note = 'above U+FFFF: a surrogate PAIR in MATLAB, so TWO ''-''';

            k = k + 1;
            defs(k).name = 'astralOnlyEmoji';
            defs(k).cp = 127881;                      % U+1F389
            defs(k).expectedStatus = 'ok';
            defs(k).expectedName = '--';
            defs(k).expectedUtf16Units = 2;
            defs(k).note = 'a lone astral character does not sanitize to empty in MATLAB';

            k = k + 1;
            defs(k).name = 'astralThenTrailingDot';
            defs(k).cp = [128512 46];                 % U+1F600 '.'
            defs(k).expectedStatus = 'ok';
            defs(k).expectedName = '--';
            defs(k).expectedUtf16Units = 3;
            defs(k).note = 'astral expansion, then the trailing-dot strip';
        end % pathSafeNameDefs

        function results = runPathSafeNameCases()
            % RUNPATHSAFENAMECASES - run every pathSafeName case through the real
            % ndi.fun.file.pathSafeName / elementDirectoryName.
            %
            %   Returns a 1xN CELL of case structs (a cell, not a struct array,
            %   so jsonencode always emits a JSON array even for a single case).
            %   Every case is wrapped in try/catch: a case that errors is
            %   RECORDED as status 'error' rather than aborting the battery.
            defs = ndi.symmetry.fun.cases.pathSafeNameDefs();
            results = cell(1, numel(defs));
            for i = 1:numel(defs)
                d = defs(i);
                inputStr = ndi.symmetry.fun.cases.fromCodepoints(d.cp);

                c = struct();
                c.name = d.name;
                c.status = 'ok';
                c.identifier = '';
                c.message = '';
                c.note = d.note;
                c.input = inputStr;
                c.inputCodepoints = reshape(double(d.cp), 1, []);
                c.inputUtf16Units = numel(inputStr);
                c.inputCodepointCount = numel(d.cp);
                c.pathSafeName = '';
                c.elementDirName = '';
                c.elementLegacyDirName = '';
                c.elementLegacyDirNameCodepoints = zeros(1,0);

                try
                    psn = ndi.fun.file.pathSafeName(inputStr);
                    [dirName, legacyDirName] = ndi.fun.file.elementDirectoryName(inputStr);
                    c.pathSafeName = reshape(char(psn), 1, []);
                    c.elementDirName = reshape(char(dirName), 1, []);
                    c.elementLegacyDirName = reshape(char(legacyDirName), 1, []);
                    c.elementLegacyDirNameCodepoints = ...
                        ndi.symmetry.fun.cases.codepoints(legacyDirName);
                catch ME
                    c.status = 'error';
                    c.identifier = ndi.symmetry.fun.cases.errorId(ME);
                    c.message = ME.message;
                end

                results{i} = c;
            end
        end % runPathSafeNameCases

        function verifyPathSafeNameExpected(testCase, results)
            % VERIFYPATHSAFENAMEEXPECTED - assert the recorded RESULTS match the
            % MATLAB reference expectations in pathSafeNameDefs.
            %
            %   MATLAB is the reference side for pathSafeName: a regression fails
            %   here loudly, exactly as ndi.symmetry.time.scenario.verifyExpected
            %   does for time_convert.
            defs = ndi.symmetry.fun.cases.pathSafeNameDefs();
            testCase.verifyEqual(numel(results), numel(defs), ...
                'Number of pathSafeName results does not match the case list.');
            n = min(numel(results), numel(defs));
            for i = 1:n
                d = defs(i);
                c = results{i};
                testCase.verifyEqual(c.name, d.name, ...
                    sprintf('pathSafeName case %d name mismatch.', i));
                testCase.verifyEqual(c.status, d.expectedStatus, ...
                    sprintf('pathSafeName case ''%s'' status mismatch (%s).', d.name, c.message));
                if ~strcmp(d.expectedStatus, 'ok') || ~strcmp(c.status, 'ok')
                    continue;
                end
                testCase.verifyEqual(c.pathSafeName, d.expectedName, ...
                    sprintf('pathSafeName case ''%s'': expected ''%s''.', d.name, d.expectedName));
                % elementDirectoryName maps space->'_' before calling
                % pathSafeName, and pathSafeName maps space->'_' too, so the two
                % must agree on every input.
                testCase.verifyEqual(c.elementDirName, c.pathSafeName, ...
                    sprintf('pathSafeName case ''%s'': elementDirectoryName disagrees with pathSafeName.', d.name));
                testCase.verifyEqual(c.inputUtf16Units, d.expectedUtf16Units, ...
                    sprintf('pathSafeName case ''%s'': UTF-16 code-unit count mismatch.', d.name));
                testCase.verifyEqual(c.inputCodepointCount, numel(d.cp), ...
                    sprintf('pathSafeName case ''%s'': codepoint count mismatch.', d.name));
                % the legacy name is the input with U+0020 -> U+005F, nothing else
                expectedLegacy = reshape(double(d.cp), 1, []);
                expectedLegacy(expectedLegacy == 32) = 95;
                testCase.verifyEqual(ndi.symmetry.fun.cases.asRow(c.elementLegacyDirNameCodepoints), ...
                    expectedLegacy, ...
                    sprintf('pathSafeName case ''%s'': legacy directory name mismatch.', d.name));
            end
        end % verifyPathSafeNameExpected

        function s = pathSafeSignature(c)
            % PATHSAFESIGNATURE - the comparable content of one pathSafeName case.
            %
            %   IDENTIFIER and MESSAGE are deliberately NOT part of the
            %   signature: MATLAB error identifiers ('MATLAB:...') and Python
            %   exception names never match, and pinning them would turn the
            %   symmetry test into a translation table instead of a behaviour
            %   check. STATUS is compared; the text is recorded for humans.
            s = strjoin({ ...
                ['status=' ndi.symmetry.fun.cases.asChar(c.status)], ...
                ['pathSafeName=' ndi.symmetry.fun.cases.asChar(c.pathSafeName)], ...
                ['elementDirName=' ndi.symmetry.fun.cases.asChar(c.elementDirName)], ...
                ['legacyCodepoints=' ndi.symmetry.fun.cases.renderSequence( ...
                    ndi.symmetry.fun.cases.asRow(c.elementLegacyDirNameCodepoints))], ...
                ['utf16Units=' ndi.symmetry.fun.cases.numToken(c.inputUtf16Units)], ...
                ['codepointCount=' ndi.symmetry.fun.cases.numToken(c.inputCodepointCount)]}, '|');
        end % pathSafeSignature

        % ----------------------------------------------------------------
        % whatVaries battery
        % ----------------------------------------------------------------

        function s = threeAngleStimuli()
            % THREEANGLESTIMULI - the fixture shared by three of the MATLAB unit
            % test methods: a stimulus_presentation.stimuli-shaped struct array
            % where angle varies and contrast / sFrequency are constant.
            s(1).parameters = struct('angle',0,  'contrast',1,'sFrequency',0.5);
            s(2).parameters = struct('angle',90, 'contrast',1,'sFrequency',0.5);
            s(3).parameters = struct('angle',180,'contrast',1,'sFrequency',0.5);
        end % threeAngleStimuli

        function [stimuli, excludeBlank] = whatVariesInput(name)
            % WHATVARIESINPUT - build the native input for one whatVaries case.
            %
            %   The case NAMEs mirror the method names of
            %   tests/+ndi/+unittest/+fun/+stimulus/whatVariesTest.m; see the
            %   mapping table in FUN_CASES_SCHEMA.md.
            excludeBlank = true;

            switch name
                case 'stimuliStructArray'
                    stimuli = ndi.symmetry.fun.cases.threeAngleStimuli();

                case 'valuesSortedAndUnique'
                    s(1).parameters = struct('angle',180,'contrast',1);
                    s(2).parameters = struct('angle',0,  'contrast',1);
                    s(3).parameters = struct('angle',90, 'contrast',1);
                    s(4).parameters = struct('angle',0,  'contrast',1);
                    stimuli = s;

                case 'cellOfParameterStructs'
                    stimuli = { struct('angle',0,'contrast',1), ...
                        struct('angle',90,'contrast',1) };

                case 'structArrayOfParameterStructs'
                    p(1) = struct('angle',0,'contrast',1);
                    p(2) = struct('angle',90,'contrast',1);
                    stimuli = p;

                case 'documentPropertiesShapedStruct'
                    dp.stimulus_presentation.stimuli = ...
                        ndi.symmetry.fun.cases.threeAngleStimuli();
                    stimuli = dp;

                case 'poolingAcrossPresentations'
                    s2(1).parameters = struct('angle',270,'contrast',1,'sFrequency',0.5);
                    dp(1).stimulus_presentation.stimuli = ...
                        ndi.symmetry.fun.cases.threeAngleStimuli();
                    dp(2).stimulus_presentation.stimuli = s2;
                    stimuli = dp;

                case 'fieldPresentInSomeStimuli'
                    stimuli = { struct('angle',0,'contrast',1), ...
                        struct('angle',0,'contrast',1,'phase',5) };

                case 'blankStimuliExcludedByDefault'
                    stimuli = { struct('angle',0, 'contrast',1), ...
                        struct('angle',90,'contrast',1), ...
                        struct('angle',0, 'contrast',1,'isblank',1) };

                case 'blankStimuliIncludedWhenOptionFalse'
                    stimuli = { struct('angle',0, 'contrast',1), ...
                        struct('angle',90,'contrast',1), ...
                        struct('angle',0, 'contrast',1,'isblank',1) };
                    excludeBlank = false;

                case 'cellValuedConstantParameter'
                    stimuli = { struct('color',{{'r','g','b'}},'angle',0), ...
                        struct('color',{{'r','g','b'}},'angle',90) };

                case 'vectorValuedVaryingParameter'
                    stimuli = { struct('rect',[0 0 100 100]), ...
                        struct('rect',[0 0 200 200]) };

                case 'allBlankStimuli'
                    stimuli = { struct('angle',0, 'isblank',1), ...
                        struct('angle',90,'isblank',1) };

                case 'nonNumericValues'
                    p(1) = struct('shape','circle','size',5);
                    p(2) = struct('shape','square','size',5);
                    stimuli = p;

                case 'allConstantSingleStimulus'
                    stimuli = struct('angle',0,'contrast',1);

                case 'emptyInput'
                    stimuli = {};

                case 'allNaNParameter'
                    stimuli = { struct('angle',NaN,'contrast',1), ...
                        struct('angle',NaN,'contrast',1) };

                case 'badInputNumeric'
                    stimuli = 42;

                case 'badCellEntry'
                    stimuli = {42};

                otherwise
                    error('ndi:symmetry:fun:cases:unknownCase', ...
                        'Unknown whatVaries case ''%s''.', name);
            end
        end % whatVariesInput

        function defs = whatVariesDefs()
            % WHATVARIESDEFS - the whatVaries cases and their MATLAB reference
            % expectations.
            %
            %   EXPECTEDSTATUS is 'ok' or 'error'. DIVERGENCEEXPECTED marks a
            %   case where MATLAB main and the Python port are believed to
            %   disagree today (see knownDivergences); such a case is neither
            %   verified against the EXPECTED* fields here nor failed in
            %   readArtifacts -- it is reported.
            defs = struct([]);
            k = 0;

            k = k + 1;
            defs(k).name = 'stimuliStructArray';
            defs(k).shape = 'stimuliStructArray';
            defs(k).expectedStatus = 'ok';
            defs(k).expectedVaries = {'angle'};
            defs(k).expectedVariesValues = {'[0, 90, 180]'};
            defs(k).expectedConstant = {'contrast','sFrequency'};
            defs(k).expectedConstantValues = {'1','0.5'};
            defs(k).divergenceExpected = false;
            defs(k).mirrors = 'testStimuliStructArray + testWhatIsConstantMatchesSecondOutput';

            k = k + 1;
            defs(k).name = 'valuesSortedAndUnique';
            defs(k).shape = 'stimuliStructArray';
            defs(k).expectedStatus = 'ok';
            defs(k).expectedVaries = {'angle'};
            defs(k).expectedVariesValues = {'[0, 90, 180]'};
            defs(k).expectedConstant = {'contrast'};
            defs(k).expectedConstantValues = {'1'};
            defs(k).divergenceExpected = false;
            defs(k).mirrors = 'testValuesSortedAndUnique';

            k = k + 1;
            defs(k).name = 'cellOfParameterStructs';
            defs(k).shape = 'cellOfParameterStructs';
            defs(k).expectedStatus = 'ok';
            defs(k).expectedVaries = {'angle'};
            defs(k).expectedVariesValues = {'[0, 90]'};
            defs(k).expectedConstant = {'contrast'};
            defs(k).expectedConstantValues = {'1'};
            defs(k).divergenceExpected = false;
            defs(k).mirrors = 'testCellOfParameterStructs';

            k = k + 1;
            defs(k).name = 'structArrayOfParameterStructs';
            defs(k).shape = 'structArrayOfParameterStructs';
            defs(k).expectedStatus = 'ok';
            defs(k).expectedVaries = {'angle'};
            defs(k).expectedVariesValues = {'[0, 90]'};
            defs(k).expectedConstant = {'contrast'};
            defs(k).expectedConstantValues = {'1'};
            defs(k).divergenceExpected = false;
            defs(k).mirrors = 'testStructArrayOfParameterStructs';

            k = k + 1;
            defs(k).name = 'documentPropertiesShapedStruct';
            defs(k).shape = 'documentProperties';
            defs(k).expectedStatus = 'ok';
            defs(k).expectedVaries = {'angle'};
            defs(k).expectedVariesValues = {'[0, 90, 180]'};
            defs(k).expectedConstant = {'contrast','sFrequency'};
            defs(k).expectedConstantValues = {'1','0.5'};
            defs(k).divergenceExpected = false;
            defs(k).mirrors = 'testDocumentPropertiesShapedStruct';

            k = k + 1;
            defs(k).name = 'poolingAcrossPresentations';
            defs(k).shape = 'documentPropertiesArray';
            defs(k).expectedStatus = 'ok';
            defs(k).expectedVaries = {'angle'};
            defs(k).expectedVariesValues = {'[0, 90, 180, 270]'};
            defs(k).expectedConstant = {'contrast','sFrequency'};
            defs(k).expectedConstantValues = {'1','0.5'};
            defs(k).divergenceExpected = false;
            defs(k).mirrors = 'testPoolingAcrossPresentations';

            k = k + 1;
            defs(k).name = 'fieldPresentInSomeStimuli';
            defs(k).shape = 'cellOfParameterStructs';
            defs(k).expectedStatus = 'ok';
            defs(k).expectedVaries = {'phase'};
            defs(k).expectedVariesValues = {'[5]'};
            defs(k).expectedConstant = {'angle','contrast'};
            defs(k).expectedConstantValues = {'0','1'};
            defs(k).divergenceExpected = false;
            defs(k).mirrors = 'testFieldPresentInSomeStimuli';

            k = k + 1;
            defs(k).name = 'blankStimuliExcludedByDefault';
            defs(k).shape = 'cellOfParameterStructs';
            defs(k).expectedStatus = 'ok';
            defs(k).expectedVaries = {'angle'};
            defs(k).expectedVariesValues = {'[0, 90]'};
            defs(k).expectedConstant = {'contrast'};
            defs(k).expectedConstantValues = {'1'};
            defs(k).divergenceExpected = false;
            defs(k).mirrors = 'testBlankStimuliExcludedByDefault';

            k = k + 1;
            defs(k).name = 'blankStimuliIncludedWhenOptionFalse';
            defs(k).shape = 'cellOfParameterStructs';
            defs(k).expectedStatus = 'ok';
            defs(k).expectedVaries = {'angle','isblank'};
            defs(k).expectedVariesValues = {'[0, 90]','[1]'};
            defs(k).expectedConstant = {'contrast'};
            defs(k).expectedConstantValues = {'1'};
            defs(k).divergenceExpected = false;
            defs(k).mirrors = 'testBlankStimuliIncludedWhenOptionFalse';

            k = k + 1;
            defs(k).name = 'cellValuedConstantParameter';
            defs(k).shape = 'cellOfParameterStructs';
            defs(k).expectedStatus = 'ok';
            defs(k).expectedVaries = {'angle'};
            defs(k).expectedVariesValues = {'[0, 90]'};
            defs(k).expectedConstant = {'color'};
            defs(k).expectedConstantValues = {'[''r'', ''g'', ''b'']'};
            defs(k).divergenceExpected = true;
            defs(k).mirrors = 'testCellValuedConstantParameter';

            k = k + 1;
            defs(k).name = 'vectorValuedVaryingParameter';
            defs(k).shape = 'cellOfParameterStructs';
            defs(k).expectedStatus = 'ok';
            defs(k).expectedVaries = {'rect'};
            defs(k).expectedVariesValues = {'[[0, 0, 100, 100], [0, 0, 200, 200]]'};
            defs(k).expectedConstant = {};
            defs(k).expectedConstantValues = {};
            defs(k).divergenceExpected = false;
            defs(k).mirrors = 'testVectorValuedVaryingParameter';

            k = k + 1;
            defs(k).name = 'allBlankStimuli';
            defs(k).shape = 'cellOfParameterStructs';
            defs(k).expectedStatus = 'ok';
            defs(k).expectedVaries = {};
            defs(k).expectedVariesValues = {};
            defs(k).expectedConstant = {};
            defs(k).expectedConstantValues = {};
            defs(k).divergenceExpected = false;
            defs(k).mirrors = 'testAllBlankStimuliGivesEmpty';

            k = k + 1;
            defs(k).name = 'nonNumericValues';
            defs(k).shape = 'structArrayOfParameterStructs';
            defs(k).expectedStatus = 'ok';
            defs(k).expectedVaries = {'shape'};
            defs(k).expectedVariesValues = {'[''circle'', ''square'']'};
            defs(k).expectedConstant = {'size'};
            defs(k).expectedConstantValues = {'5'};
            defs(k).divergenceExpected = false;
            defs(k).mirrors = 'testNonNumericValuesReturnedAsCell';

            k = k + 1;
            defs(k).name = 'allConstantSingleStimulus';
            defs(k).shape = 'singleParameterStruct';
            defs(k).expectedStatus = 'ok';
            defs(k).expectedVaries = {};
            defs(k).expectedVariesValues = {};
            defs(k).expectedConstant = {'angle','contrast'};
            defs(k).expectedConstantValues = {'0','1'};
            defs(k).divergenceExpected = false;
            defs(k).mirrors = 'testAllConstantSingleStimulus';

            k = k + 1;
            defs(k).name = 'emptyInput';
            defs(k).shape = 'emptyCell';
            defs(k).expectedStatus = 'ok';
            defs(k).expectedVaries = {};
            defs(k).expectedVariesValues = {};
            defs(k).expectedConstant = {};
            defs(k).expectedConstantValues = {};
            defs(k).divergenceExpected = false;
            defs(k).mirrors = 'testEmptyInput';

            k = k + 1;
            defs(k).name = 'allNaNParameter';
            defs(k).shape = 'cellOfParameterStructs';
            defs(k).expectedStatus = 'ok';
            defs(k).expectedVaries = {'angle'};
            defs(k).expectedVariesValues = {'[NaN]'};
            defs(k).expectedConstant = {'contrast'};
            defs(k).expectedConstantValues = {'1'};
            defs(k).divergenceExpected = true;
            defs(k).mirrors = 'none - added to pin the eqlen(NaN,NaN) divergence';

            k = k + 1;
            defs(k).name = 'badInputNumeric';
            defs(k).shape = 'badInput';
            defs(k).expectedStatus = 'error';
            defs(k).expectedVaries = {};
            defs(k).expectedVariesValues = {};
            defs(k).expectedConstant = {};
            defs(k).expectedConstantValues = {};
            defs(k).divergenceExpected = false;
            defs(k).mirrors = 'testBadInputErrors (first assertion)';

            k = k + 1;
            defs(k).name = 'badCellEntry';
            defs(k).shape = 'badInput';
            defs(k).expectedStatus = 'error';
            defs(k).expectedVaries = {};
            defs(k).expectedVariesValues = {};
            defs(k).expectedConstant = {};
            defs(k).expectedConstantValues = {};
            defs(k).divergenceExpected = false;
            defs(k).mirrors = 'testBadInputErrors (second assertion)';
        end % whatVariesDefs

        function names = knownDivergences()
            % KNOWNDIVERGENCES - whatVaries cases where MATLAB main and the
            % Python port are believed to disagree TODAY.
            %
            %   Both entries trace to one line: local_varyingFields in
            %   src/ndi/+ndi/+fun/+stimulus/whatVaries.m compares with
            %   vlt.data.eqlen (which bottoms out in a bare '=='), while
            %   local_uniqueValues in the same file already uses isequaln and
            %   the Python port uses isequaln semantics throughout.
            %
            %     cellValuedConstantParameter - '==' is undefined for two cell
            %       arrays, so MATLAB is expected to ERROR where Python succeeds.
            %     allNaNParameter - eqlen(NaN,NaN) is false, so MATLAB is
            %       expected to report an all-NaN parameter as VARYING where
            %       Python reports it CONSTANT.
            %
            %   Both are SOURCE-READ predictions, not measurements. When this
            %   suite is first run on a real MATLAB the readArtifacts test prints
            %   whether each divergence is real; if one turns out to agree after
            %   all, delete it here AND clear divergenceExpected in
            %   whatVariesDefs so the case becomes a hard assertion again.
            names = {'cellValuedConstantParameter', 'allNaNParameter'};
        end % knownDivergences

        function results = runWhatVariesCases()
            % RUNWHATVARIESCASES - run every whatVaries case through the real
            % ndi.fun.stimulus.whatVaries / whatIsConstant.
            %
            %   Returns a 1xN CELL of case structs. EVERY case is wrapped in
            %   try/catch BY DESIGN: whatVaries on current MATLAB main is
            %   expected to throw on at least one case (see knownDivergences),
            %   and an exception must be recorded as data so the artifact still
            %   gets written and the Python side still has something to compare
            %   against.
            defs = ndi.symmetry.fun.cases.whatVariesDefs();
            results = cell(1, numel(defs));
            for i = 1:numel(defs)
                d = defs(i);

                c = struct();
                c.name = d.name;
                c.status = 'ok';
                c.identifier = '';
                c.message = '';
                c.shape = d.shape;
                c.mirrors = d.mirrors;
                c.excludeBlank = true;
                c.inputRendered = '';
                c.variesParameters = {};
                c.variesValues = {};
                c.constantParameters = {};
                c.constantValues = {};
                c.whatIsConstantRendered = '';

                try
                    [stimuli, excludeBlank] = ndi.symmetry.fun.cases.whatVariesInput(d.name);
                    c.excludeBlank = logical(excludeBlank);
                    c.inputRendered = ndi.symmetry.fun.cases.render(stimuli);
                catch ME
                    c.status = 'error';
                    c.identifier = ndi.symmetry.fun.cases.errorId(ME);
                    c.message = ME.message;
                    results{i} = c;
                    continue;
                end

                try
                    [varies, constant] = ndi.fun.stimulus.whatVaries(stimuli, ...
                        'excludeBlank', c.excludeBlank);
                    constant2 = ndi.fun.stimulus.whatIsConstant(stimuli, ...
                        'excludeBlank', c.excludeBlank);
                    c.variesParameters   = ndi.symmetry.fun.cases.paramNames(varies);
                    c.variesValues       = ndi.symmetry.fun.cases.renderedList(varies, 'values');
                    c.constantParameters = ndi.symmetry.fun.cases.paramNames(constant);
                    c.constantValues     = ndi.symmetry.fun.cases.renderedScalar(constant, 'value');
                    c.whatIsConstantRendered = ndi.symmetry.fun.cases.render(constant2);
                catch ME
                    c.status = 'error';
                    c.identifier = ndi.symmetry.fun.cases.errorId(ME);
                    c.message = ME.message;
                end

                results{i} = c;
            end
        end % runWhatVariesCases

        function verifyWhatVariesExpected(testCase, results)
            % VERIFYWHATVARIESEXPECTED - check the recorded RESULTS against the
            % MATLAB reference expectations, SKIPPING the cases marked
            % divergenceExpected (whose current MATLAB behaviour is exactly what
            % this battery exists to measure).
            defs = ndi.symmetry.fun.cases.whatVariesDefs();
            testCase.verifyEqual(numel(results), numel(defs), ...
                'Number of whatVaries results does not match the case list.');
            n = min(numel(results), numel(defs));
            for i = 1:n
                d = defs(i);
                c = results{i};
                testCase.verifyEqual(c.name, d.name, ...
                    sprintf('whatVaries case %d name mismatch.', i));
                if d.divergenceExpected
                    continue;
                end
                testCase.verifyEqual(c.status, d.expectedStatus, ...
                    sprintf('whatVaries case ''%s'' status mismatch (%s).', d.name, c.message));
                if ~strcmp(d.expectedStatus, 'ok') || ~strcmp(c.status, 'ok')
                    continue;
                end
                testCase.verifyEqual(ndi.symmetry.fun.cases.asCellStr(c.variesParameters), ...
                    d.expectedVaries, ...
                    sprintf('whatVaries case ''%s'': varying parameter names.', d.name));
                testCase.verifyEqual(ndi.symmetry.fun.cases.asCellStr(c.variesValues), ...
                    d.expectedVariesValues, ...
                    sprintf('whatVaries case ''%s'': varying parameter values.', d.name));
                testCase.verifyEqual(ndi.symmetry.fun.cases.asCellStr(c.constantParameters), ...
                    d.expectedConstant, ...
                    sprintf('whatVaries case ''%s'': constant parameter names.', d.name));
                testCase.verifyEqual(ndi.symmetry.fun.cases.asCellStr(c.constantValues), ...
                    d.expectedConstantValues, ...
                    sprintf('whatVaries case ''%s'': constant parameter values.', d.name));
            end
        end % verifyWhatVariesExpected

        function s = whatVariesSignature(c)
            % WHATVARIESSIGNATURE - the comparable content of one whatVaries case.
            %
            %   IDENTIFIER and MESSAGE are deliberately NOT part of the signature
            %   (see pathSafeSignature for why). EXCLUDEBLANK and INPUTRENDERED
            %   ARE, so a battery that has drifted apart between the two
            %   languages is caught as a mismatch instead of silently comparing
            %   two different inputs.
            s = strjoin({ ...
                ['status=' ndi.symmetry.fun.cases.asChar(c.status)], ...
                ['excludeBlank=' ndi.symmetry.fun.cases.render(logical(c.excludeBlank))], ...
                ['input=' ndi.symmetry.fun.cases.asChar(c.inputRendered)], ...
                ['varies=' ndi.symmetry.fun.cases.pairs(c.variesParameters, c.variesValues)], ...
                ['constant=' ndi.symmetry.fun.cases.pairs(c.constantParameters, c.constantValues)], ...
                ['whatIsConstant=' ndi.symmetry.fun.cases.asChar(c.whatIsConstantRendered)]}, '|');
        end % whatVariesSignature

        % ----------------------------------------------------------------
        % small shared utilities
        % ----------------------------------------------------------------

        function eid = errorId(ME)
            % ERRORID - ME.identifier, or 'error' when MATLAB left it empty.
            eid = ME.identifier;
            if isempty(eid)
                eid = 'error';
            end
        end % errorId

        function names = paramNames(s)
            % PARAMNAMES - the 'parameter' field of a (possibly empty) whatVaries
            % / whatIsConstant result struct array, as a 1xN cellstr.
            if isempty(s)
                names = {};
                return;
            end
            names = reshape({s.parameter}, 1, []);
            for i = 1:numel(names)
                names{i} = reshape(char(names{i}), 1, []);
            end
        end % paramNames

        function vals = renderedList(s, fieldName)
            % RENDEREDLIST - render FIELDNAME of every element of struct array S
            % as a SEQUENCE (used for whatVaries' 'values', which is a list even
            % when MATLAB collapses it to a scalar).
            if isempty(s)
                vals = {};
                return;
            end
            vals = cell(1, numel(s));
            for i = 1:numel(s)
                vals{i} = ndi.symmetry.fun.cases.renderSequence(s(i).(fieldName));
            end
        end % renderedList

        function vals = renderedScalar(s, fieldName)
            % RENDEREDSCALAR - render FIELDNAME of every element of struct array
            % S as a single value (used for whatIsConstant's 'value').
            if isempty(s)
                vals = {};
                return;
            end
            vals = cell(1, numel(s));
            for i = 1:numel(s)
                vals{i} = ndi.symmetry.fun.cases.render(s(i).(fieldName));
            end
        end % renderedScalar

        function s = pairs(names, values)
            % PAIRS - 'name=value; name=value' for two parallel cellstrs.
            n = ndi.symmetry.fun.cases.asCellStr(names);
            v = ndi.symmetry.fun.cases.asCellStr(values);
            m = min(numel(n), numel(v));
            parts = cell(1, m);
            for i = 1:m
                parts{i} = [n{i} '=' v{i}];
            end
            s = ndi.symmetry.fun.cases.joinParts(parts, '; ');
            if numel(n) ~= numel(v)
                s = [s ' <<PARALLEL ARRAYS OF DIFFERENT LENGTH>>'];
            end
        end % pairs

        function c = asCellStr(v)
            % ASCELLSTR - normalize a decoded JSON value to a 1xN cellstr.
            %
            %   jsondecode turns an empty JSON array into 0x0 double, a
            %   one-element array of strings into a 1x1 cell, and a longer one
            %   into an Nx1 cell. Collapse all of those to one shape so a
            %   comparison never trips over a container type.
            if isempty(v)
                c = {};
            elseif ischar(v)
                c = {reshape(v, 1, [])};
            elseif isstring(v)
                c = cellstr(reshape(v, 1, []));
            elseif iscell(v)
                c = reshape(v, 1, []);
                for i = 1:numel(c)
                    c{i} = reshape(char(string(c{i})), 1, []);
                end
            else
                c = {};
            end
        end % asCellStr

        function r = asRow(v)
            % ASROW - normalize a decoded JSON number array to a 1xN double row.
            if isempty(v)
                r = zeros(1, 0);
            else
                r = reshape(double(v), 1, []);
            end
        end % asRow

        function s = asChar(v)
            % ASCHAR - normalize a decoded JSON string (which can come back as
            % '', "", a missing string, or [] for null) to a char row vector.
            if isempty(v)
                s = '';
                return;
            end
            str = string(v);
            if all(ismissing(str))
                s = '';
            else
                s = reshape(char(str(1)), 1, []);
            end
        end % asChar

        function m = indexByName(cellOfCases)
            % INDEXBYNAME - containers.Map from case name -> case struct.
            m = containers.Map('KeyType', 'char', 'ValueType', 'any');
            for i = 1:numel(cellOfCases)
                c = cellOfCases{i};
                m(ndi.symmetry.fun.cases.asChar(c.name)) = c;
            end
        end % indexByName

        function cellCases = loadCases(file)
            % LOADCASES - read an artifact JSON and return its cases as a 1xN
            % cell of structs, whatever shape jsondecode chose.
            %
            %   The file is read as UTF-8 bytes rather than through fileread so
            %   the astral pathSafeName cases survive on a machine whose default
            %   character encoding is not UTF-8.
            fid = fopen(file, 'r');
            if fid < 0
                error('ndi:symmetry:fun:cases:cannotRead', ...
                    'Could not open %s for reading.', file);
            end
            cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
            bytes = fread(fid, inf, '*uint8');
            clear cleaner;
            raw = native2unicode(reshape(bytes, 1, []), 'UTF-8');

            payload = jsondecode(raw);
            c = payload.cases;
            if isstruct(c)
                c = num2cell(c);
            elseif ~iscell(c)
                c = {};
            end
            cellCases = reshape(c, 1, []);
        end % loadCases

        function writeCases(testCase, artifactDir, fileName, payload)
            % WRITECASES - (re)create ARTIFACTDIR and write PAYLOAD as pretty
            % JSON, mirroring ndi.symmetry.makeArtifacts.time.timeConvert.
            %
            %   Bytes are written as UTF-8 rather than with fwrite(...,'char')
            %   because the astral pathSafeName cases put characters above U+00FF
            %   in the payload, and 'char' would truncate each to one byte.
            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            jsonStr = jsonencode(payload, 'PrettyPrint', true);
            outFile = fullfile(artifactDir, fileName);
            fid = fopen(outFile, 'w');
            testCase.assertGreaterThan(fid, 0, ...
                sprintf('Could not open %s for writing.', fileName));
            cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
            fwrite(fid, unicode2native(jsonStr, 'UTF-8'), 'uint8');
            clear cleaner;

            testCase.verifyTrue(isfile(outFile), ...
                sprintf('Artifact file %s was not written.', fileName));
        end % writeCases

    end % methods (Static)
end % classdef
