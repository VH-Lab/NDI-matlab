function d = openMINDSobj2ndi_document(openmindsObj, session_id, dependency_type, dependency_value, varargin)
    % OPENMINDSOBJ2NDI_DOCUMENT - openMinds objects to set of ndi.document objects
    %
    % D = ndi.database.fun.openMINDSobj2ndi_document(OPENMINDS_OBJ, SESSION_ID, [DEPENDENCY_TYPE], [DEPENDENCY_VALUE])
    %
    % Convert a cell array of openMINDS objects to a set of ndi.document objects.
    % D is a cell array of ndi.document objects. If the document is requested to be of a particular
    % DEPENDENCY_TYPE ('subject', 'element'), then the corresponding dependency is set to
    % DEPENDENCY_VALUE.
    %
    % Example 1:
    %   p = personWithTwoAffiliations(); % openMINDS library function
    %   session_id = S.id(); % get the id of an ndi.session S
    %   d = ndi.database.fun.openMINDSobj2ndi_document(p, session_id);
    %
    % Example 2:
    %   s = openminds.controlledterms.Species('name','Mustela putorius furo','preferredOntologyIdentifier','NCBI:txid9669');
    %   session_id = S.id(); % get the id of an ndi.session S
    %   subject_docs = S.database_search(ndi.query('','isa','subject'));
    %   d = ndi.database.fun.openMINDSobj2ndi_document(s, session_id, 'subject', subject_docs{1}.id());
    %
    % D = ndi.database.fun.openMINDSobj2ndi_document(OPENMINDS_OBJ, SESSION, ...)
    %
    % Gives the tool the session (an ndi.session) instead of its id, and the
    % documents are written for that session's database. On a v2 database
    % (ndi.session/writesV2), objects about a subject (DEPENDENCY_TYPE
    % 'subject') are the v2 documents ndi.database.fun.openMINDSobj2V2 builds:
    % term assertions about the subject and, for a Strain, a strain entity the
    % subject is `instance_of`. On a v1 database, or given only a session id,
    % D is the v1 documents, as before.
    %
    % Objects with no subject (DEPENDENCY_TYPE '', 'element' or 'stimulus')
    % stay v1 documents on either database: did-schema's coverage ledger
    % records no decided v2 target
    % for the bare `openminds` and `openminds_stimulus` classes, and the
    % element an `openminds_element` is about is itself still written v1 on
    % the v2 line (element writers wait on did-schema docs/V2_PLAN.md G84,
    % parked; [new database defaults to v2]). A v2
    % database stores them as v1 documents (did2sqlite; [v1 writes into a V2
    % session]).
    %
    % Decided by Jess Haley, 2026-11-03 [writers are given the session] and
    % [v2 line reads and writes both] (did-schema
    % did_v2_go_forward_class_audit.md): a tool learns the version from the
    % session's database; no "write V2" switch.
    %

    if ~iscell(openmindsObj)
        newcell = {};
        for i=1:numel(openmindsObj)
            newcell{i} = openmindsObj(i);
        end
        openmindsObj = newcell;
    end

    if nargin<3
        dependency_type = '';
    end

    if nargin<4
        dependency_value = '';
    end

    if ~isempty(dependency_type) & isempty(dependency_value)
        error(['DEPENDENCY_VALUE must not be empty if DEPENDENCY_TYPE is given.']);
    end

    % the session, when given, decides the version written
    session = [];
    if isa(session_id, 'ndi.session')
        session = session_id;
        session_id = session.id();
    end
    if ~isempty(session) && strcmpi(dependency_type, 'subject') && session.writesV2()
        if ~isempty(varargin)
            error('ndi:database:fun:openMINDSobj2ndi_document:v2Properties', ...
                ['Extra v1 document properties cannot be set on the v2 documents ' ...
                'written for a v2 database.']);
        end
        d = ndi.database.fun.openMINDSobj2V2(openmindsObj, session, dependency_value);
        return;
    end

    s = ndi.database.fun.openMINDSobj2struct(openmindsObj);

    docName = 'openminds';

    switch lower(dependency_type)
        case ''
            dependency_name = '';
            docName = 'openminds';
        case 'subject'
            dependency_name = 'subject_id';
            docName = 'openminds_subject';
        case 'element'
            dependency_name = 'element_id';
            docName = ['openminds_element'];
        case 'stimulus'
            dependency_name = 'stimulus_element_id';
            docName = ['openminds_stimulus'];
        otherwise
            error(['Unknown DEPENDENCY_TYPE ' dependency_type '.']);
    end

    d = {};

    for i=1:numel(s)
        openminds_struct = rmfield(s(i),'complete');
        ndi_id_here = openminds_struct.ndi_id;
        openminds_struct = rmfield(openminds_struct,'ndi_id');
        d{i} = ndi.document(docName,'base.id',ndi_id_here,...
            'base.session_id',session_id,...
            'openminds',openminds_struct,varargin{:});
        fn = fieldnames(openminds_struct.fields);
        added_dependency = 0;
        for j=1:numel(fn)
            g = getfield(openminds_struct.fields,fn{j});
            if iscell(g)
                for k=1:numel(g)
                    if ischar(g{k})
                        if startsWith(g{k},'ndi://')
                            id_here = g{k}(7:end);
                            d{i} = add_dependency_value_n(d{i},...
                                'openminds',id_here,...
                                'ErrorIfNotFound',0);
                            added_dependency = 1;
                        end
                    end
                end
            end
        end
        if ~added_dependency
            d{i} = set_dependency_value(d{i},'openminds','','ErrorIfNotFound',0);
        end
        if ~isempty(dependency_name)
            d{i} = d{i}.set_dependency_value(dependency_name,dependency_value);
        end
    end
