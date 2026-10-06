classdef subject < ndi.ido & ndi.documentservice & ndi.entity
    % ndi.subject - an object describing the subject of a measurement or stimulation
    %
    % ndi.subject is an object that stores information about the subject of an ndi.element.
    %   Each ndi.element object must have a subject; the subject associated with the element
    %   is a key defining feature of an ndi.element object.
    %
    % ndi.subject Properties:
    %  local_identifier - A string that is a unique global identifier but that also has meaning within an individual
    %                     lab. Must include an '@' character that identifies the lab. For example: anteater23@nosuchlab.org
    %  description - A string of description that is free for the user to choose.
    %
    % ndi.subject Methods:
    %  subject - Create a new ndi.subject object
    %  newdocument - Create an ndi.document based on an ndi.subject
    %  searchquery - Search for an ndi.document representation of an ndi.subject
    %  isvalidlocalidentifierstring - Is a string a valid local_identifier string? (Static)
    %  does_subjectstring_match_session_document - Does an ndi.subject object already have a representation in an ndi.database? (Static)
    %

    properties (GetAccess=public, SetAccess=protected)
        local_identifier    % A string that is a local identifier in the lab, e.g. anteater23@nosuchlab.org
        description             % A string description
    end % properties

    properties (Dependent, SetAccess = private)
        type    % V2: the subject's coarse kind ('organism', 'group', ...); '' without a V2 document
    end

    methods

        function ndi_subject_obj = subject(varargin)
            % ndi.subject - create a new ndi.subject object
            %
            % NDI_SUBJECT_OBJ = ndi.subject(LOCAL_IDENTIFIER, DESCRIPTION)
            %   or
            % NDI_SUBJECT_OBJ = ndi.subject(NDI_SESSION_OBJ, NDI_SUBJECT_DOCUMENT)
            %
            % Creates an ndi.subject object, either from a local identifier name or
            % an ndi.session object and an ndi.document that describes the ndi.subject object.
            %
            %
            local_identifier_ = '';
            description_ = '';

            if numel(varargin)==2
                E = varargin{1};
                if ~isa(E,'ndi.session')
                    local_identifier_ = varargin{1};
                    [b,msg] = ndi.subject.isvalidlocalidentifierstring(local_identifier_);
                    if ~b
                        error(msg);
                    end
                    description_ = varargin{2};
                    if ~ischar(description_)
                        error(['description must be a string.']);
                    end
                else
                    if ~isa(E,'ndi.session')
                        error(['First input argument must be an ndi.session input']);
                    end
                    if ~isa(varargin{2},'ndi.document')
                        subject_search = E.database_search(ndi.query('base.id',...
                            'exact_string',varargin{2},''));
                        if numel(subject_search)~=1
                            error(['When 2 input arguments are given, 2nd input must be an ndi.document or document ID.']);
                        end
                        subject_doc = subject_search{1};
                    else
                        subject_doc = varargin{2};
                    end
                    local_identifier_ = subject_doc.document_properties.subject.local_identifer;
                    description_ = subject_doc.document_properties.subject.description;
                end
            end
            ndi_subject_obj.local_identifier = local_identifier_;
            ndi_subject_obj.description = description_;
        end % ndi.subject()

        %%% ndi.documentservice methods

        function ndi_document_obj = newdocument(ndi_subject_obj)
            % NEWDOCUMENT - return a new database document of type ndi.document based on a subject
            %
            % NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_SUBJECT_OBJ)
            %
            % Creates a new ndi.document of type 'subject'.
            %
            ndi_document_obj = ndi.document('subject',...
                'subject.local_identifier', ndi_subject_obj.local_identifier,...
                'subject.description', ndi_subject_obj.description,...
                'base.id', ndi_subject_obj.id(),...
                'base.name', ndi_subject_obj.local_identifier,...
                'base.session_id', ndi.session.empty_id());

        end % newdocument()

        function sq = searchquery(ndi_subject_obj)
            % SEARCHQUERY - return a search query for an ndi.document based on this element
            %
            % SQ = SEARCHQUERY(NDI_SUBJECT_OBJ)
            %
            %
            sq = {'subject.local_identifier',ndi_subject.local_identifer'};
        end % searchquery()

        %%% V2 (V_eta) methods: an ndi.subject read from a V2 document with
        %%% ndi.subject.fromDocument / ndi.subject.find. They return empty on
        %%% a subject that was not (no container to search).

        function t = get.type(ndi_subject_obj)
            % TYPE - the subject's coarse kind: 'organism', 'group', 'culture', 'material', ...
            %   ('' for a subject with no V2 document)
            t = '';
            if isempty(ndi_subject_obj.entity_document_), return; end
            t = ndi.v2.termName(ndi.v2.blockOf(ndi_subject_obj.document_properties(), 'subject', 'type', ''));
        end % get.type()

        function s = statements(ndi_subject_obj, varargin)
            % STATEMENTS - the statements about this subject
            %
            % S = STATEMENTS(NDI_SUBJECT_OBJ, ...) returns a cell array of
            % ndi.statement objects (each the right child: ndi.observation,
            % ndi.manipulation, ndi.calculation, ndi.assertion). Takes the
            % filters of ndi.statement.find: 'Variable', 'Class', 'Method'.
            s = {};
            if isempty(ndi_subject_obj.container_), return; end
            s = ndi.statement.find(ndi_subject_obj.container_, 'Subject', ndi_subject_obj, varargin{:});
        end % statements()

        function T = assertions(ndi_subject_obj)
            % ASSERTIONS - table of what is asserted about the subject (variable, value)
            %
            % e.g. species 'Caenorhabditis elegans', strain 'N2', inclusion in
            % analysis 'excluded'.
            variable = strings(0, 1); value = strings(0, 1); node = strings(0, 1);
            a = ndi_subject_obj.statements('Class', 'assertion');
            for i = 1:numel(a)
                v = a{i}.raw_value();
                variable(end+1, 1) = string(a{i}.variable_name()); %#ok<AGROW>
                value(end+1, 1) = string(ndi.v2.termName(v)); %#ok<AGROW>
                nd = '';
                if isstruct(v) && isfield(v, 'node'), nd = char(v(1).node); end
                node(end+1, 1) = string(nd); %#ok<AGROW>
            end
            T = table(variable, value, node);
        end % assertions()

        function m = members(ndi_subject_obj)
            % MEMBERS - a group's members (the subjects that are member_of it), a cell array
            m = ndi_subject_obj.children('member_of');
        end

        function g = memberOf(ndi_subject_obj)
            % MEMBEROF - the groups this subject is member_of, a cell array
            g = ndi_subject_obj.parents('member_of');
        end

        function p = parts(ndi_subject_obj)
            % PARTS - the subjects that are part_of this one (a plate's patches), a cell array
            p = ndi_subject_obj.children('part_of');
        end

        function w = partOf(ndi_subject_obj)
            % PARTOF - what this subject is part_of (a patch's plate), a cell array
            w = ndi_subject_obj.parents('part_of');
        end

    end % methods

    methods (Static) % static methods

        function obj = fromDocument(container, doc)
            % FROMDOCUMENT - an ndi.subject read from a subject document (V2 or v1)
            %
            % OBJ = ndi.subject.fromDocument(CONTAINER, DOC); CONTAINER is the
            % ndi.session or ndi.dataset DOC was read from; DOC an ndi.document
            % or a document id. The subject keeps DOC's id. The '@' that
            % ndi.subject(LOCAL_IDENTIFIER, DESCRIPTION) requires is a v1 rule
            % for MAKING a subject and is not applied here (V2_Object_Layer.md, D6).
            if ischar(doc) || isstring(doc)
                d = ndi.v2.getDocument(container, char(doc));
                if isempty(d)
                    error('ndi:subject:notFound', 'No document %s in this %s.', char(doc), class(container));
                end
                doc = d;
            end
            p = ndi.v2.props(doc);
            obj = ndi.subject();
            obj.identifier = char(p.base.id);
            obj.local_identifier = char(ndi.v2.blockOf(p, 'subject', 'local_identifier', ''));
            obj.description = char(ndi.v2.blockOf(p, 'subject', 'description', ''));
            obj.container_ = container;
            obj.entity_document_ = doc;
        end % fromDocument()

        function s = find(container, options)
            % FIND - the subjects in a session or dataset
            %
            % S = ndi.subject.find(CONTAINER, ...) returns a cell array of
            % ndi.subject. Options: 'Type' (e.g. 'organism'), 'LocalIdentifier'.
            % Every subject is returned unless a filter says otherwise,
            % instrument subjects included (V2_Object_Layer.md, Q2).
            arguments
                container
                options.Type (1,:) char = ''
                options.LocalIdentifier (1,:) char = ''
            end
            q = ndi.query('', 'isa', 'subject', '');
            if ~isempty(options.LocalIdentifier)
                q = q & ndi.query('subject.local_identifier', 'exact_string', options.LocalIdentifier, '');
            end
            docs = container.database_search(q);
            s = {};
            for i = 1:numel(docs)
                x = ndi.subject.fromDocument(container, docs{i});
                if ~isempty(options.Type) && ~strcmp(x.type, options.Type)
                    continue;
                end
                s{end+1} = x; %#ok<AGROW>
            end
        end % find()

        function [b,msg] = isvalidlocalidentifierstring(local_identifier)
            % ISVALIDLOCALIDENTIFIERSTRING - is this a valid local identifier string?
            %
            % [B,MSG] = ISVALIDLOCALIDENTIFIERSTRING(LOCAL_IDENTIFIER)
            %
            % Returns 1 if the input LOCAL_IDENTIFIER is a character string and
            % if it has an '@' in it. If B is 0, then an error message string is returned
            % in MSG.
            b = 1; msg = '';
            if ~ischar(local_identifier)
                msg = 'local_identifier must be a character string';
                b = 0;
            end
            if ~any(local_identifier=='@')
                msg = 'local_identifier must have an @ character.';
                b = 0;
            end
            if any(local_identifier==' ')
                msg = 'local_identifier must not have any spaces.';
                b = 0;
            end
        end % isvalidlocalidentifierstring()

        function [b,subject_id] = does_subjectstring_match_session_document(ndi_session_obj,subjectstring,makeit)
            % DOES_SUBJECTSTRING_MATCH_SESSION_DOCUMENT - does a subject string match a document?
            %
            % [B, SUBJECT_ID] = DOES_SUBJECTSTRING_MATCH_SESSION_DOCUMENT(NDI_SESSION_OBJ, ...
            %    SUBJECTSTRING, MAKEIT)
            %
            % Given a SUBJECTSTRING, which is either the local identifier for a subject in the
            % ndi.session object, or a document ID in the database, determine if the SUBJECTSTRING
            % corresponds to an ndi.document already in the database. If so, then the ID of that document
            % is returned in SUBJECT_ID and B is 1. If it is not there, and if MAKEIT is 1, then
            % a new entry is made and the document id is returned in SUBJECT_ID. If MAKEIT is 0, and it is
            % not there, then B is 0 and SUBJECT_ID is empty.
            %
            need_to_make_it = 0;
            b = 0;
            subject_id = '';

            islocal = ndi.subject.isvalidlocalidentifierstring(subjectstring);
            if islocal
                subject_doc = ndi_session_obj.database_search(...
                    ndi.query('subject.local_identifier','exact_string',subjectstring,''));
            else
                subject_doc = ndi_session_obj.database_search(...
                    ndi.query('base.id','exact_string',subjectstring,''));
            end
            if numel(subject_doc)==1
                subject_id = subject_doc{1}.document_properties.base.id;
                b = 1;
                return;
            elseif numel(subject_doc)==0
                if islocal&makeit
                    newsubject = ndi.subject(subjectstring,'');
                    subject_doc = newsubject.newdocument();
                    ndi_session_obj.database_add(subject_doc);
                    subject_id = subject_doc.document_properties.base.id;
                    b = 1;
                else
                    return;
                end
            elseif numel(subject_doc)>1
                error(['More than one subject doc matches..should only be 1!']);
            end
        end % does_subjectstring_match_session_document()
    end % static methods
end % classdef ndi.subject
