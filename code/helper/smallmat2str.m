function m = smallmat2str(mat, c)

%bare bones and much faster alternative to mat2str.

%this won't accurately represent int64s or uint64. Listen to this
%screamer of a line from the matlab documentation!
%
%"NOTE: The range of values that can be passed to UINT64 from the command
%prompt or from an M-file function without loss of precision is 0 to
%2^53, inclusive. When reading values from a MAT-file, UINT64 correctly
%represents the full range 0 to (2^64)-1."
%
%What the hell kind of language has data types that can't possibly be
%filled in from source literals, even in principle?
%
if isscalar(mat)
    m = sprintf('%.15g', mat');
    if nargin > 1 && ~isa(mat, 'double')
        m = [class(mat), '(', m, ')'];
    end
    m = sprintf('%.15g ', mat');

elseif isempty(mat)
    if ~isequal(size(mat), [0 0])
        m = ['zeros(' sprintf('%d,', size(mat)) ')'];
        m(end-1) = [];
    else
        m = '[]';
    end
    if nargin > 1 && ~isa(mat, 'double')
        m = [class(mat), '(', m, ')'];
    end
else
    m = sprintf('%.15g ', mat');
    %FIXME: weird-zero-size-arrays

    ncols = size(mat, 2);
    if(size(mat, 1) > 1)
        spaceix = find(m == ' ');
        m(spaceix(ncols:ncols:end-1)) = ';';
    end

    if nargin > 1 && ~isa(mat, 'double')
        m(end) = ']';
        m = [class(mat), '([', m, ')'];
    else
        m = ['[', m];
        m(end) = ']';
    end
end
end