classdef statusIconCases
    % statusIconCases - shared statusIcon badge battery, identical in both languages
    %
    %   Python counterpart: tests/symmetry/gui/status_icon_cases.py
    %
    %   WHY THIS BATTERY COMPARES PIXELS AND NOT BYTES
    %   Like the VHSB battery (ndi.symmetry.element.vhsbCases), what crosses
    %   the language boundary here is a binary rather than a JSON transcript
    %   of results -- ndi.gui.nav.statusIcon turns a status into a PNG, and
    %   the thing that has to hold is that both ports draw the same picture.
    %
    %   But unlike VHSB, the BYTES are not the contract. This side writes its
    %   badge with imwrite(rgb, path, 'Alpha', alpha); the Python port encodes
    %   the PNG itself with zlib/struct, so its shipped module needs no
    %   imaging stack. Both produce a valid 8-bit RGBA PNG of the same
    %   picture, and both are free to differ in compression level, scanline
    %   filter choice, chunk layout and ancillary chunks. A byte comparison
    %   would go red for a reason that has nothing to do with whether the two
    %   badges look the same.
    %
    %   So both files are DECODED and compared as (width, height) plus every
    %   pixel's (r, g, b, a).
    %
    %   WHY THE EXPECTATION IS RE-DERIVED HERE RATHER THAN CALLED
    %   expectedImage renders each case from this class's own glyph table,
    %   geometry and state->colour vocabulary rather than calling into
    %   ndi.gui.nav.statusIcon. That is what makes the battery non-vacuous in
    %   the direction that matters: each language checks BOTH languages'
    %   artifacts against its own independent reference, so two ports that
    %   agreed with each other on the WRONG picture still go red. On this side
    %   there is no alternative anyway -- glyphMask, glyphLetter and
    %   stateColor are local functions inside statusIcon.m and are not
    %   reachable from a test -- and re-deriving on the Python side too keeps
    %   the two batteries the same shape.
    %
    %   The one thing taken from shipped code is the palette
    %   (ndi.gui.cloudColors), a shared documented constant on both sides.
    %
    %   BADGEVERSION MUST STAY LEVEL ACROSS THE TWO PORTS
    %   Both are at 'v2'. The cache key is navstatus_<version>_<key>.png, so
    %   if one side bumps and the other does not, the same filename means
    %   different pictures in the two caches. The index records the version
    %   each language actually wrote, read out of that filename, so a
    %   one-sided bump is a named failure rather than eleven pixel
    %   mismatches. If this battery is ever red on a case whose picture
    %   obviously matches, check that first.
    %
    %   /!\ AUTHORED WITHOUT A MATLAB RUNTIME -- validate before relying on it.
    %
    %   See also: ndi.gui.nav.statusIcon, ndi.gui.cloudColors,
    %     ndi.symmetry.makeArtifacts.gui.statusIcon,
    %     ndi.symmetry.readArtifacts.gui.statusIcon

    properties (Constant)
        IndexFile = 'statusIconIndex.json';

        % The badge version both ports must agree on. Checked against the
        % version statusIcon actually stamps into its cache filename.
        ExpectedBadgeVersion = 'v2';

        % ------------------------------------------------------------------
        % The battery's own reference rendering vocabulary.
        %
        % These mirror the locals inside statusIcon's renderBadge/glyphMask
        % (and the module constants in the Python port). They are duplicated
        % on purpose -- see the class docstring. A deliberate change to the
        % badge means editing the renderer, both batteries and BADGEVERSION;
        % an accidental one-sided change goes red here.
        % ------------------------------------------------------------------
        Scale = 2;      % integer upscaling of the 5x7 bitmap cells
        PadTB = 1;      % transparent rows above and below the glyphs
        PadLR = 1;      % transparent cols at the far left/right
        Gap   = 2;      % transparent cols between adjacent glyphs
        CellW = 5;
        CellH = 7;
    end

    methods (Static)

        function names = caseNames()
            % CASENAMES - case names in a stable (sorted) order.
            names = sort({ ...
                'allUnknown', 'bothDrawn', 'bothMixed', 'cloudIncloud', ...
                'cloudNotInCloud', 'emptyStatus', 'extraField', ...
                'ingestedUnknownCloud', 'ingestionIngested', ...
                'ingestionLinked', 'ingestionNone'});
        end

        function [status, note] = caseInfo(name)
            % CASEINFO - the status a case is built from, and why it is here.
            %
            %   Eight cases draw a badge; three deliberately draw none, and
            %   that distinction is the whole point of statusIcon returning ''.
            switch name
                case 'ingestionIngested'
                    status = struct('ingestion', 'ingested');
                    note = 'The completed state: capital ''I'' in okGreen. 12x16.';
                case 'ingestionLinked'
                    status = struct('ingestion', 'linked');
                    note = ['Linked but not ingested: lowercase ''i'' in warnAmber, ' ...
                        'so the partial state differs from the complete one in ' ...
                        'shape as well as colour. 12x16.'];
                case 'ingestionNone'
                    status = struct('ingestion', 'none');
                    note = 'On disk, not ingested: lowercase ''i'' in neutralGrey. 12x16.';
                case 'cloudIncloud'
                    status = struct('cloud', 'incloud');
                    note = 'The only drawn cloud state: capital ''C'' in lightBlue. 12x16.';
                case 'bothDrawn'
                    status = struct('ingestion', 'ingested', 'cloud', 'incloud');
                    note = ['Both dimensions active: 24x16, green ''I'' then blue ' ...
                        '''C'', left to right in DIMS order. Pins the composite ' ...
                        'width (two glyphs plus one gap) and the drawing order.'];
                case 'bothMixed'
                    status = struct('ingestion', 'linked', 'cloud', 'incloud');
                    note = ['Two dimensions in different states: amber ''i'' then ' ...
                        'blue ''C''. Pins that each glyph carries its own ' ...
                        'dimension''s colour.'];
                case 'ingestedUnknownCloud'
                    status = struct('ingestion', 'ingested', 'cloud', 'unknown');
                    note = ['An unknown dimension contributes nothing but must not ' ...
                        'suppress the other: 12x16, not 24x16 with a blank slot ' ...
                        'and not an empty badge.'];
                case 'extraField'
                    status = struct('ingestion', 'ingested', 'bookkeeping', 'whatever');
                    note = ['Unrecognised fields are ignored, so callers may pass ' ...
                        'extra bookkeeping fields. Renders identically to ' ...
                        'ingestionIngested.'];
                case 'cloudNotInCloud'
                    status = struct('cloud', 'notincloud');
                    note = ['NO BADGE. A local-only dataset carries no cloud glyph ' ...
                        '-- ''notincloud'' is a known state that is deliberately ' ...
                        'not drawn, rather than an unknown one.'];
                case 'allUnknown'
                    status = struct('ingestion', 'unknown', 'cloud', 'unknown');
                    note = ['NO BADGE. Every dimension unknown, so a freshly-listed ' ...
                        'node carries no icon until a status command computes one.'];
                case 'emptyStatus'
                    status = struct();
                    note = ['NO BADGE. No dimensions at all: the empty status must ' ...
                        'not error and must not draw an empty image.'];
                otherwise
                    error('ndi:symmetry:gui:statusIconCases:unknownCase', ...
                        'Unknown statusIcon case ''%s''.', name);
            end
        end

        function glyphs = expectedGlyphs(name)
            % EXPECTEDGLYPHS - the (letter, colour) pairs a case should draw.
            %
            %   Returns a 1xN struct array with fields 'letter' and 'color',
            %   left to right. Empty means the case must draw no badge at all.
            %
            %   Derived from this class's own vocabulary, not from the
            %   renderer: the state->colour map, the drawing order and the
            %   shape double-coding are restated here so a one-sided change to
            %   any of them is what goes red.
            c = ndi.gui.cloudColors();

            % Dimension name -> default (lowercase) glyph, in drawing order.
            dims = struct('field', {'ingestion', 'cloud'}, 'letter', {'i', 'c'});

            status = ndi.symmetry.gui.statusIconCases.caseInfo(name);
            glyphs = struct('letter', {}, 'color', {});
            for i = 1:numel(dims)
                f = dims(i).field;
                if ~isfield(status, f)
                    continue;
                end
                state = lower(char(status.(f)));
                switch state
                    case 'ingested'
                        col = c.okGreen;
                    case 'linked'
                        col = c.warnAmber;
                    case 'none'
                        col = c.neutralGrey;
                    case 'incloud'
                        col = c.lightBlue;
                    otherwise
                        % 'unknown', 'notincloud', or anything unrecognised
                        % draws nothing at all. That is the mechanism behind
                        % the three no-badge cases.
                        continue;
                end

                % The two states that are double-coded by SHAPE as well as
                % colour, so ingested-vs-not and in-cloud-vs-not stay
                % distinguishable without relying on colour. An accessibility
                % property, not decoration.
                letter = dims(i).letter;
                if strcmp(f, 'ingestion') && strcmp(state, 'ingested')
                    letter = 'I';
                elseif strcmp(f, 'cloud') && strcmp(state, 'incloud')
                    letter = 'C';
                end

                glyphs(end+1) = struct('letter', letter, 'color', col); %#ok<AGROW>
            end
        end

        function tf = drawsBadge(name)
            % DRAWSBADGE - whether a case should produce a file at all.
            tf = ~isempty(ndi.symmetry.gui.statusIconCases.expectedGlyphs(name));
        end

        function art = glyphArt(letter)
            % GLYPHART - the 5-wide by 7-tall bitmap for a battery glyph.
            %
            %   Only the glyphs this battery draws. '#' marks a lit pixel.
            %   Case-sensitive: lowercase 'i' and capital 'I' are distinct.
            switch letter
                case 'i'
                    art = {'..#..'; '.....'; '..#..'; '..#..'; '..#..'; '..#..'; '..#..'};
                case 'I'
                    art = {'#####'; '..#..'; '..#..'; '..#..'; '..#..'; '..#..'; '#####'};
                case 'C'
                    art = {'.###.'; '#...#'; '#....'; '#....'; '#....'; '#...#'; '.###.'};
                otherwise
                    error('ndi:symmetry:gui:statusIconCases:unknownGlyph', ...
                        'The battery has no bitmap for badge glyph ''%s''.', letter);
            end
        end

        function img = expectedImage(name)
            % EXPECTEDIMAGE - render a case locally as an HxWx4 uint8 RGBA image.
            %
            %   Empty means the case must produce no badge. Everything outside
            %   a lit glyph pixel is fully transparent black, which is what
            %   both renderers leave behind when they paint only the lit cells
            %   onto a zeroed canvas.
            glyphs = ndi.symmetry.gui.statusIconCases.expectedGlyphs(name);
            if isempty(glyphs)
                img = uint8([]);   % no badge for this case
                return;
            end

            S     = ndi.symmetry.gui.statusIconCases.Scale;
            padTB = ndi.symmetry.gui.statusIconCases.PadTB;
            padLR = ndi.symmetry.gui.statusIconCases.PadLR;
            gap   = ndi.symmetry.gui.statusIconCases.Gap;
            gW    = ndi.symmetry.gui.statusIconCases.CellW * S;
            gH    = ndi.symmetry.gui.statusIconCases.CellH * S;

            n = numel(glyphs);
            H = gH + 2 * padTB;
            W = 2 * padLR + n * gW + (n - 1) * gap;

            img = zeros(H, W, 4, 'uint8');
            x = padLR;
            for i = 1:n
                art = ndi.symmetry.gui.statusIconCases.glyphArt(glyphs(i).letter);
                mask = false(numel(art), numel(art{1}));
                for r = 1:numel(art)
                    mask(r, :) = art{r} == '#';
                end
                mask = repelem(mask, S, S);

                col = uint8(round(glyphs(i).color * 255));
                rows = padTB + (1:gH);
                cols = x + (1:gW);
                for ch = 1:3
                    plane = img(rows, cols, ch);
                    plane(mask) = col(ch);
                    img(rows, cols, ch) = plane;
                end
                a = img(rows, cols, 4);
                a(mask) = 255;
                img(rows, cols, 4) = a;

                x = x + gW + gap;
            end
        end

        function img = readBadge(file)
            % READBADGE - decode a PNG written by EITHER language as HxWx4 uint8.
            %
            %   imread handles every PNG variant either port can write,
            %   including the adaptively-filtered scanlines this side's
            %   imwrite produces. (The Python battery has to implement the
            %   five PNG filter types by hand for exactly that reason; here
            %   the platform does it.)
            [pix, map, alpha] = imread(file);

            if ~isempty(map)
                % Indexed PNG. Neither port writes one, but decode it rather
                % than fail confusingly if one ever starts.
                idx = double(pix) + 1;
                rgb = zeros([size(pix, 1), size(pix, 2), 3]);
                for ch = 1:3
                    plane = map(:, ch);
                    rgb(:, :, ch) = reshape(plane(idx), size(pix, 1), size(pix, 2));
                end
                pix = uint8(round(rgb * 255));
            end

            pix = ndi.symmetry.gui.statusIconCases.toUint8(pix);
            if size(pix, 3) == 1
                pix = repmat(pix, 1, 1, 3);
            end

            if isempty(alpha)
                alpha = repmat(uint8(255), size(pix, 1), size(pix, 2));
            else
                alpha = ndi.symmetry.gui.statusIconCases.toUint8(alpha);
            end

            img = cat(3, pix(:, :, 1:3), alpha);
        end

        function out = toUint8(in)
            % TOUINT8 - reduce a 16-bit sample to its high byte; pass 8-bit through.
            if isa(in, 'uint16')
                out = uint8(bitshift(in, -8));
            else
                out = uint8(in);
            end
        end

        function v = badgeVersionFromPath(p)
            % BADGEVERSIONFROMPATH - the BADGEVERSION a cache filename carries.
            %
            %   Read out of the filename rather than out of the constant
            %   because BADGEVERSION is a local inside statusIcon.m and a test
            %   cannot reach it -- and because the filename is the thing the
            %   two ports can actually collide on. The Python battery parses
            %   it the same way so both observe the same thing.
            [~, base] = fileparts(p);
            parts = strsplit(base, '_');
            if numel(parts) < 3 || ~strcmp(parts{1}, 'navstatus')
                error('ndi:symmetry:gui:statusIconCases:badCacheName', ...
                    'Unexpected badge cache filename ''%s''.', base);
            end
            v = parts{2};
        end

        function clearBadgeCache()
            % CLEARBADGECACHE - empty the shared on-disk badge cache.
            %
            %   Both ports render into <tempdir>/ndi_navstatus, and on a CI
            %   runner they share one tempdir. Without this, whichever
            %   language runs second finds the first one's PNG already sitting
            %   at the cache key, returns it unrendered, and publishes the
            %   OTHER language's bytes as its own artifact -- a comparison
            %   that can only pass. Clearing also drops a stale badge left by
            %   an earlier run of this same language.
            %
            %   The path is restated here because statusIcon's cacheDir is a
            %   local function.
            d = fullfile(tempdir, 'ndi_navstatus');
            if isfolder(d)
                rmdir(d, 's');
            end
        end

        function [badges, observedVersion] = writeCases(destDir)
            % WRITECASES - render every case into DESTDIR as <name>.png, plus the index.
            %
            %   Returns the name -> drew-a-badge struct that goes into the
            %   index, and the BADGEVERSION observed on the rendered paths.
            %   statusIcon writes into its own temp cache and takes no
            %   destination, so the returned path is COPIED here rather than
            %   widening shipped code with a dest argument.
            if isfolder(destDir)
                rmdir(destDir, 's');
            end
            mkdir(destDir);
            ndi.symmetry.gui.statusIconCases.clearBadgeCache();

            names = ndi.symmetry.gui.statusIconCases.caseNames();
            badges = struct();
            observedVersion = '';
            for i = 1:numel(names)
                status = ndi.symmetry.gui.statusIconCases.caseInfo(names{i});
                p = ndi.gui.nav.statusIcon(status);
                badges.(names{i}) = ~isempty(p);
                if ~isempty(p)
                    observedVersion = ...
                        ndi.symmetry.gui.statusIconCases.badgeVersionFromPath(p);
                    copyfile(p, fullfile(destDir, [names{i} '.png']));
                end
            end

            payload = struct();
            payload.schemaVersion = 1;
            payload.language = 'matlab';
            % Observed from the cache filename, not asserted: the reader
            % compares the two languages' values, so a one-sided bump shows up
            % as a named failure instead of eleven pixel mismatches.
            payload.badgeVersion = observedVersion;
            payload.cases = reshape(names, 1, []);
            % Which cases produced a badge. A silently-missing file and a
            % deliberately-absent badge look identical on disk, and telling
            % those apart is exactly what statusIcon returning '' is for.
            payload.badges = badges;

            jsonStr = jsonencode(payload, 'PrettyPrint', true);
            fid = fopen(fullfile(destDir, ...
                ndi.symmetry.gui.statusIconCases.IndexFile), 'w');
            if fid < 0
                error('ndi:symmetry:gui:statusIconCases:cannotWriteIndex', ...
                    'Could not write the statusIcon index file.');
            end
            cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
            fwrite(fid, unicode2native(jsonStr, 'UTF-8'), 'uint8');
            clear cleaner;
        end

        function problems = compareToExpectation(name, file)
            % COMPARETOEXPECTATION - check one badge against the local reference.
            %
            %   Returns a 1xN cellstr of problems; empty means it matched.
            problems = {};

            want = ndi.symmetry.gui.statusIconCases.expectedImage(name);
            if isempty(want)
                problems = {sprintf('expected no badge, but %s exists', file)};
                return;
            end

            got = ndi.symmetry.gui.statusIconCases.readBadge(file);
            if ~isequal(size(got), size(want))
                problems = {sprintf('size %s ~= %s', ...
                    mat2str(size(got)), mat2str(size(want)))};
                return;
            end
            problems = ndi.symmetry.gui.statusIconCases.pixelDiffs( ...
                got, want, 'got', 'expected');
        end

        function problems = compareFiles(fileA, fileB)
            % COMPAREFILES - compare two languages' badges pixel for pixel.
            %
            %   Deliberately NOT a byte comparison: the two encoders differ in
            %   compression level, scanline filters and chunk layout, none of
            %   which changes the picture. See the class docstring.
            a = ndi.symmetry.gui.statusIconCases.readBadge(fileA);
            b = ndi.symmetry.gui.statusIconCases.readBadge(fileB);
            if ~isequal(size(a), size(b))
                problems = {sprintf('size %s ~= %s', mat2str(size(a)), mat2str(size(b)))};
                return;
            end
            problems = ndi.symmetry.gui.statusIconCases.pixelDiffs(a, b, 'matlab', 'python');
        end

        function problems = pixelDiffs(a, b, labelA, labelB)
            % PIXELDIFFS - up to 8 differing pixels, as 0-based (x,y) messages.
            %
            %   0-based and x-first so a failure reads the same in either
            %   language's output.
            problems = {};
            differing = any(a ~= b, 3);
            idx = find(differing);
            [rows, cols] = ind2sub(size(differing), idx);
            for k = 1:min(numel(idx), 8)
                r = rows(k);
                c = cols(k);
                problems{end+1} = sprintf('pixel (%d,%d) %s is %s, %s is %s', ...
                    c - 1, r - 1, ...
                    labelA, mat2str(double(reshape(a(r, c, :), 1, []))), ...
                    labelB, mat2str(double(reshape(b(r, c, :), 1, [])))); %#ok<AGROW>
            end
            if numel(idx) > 8
                problems{end+1} = '... further pixel differences not listed';
            end
        end

        function payload = loadIndex(file)
            % LOADINDEX - read an index JSON written by either language.
            fid = fopen(file, 'r');
            if fid < 0
                error('ndi:symmetry:gui:statusIconCases:cannotReadIndex', ...
                    'Could not read %s.', file);
            end
            cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
            bytes = fread(fid, inf, '*uint8');
            clear cleaner;
            payload = jsondecode(native2unicode(reshape(bytes, 1, []), 'UTF-8'));
        end

    end % methods (Static)
end % classdef
