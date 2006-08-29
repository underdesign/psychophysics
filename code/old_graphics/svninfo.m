function info = svninfo(filename)
% function info = svninfo(filename)
% Returns the SVN info from 'svn info' for the given full DIRECTORY name.
% 
% Important for keeping track of and reproducing experiments from potentially 
% changing code.
%
% Expects the svn executable to be at /usr/local/bin/svn.

persistent cache;

% use a struct as pretend associative array by cleaning the file names (hackish)
e = env;
fieldname = strrep(filename, [e.basedir '/'], '');
fieldname = regexprep(fieldname, '(^[^a-zA-Z])|([^a-zA-Z0-9])', '_');
fieldname = regexprep(fieldname, '^[^a-zA-Z]', 'f');
fieldname = fieldname(max(1,end-63):end);

if isfield(cache,fieldname)
	info = cache(1).(fieldname);
else
	escaped = regexprep(filename, '[^a-zA-Z0-9]', '\\$0');
	[s, info] = system(sprintf('cd %s;/usr/local/bin/svn status -Nvq .', filename));
	cache(1).(fieldname) = info;
	
	if s ~= 0
		cache(1).(fieldname) = '';
		warning('Could not retreive SVN revision information. File format versions will not be tracked...');
	end
end