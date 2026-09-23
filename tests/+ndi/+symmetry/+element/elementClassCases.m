classdef elementClassCases
    % elementClassCases - shared element.ndi_element_class battery, identical in both languages
    %
    %   Python counterpart: tests/symmetry/element/element_class_cases.py
    %
    %   WHAT CROSSES THE LANGUAGE BOUNDARY
    %   An element document records the name of the class that wrote it, in
    %   element.ndi_element_class. That string is the only thing that tells a
    %   reader what to rebuild: MATLAB calls feval on it
    %   (+ndi/+database/+fun/ndi_document2ndi_object.m) and Python looks it up
    %   in ndi.class_registry. So each language writes a session containing one
    %   element of each kind, and the other language opens that session, asks
    %   it for its elements, and checks that each came back as the class that
    %   wrote it.
    %
    %   WHY IT IS A SESSION AND NOT A JSON TRANSCRIPT
    %   The transcript is written too, but it is the weaker half. Comparing two
    %   transcripts would only show that both languages spell the class names
    %   the same way; it would not have caught NDI-python issue #133, where
    %   Python spelled 'ndi.neuron' correctly nowhere and could not rebuild a
    %   MATLAB-written neuron at all -- its getelements swallowed the failure
    %   and returned an empty list. What pins that is one language reading the
    %   OTHER language's database and getting objects back.
    %
    %   THE ASSERTION IS ON THE REBUILT OBJECT, NOT THE STORED STRING
    %   Each side reports class(obj) of what getelements handed it. Reading the
    %   string straight out of the document would pass even if the reader
    %   silently downgraded every element to the base class -- which is exactly
    %   the failure this battery exists to catch.
    %
    %   See also: ndi.symmetry.makeArtifacts.element.elementClass,
    %     ndi.symmetry.readArtifacts.element.elementClass

    properties (Constant)
        % Written next to the session copy by each side's makeArtifacts test.
        IndexFile = 'elementClasses.json';

        % The session reference both languages build under.
        SessionReference = 'elementclass1';

        % The subject both languages hang the elements off.
        SubjectName = 'anteater27@nosuchlab.org';
    end

    methods (Static)

        function c = cases()
            % CASES - one element per element class, with the name it must carry.
            %
            %   The MATLAB name is the contract on both sides: +ndi/element.m
            %   stores class(ndi_element_obj).
            c = struct( ...
                'name', {'elec1', 'ts1', 'neuron1'}, ...
                'reference', {1, 1, 1}, ...
                'type', {'n-trode', 'spikes', 'neuron'}, ...
                'ndi_element_class', {'ndi.element', 'ndi.element.timeseries', 'ndi.neuron'}, ...
                'note', { ...
                    ['The base class. It is here as the control: if a reader ' ...
                     'downgrades everything to ndi.element, this case still ' ...
                     'passes and the other two fail, which distinguishes a ' ...
                     'broken reader from a broken writer.'], ...
                    ['Python wrote this as ''ndi.element'' until issue #133, ' ...
                     'because ndi_element_timeseries did not override ' ...
                     'ndi_element_class(), so it round-tripped without ' ...
                     'readtimeseries -- the one method the class exists for.'], ...
                    ['The case that lost data in both directions (issue #133). ' ...
                     'Python wrote neurons labelled ''ndi.element''; and ' ...
                     '''ndi.neuron'', which is what MATLAB writes, was in no ' ...
                     'registry, so every MATLAB-written neuron was dropped ' ...
                     'from getelements without a word.']});
        end

        function names = caseNames()
            % CASENAMES - the element names, in the order they are built.
            c = ndi.symmetry.element.elementClassCases.cases();
            names = {c.name};
        end

        function w = expected()
            % EXPECTED - the expected observation for each case.
            c = ndi.symmetry.element.elementClassCases.cases();
            w = rmfield(c, 'note');
            w = ndi.symmetry.element.elementClassCases.sortByName(w);
        end

        function obs = observe(elements)
            % OBSERVE - reduce getelements output to the shared transcript.
            %
            %   ELEMENTS is the cell array ndi.session/getelements returns.
            %   class(e) is asked of the OBJECT, so what is recorded is the
            %   class the reader actually built -- not the string it read out
            %   of the document.
            obs = struct('name', {}, 'reference', {}, 'type', {}, 'ndi_element_class', {});
            for i = 1:numel(elements)
                e = elements{i};
                obs(end+1) = struct( ...
                    'name', e.name, ...
                    'reference', double(e.reference), ...
                    'type', e.type, ...
                    'ndi_element_class', class(e)); %#ok<AGROW>
            end
            obs = ndi.symmetry.element.elementClassCases.sortByName(obs);
        end

        function s = sortByName(s)
            % SORTBYNAME - a stable order, so two transcripts line up.
            if isempty(s)
                return;
            end
            [~, idx] = sort({s.name});
            s = s(idx);
        end

        function file = writeIndex(destDir, obs)
            % WRITEINDEX - write this language's transcript beside its session copy.
            payload = struct('schemaVersion', 1, 'language', 'matlab', ...
                'sessionReference', ndi.symmetry.element.elementClassCases.SessionReference, ...
                'elements', {reshape(obs, 1, [])});
            jsonStr = jsonencode(payload, 'PrettyPrint', true);
            file = fullfile(destDir, ndi.symmetry.element.elementClassCases.IndexFile);
            fid = fopen(file, 'w');
            if fid < 0
                error('ndi:symmetry:element:elementClassCases:cannotWriteIndex', ...
                    'Could not write the element-class index file.');
            end
            fwrite(fid, unicode2native(jsonStr, 'UTF-8'), 'uint8');
            fclose(fid);
        end

        function s = loadIndex(file)
            % LOADINDEX - read a transcript written by either language.
            fid = fopen(file, 'r');
            if fid < 0
                error('ndi:symmetry:element:elementClassCases:cannotReadIndex', ...
                    'Could not read ''%s''.', file);
            end
            raw = fread(fid, Inf, 'uint8=>uint8');
            fclose(fid);
            s = jsondecode(native2unicode(raw(:)', 'UTF-8'));
        end

        function problems = compare(obs)
            % COMPARE - every difference between OBS and the shared case list.
            problems = ndi.symmetry.element.elementClassCases.compareLists(obs, ...
                ndi.symmetry.element.elementClassCases.expected());
        end

        function problems = compareLists(obs, want)
            % COMPARELISTS - every difference between two transcripts, by name.
            %
            %   Returns a 1xN cellstr of problems; empty means agreement.
            %   WANT may be a struct array from either the case list or a
            %   decoded index file, so the fields are read by name rather than
            %   by position and an extra field (a note, a schema marker) does
            %   not count as a difference.
            problems = {};
            obs = ndi.symmetry.element.elementClassCases.sortByName(obs);
            want = ndi.symmetry.element.elementClassCases.sortByName(want);

            obsNames = {}; if ~isempty(obs), obsNames = {obs.name}; end
            wantNames = {}; if ~isempty(want), wantNames = {want.name}; end

            missing = sort(setdiff(wantNames, obsNames));
            for i = 1:numel(missing)
                k = find(strcmp(wantNames, missing{i}), 1);
                problems{end+1} = sprintf(['%s: no element of this name came back from ' ...
                    'getelements (expected %s). An element that cannot be reconstructed ' ...
                    'is dropped, which is how NDI-python issue #133 stayed invisible.'], ...
                    missing{i}, want(k).ndi_element_class); %#ok<AGROW>
            end

            extra = sort(setdiff(obsNames, wantNames));
            for i = 1:numel(extra)
                problems{end+1} = sprintf('%s: unexpected extra element', extra{i}); %#ok<AGROW>
            end

            fields = {'reference', 'type', 'ndi_element_class'};
            for i = 1:numel(obsNames)
                k = find(strcmp(wantNames, obsNames{i}), 1);
                if isempty(k)
                    continue;
                end
                for f = 1:numel(fields)
                    got = obs(i).(fields{f});
                    wantValue = want(k).(fields{f});
                    if ischar(got) || isstring(got)
                        same = strcmp(char(got), char(wantValue));
                        gotStr = char(got);
                        wantStr = char(wantValue);
                    else
                        same = isequal(double(got), double(wantValue));
                        gotStr = mat2str(double(got));
                        wantStr = mat2str(double(wantValue));
                    end
                    if ~same
                        problems{end+1} = sprintf('%s: %s is ''%s'', expected ''%s''', ...
                            obsNames{i}, fields{f}, gotStr, wantStr); %#ok<AGROW>
                    end
                end
            end
        end

    end % methods (Static)
end % classdef
