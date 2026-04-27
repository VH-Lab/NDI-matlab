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
%   Backends, chosen automatically on first use:
%
%       vault  - MATLAB's setSecret/getSecret (R2024a+). Preferred.
%       aes    - AES-128/CBC encrypted file in prefdir, used when the
%                vault is not available. The key is derived from
%                SHA-256([hostname username 'NDI Cloud']) so the file
%                is reproducible only on the machine that wrote it.
%       memory - in-memory containers.Map. Reserved for tests; use
%                ndi.cloud.profile.useBackend('memory') to opt in.
%
%   Profile metadata (everything except passwords) is persisted to:
%
%       fullfile(prefdir, 'NDI_Cloud_Profiles.json')
%
%   The vault never sees that file; the AES backend writes ciphertext
%   to a sibling file:
%
%       fullfile(prefdir, 'NDI_Cloud_Secrets.json')
%
%   Typical usage:
%
%       uid = ndi.cloud.profile.add('Lab account', 'me@lab.org', 'pw1');
%       ndi.cloud.profile.setCurrent(uid);
%       ndi.cloud.profile.switchProfile(uid);   % logout + setenv
%
%       devUid = ndi.cloud.profile.add('Dev', 'me@lab.org', 'pw2');
%       ndi.cloud.profile.setStage(devUid, 'dev');
%
%   See also: ndi.gui.profileEditor, ndi.preferences, ndi.ido,
%             ndi.cloud.logout

    properties (Constant, Access = private)
        % Filename - JSON file holding the profile list (no passwords).
        Filename = fullfile(prefdir, 'NDI_Cloud_Profiles.json')

        % SecretsFilename - AES backend's ciphertext file.
        SecretsFilename = fullfile(prefdir, 'NDI_Cloud_Secrets.json')

        % SecretKeyPrefix - prefix used for every per-profile secret key.
        SecretKeyPrefix = 'NDI Cloud '
    end

    properties (SetAccess = private)
        % Profiles - struct array of profiles.
        % Fields: UID, Nickname, Email, Stage, PasswordSecret.
        Profiles struct

        % CurrentUID - UID of the active profile, '' if none.
        CurrentUID char

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
        %
        %   Initialises an empty profile array, picks the secrets
        %   backend (vault if available, else aes), then loads any
        %   on-disk profile list. A missing file is the first-run
        %   case and is silently tolerated.
            obj.Profiles   = ndi.cloud.profile.emptyProfiles();
            obj.CurrentUID = '';
            obj.Backend    = ndi.cloud.profile.detectBackend();
            obj.loadFromDisk();
        end

        function loadFromDisk(obj)
        %LOADFROMDISK Read the profile list and current UID from JSON.
            if ~isfile(obj.Filename); return; end
            try
                txt = fileread(obj.Filename);
                if isempty(strtrim(txt)); return; end
                S = jsondecode(txt);
                if isfield(S, 'Profiles') && ~isempty(S.Profiles)
                    obj.Profiles = ndi.cloud.profile.normalizeProfiles(S.Profiles);
                end
                if isfield(S, 'CurrentUID')
                    obj.CurrentUID = char(S.CurrentUID);
                end
            catch ME
                warning('NDI:cloud:profile:loadFailed', ...
                    'Could not load cloud profiles from %s: %s', ...
                    obj.Filename, ME.message);
            end
        end

        function saveToDisk(obj)
        %SAVETODISK Write the profile list and current UID to JSON.
            S = struct('Profiles', obj.Profiles, ...
                       'CurrentUID', obj.CurrentUID);
            try
                txt = jsonencode(S, 'PrettyPrint', true);
                fid = fopen(obj.Filename, 'w');
                if fid < 0
                    error('NDI:cloud:profile:saveFailed', ...
                        'Could not open %s for writing.', obj.Filename);
                end
                cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
                fwrite(fid, txt, 'char');
            catch ME
                warning('NDI:cloud:profile:saveFailed', ...
                    'Could not save cloud profiles to %s: %s', ...
                    obj.Filename, ME.message);
            end
        end

        function idx = findIndex(obj, uid)
        %FINDINDEX Return the index of the profile with the given UID.
            mask = strcmp({obj.Profiles.UID}, uid);
            idx = find(mask, 1, 'first');
            if isempty(idx)
                error('NDI:cloud:profile:unknownProfile', ...
                    'Unknown profile UID "%s".', uid);
            end
        end

        function setSecretInternal(obj, key, value)
        %SETSECRETINTERNAL Backend-dispatched secret writer.
            switch obj.Backend
                case 'vault'
                    setSecret(key, value); %#ok<UNRCH>
                case 'aes'
                    ndi.cloud.profile.aesWriteSecret( ...
                        obj.SecretsFilename, key, value);
                case 'memory'
                    obj.MemoryStore(key) = value;
            end
        end

        function value = getSecretInternal(obj, key)
        %GETSECRETINTERNAL Backend-dispatched secret reader.
            switch obj.Backend
                case 'vault'
                    value = char(getSecret(key)); %#ok<UNRCH>
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
        %REMOVESECRETINTERNAL Backend-dispatched secret deleter.
            switch obj.Backend
                case 'vault'
                    if isSecret(key) %#ok<UNRCH>
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
        %EMPTYPROFILES Empty struct array with the canonical fields.
            p = struct('UID', {}, 'Nickname', {}, 'Email', {}, ...
                       'Stage', {}, 'PasswordSecret', {});
        end

        function out = normalizeProfiles(in)
        %NORMALIZEPROFILES Coerce a JSON-decoded payload into the canonical
        %struct-array shape, supplying defaults for any missing field.
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
        %DETECTBACKEND 'vault' if setSecret is available, else 'aes'.
            persistent forced
            if ~isempty(forced)
                backend = forced;
                return;
            end
            if ~isempty(which('setSecret')) ...
                    && ~isempty(which('getSecret')) ...
                    && ~isempty(which('isSecret'))
                backend = 'vault';
            else
                backend = 'aes';
            end
        end

        function key = aesKeyBytes()
        %AESKEYBYTES First 16 bytes of SHA-256([hostname username 'NDI Cloud']).
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
        %AESWRITESECRET Encrypt value under the per-machine key and store
        %it in the AES JSON file under the given key.
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
        %AESREADSECRET Decrypt and return the secret stored under key.
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
        end

        function aesRemoveSecret(filename, key)
        %AESREMOVESECRET Remove the entry for the given key.
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
        end

        function f = fieldFor(key)
        %FIELDFOR Convert a free-form key into a legal MATLAB field name.
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
            sr = java.security.SecureRandom();
            bytes = zeros(1, n, 'int8');
            javaArr = javaArray('java.lang.Byte', n); %#ok<JAVAB>
            tmp = int8(zeros(1, n));
            jb = javaObject('java.lang.reflect.Array');
            % Simplest portable approach: nextBytes on a Java byte[].
            buf = javaMethod('newInstance', 'java.lang.reflect.Array', ...
                java.lang.Byte.TYPE, n);
            sr.nextBytes(buf);
            for i = 1:n
                tmp(i) = buf(i);
            end
            bytes = tmp;
            % Suppress unused-variable analyser warnings
            javaArr = []; %#ok<NASGU>
            jb      = []; %#ok<NASGU>
        end
    end

    methods (Static)

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
        %
        %   UID = ADD(NICKNAME, EMAIL, PASSWORD) generates a new UID
        %   via ndi.ido, persists the profile metadata to disk, stores
        %   PASSWORD in the active secrets backend under the key
        %   ['NDI Cloud ' UID], and returns the new UID. NICKNAME and
        %   EMAIL need not be unique across profiles. Stage defaults to
        %   'prod'; use setStage to change it.
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

        function remove(uid)
        %NDI.CLOUD.PROFILE.REMOVE Delete a profile and its stored secret.
            arguments
                uid (1,:) char
            end
            obj = ndi.cloud.profile.getSingleton();
            idx = obj.findIndex(uid);
            secretKey = obj.Profiles(idx).PasswordSecret;
            obj.removeSecretInternal(secretKey);
            obj.Profiles(idx) = [];
            if strcmp(obj.CurrentUID, uid)
                obj.CurrentUID = '';
            end
            obj.saveToDisk();
        end

        function p = getCurrent()
        %NDI.CLOUD.PROFILE.GETCURRENT Return the active profile or [].
            obj = ndi.cloud.profile.getSingleton();
            if isempty(obj.CurrentUID)
                p = ndi.cloud.profile.emptyProfiles();
                return;
            end
            mask = strcmp({obj.Profiles.UID}, obj.CurrentUID);
            idx  = find(mask, 1, 'first');
            if isempty(idx)
                p = ndi.cloud.profile.emptyProfiles();
            else
                p = obj.Profiles(idx);
            end
        end

        function setCurrent(uid)
        %NDI.CLOUD.PROFILE.SETCURRENT Make UID the active profile.
            arguments
                uid (1,:) char
            end
            obj = ndi.cloud.profile.getSingleton();
            obj.findIndex(uid);   % validates existence
            obj.CurrentUID = uid;
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
        %NDI.CLOUD.PROFILE.SETPASSWORD Update a profile's password in
        %the secrets backend. The profile JSON is unaffected.
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
        %NDI.CLOUD.PROFILE.SETSTAGE Set the profile's Stage. Hidden from
        %the GUI editor; meant for developer use from the command line.
            arguments
                uid   (1,:) char
                stage (1,:) char {mustBeMember(stage, {'prod','dev'})}
            end
            obj = ndi.cloud.profile.getSingleton();
            idx = obj.findIndex(uid);
            obj.Profiles(idx).Stage = stage;
            obj.saveToDisk();
        end

        function switchProfile(uid)
        %NDI.CLOUD.PROFILE.SWITCHPROFILE Make UID active and reconfigure
        %the cloud session.
        %
        %   Calls ndi.cloud.logout, then sets the environment variables
        %   CLOUD_API_ENVIRONMENT (= profile.Stage),
        %   NDI_CLOUD_USERNAME    (= profile.Email), and
        %   NDI_CLOUD_PASSWORD    (= getPassword(uid)),
        %   and finally marks UID as the current profile.
            arguments
                uid (1,:) char
            end
            obj  = ndi.cloud.profile.getSingleton();
            idx  = obj.findIndex(uid);
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
            obj.CurrentUID = uid;
            obj.saveToDisk();
        end

        function path = filename()
        %NDI.CLOUD.PROFILE.FILENAME Return the JSON profile-list path.
            path = ndi.cloud.profile.getSingleton().Filename;
        end

        function name = backend()
        %NDI.CLOUD.PROFILE.BACKEND Return the active secrets backend.
            name = ndi.cloud.profile.getSingleton().Backend;
        end

        function useBackend(name)
        %NDI.CLOUD.PROFILE.USEBACKEND Force a backend (test hook).
        %
        %   Reset the singleton, then point the next instance at the
        %   given backend ('vault', 'aes', or 'memory'). Tests use
        %   'memory' to avoid touching MATLAB's vault or the disk
        %   ciphertext file.
            arguments
                name (1,:) char {mustBeMember(name, {'vault','aes','memory'})}
            end
            obj = ndi.cloud.profile.getSingleton();
            obj.Backend = name;
        end

        function reset()
        %NDI.CLOUD.PROFILE.RESET Clear the in-memory singleton state.
        %Used by tests; does not delete on-disk files.
            obj = ndi.cloud.profile.getSingleton();
            obj.Profiles    = ndi.cloud.profile.emptyProfiles();
            obj.CurrentUID  = '';
            obj.MemoryStore = containers.Map('KeyType','char','ValueType','char');
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
            if ~isempty(obj.Profiles)
                s.Nicknames = {obj.Profiles.Nickname};
                s.Emails    = {obj.Profiles.Email};
            end
            groups = matlab.mixin.util.PropertyGroup(s);
        end
    end
end
