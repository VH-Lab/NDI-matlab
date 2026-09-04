classdef profile < matlab.mixin.CustomDisplay & handle
%NDI.CLOUD.PROFILE Singleton manager for NDI Cloud user profiles.
%
%   ndi.cloud.profile keeps a list of NDI Cloud login profiles for the
%   current MATLAB user. Each profile carries a Nickname, an Email, a
%   MATLAB-generated UID, and a Stage ('prod' or 'dev', hidden from the
%   GUI editor). Passwords are not stored in the profile JSON; instead
%   each profile points at a secret keyed by ['NDI Cloud ' UID] in a
%   pluggable backend.
%
%   Backends:
%
%       aes    - AES-128/CBC encrypted file in prefdir. This is the
%                default. The key is derived from
%                SHA-256([hostname username 'NDI Cloud']) so the file is
%                reproducible only on the machine and user that wrote it
%                (and, being a standard AES-128-CBC/PKCS7 + JSON format,
%                is readable from other languages such as ndi-python on
%                that same host+user).
%       vault  - MATLAB's setSecret/getSecret (R2024a+). Read-only here:
%                MATLAB's setSecret is interactive and takes only a secret
%                name, so it cannot persist a password supplied in code.
%                Not auto-selected; forcing it via useBackend errors on
%                write. Kept as a seam only.
%       memory - in-memory containers.Map. Reserved for tests; use
%                ndi.cloud.profile.useBackend('memory') to opt in.
%
%   Current vs default profile
%   --------------------------
%   The class distinguishes between two notions of "selected":
%
%       CurrentUID  - the active profile for THIS MATLAB session.
%                     Held in memory only; never persisted. This lets
%                     two MATLAB instances run concurrently with
%                     different active profiles without fighting each
%                     other.
%       DefaultUID  - the user's preferred profile, persisted to the
%                     JSON file. At session start the constructor
%                     copies a valid DefaultUID into CurrentUID, so
%                     the next session opens with the same active
%                     profile by default.
%
%   The on-disk file holds {Profiles, DefaultUID}; CurrentUID never
%   touches disk.
%
%   Profile metadata is persisted to:
%
%       fullfile(userHome, '.ndi', 'NDI_Cloud_Profiles.json')
%
%   The vault never sees that file; the AES backend writes ciphertext
%   to a sibling file:
%
%       fullfile(userHome, '.ndi', 'NDI_Cloud_Secrets.json')
%
%   The location was moved from MATLAB's prefdir to ~/.ndi/ so that
%   ndi-python (which has always defaulted to ~/.ndi/) and MATLAB share
%   the same saved profiles by default. A legacy pair in prefdir is
%   migrated on first load. See ndi-matlab#920 and ndi-python#168.
%
%   Typical usage:
%
%       uid = ndi.cloud.profile.add('Lab account', 'me@lab.org', 'pw1');
%       ndi.cloud.profile.setCurrent(uid);          % session only
%       ndi.cloud.profile.setDefault(uid);          % persisted
%       ndi.cloud.profile.switchProfile(uid);       % logout + setenv
%
%       devUid = ndi.cloud.profile.add('Dev', 'me@lab.org', 'pw2');
%       ndi.cloud.profile.setStage(devUid, 'dev');
%
%   See also: ndi.gui.profileEditor, ndi.preferences, ndi.ido,
%             ndi.cloud.logout

    properties (Constant)
        % Filename - JSON file holding profile list and DefaultUID.
        % Kept in sync with ndi.cloud.profile.userPrefDir(); inlined here
        % because Constant property initializers cannot reliably call
        % static methods on their own class across every supported MATLAB
        % release.
        Filename = fullfile(char(java.lang.System.getProperty('user.home')), ...
                            '.ndi', 'NDI_Cloud_Profiles.json')

        % SecretsFilename - AES backend's ciphertext file.
        SecretsFilename = fullfile(char(java.lang.System.getProperty('user.home')), ...
                                   '.ndi', 'NDI_Cloud_Secrets.json')

        % LegacyFilename - historical location under MATLAB's prefdir.
        % Kept for one-time migration only; never written to.
        LegacyFilename        = fullfile(prefdir, 'NDI_Cloud_Profiles.json')

        % LegacySecretsFilename - historical AES ciphertext file.
        LegacySecretsFilename = fullfile(prefdir, 'NDI_Cloud_Secrets.json')
    end

    properties (Constant, Access = private)
        % SecretKeyPrefix - prefix used for every per-profile secret key.
        SecretKeyPrefix = 'NDI Cloud '
    end

    properties (SetAccess = private)
        % Profiles - struct array of profiles.
        % Fields: UID, Nickname, Email, Stage, PasswordSecret.
        Profiles struct

        % CurrentUID - active profile for this session (in-memory only).
        CurrentUID char

        % DefaultUID - preferred profile, persisted to disk; copied
        % into CurrentUID at session start.
        DefaultUID char

        % Backend - 'vault', 'aes', or 'memory'.
        Backend char
    end

    properties (Access = private)
        % MemoryStore - per-instance map for the 'memory' backend.
        MemoryStore = containers.Map('KeyType','char','ValueType','char')
    end

    methods (Access = private)

        function obj = profile()
        %PROFILE Construct the singleton (called only by getSingleton).
            obj.Profiles   = ndi.cloud.profile.emptyProfiles();
            obj.CurrentUID = '';
            obj.DefaultUID = '';
            obj.Backend    = ndi.cloud.profile.detectBackend();
            obj.loadFromDisk();
            obj.adoptDefaultAsCurrent();
        end

        function adoptDefaultAsCurrent(obj)
        %ADOPTDEFAULTASCURRENT Copy DefaultUID into CurrentUID if valid.
            if isempty(obj.DefaultUID) || isempty(obj.Profiles)
                return
            end
            if any(strcmp({obj.Profiles.UID}, obj.DefaultUID))
                obj.CurrentUID = obj.DefaultUID;
            end
        end

        function loadFromDisk(obj)
        %LOADFROMDISK Read profiles and DefaultUID from JSON. CurrentUID
        %is intentionally not persisted (per-session state).
            ndi.cloud.profile.migrateLegacyIfNeeded();
            if ~isfile(obj.Filename); return; end
            try
                txt = fileread(obj.Filename);
                if isempty(strtrim(txt)); return; end
                S = jsondecode(txt);
                if isfield(S, 'Profiles') && ~isempty(S.Profiles)
                    obj.Profiles = ndi.cloud.profile.normalizeProfiles(S.Profiles);
                end
                if isfield(S, 'DefaultUID')
                    obj.DefaultUID = char(S.DefaultUID);
                end
            catch ME
                warning('NDI:cloud:profile:loadFailed', ...
                    'Could not load cloud profiles from %s: %s', ...
                    obj.Filename, ME.message);
            end
        end

        function saveToDisk(obj)
        %SAVETODISK Write profiles and DefaultUID. CurrentUID is omitted.
            ndi.cloud.profile.ensurePrefDir();
            S = struct('Profiles', obj.Profiles, ...
                       'DefaultUID', obj.DefaultUID);
            try
                txt = jsonencode(S, 'PrettyPrint', true);
                fid = fopen(obj.Filename, 'w');
                if fid < 0
                    error('NDI:cloud:profile:saveFailed', ...
                        'Could not open %s for writing.', obj.Filename);
                end
                cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
                fwrite(fid, txt, 'char');
                clear cleaner;   % flush + close before tightening permissions
                % Profiles file holds account emails/UIDs; restrict to owner.
                ndi.cloud.profile.restrictToOwner(obj.Filename);
            catch ME
                warning('NDI:cloud:profile:saveFailed', ...
                    'Could not save cloud profiles to %s: %s', ...
                    obj.Filename, ME.message);
            end
        end

        function idx = findIndex(obj, key)
        %FINDINDEX Resolve KEY to a profile index.
        %
        %   KEY may be a UID (exact match), a Nickname (exact match), or an
        %   Email (case-insensitive exact match), tried in that order. UID
        %   wins outright; among nickname/email matches an ambiguous
        %   result throws NDI:cloud:profile:ambiguousProfile rather than
        %   silently picking one. No match throws
        %   NDI:cloud:profile:unknownProfile.
            if isempty(obj.Profiles)
                error('NDI:cloud:profile:unknownProfile', ...
                    'Unknown profile "%s" (no profiles saved).', key);
            end
            uidHit = find(strcmp({obj.Profiles.UID}, key), 1, 'first');
            if ~isempty(uidHit)
                idx = uidHit;
                return;
            end
            nickHits = find(strcmp({obj.Profiles.Nickname}, key));
            if isscalar(nickHits)
                idx = nickHits;
                return;
            elseif numel(nickHits) > 1
                cands = strjoin({obj.Profiles(nickHits).UID}, ', ');
                error('NDI:cloud:profile:ambiguousProfile', ...
                    'Nickname "%s" matches multiple profiles (%s); use the UID to disambiguate.', ...
                    key, cands);
            end
            emailHits = find(strcmpi({obj.Profiles.Email}, key));
            if isscalar(emailHits)
                idx = emailHits;
                return;
            elseif numel(emailHits) > 1
                cands = strjoin({obj.Profiles(emailHits).UID}, ', ');
                error('NDI:cloud:profile:ambiguousProfile', ...
                    'Email "%s" matches multiple profiles (%s); use the UID to disambiguate.', ...
                    key, cands);
            end
            error('NDI:cloud:profile:unknownProfile', ...
                'Unknown profile "%s" (not a UID, Nickname, or Email).', key);
        end

        function setSecretInternal(obj, key, value)
            switch obj.Backend
                case 'vault'
                    % MATLAB's setSecret is interactive: it accepts only the
                    % secret NAME and prompts the user for the value, so it
                    % cannot persist a value supplied in code. The profile
                    % system always has the password in hand, so the vault is
                    % unsupported for writing here; the default backend is
                    % 'aes'. (Fail clearly rather than with the opaque
                    % "requires exactly 1 positional input" from setSecret.)
                    error('NDI:cloud:profile:vaultWriteUnsupported', ...
                        ['The MATLAB vault backend cannot store a secret ' ...
                         'value supplied in code (its setSecret prompts ' ...
                         'interactively). Use the ''aes'' backend, which is ' ...
                         'the default.']);
                case 'aes'
                    ndi.cloud.profile.aesWriteSecret( ...
                        obj.SecretsFilename, key, value);
                case 'memory'
                    obj.MemoryStore(key) = value;
            end
        end

        function value = getSecretInternal(obj, key)
            switch obj.Backend
                case 'vault'
                    value = char(getSecret(key));
                case 'aes'
                    value = ndi.cloud.profile.aesReadSecret( ...
                        obj.SecretsFilename, key);
                case 'memory'
                    if isKey(obj.MemoryStore, key)
                        value = obj.MemoryStore(key);
                    else
                        error('NDI:cloud:profile:secretMissing', ...
                            'No secret stored for "%s".', key);
                    end
            end
        end

        function removeSecretInternal(obj, key)
            switch obj.Backend
                case 'vault'
                    if isSecret(key)
                        removeSecret(key);
                    end
                case 'aes'
                    ndi.cloud.profile.aesRemoveSecret( ...
                        obj.SecretsFilename, key);
                case 'memory'
                    if isKey(obj.MemoryStore, key)
                        remove(obj.MemoryStore, key);
                    end
            end
        end
    end

    methods (Static, Access = private)

        function p = emptyProfiles()
            p = struct('UID', {}, 'Nickname', {}, 'Email', {}, ...
                       'Stage', {}, 'PasswordSecret', {});
        end

        function out = normalizeProfiles(in)
            out = ndi.cloud.profile.emptyProfiles();
            if isstruct(in)
                arr = in;
            elseif iscell(in)
                arr = [in{:}];
            else
                return;
            end
            for k = 1:numel(arr)
                a = arr(k);
                item.UID            = char(getfieldOr(a, 'UID', ''));
                item.Nickname       = char(getfieldOr(a, 'Nickname', ''));
                item.Email          = char(getfieldOr(a, 'Email', ''));
                item.Stage          = char(getfieldOr(a, 'Stage', 'prod'));
                item.PasswordSecret = char(getfieldOr(a, 'PasswordSecret', ''));
                if isempty(item.PasswordSecret) && ~isempty(item.UID)
                    item.PasswordSecret = ['NDI Cloud ' item.UID];
                end
                out(end+1) = item; %#ok<AGROW>
            end
            function v = getfieldOr(s, f, d)
                if isfield(s, f); v = s.(f); else; v = d; end
            end
        end

        function backend = detectBackend()
            % The AES encrypted-file backend is the default. MATLAB's vault
            % setSecret is interactive and accepts only a secret NAME (it
            % prompts for the value), so it cannot persist a password the
            % caller already holds -- which is exactly what the profile
            % system does. The AES file also has a documented, standard
            % format (AES-128-CBC/PKCS7 + JSON) that is reproducible from
            % other languages (e.g. ndi-python) on the same host and user.
            backend = 'aes';
        end

        function key = aesKeyBytes()
            try
                host = char(java.net.InetAddress.getLocalHost().getHostName());
            catch
                host = char(java.lang.System.getProperty('user.name'));
            end
            user = char(java.lang.System.getProperty('user.name'));
            seed = [host ' ' user ' NDI Cloud'];
            md   = java.security.MessageDigest.getInstance('SHA-256');
            md.update(int8(unicode2native(seed, 'UTF-8')));
            digest = typecast(md.digest(), 'int8');
            key = digest(1:16);
        end

        function aesWriteSecret(filename, key, value)
            ndi.cloud.profile.ensurePrefDir();
            keyBytes = ndi.cloud.profile.aesKeyBytes();
            keySpec  = javax.crypto.spec.SecretKeySpec(keyBytes, 'AES');
            cipher   = javax.crypto.Cipher.getInstance('AES/CBC/PKCS5Padding');
            iv       = ndi.cloud.profile.randomBytes(16);
            ivSpec   = javax.crypto.spec.IvParameterSpec(iv);
            cipher.init(javax.crypto.Cipher.ENCRYPT_MODE, keySpec, ivSpec);
            plain = int8(unicode2native(char(value), 'UTF-8'));
            ct    = typecast(cipher.doFinal(plain), 'int8');

            entry = struct( ...
                'iv',         ndi.cloud.profile.b64Encode(iv), ...
                'ciphertext', ndi.cloud.profile.b64Encode(ct));

            S = ndi.cloud.profile.readSecretsFile(filename);
            S.(ndi.cloud.profile.fieldFor(key)) = entry;
            ndi.cloud.profile.writeSecretsFile(filename, S);
        end

        function value = aesReadSecret(filename, key)
            S = ndi.cloud.profile.readSecretsFile(filename);
            f = ndi.cloud.profile.fieldFor(key);
            if ~isfield(S, f)
                error('NDI:cloud:profile:secretMissing', ...
                    'No secret stored for "%s".', key);
            end
            entry    = S.(f);
            keyBytes = ndi.cloud.profile.aesKeyBytes();
            keySpec  = javax.crypto.spec.SecretKeySpec(keyBytes, 'AES');
            cipher   = javax.crypto.Cipher.getInstance('AES/CBC/PKCS5Padding');
            iv       = ndi.cloud.profile.b64Decode(entry.iv);
            ct       = ndi.cloud.profile.b64Decode(entry.ciphertext);
            ivSpec   = javax.crypto.spec.IvParameterSpec(iv);
            cipher.init(javax.crypto.Cipher.DECRYPT_MODE, keySpec, ivSpec);
            plain = typecast(cipher.doFinal(ct), 'int8');
            value = native2unicode(typecast(plain, 'uint8'), 'UTF-8');
            % cipher.doFinal returns a Java byte[], which MATLAB imports as a
            % COLUMN vector, so native2unicode yields a column char. Force a
            % row so the AES backend returns a password with the same shape
            % (1xN char) as the memory and vault backends.
            value = reshape(value, 1, []);
        end

        function aesRemoveSecret(filename, key)
            S = ndi.cloud.profile.readSecretsFile(filename);
            f = ndi.cloud.profile.fieldFor(key);
            if isfield(S, f)
                S = rmfield(S, f);
                ndi.cloud.profile.writeSecretsFile(filename, S);
            end
        end

        function S = readSecretsFile(filename)
            if ~isfile(filename); S = struct(); return; end
            txt = fileread(filename);
            if isempty(strtrim(txt)); S = struct(); return; end
            S = jsondecode(txt);
            if ~isstruct(S); S = struct(); end
        end

        function writeSecretsFile(filename, S)
            txt = jsonencode(S, 'PrettyPrint', true);
            fid = fopen(filename, 'w');
            if fid < 0
                error('NDI:cloud:profile:saveFailed', ...
                    'Could not open %s for writing.', filename);
            end
            cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
            fwrite(fid, txt, 'char');
            clear cleaner;   % flush + close before tightening permissions
            % The secrets file holds AES-encrypted passwords; restrict it to
            % owner read/write so other local users cannot read the ciphertext.
            ndi.cloud.profile.restrictToOwner(filename);
        end

        function restrictToOwner(filename)
        %RESTRICTTOOWNER Best-effort chmod 600 (owner read/write only) on POSIX.
        %   On Windows this is a no-op (NTFS ACL inheritance, no umask
        %   equivalent). Failures are non-fatal (secrets are still AES-encrypted,
        %   so this is defense in depth) but a real failure is surfaced as a
        %   warning rather than swallowed, so it cannot silently leave the file
        %   world-readable.
            if ispc || ~isfile(filename)
                return
            end
            try
                jpath = java.io.File(filename).toPath();
                perms = java.util.HashSet();
                perms.add(java.nio.file.attribute.PosixFilePermission.OWNER_READ);
                perms.add(java.nio.file.attribute.PosixFilePermission.OWNER_WRITE);
                % setPosixFilePermissions throws if it cannot apply the mode, so
                % reaching the next line means the restriction took effect. We do
                % NOT read it back to confirm: getPosixFilePermissions is a Java
                % varargs method (Path, LinkOption...), which MATLAB's Java bridge
                % cannot resolve when the trailing array is omitted -- that
                % readback threw and produced a misleading "may be readable"
                % warning even though the file had just been restricted.
                java.nio.file.Files.setPosixFilePermissions(jpath, perms);
            catch ME
                % An UnsupportedOperationException means the platform/JVM has no
                % POSIX permission view (e.g. a non-POSIX filesystem) -- an
                % expected no-op. Anything else is a real failure worth warning.
                if ~contains(ME.message, 'UnsupportedOperationException')
                    warning('NDI:cloud:profile:restrictToOwnerFailed', ...
                        'Could not restrict %s to owner-only permissions (%s); it may be readable by other users.', ...
                        filename, ME.message);
                end
            end
        end

        function f = fieldFor(key)
            f = matlab.lang.makeValidName(key, 'ReplacementStyle', 'underscore');
        end

        function s = b64Encode(bytes)
            enc = java.util.Base64.getEncoder();
            s = char(enc.encodeToString(bytes));
        end

        function bytes = b64Decode(s)
            dec   = java.util.Base64.getDecoder();
            bytes = typecast(dec.decode(uint8(s)), 'int8');
        end

        function bytes = randomBytes(n)
            % Generate cryptographically secure random bytes for the AES-CBC IV.
            %
            % The previous implementation used int8(randi([-128,127],1,n)),
            % which draws from MATLAB's default RNG -- a deterministic stream
            % that starts from a fixed seed in every fresh MATLAB session. The
            % AES key is derived only from hostname+username (aesKeyBytes), with
            % no per-write randomness, so a repeated IV under that fixed key
            % makes identical passwords encrypt to identical ciphertext blocks
            % (IV reuse). java.security.SecureRandom is a CSPRNG, so IVs do not
            % repeat.
            %
            % The bytes must come OUT of Java as a return value, never be
            % filled INTO a buffer passed in. MATLAB converts a Java primitive
            % array to a MATLAB array at the boundary, so a byte[] obtained via
            % reflection is already a plain int8 array by the time it reaches
            % MATLAB; handing it to nextBytes marshals a *copy* into the JVM,
            % SecureRandom fills the copy, and it is discarded on return --
            % leaving the IV all zeros. A fixed zero IV under the fixed
            % hostname+username key is worse than the randi draw this replaced.
            %
            % generateSeed declares a byte[] return type, so MATLAB converts the
            % already-filled result outward and the by-value boundary cannot
            % swallow it.
            sr = java.security.SecureRandom();
            bytes = reshape(int8(sr.generateSeed(n)), 1, n);
        end
    end

    methods (Static)

        function d = userPrefDir()
        %NDI.CLOUD.PROFILE.USERPREFDIR Cross-language NDI preferences directory.
        %
        %   Returns fullfile(userHome, '.ndi'). Uses Java to resolve the
        %   user's home directory so the same location resolves on every
        %   platform. ndi-python already writes to ~/.ndi/ by default,
        %   so MATLAB sharing this location lets the two clients see
        %   each other's saved profiles without per-user configuration.
            home = char(java.lang.System.getProperty('user.home'));
            d = fullfile(home, '.ndi');
        end

        function ensurePrefDir()
        %NDI.CLOUD.PROFILE.ENSUREPREFDIR Create the ~/.ndi directory on demand.
            d = ndi.cloud.profile.userPrefDir();
            if ~isfolder(d)
                try
                    mkdir(d);
                catch ME
                    warning('NDI:cloud:profile:mkdirFailed', ...
                        'Could not create %s: %s', d, ME.message);
                end
            end
        end

        function migrateLegacyIfNeeded()
        %NDI.CLOUD.PROFILE.MIGRATELEGACYIFNEEDED Copy any old prefdir profiles into ~/.ndi/.
        %
        %   One-time, best-effort. If the new location already has a
        %   profiles file, this is a no-op -- the new location wins.
        %   The legacy files are left in place (this is a copy, not a
        %   move) so a downgrade to a pre-migration MATLAB keeps
        %   working, at the cost of a stale set that will drift.
            newProfiles = ndi.cloud.profile.Filename;
            oldProfiles = ndi.cloud.profile.LegacyFilename;
            if isfile(newProfiles)
                return;
            end
            if ~isfile(oldProfiles)
                return;
            end
            ndi.cloud.profile.ensurePrefDir();
            try
                copyfile(oldProfiles, newProfiles);
            catch ME
                warning('NDI:cloud:profile:migrateFailed', ...
                    'Could not migrate %s to %s: %s', ...
                    oldProfiles, newProfiles, ME.message);
                return;
            end
            oldSecrets = ndi.cloud.profile.LegacySecretsFilename;
            newSecrets = ndi.cloud.profile.SecretsFilename;
            if isfile(oldSecrets) && ~isfile(newSecrets)
                try
                    copyfile(oldSecrets, newSecrets);
                catch ME
                    warning('NDI:cloud:profile:migrateFailed', ...
                        'Could not migrate %s to %s: %s', ...
                        oldSecrets, newSecrets, ME.message);
                end
            end
        end

        function obj = getSingleton()
        %NDI.CLOUD.PROFILE.GETSINGLETON Return the shared profile manager.
            persistent objStore
            if isempty(objStore) || ~isvalid(objStore)
                objStore = ndi.cloud.profile();
            end
            obj = objStore;
        end

        function profiles = list()
        %NDI.CLOUD.PROFILE.LIST Return the profile struct array.
            profiles = ndi.cloud.profile.getSingleton().Profiles;
        end

        function p = get(uid)
        %NDI.CLOUD.PROFILE.GET Return the profile struct for UID.
            arguments
                uid (1,:) char
            end
            obj = ndi.cloud.profile.getSingleton();
            p = obj.Profiles(obj.findIndex(uid));
        end

        function uid = add(nickname, email, password)
        %NDI.CLOUD.PROFILE.ADD Create a new profile and store its password.
            arguments
                nickname (1,:) char
                email    (1,:) char
                password (1,:) char
            end
            obj = ndi.cloud.profile.getSingleton();
            id  = ndi.ido();
            uid = char(id.id());
            secretKey = [obj.SecretKeyPrefix uid];
            entry = struct( ...
                'UID',            uid, ...
                'Nickname',       nickname, ...
                'Email',          email, ...
                'Stage',          'prod', ...
                'PasswordSecret', secretKey);
            obj.Profiles(end+1) = entry;
            obj.setSecretInternal(secretKey, password);
            obj.saveToDisk();
        end

        function remove(key)
        %NDI.CLOUD.PROFILE.REMOVE Delete a profile and its stored secret.
        %If the removed profile was the current and/or default, both
        %selections are cleared. KEY is UID | Nickname | Email (see findIndex).
            arguments
                key (1,:) char
            end
            obj = ndi.cloud.profile.getSingleton();
            idx = obj.findIndex(key);
            resolvedUid = obj.Profiles(idx).UID;
            secretKey   = obj.Profiles(idx).PasswordSecret;
            obj.removeSecretInternal(secretKey);
            obj.Profiles(idx) = [];
            if strcmp(obj.CurrentUID, resolvedUid)
                obj.CurrentUID = '';
            end
            if strcmp(obj.DefaultUID, resolvedUid)
                obj.DefaultUID = '';
            end
            obj.saveToDisk();
        end

        function p = getCurrent()
        %NDI.CLOUD.PROFILE.GETCURRENT Return the active profile or [].
            obj = ndi.cloud.profile.getSingleton();
            p = ndi.cloud.profile.profileForUID(obj, obj.CurrentUID);
        end

        function setCurrent(key)
        %NDI.CLOUD.PROFILE.SETCURRENT Set the current profile (session only).
        %
        %   KEY is UID | Nickname | Email; the resolved UID is stored.
        %   The change does NOT touch disk. CurrentUID is per-session
        %   so two MATLAB instances can hold different active
        %   profiles concurrently.
            arguments
                key (1,:) char
            end
            obj = ndi.cloud.profile.getSingleton();
            obj.CurrentUID = obj.Profiles(obj.findIndex(key)).UID;
        end

        function p = getDefault()
        %NDI.CLOUD.PROFILE.GETDEFAULT Return the default profile or [].
            obj = ndi.cloud.profile.getSingleton();
            p = ndi.cloud.profile.profileForUID(obj, obj.DefaultUID);
        end

        function setDefault(key)
        %NDI.CLOUD.PROFILE.SETDEFAULT Persist the profile as the default.
        %
        %   KEY is UID | Nickname | Email; the resolved UID is persisted.
        %   The constructor copies DefaultUID into CurrentUID at the
        %   start of every MATLAB session. Setting a default does not
        %   change CurrentUID for the current session; use setCurrent
        %   for that, or switchProfile to also reconfigure env vars.
            arguments
                key (1,:) char
            end
            obj = ndi.cloud.profile.getSingleton();
            obj.DefaultUID = obj.Profiles(obj.findIndex(key)).UID;
            obj.saveToDisk();
        end

        function clearDefault()
        %NDI.CLOUD.PROFILE.CLEARDEFAULT Forget any persisted default.
            obj = ndi.cloud.profile.getSingleton();
            obj.DefaultUID = '';
            obj.saveToDisk();
        end

        function pw = getPassword(uid)
        %NDI.CLOUD.PROFILE.GETPASSWORD Retrieve the stored password.
            arguments
                uid (1,:) char
            end
            obj = ndi.cloud.profile.getSingleton();
            idx = obj.findIndex(uid);
            pw = obj.getSecretInternal(obj.Profiles(idx).PasswordSecret);
        end

        function setPassword(uid, password)
        %NDI.CLOUD.PROFILE.SETPASSWORD Update a profile's password.
            arguments
                uid      (1,:) char
                password (1,:) char
            end
            obj = ndi.cloud.profile.getSingleton();
            idx = obj.findIndex(uid);
            obj.setSecretInternal(obj.Profiles(idx).PasswordSecret, password);
        end

        function s = getStage(uid)
        %NDI.CLOUD.PROFILE.GETSTAGE Return the profile's Stage.
            arguments
                uid (1,:) char
            end
            obj = ndi.cloud.profile.getSingleton();
            idx = obj.findIndex(uid);
            s = obj.Profiles(idx).Stage;
        end

        function setStage(uid, stage)
        %NDI.CLOUD.PROFILE.SETSTAGE Set the profile's Stage.
            arguments
                uid   (1,:) char
                stage (1,:) char {mustBeMember(stage, {'prod','dev'})}
            end
            obj = ndi.cloud.profile.getSingleton();
            idx = obj.findIndex(uid);
            obj.Profiles(idx).Stage = stage;
            obj.saveToDisk();
        end

        function switchProfile(key)
        %NDI.CLOUD.PROFILE.SWITCHPROFILE Make a saved profile active for this session.
        %
        %   KEY is UID | Nickname | Email (see findIndex).
        %   Calls ndi.cloud.logout, sets the env vars
        %   CLOUD_API_ENVIRONMENT (= profile.Stage),
        %   NDI_CLOUD_USERNAME    (= profile.Email), and
        %   NDI_CLOUD_PASSWORD    (= getPassword(uid)),
        %   then marks the resolved profile as the current profile
        %   (in memory only — does not change DefaultUID).
            arguments
                key (1,:) char
            end
            obj  = ndi.cloud.profile.getSingleton();
            idx  = obj.findIndex(key);
            prof = obj.Profiles(idx);
            try
                ndi.cloud.logout();
            catch ME
                warning('NDI:cloud:profile:logoutFailed', ...
                    'ndi.cloud.logout failed during switchProfile: %s', ...
                    ME.message);
            end
            setenv('CLOUD_API_ENVIRONMENT', prof.Stage);
            setenv('NDI_CLOUD_USERNAME',    prof.Email);
            setenv('NDI_CLOUD_PASSWORD',    obj.getSecretInternal(prof.PasswordSecret));
            obj.CurrentUID = prof.UID;
        end

        function path = filename()
        %NDI.CLOUD.PROFILE.FILENAME Return the JSON profile-list path.
            path = ndi.cloud.profile.getSingleton().Filename;
        end

        function path = secretsFilename()
        %NDI.CLOUD.PROFILE.SECRETSFILENAME Return the AES secrets file path.
            path = ndi.cloud.profile.getSingleton().SecretsFilename;
        end

        function name = backend()
        %NDI.CLOUD.PROFILE.BACKEND Return the active secrets backend.
            name = ndi.cloud.profile.getSingleton().Backend;
        end

        function useBackend(name)
        %NDI.CLOUD.PROFILE.USEBACKEND Force a backend (test hook).
            arguments
                name (1,:) char {mustBeMember(name, {'vault','aes','memory'})}
            end
            obj = ndi.cloud.profile.getSingleton();
            obj.Backend = name;
        end

        function reload()
        %NDI.CLOUD.PROFILE.RELOAD Re-read profiles and DefaultUID from disk.
        %
        %   Clears the in-memory state and reloads from the JSON file,
        %   then re-applies the default-as-current rule. Useful for
        %   tests that simulate a fresh MATLAB session.
            obj = ndi.cloud.profile.getSingleton();
            obj.Profiles   = ndi.cloud.profile.emptyProfiles();
            obj.CurrentUID = '';
            obj.DefaultUID = '';
            obj.loadFromDisk();
            obj.adoptDefaultAsCurrent();
        end

        function reset()
        %NDI.CLOUD.PROFILE.RESET Clear the in-memory singleton state.
            obj = ndi.cloud.profile.getSingleton();
            obj.Profiles    = ndi.cloud.profile.emptyProfiles();
            obj.CurrentUID  = '';
            obj.DefaultUID  = '';
            obj.MemoryStore = containers.Map('KeyType','char','ValueType','char');
        end
    end

    methods (Static, Access = private)

        function p = profileForUID(obj, uid)
        %PROFILEFORUID Return the profile struct for UID, or empty if
        %UID is empty/unknown.
            if isempty(uid) || isempty(obj.Profiles)
                p = ndi.cloud.profile.emptyProfiles();
                return;
            end
            mask = strcmp({obj.Profiles.UID}, uid);
            idx  = find(mask, 1, 'first');
            if isempty(idx)
                p = ndi.cloud.profile.emptyProfiles();
            else
                p = obj.Profiles(idx);
            end
        end
    end

    methods (Access = protected)

        function str = getHeader(obj)
            link = sprintf('<a href="matlab:help ndi.cloud.profile" style="font-weight:bold">%s</a>', 'ndi.cloud.profile');
            str = sprintf('NDI Cloud profiles (%s, backend=%s):\n', link, obj.Backend);
        end

        function groups = getPropertyGroups(obj)
            s = struct();
            s.NumProfiles = numel(obj.Profiles);
            s.CurrentUID  = obj.CurrentUID;
            s.DefaultUID  = obj.DefaultUID;
            if ~isempty(obj.Profiles)
                s.Nicknames = {obj.Profiles.Nickname};
                s.Emails    = {obj.Profiles.Email};
            end
            groups = matlab.mixin.util.PropertyGroup(s);
        end
    end
end
