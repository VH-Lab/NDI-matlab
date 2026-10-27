classdef CloudTestsNameOrganizationTest < matlab.unittest.TestCase
% CloudTestsNameOrganizationTest - Tests that create cloud datasets must name the organization.
%
%   NDI Cloud users may belong to several organizations. When a call to
%   ndi.cloud.api.datasets.createDataset or ndi.cloud.uploadDataset does
%   not name one, ndi.cloud.internal.chooseOrganization opens a picker in
%   the desktop and errors under -batch. A test that relies on that only
%   works for accounts with a single organization, so every such call in
%   tests/ must pass 'organizationID' (normally
%   ndi.unittest.cloud.testOrganizationID()) or 'organizationName'.
%
%   This scans the test sources statically; it needs no network access or
%   credentials.

    properties (Constant)
        % Files whose calls deliberately name no organization, with why.
        Exempt = struct( ...
            'file', {'uploadDatasetIngestionGate.m'}, ...
            'reason', {'uploadDataset refuses a non-ingested dataset before choosing an organization'});
    end

    methods (Test)
        function testDatasetCreatingCallsNameAnOrganization(testCase)
            testsRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            files = dir(fullfile(testsRoot, '**', '*.m'));
            exemptFiles = {testCase.Exempt.file};

            offenders = strings(0, 1);
            for k = 1:numel(files)
                if any(strcmp(files(k).name, exemptFiles))
                    continue;
                end
                path = fullfile(files(k).folder, files(k).name);
                calls = datasetCreatingCalls(fileread(path));
                for c = 1:numel(calls)
                    if ~contains(calls{c}, ["organizationID", "organizationName"])
                        offenders(end+1) = string(path) + ": " + ...
                            regexprep(calls{c}, '\s+', ' '); %#ok<AGROW>
                    end
                end
            end

            testCase.verifyEmpty(offenders, sprintf( ...
                ['These calls create a cloud dataset without naming an organization; ', ...
                 'pass ''organizationID'', ndi.unittest.cloud.testOrganizationID():\n%s'], ...
                strjoin(offenders, newline)));
        end
    end
end

function calls = datasetCreatingCalls(source)
% Full text of each createDataset / uploadDataset call in SOURCE, ignoring
% comment lines. A call runs from its name to the matching close paren, so
% it spans '...' continuation lines.
    lines = splitlines(source);
    lines = lines(~startsWith(strtrim(lines), '%'));
    text = char(strjoin(lines, newline));

    calls = {};
    [starts, ends] = regexp(text, 'ndi\.cloud\.(api\.datasets\.createDataset|uploadDataset)\(');
    for k = 1:numel(starts)
        depth = 1;
        i = ends(k);
        while depth > 0 && i < numel(text)
            i = i + 1;
            if text(i) == '('
                depth = depth + 1;
            elseif text(i) == ')'
                depth = depth - 1;
            end
        end
        calls{end+1} = text(starts(k):i); %#ok<AGROW>
    end
end
