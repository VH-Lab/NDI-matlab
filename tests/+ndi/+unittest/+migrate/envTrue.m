function tf = envTrue(name)
%ENVTRUE True when the environment variable NAME is set to 1, true, yes or on.
v = lower(strtrim(getenv(name)));
tf = any(strcmp(v, {'1', 'true', 'yes', 'on'}));
end
