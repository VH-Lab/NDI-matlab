classdef element < ndi.ido & ndi.epoch.epochset & ndi.documentservice & matlab.mixin.Heterogeneous
    % ndi.element - define or examine a element in the session
    %
    properties (GetAccess=public, SetAccess=protected)
        session   % associated ndi_session object
        name         %
        type         %
        reference    %
        underlying_element % does this element depend on underlying element data (epochs)?
        direct       % is it direct from the element it underlies, or is it different with its own possibly modified epochs?
        subject_id   % ID of the subject that is related to the ndi.element
        dependencies % a structure of name/value pairs of document dependencies (with exception of underlying_element and subject_id)
    end; % properties

    methods
        function [ndi_element_obj,element_doc] = element(varargin)
            % NDI.ELEMENT - creator for ndi.element
            %
            % NDI_ELEMENT_OBJ = ndi.element(NDI_SESSION_OBJ, ELEMENT_NAME, ELEMENT_REFERENCE, ...
            %        ELEMENT_TYPE, UNDERLYING_EPOCHSET, DIRECT, [SUBJECT_ID], [DEPENDENCIES])
            %    or
            % NDI_ELEMENT_OBJ = ndi.element(NDI_SESSION_OBJ, ELEMENT_DOCUMENT)
            %
            % Creates an ndi.element object, either from a name and and associated ndi.probe object,
            % or builds the ndi.element in memory from an ndi.document of type 'element'.
            %
            % If the UNDERLYING_EPOCHSET has a subject_id, then that subject ID is used for the new
            % element.
            %
            set_identifier = 0;

            if nargin == 0;
                return % Support 0-argument construction
            end

            needs_newdocument_call = 1;

            if numel(varargin)>=6,
                % first type
                ndi_element_class = 'ndi.element';
                element_session = varargin{1};
                element_name = varargin{2};
                element_reference = varargin{3};
                element_type = varargin{4};
                element_underlying_element = varargin{5};
                direct = logical(varargin{6});
                if ~isempty(element_underlying_element),
                    if ~isa(element_underlying_element,'ndi.element'),
                        error(['Underlying element must be an ndi.element.']);
                    end;
                end;
                if ~isempty(element_underlying_element),
                    subject_id = element_underlying_element.subject_id;
                    if numel(varargin)==7,
                        warning(['Ignoring input subject_id because underlying element is given.']);
                    end;
                elseif numel(varargin)>=7 & ~isempty(varargin{7}),
                    subject_id = varargin{7};
                    [b,subject_id] = ndi.subject.does_subjectstring_match_session_document(element_session,subject_id,1);
                    if ~b,
                        error(['Subject does not correspond to a valid document_id entry in the database.']);
                    end;
                end;
                if numel(varargin)>=8,
                    dependencies = varargin{8};
                else,
                    dependencies = {};
                end;
            elseif numel(varargin)==2,
                element_session = varargin{1};
                if ~isa(element_session,'ndi.session'),
                    error(['When 2 input arguments are given, 1st input must be an ndi.session.']);
                end;
                needs_newdocument_call = 0;
                element_doc = [];
                if ~isa(varargin{2},'ndi.document'),
                    % might be id
                    element_search = element_session.database_search(ndi.query('base.id','exact_string',varargin{2},''));
                    if numel(element_search)~=1,
                        error(['When 2 input arguments are given, 2nd input argument must be an ndi.document or document ID.']);
                    else,
                        element_doc = element_search{1};
                    end;
                else,
                    element_doc = varargin{2};
                end;
                if ~isfield(element_doc.document_properties, 'element'),
                    error(['This document does not have parameters ''element''.']);
                end;
                % now we have the document and can start reading
                ndi_element_class = element_doc.document_properties.element.ndi_element_class;
                element_name = element_doc.document_properties.element.name;
                element_reference = element_doc.document_properties.element.reference;
                element_type = element_doc.document_properties.element.type;
                if isempty(element_doc.dependency_value('underlying_element_id')),
                    element_underlying_element = [];
                else,
                    element_underlying_element = ndi.database.fun.ndi_document2ndi_object(...
                        dependency_value(element_doc,'underlying_element_id'), element_session);
                end;
                if ischar(element_doc.document_properties.element.direct),
                    direct = logical(eval(element_doc.document_properties.element.direct));
                else,
                    direct = logical(element_doc.document_properties.element.direct);
                end;
                subject_id = element_doc.dependency_value('subject_id');
                [dependency_names,dependencies] = element_doc.dependency();
                [dependency_names_here,ia] = setdiff(dependency_names,{'subject_id','underlying_element_id'});
                dependencies = dependencies(ia);
                set_identifier = 1;
                identifier_value = element_doc.id();
            elseif numel(varargin)==0,
                element_session='';
                element_name = '';
                element_reference = 1;
                element_type = '';
                element_underlying_element = [];
                direct = 0;
                warning('empty call to ndi.element(); did not think this would happen...');
            else,
                error(['Improper number of input arguments']);
            end;

            if (set_identifier),
                ndi_element_obj.identifier = identifier_value;
            end;
            ndi_element_obj.session = element_session;
            ndi_element_obj.name = element_name;
            ndi_element_obj.reference = element_reference;
            ndi_element_obj.type = element_type;
            ndi_element_obj.underlying_element = element_underlying_element;
            ndi_element_obj.direct = direct;
            ndi_element_obj.subject_id = subject_id;
            ndi_element_obj.dependencies = dependencies;
            if needs_newdocument_call, % do we need to create the document and add it to the database?
                % or, do we already have it?
                element_doc = ndi_element_obj.newdocument();
            end;
        end; % ndi.element()

        % ndi.epoch.epochset-based methods

        function b = issyncgraphroot(ndi_element_obj)
        % ISSYNCGRAPHROOT - should this object be a root in an ndi.time.syncgraph epoch graph?
        %
        % B = ISSYNCGRAPHROOT(NDI_ELEMENT_OBJ)
        %
        % This function tells an ndi.time.syncgraph object whether it should continue
        % adding the 'underlying' epochs to the graph, or whether it should stop at this level.
        %
        % For ndi.element objects, this returns 0 so that underlying ndi.probe epochs are added.
            b = isempty(ndi_element_obj.underlying_element);
        end; % issyncgraphroot

        function name = epochsetname(ndi_element_obj)
        % EPOCHSETNAME - the name of the ndi.element object, for EPOCHNODES
        %
        % NAME = EPOCHSETNAME(NDI_ELEMENT_OBJ)
        %
        % Returns the object name that is used when creating epoch nodes.
        %
        % For ndi.element objects, this is ndi.element/ELEMENTSTRING.
            name = ['element: ' ndi_element_obj.elementstring()];
        end; % epochsetname

        function ec = epochclock(ndi_element_obj, epoch_number)
        % EPOCHCLOCK - return the ndi.time.clocktype objects for an epoch
        %
        % EC = EPOCHCLOCK(NDI_ELEMENT_OBJ, EPOCH_NUMBER)
        %
        % Return the clock types available for this epoch.
        %
        % The ndi.element class always returns the clock type(s) of the element it is based on
        %
            et = epochtableentry(ndi_element_obj, epoch_number);
            ec = et.epoch_clock;
        end; % epochclock()

        function t0t1 = t0_t1(ndi_element_obj, epoch_number)
            %
            % T0_T1 - return the t0_t1 (beginning and end) epoch times for an epoch
            %
            % T0T1 = T0_T1(NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
            %
            % Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
            % in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
            %
            % The abstract class always returns {[NaN NaN]}.
            %
            % See also: ndi.time.clocktype, EPOCHCLOCK
            %
            % TODO: this must be a bug, it's just self-referential
            et = epochtableentry(ndi_element_obj, epoch_number);
            t0t1 = et.t0_t1;
        end; % t0t1()

        function [cache,key] = getcache(ndi_element_obj)
            % GETCACHE - return the NDI_CACHE and key for ndi.element
            %
            % [CACHE,KEY] = GETCACHE(NDI_ELEMENT_OBJ)
            %
            % Returns the CACHE and KEY for the ndi.element object.
            %
            % The CACHE is returned from the associated session.
            % The KEY is the probe's ELEMENTSTRING plus the TYPE of the ELEMENT.
            %
            % See also: ndi.file.navigator

            cache = [];
            key = [];
            if isa(ndi_element_obj.session,'handle'),,
                E = ndi_element_obj.session;
                cache = E.cache;
                key = [ndi_element_obj.elementstring() ' | ' ndi_element_obj.type];
            end
        end; % getcache()

        function et = buildepochtable(ndi_element_obj)
            % BUILDEPOCHTABLE - build the epoch table for an ndi.element
            %
            % ET = BUILDEPOCHTABLE(NDI_ELEMENT_OBJ)
            %
            % ET is a structure array with the following fields:
            % Fieldname:                | Description
            % ------------------------------------------------------------------------
            % 'epoch_number'            | The number of the epoch (may change)
            % 'epoch_id'                | The epoch ID code (will never change once established)
            %                           |   This uniquely specifies the epoch (with the session id).
            % 'epoch_session_id'           | Session of the epoch
            % 'epochprobemap'           | The epochprobemap object from each epoch
            % 'epoch_clock'             | A cell array of ndi.time.clocktype objects that describe the type of clocks available
            % 't0_t1'                   | A cell array of ordered pairs [t0 t1] that indicates, for each ndi.time.clocktype, the start and stop
            %                           |   time of this epoch. The time units of t0_t1{i} match epoch_clock{i}.
            % 'underlying_epochs'       | A structure array of the ndi.epoch.epochset objects that comprise these epochs.
            %                           |   It contains fields 'underlying', 'epoch_number', and 'epoch_id'

                ue = vlt.data.emptystruct('underlying','epoch_id','epoch_session_id','epochprobemap','epoch_clock','t0_t1');
                et = vlt.data.emptystruct('epoch_number','epoch_id','epoch_session_id','epochprobemap','epoch_clock','t0_t1','underlying_epochs');

                % pull all the devices from the session and look for device strings that match this probe

                epoch_mapping = true;

                underlying_et = et;
                if ~isempty(ndi_element_obj.underlying_element)
                    underlying_et = ndi_element_obj.underlying_element.epochtable();
                end;

                if ndi_element_obj.direct
                    ib = 1:numel(underlying_et);
                    ia = 1:numel(underlying_et);
                else
                    et_added = ndi_element_obj.loadaddedepochs();
                    if isempty(ndi_element_obj.underlying_element)
                        c = {et_added.epoch_id};
                        ia = 1:numel(et_added);
                        ib = [];
                    else
                        % if there are underlying epochs, we need to make sure we have the right mapping
                        % of epochids between the underlying and the current level
                        [c,ia,ib] = intersect({et_added.epoch_id}, {underlying_et.epoch_id});

                        if isempty(ia)
                            % it is legal for there to be no mapping
                            epoch_mapping = false;
                            ia = 1:numel(et_added);
                            ib = 1:numel(et_added);
                        end
                    end
                end

                for n=1:numel(ia)
                    et_ = vlt.data.emptystruct('epoch_number','epoch_id','epoch_session_id','epochprobemap','underlying_epochs');
                    et_(1).epoch_number = n;
                    et_(1).epoch_session_id = ndi_element_obj.session.id();
                    if ~isempty(ndi_element_obj.underlying_element)
                        if epoch_mapping
                            et_(1).epoch_id = underlying_et(ib(n)).epoch_id;
                        else
                            et_(1).epoch_id = et_added(ia(n)).epoch_id;
                        end
                    else,
                        et_(1).epoch_id = et_added(ia(n)).epoch_id;
                    end;
                    if ndi_element_obj.direct,
                        et_(1).epoch_clock = underlying_et(ib(n)).epoch_clock;
                        et_(1).t0_t1 = underlying_et(ib(n)).t0_t1;
                        et_(1).epochprobemap = underlying_et(ib(n)).epochprobemap;
                    else,
                        et_(1).epochprobemap = []; % not applicable for non-direct elements
                        et_(1).epoch_clock = et_added(ia(n)).epoch_clock;
                        et_(1).t0_t1 = et_added(ia(n)).t0_t1(:)';
                    end;
                    underlying_epochs = vlt.data.emptystruct('underlying','epoch_id','epoch_session_id', 'epochprobemap','epoch_clock');
                    if ~isempty(ndi_element_obj.underlying_element),
                        underlying_epochs(1).underlying = ndi_element_obj.underlying_element;
                        underlying_epochs.epoch_id = underlying_et(ib(n)).epoch_id;
                        underlying_epochs.epoch_session_id = underlying_et(ib(n)).epoch_session_id;
                        underlying_epochs.epochprobemap = underlying_et(ib(n)).epochprobemap;
                        underlying_epochs.epoch_clock = underlying_et(ib(n)).epoch_clock;
                        underlying_epochs.t0_t1 = underlying_et(ib(n)).t0_t1;
                    end;
                    et_(1).underlying_epochs = underlying_epochs;
                    et(end+1) = et_;
                end
        end; % buildepochtable()

        %% unique ndi.element methods

        function elementstr = elementstring(ndi_element_obj)
            % ELEMENTSTRING - Produce a human-readable element string
            %
            % ELEMENTSTR = ELEMENTSTRING(NDI_ELEMENT_OBJ)
            %
            % Returns the name as a human-readable string.
            %
            % For ndi.element objects, this is the string 'element: ' followed by its name
            %
            elementstr = [ndi_element_obj.name ' | ' int2str(ndi_element_obj.reference)];
        end; %elementstring()

        function [ndi_element_obj, epochdoc] = addepoch(ndi_element_obj, epochid, epochclock, t0_t1, add_to_db)
            % ADDEPOCH - add an epoch to the ndi.element
            %
            % [NDI_ELEMENT_OBJ, EPOCHDOC] = ADDEPOCH(NDI_ELEMENT_OBJ, EPOCHID, EPOCHCLOCK, T0_T1, [ADD_TO_DB])
            %
            % Registers the data for an epoch with the NDI_ELEMENT_OBJ.
            %
            % Inputs:
            %   NDI_ELEMENT_OBJ: The ndi.element object to modify
            %   EPOCHID:       The name of the epoch to add; should match the name of an epoch from the probe
            %   EPOCHCLOCK:    The epoch clock; must be a single clock type that matches one of the clock types
            %                     of the probe
            %   T0_T1:         The starting time and ending time of the existence of information about the ELEMENT on
            %                     the probe, in units of the epock clock
            %   ADD_TO_DB:     0/1 Should we actually add the epoch document to the database? Default 0.
            %
            if nargin < 5,
                add_to_db = 0;
            end;
            epochdoc = [];
            if ndi_element_obj.direct,
                error(['Cannot add external observations to an ndi.element that is directly based on ndi.probe.*']);
            end;
            E = ndi_element_obj.session;
            if ~isempty(E),
                elementdoc = E.database_search(ndi_element_obj.searchquery());
                if isempty(elementdoc),
                    error(['ndi.element is not part of the database.']);
                elseif numel(elementdoc)>1,
                    error(['More than one document corresponds to this ndi.element; shouldn''t happen.']);
                else,
                    elementdoc = elementdoc{1};
                end;
                if isa(epochclock,'ndi.time.clocktype')
                    epochclockstr = epochclock.ndi_clocktype2char();
                else
                    epochclockstr = epochclock;
                end
                if numel(t0_t1)==2,
                    t0_t1_input = vlt.data.colvec(t0_t1);
                else
                    t0_t1_input = t0_t1;
                end
                epochdoc = E.newdocument('element_epoch', ...
                    'element_epoch.epoch_clock', epochclockstr, ...
                    'element_epoch.t0_t1', t0_t1_input, 'epochid.epochid',epochid);
                epochdoc = epochdoc.set_dependency_value('element_id',elementdoc.id());
                if add_to_db,
                    E.database_add(epochdoc);
                end;
            end
        end; % addepoch()

        function [et_added, epochdocs] = loadaddedepochs(ndi_element_obj)
            % LOADADDEDEPOCHS - load the added epochs from an ndi.element
            %
            % [ET_ADDED, EPOCHDOCS] = LOADADDEDEOPCHS(NDI_ELEMENT_OBJ)
            %
            % Load the EPOCHTABLE that consists of added/registered epochs that provide information
            % about the ndi.element.
            %
            %
            et_added = vlt.data.emptystruct('epoch_number','epoch_id','epochprobemap','epoch_clock','t0_t1','underlying_epochs');
            epochdocs = {};
            if ndi_element_obj.direct,
                % nothing can be added
                return;
            end;
            % loads from database
            potential_epochdocs = ndi_element_obj.load_all_element_docs();
            for i=1:numel(potential_epochdocs),
                if isfield(potential_epochdocs{i}.document_properties,'element_epoch');
                    clear newet;
                    newet.epoch_number = i;
                    newet.epoch_id = potential_epochdocs{i}.document_properties.epochid.epochid;
                    newet.epochprobemap = '';
                    clock_types = strtrim(split(potential_epochdocs{i}.document_properties.element_epoch.epoch_clock,','));
                    ec = {};
                    t0_t1 = {};
                    for k=1:numel(clock_types)
                        ec{k} = ndi.time.clocktype(clock_types{k});
                        t0_t1{k} = vlt.data.rowvec(potential_epochdocs{i}.document_properties.element_epoch.t0_t1(:,k));
                    end
                    newet.epoch_clock = ec;
                    newet.t0_t1 = t0_t1;
                    newet.underlying_epochs = []; % leave this for buildepochtable
                    et_added(end+1) = newet;
                    epochdocs{end+1} = potential_epochdocs{i};
                end;
            end;
        end; % LOADEDEPOCHS(NDI_ELEMENT_OBJ)

        function element_doc = load_element_doc(ndi_element_obj)
            % LOAD_ELEMENT_DOC - load a element doc from the session database
            %
            % ELEMENT_DOC = LOAD_ELEMENT_DOC(NDI_ELEMENT_OBJ)
            %
            % Load an ndi.document that is based on the ndi.element object.
            %
            % Returns empty if there is no such document.
            %
            sq = ndi_element_obj.searchquery();
            E = ndi_element_obj.session;
            element_doc = E.database_search(sq);
            if numel(element_doc)>1,
                error(['More than one document matches the ELEMENT definition. This should not happen.']);
            elseif ~isempty(element_doc),
                element_doc = element_doc{1};
            end;
        end; % load_element_doc()

        function element_ref = doc_unique_id(ndi_element_obj)
            % DOC_UNIQUE_ID - return the document unique reference for an ndi.element object
            %
            % UNIQUE_REF = DOC_UNIQUE_ID(NDI_ELEMENT_OBJ)
            %
            % Returns the document unique reference for NDI_ELEMENT_OBJ. If there is no associated
            % document for the element, then empty is returned.
            warning('depricated..use ID() instead');
            element_ref = [];
            element_doc = ndi_element_obj.load_element_doc();
            if ~isempty(element_doc),
                element_ref = element_doc.id();
            end;
        end; % doc_unique_ref()

        function element_id = id(ndi_element_obj)
            % ID - return the document unique identifier for an ndi.element object
            %
            % UNIQUE_REF = ID(NDI_ELEMENT_OBJ)
            %
            % Returns the document unique reference for NDI_ELEMENT_OBJ. If there is no associated
            % document for the element, then an error is returned.
            element_id = [];
            element_doc = ndi_element_obj.load_element_doc();
            if isempty(element_doc),
                error('no element document.');
            end;
            element_id = element_doc.id();
        end; % id()

        function element_docs = load_all_element_docs(ndi_element_obj)
            % LOAD_ALL_ELEMENT_DOCS - load all of the ndi.element objects from an session database
            %
            % ELEMENT_DOCS = LOAD_ALL_ELEMENT_DOCS(NDI_ELEMENT_OBJ)
            %
            % Loads the ndi.document that is based on the ndi.element object and any associated
            % epoch documents.
            %
            element_doc = ndi_element_obj.load_element_doc();
            if ~isempty(element_doc),
                sq = ndi.query('depends_on','depends_on','element_id',ndi_element_obj.id());
                E = ndi_element_obj.session;
                epochdocs = E.database_search(sq);
                element_docs = cat(1, {element_doc}, epochdocs(:));
            else,
                epochdocs = {};
                element_docs = {};
            end;
        end; % LOAD_ALL_ELEMENT_DOCS

        %%% ndi.documentservice methods

        function ndi_document_obj = newdocument(ndi_element_obj)
            % NEWDOCUMENT - return a new database document of type ndi.document based on a element
            %
            % NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_ELEMENT_OBJ)
            %
            % Fill out the fields of an NDI_DOCUMENT_OBJ of type 'element'
            % with the corresponding 'name' and 'type' fields of the element NDI_ELEMENT_OBJ and the
            % 'name', 'type', and 'reference' fields of its underlying NDI_PROBE_OBJ.
            % If EPOCHID is provided, then an EPOCHID field is filled out as well
            % in accordance to 'epochid'.
            %
            % When the document is created, it is automatically added to the session.
            %
            ndi_document_obj = ndi_element_obj.load_element_doc();
            if isempty(ndi_document_obj),
                ndi_document_obj = ndi.document('element',...
                    'element.ndi_element_class', class(ndi_element_obj), ...
                    'element.name',ndi_element_obj.name,...
                    'element.reference', ndi_element_obj.reference, ...
                    'element.type',ndi_element_obj.type, ...
                    'element.direct',ndi_element_obj.direct);
                ndi_document_obj = ndi_document_obj + ...
                    newdocument(ndi_element_obj.session);
                underlying_id = [];
                if ~isempty(ndi_element_obj.underlying_element),
                    underlying_id = ndi_element_obj.underlying_element.id();
                    if isempty(underlying_id), % underlying element hasn't been saved yet
                        newdoc = ndi_element_obj.underlying_element.newdocument();
                        underlying_id = newdoc.id();
                    end;
                end;
                ndi_document_obj = ndi_document_obj.setproperties('base.id',ndi_element_obj.identifier);
                ndi_document_obj = set_dependency_value(ndi_document_obj,'underlying_element_id',underlying_id);
                ndi_document_obj = set_dependency_value(ndi_document_obj,'subject_id',ndi_element_obj.subject_id);
                for i=1:numel(ndi_element_obj.dependencies),
                    ndi_document_obj = ndi_document_obj.set_dependency_value(ndi_element_obj.dependencies(i).name,...
                        ndi_element_obj.dependencies(i).value,'ErrorIfNotFound',0);
                end;
                ndi_element_obj.session.database_add(ndi_document_obj);
            end;
        end; % newdocument()

        function sq = searchquery(ndi_element_obj, epochid)
            % SEARCHQUERY - return a search query for an ndi.document based on this element
            %
            % SQ = SEARCHQUERY(NDI_ELEMENT_OBJ, [EPOCHID])
            %
            % Returns a search query for the fields of an NDI_DOCUMENT_OBJ of type 'element'
            % with the corresponding 'name' and 'type' fields of the element NDI_ELEMENT_OBJ.
            %
            sq = ndi.query(ndi_element_obj.session.searchquery());
            sq = sq & ndi.query('element.name','exact_string',ndi_element_obj.name,'');
            sq = sq & ndi.query('element.type','exact_string',ndi_element_obj.type,'');
            sq = sq & ndi.query('element.ndi_element_class','exact_string',class(ndi_element_obj),'');
            sq = sq & ndi.query('element.reference','exact_number',ndi_element_obj.reference','');

            if nargin>1,
                sq = sq & ndi.query('epochid.epochid','exact_string',epochid,'');
            end;

        end; % searchquery()

    end; % methods

end % classdef
