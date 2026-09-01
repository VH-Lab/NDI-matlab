classdef TextParserRulesTest < matlab.unittest.TestCase
% TextParserRulesTest - Offline tests for the shipped conversion parser rules.
%
%   The lab conversion packages under src/ndi/+ndi/+setup/+conv ship JSON files
%   of regular-expression rules ({VariableName, StringFormat, ...}) that are fed
%   to regexp by ndi.fun.parseText and by the dabrowska import path. A pattern
%   that does not compile is not caught until an import is run against real
%   data, at which point the import throws part way through the rule list.
%
%   These tests compile every shipped rule and pin the one rule that was found
%   broken this way: babu's PT3602 pattern carried an unmatched ')'.
%
%   Runs fully offline; no data, database or network access is needed.
%
%   See also: ndi.fun.parseText, ndi.setup.conv.babu.import

    methods (Static)
        function fileName = babuParserFile()
            % BABUPARSERFILE - babu/textParser.json, found the way import.m does.
            fileName = which(fullfile('+ndi', '+setup', '+conv', '+babu', ...
                'textParser.json'));
        end

        function fileList = parserFiles()
            % PARSERFILES - every shipped JSON under +setup/+conv holding rules.
            convFolder = fileparts(fileparts( ...
                ndi.unittest.setup.conv.TextParserRulesTest.babuParserFile()));
            listing = dir(fullfile(convFolder, '**', '*.json'));
            fileList = {};
            for i = 1:numel(listing)
                fullName = fullfile(listing(i).folder, listing(i).name);
                if contains(fileread(fullName), '"StringFormat"')
                    fileList{end+1} = fullName; %#ok<AGROW>
                end
            end
        end

        function rules = readRules(fileName)
            % READRULES - decode one parser file into a cell array of structs.
            %
            %   jsondecode returns a struct array when every entry has the same
            %   fields and a cell array when they differ, so normalize to cell.
            decoded = jsondecode(fileread(fileName));
            if iscell(decoded)
                rules = decoded;
            else
                rules = num2cell(decoded);
            end
        end

        function pattern = babuPattern(variableName)
            % BABUPATTERN - the StringFormat of one rule in babu/textParser.json.
            fileName = ndi.unittest.setup.conv.TextParserRulesTest.babuParserFile();
            rules = ndi.unittest.setup.conv.TextParserRulesTest.readRules(fileName);
            for r = 1:numel(rules)
                if strcmp(rules{r}.VariableName, variableName)
                    pattern = rules{r}.StringFormat;
                    return
                end
            end
            error('NDI:test:ruleNotFound', ...
                'No rule named %s in %s.', variableName, fileName);
        end
    end

    methods (Test)
        function testParserFilesAreFound(testCase)
            % Guard against the discovery above silently finding nothing.
            testCase.assertNotEmpty( ...
                ndi.unittest.setup.conv.TextParserRulesTest.babuParserFile(), ...
                'babu/textParser.json was not found on the MATLAB path.');
            fileList = ndi.unittest.setup.conv.TextParserRulesTest.parserFiles();
            testCase.verifyNotEmpty(fileList, ...
                ['No parser JSON files were found under +setup/+conv; the ' ...
                 'other tests in this class would then assert nothing.']);
        end

        function testEveryShippedRuleCompiles(testCase)
            % Every StringFormat in every shipped parser file must be a regular
            % expression that regexp accepts.
            fileList = ndi.unittest.setup.conv.TextParserRulesTest.parserFiles();
            for f = 1:numel(fileList)
                rules = ndi.unittest.setup.conv.TextParserRulesTest.readRules(fileList{f});
                for r = 1:numel(rules)
                    rule = rules{r};
                    if ~isfield(rule, 'StringFormat') || isempty(rule.StringFormat)
                        continue
                    end
                    errorMessage = '';
                    try
                        regexp('probe text', rule.StringFormat, 'once');
                    catch ME
                        errorMessage = ME.message;
                    end
                    testCase.verifyEmpty(errorMessage, sprintf( ...
                        'Rule %s in %s does not compile: %s\nPattern: %s', ...
                        rule.VariableName, fileList{f}, errorMessage, ...
                        rule.StringFormat));
                end
            end
        end

        function testBabuPT3602MatchesBothAlternatives(testCase)
            % The PT3602 rule names two file forms: the Control condition of
            % figure S5D, and the figure 5E files. It once read
            % 'S5D.*Control|Figure_5)E', whose stray ')' made it uncompilable.
            pattern = ndi.unittest.setup.conv.TextParserRulesTest.babuPattern('PT3602');

            testCase.verifyNotEmpty( ...
                regexp('Figure_S5D_PT3602_Control_Rep_I', pattern, 'once'), ...
                'PT3602 should match the S5D Control files.');
            testCase.verifyNotEmpty( ...
                regexp('Figure_5E_part_1_Mean_summation', pattern, 'once'), ...
                'PT3602 should match the Figure_5E files.');
            testCase.verifyEmpty( ...
                regexp('Figure_4C_TM5848', pattern, 'once'), ...
                'PT3602 should not match files of an unrelated figure.');
        end
    end
end
