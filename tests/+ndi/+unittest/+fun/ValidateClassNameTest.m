classdef ValidateClassNameTest < matlab.unittest.TestCase
    % VALIDATECLASSNAMETEST - regression tests for ndi.fun.validateClassName
    %
    % Guards the eval->feval hardening of the NDI object-reconstruction paths
    % (ndi.database.fun.ndi_document2ndi_object, ndi.epoch.epochset.param).
    % An untrusted *_class field must never reach eval/feval as executable
    % code; it must either name a real ndi./did. class or be rejected.
    %
    % Authored without a local MATLAB runtime; needs MATLAB to validate/run.

    methods (Test)

        function testAcceptsValidNdiClass(testCase)
            % A real, fully-qualified ndi. class passes through unchanged.
            name = ndi.fun.validateClassName('ndi.epoch.epochprobemap_daqsystem');
            testCase.verifyEqual(name, 'ndi.epoch.epochprobemap_daqsystem');
        end

        function testAcceptsStringScalar(testCase)
            % A string scalar is accepted and normalised to char.
            name = ndi.fun.validateClassName("ndi.epoch.epochprobemap_daqsystem");
            testCase.verifyTrue(ischar(name));
            testCase.verifyEqual(name, 'ndi.epoch.epochprobemap_daqsystem');
        end

        function testRejectsInjectionPayload(testCase)
            % The canonical attack: code smuggled through the class-name field.
            payload = "system('touch /tmp/ndi_canary'), ndi.daq.reader";
            testCase.verifyError(@() ndi.fun.validateClassName(payload), ...
                'ndi:fun:validateClassName:invalidClassName');
        end

        function testRejectsParenthesesAndArgs(testCase)
            testCase.verifyError(...
                @() ndi.fun.validateClassName('ndi.daq.reader(x)'), ...
                'ndi:fun:validateClassName:invalidClassName');
        end

        function testRejectsSemicolonSequence(testCase)
            testCase.verifyError(...
                @() ndi.fun.validateClassName('ndi.daq.reader; system(''x'')'), ...
                'ndi:fun:validateClassName:invalidClassName');
        end

        function testRejectsNonAllowlistedNamespace(testCase)
            % Even a syntactically valid identifier outside ndi./did. is refused.
            testCase.verifyError(...
                @() ndi.fun.validateClassName('exit'), ...
                'ndi:fun:validateClassName:invalidClassName');
            testCase.verifyError(...
                @() ndi.fun.validateClassName('some.other.Class'), ...
                'ndi:fun:validateClassName:invalidClassName');
        end

        function testRejectsNonexistentNdiClass(testCase)
            % ndi.-prefixed but not a real class -> diagnosable rejection.
            testCase.verifyError(...
                @() ndi.fun.validateClassName('ndi.not.a.real.Class'), ...
                'ndi:fun:validateClassName:invalidClassName');
        end

        function testRejectsEmptyAndNonChar(testCase)
            testCase.verifyError(...
                @() ndi.fun.validateClassName(''), ...
                'ndi:fun:validateClassName:invalidClassName');
            testCase.verifyError(...
                @() ndi.fun.validateClassName(42), ...
                'ndi:fun:validateClassName:invalidClassName');
        end

        function testCustomErrorIdIsUsed(testCase)
            % Call sites pass their own identifier for diagnosability.
            testCase.verifyError(...
                @() ndi.fun.validateClassName('bad name', 'ndi:my:customId'), ...
                'ndi:my:customId');
        end

    end

end
