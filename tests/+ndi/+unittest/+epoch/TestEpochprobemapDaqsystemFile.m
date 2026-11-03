classdef TestEpochprobemapDaqsystemFile < matlab.unittest.TestCase
    % TESTEPOCHPROBEMAPDAQSYSTEMFILE - reading epochprobemap_daqsystem files
    %
    % A trailing tab on each line makes READTABLE add an empty 'Var6'
    % column; that must not make the file unreadable.

    methods (Test)
        function testTrailingTabIsIgnored(testCase)
            fname = [tempname '.epochprobemap.ndi'];
            cleanup = onCleanup(@() delete(fname)); %#ok<NASGU>
            fid = fopen(fname, 'wt');
            fprintf(fid, 'name\treference\ttype\tdevicestring\tsubjectstring\t\n');
            fprintf(fid, 'ctx\t1\tn-trode\tintan1:ai1\tanteater27@nosuchlab.org\t\n');
            fclose(fid);
            e = ndi.epoch.epochprobemap_daqsystem(fname);
            testCase.verifyNumElements(e, 1);
            testCase.verifyEqual(e.name, 'ctx');
            testCase.verifyEqual(e.subjectstring, 'anteater27@nosuchlab.org');
        end

        function testUnexpectedColumnIsStillAnError(testCase)
            fname = [tempname '.epochprobemap.ndi'];
            cleanup = onCleanup(@() delete(fname)); %#ok<NASGU>
            fid = fopen(fname, 'wt');
            fprintf(fid, 'name\treference\ttype\tdevicestring\tsubjectstring\textra\n');
            fprintf(fid, 'ctx\t1\tn-trode\tintan1:ai1\tanteater27@nosuchlab.org\tfoo\n');
            fclose(fid);
            testCase.verifyError(@() ndi.epoch.epochprobemap_daqsystem(fname), ?MException);
        end

        function testDropEmptyExtraColumns(testCase)
            st = struct('name','ctx','reference',1,'type','n-trode', ...
                'devicestring','intan1:ai1','subjectstring','a@b.org','Var6',NaN);
            out = ndi.epoch.epochprobemap_daqsystem.dropEmptyExtraColumns(st);
            testCase.verifyFalse(isfield(out,'Var6'));
            st.Var6 = 'something';
            out = ndi.epoch.epochprobemap_daqsystem.dropEmptyExtraColumns(st);
            testCase.verifyTrue(isfield(out,'Var6'));
        end
    end
end
