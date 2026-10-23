classdef TestNoOldLeafNames < matlab.unittest.TestCase
%TESTNOOLDLEAFNAMES The V2 import code writes no pre-composition leaf name.
%
%   did-schema #88: a statement is a direction class (assertion, observation,
%   manipulation, calculation) plus ONE value-kind mixin in `superclasses`,
%   built as did2.build.statement('<direction>', ..., 'ValueKind', '<kind>').
%   The only named statement classes are the eight vision calculators. Jess
%   Haley: "stop mentioning old leafs". did2.build still resolves a joined
%   '<kind>_<direction>' name from an old-vintage caller; this code must not
%   be one. (DID-matlab's twin: tests/+did2/+unittest/testNoOldLeafNames.m.)
%
%   Two rules:
%     1. The Haley import (src/ndi/+ndi/+setup/+conv/+haley), the V2 import
%        helpers (+setup/+V2) and the template importer (+setup/+conv/+template):
%        no joined leaf name anywhere in a .m or .json file, comments
%        included, and no quoted '_<direction>' suffix (the piece that builds
%        one by concatenation). The decision logs (.md) are the record and
%        are not scanned.
%     2. Every .m file under src/ and tests/: no did2.build.* call whose first
%        argument is a quoted joined leaf name.
%
%   Each scan prints its DENOMINATOR first and refuses to pass over an empty
%   tree; testTheScannerSeesAPlantedViolation proves the patterns can match.

    methods (Test)
        function testImportSourceNamesNoOldLeaf(testCase)
            root = repoRoot();
            areas = {fullfile('src', 'ndi', '+ndi', '+setup', '+conv', '+haley'), ...
                fullfile('src', 'ndi', '+ndi', '+setup', '+V2'), ...
                fullfile('src', 'ndi', '+ndi', '+setup', '+conv', '+template')};
            files = {};
            for a = 1:numel(areas)
                files = [files, filesUnder(fullfile(root, areas{a}), {'.m', '.json'})]; %#ok<AGROW>
            end
            nLines = 0;
            hits = {};
            for k = 1:numel(files)
                lines = regexp(fileread(files{k}), '\r?\n', 'split');
                nLines = nLines + numel(lines);
                for i = 1:numel(lines)
                    for name = oldLeafTokens(lines{i})
                        hits{end+1} = sprintf('%s:%d: %s', relative(root, files{k}), i, name{1}); %#ok<AGROW>
                    end
                end
            end
            fprintf(['TestNoOldLeafNames rule 1 DENOMINATOR: %d file(s) (.m, .json) in %d ' ...
                'area(s), %d line(s) inspected; %d violation(s)\n'], ...
                numel(files), numel(areas), nLines, numel(hits));
            if ~isempty(hits), fprintf('  VIOLATION %s\n', hits{:}); end
            % an empty tree is "not measured", never "clean"
            testCase.verifyGreaterThan(numel(files), 40, ...
                sprintf('only %d files found under the import areas: wrong root %s?', numel(files), root));
            testCase.verifyEmpty(hits, sprintf( ...
                ['%d pre-composition leaf name(s) in the V2 import source. Build a statement ' ...
                 'as its direction with ''ValueKind'' (did2.build.statement), and describe it ' ...
                 'in words ("a velocity calculation"):\n%s'], numel(hits), strjoin(hits, newline)));
        end

        function testNoBuildCallIsGivenAnOldLeaf(testCase)
            root = repoRoot();
            files = [filesUnder(fullfile(root, 'src'), {'.m'}), filesUnder(fullfile(root, 'tests'), {'.m'})];
            nCalls = 0;
            hits = {};
            for k = 1:numel(files)
                txt = fileread(files{k});
                nCalls = nCalls + numel(regexp(txt, 'did2\.build\.\w+\(', 'start'));
                for name = oldLeafBuildCalls(txt)
                    hits{end+1} = sprintf('%s: %s', relative(root, files{k}), name{1}); %#ok<AGROW>
                end
            end
            fprintf(['TestNoOldLeafNames rule 2 DENOMINATOR: %d .m file(s) under src/ and tests/, ' ...
                '%d did2.build call(s) inspected; %d violation(s)\n'], numel(files), nCalls, numel(hits));
            if ~isempty(hits), fprintf('  VIOLATION %s\n', hits{:}); end
            testCase.verifyGreaterThan(numel(files), 500, ...
                sprintf('only %d .m files found under %s: wrong root?', numel(files), root));
            testCase.verifyGreaterThan(nCalls, 100, 'too few did2.build calls seen: the scan cannot see');
            testCase.verifyEmpty(hits, sprintf( ...
                ['%d did2.build call(s) given a pre-composition leaf name. Pass the direction ' ...
                 'with ''ValueKind'':\n%s'], numel(hits), strjoin(hits, newline)));
        end

        function testTheScannerSeesAPlantedViolation(testCase)
            % A scanner that cannot match proves nothing. The planted names are
            % built by concatenation so this file is not itself a violation.
            obs = ['voltage' '_observation'];
            testCase.verifyEqual(oldLeafTokens(['% a ' obs ' of the probe']), {obs});
            testCase.verifyEqual(oldLeafTokens(['x = [k ''' '_manipulation' '''];']), ...
                {'''_manipulation'''});
            testCase.verifyEqual(oldLeafTokens(['"_about": "one ' 'model_fit' '_calculation"']), ...
                {['model_fit' '_calculation']});
            testCase.verifyEmpty(oldLeafTokens(['tuning_curve' '_calculation, ' ...
                'receptive_field' '_calculation']), 'a named calculator is not an old leaf');
            testCase.verifyEmpty(oldLeafTokens('a velocity calculation; ''calculation'', ''ValueKind'''));
            call = ['st = did2.build.statement(''' 'term' '_assertion' ''', id, v, x);'];
            testCase.verifyEqual(oldLeafBuildCalls(call), {['term' '_assertion']});
            testCase.verifyEqual(oldLeafBuildCalls(['v = did2.build.composite(''' 'dose' ...
                '_manipulation' ''', ''value'', s);']), {['dose' '_manipulation']});
            testCase.verifyEmpty(oldLeafBuildCalls(['did2.build.statement(''' 'speed_tuning' ...
                '_calculation' ''', id)']), 'a named calculator is a class');
            testCase.verifyEmpty(oldLeafBuildCalls( ...
                'did2.build.statement(''assertion'', id, v, x, ''ValueKind'', ''term'')'));
        end
    end
end

% ===================== the rules ==============================================

function names = oldLeafTokens(line)
% Every joined '<kind>_<direction>' word in LINE that is not a named
% calculator, and every quoted '_<direction>' suffix.
words = regexp(line, ['(?<![A-Za-z0-9_])[a-z][a-z0-9_]*_' directions() '(?![A-Za-z0-9_])'], 'match');
words = words(~ismember(words, namedCalculators()));
suffixes = regexp(line, ['''_' directions() ''''], 'match');
names = [words, suffixes];
end

function names = oldLeafBuildCalls(txt)
% The first argument of every did2.build.* call in TXT that is a quoted joined
% leaf name (not a named calculator).
tok = regexp(txt, ['did2\.build\.\w+\(\s*''([a-z][a-z0-9_]*_' directions() ')'''], 'tokens');
names = cellfun(@(t) t{1}, tok, 'UniformOutput', false);
names = names(~ismember(names, namedCalculators()));
end

function p = directions()
p = '(?:assertion|observation|manipulation|calculation)';
end

function names = namedCalculators()
% did-schema #88 stable/*_calculation.json: the eight named calculators.
names = {'tuning_curve_calculation', 'orientation_direction_tuning_calculation', ...
    'spatial_frequency_tuning_calculation', 'temporal_frequency_tuning_calculation', ...
    'speed_tuning_calculation', 'contrast_tuning_calculation', ...
    'receptive_field_calculation', 'contrast_sensitivity_calculation'};
end

% ===================== files ==================================================

function root = repoRoot()
here = fileparts(mfilename('fullpath'));            % <root>/tests/+ndi/+unittest/+setup/+V2
root = here;
for k = 1:5
    root = fileparts(root);
end
end

function files = filesUnder(folder, exts)
% Every file below FOLDER with one of the extensions EXTS, walked explicitly
% (portable; no '**' glob).
files = {};
entries = dir(folder);
for k = 1:numel(entries)
    e = entries(k);
    if any(strcmp(e.name, {'.', '..'})); continue; end
    p = fullfile(folder, e.name);
    if e.isdir
        files = [files, filesUnder(p, exts)]; %#ok<AGROW>
    else
        [~, ~, x] = fileparts(e.name);
        if any(strcmp(x, exts))
            files{end + 1} = p; %#ok<AGROW>
        end
    end
end
end

function r = relative(root, p)
r = strrep(p(numel(root) + 2:end), '\', '/');
end
