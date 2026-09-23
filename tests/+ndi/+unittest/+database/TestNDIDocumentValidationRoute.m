classdef TestNDIDocumentValidationRoute < matlab.unittest.TestCase
    % Where an ndi.document is actually checked against its schema.
    %
    % ndi.document declared validate(), whose whole body was:
    %
    %     b = 1; % for now, skip this
    %
    % under a docstring saying it "checks the fields of the ndi.document
    % object against the schema". Nothing in src/ or tests/ called it. That
    % combination is worse than an unused method: anyone who found it got a
    % confident "valid" back for a document nothing had looked at.
    %
    % did.document's counterpart was no better -- it delegated to did.validate,
    % which does not exist in DID-matlab and never did, so it threw on every
    % call. It is removed in VH-Lab/DID-matlab#182.
    %
    % A document cannot validate itself: the schema check needs the database,
    % because resolving depends_on requires knowing which ids exist. The real
    % route is did.database/add -> validate_docs -> validate_doc_vs_schema,
    % on by default via add's Validate option.
    %
    % Note on timing: NDI resolves DID unpinned from main at run time, so
    % while DID#182 is unmerged ndi.document still INHERITS did.document's
    % throwing validate. Both tests below are written to hold either way --
    % they assert ndi.document does not DEFINE validate, and that calling it
    % errors, which is true of the inherited version and of no version at all.

    methods

        function definingClass = definerOf(~, methodName)
            mc = meta.class.fromName('ndi.document');
            k = find(strcmp({mc.MethodList.Name}, methodName), 1);
            if isempty(k)
                definingClass = '';
            else
                definingClass = mc.MethodList(k).DefiningClass.Name;
            end
        end

    end

    methods (Test)

        function testNdiDocumentDoesNotDefineValidate(testCase)
            % '' once DID#182 lands, 'did.document' until then. Either is fine;
            % what must not come back is ndi.document defining its own.
            testCase.verifyNotEqual(testCase.definerOf('validate'), 'ndi.document', ...
                ['ndi.document declares validate() again. The old one returned ' ...
                 '1 unconditionally while claiming to check the schema. ' ...
                 'Documents are validated on the way into the database, by ' ...
                 'did.database/add -> validate_docs.']);
        end

        function testCallingValidateOnADocumentErrors(testCase)
            % The point of the removal: asking for the route fails instead of
            % returning a reassuring answer that means nothing.
            doc = ndi.document('demoNDI', 'demoNDI.value', 5);
            testCase.verifyError(@() doc.validate(), ?MException);
        end

        function testDatabaseDeclaresTheValidationEntryPoint(testCase)
            % The live route, named here so that renaming it breaks the test
            % that documents it rather than silently orphaning this comment.
            testCase.verifyTrue(any(strcmp(methods('did.database'), 'validate_docs')), ...
                'did.database no longer declares validate_docs');
        end

    end
end
