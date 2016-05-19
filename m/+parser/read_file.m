function RawFile=read_file(FileName)
% H1 line
%
% Syntax
% -------
% ::
%
% Inputs
% -------
%
% Outputs
% --------
%
% More About
% ------------
%
% Examples
% ---------
%
% See also: 


RawFile=cell(0,1);

if isempty(FileName)
    
    return
    
end

for ifile=1:numel(FileName)
    
    RawFile_i=reading_engine(FileName(ifile));
    
    RawFile=[RawFile;RawFile_i];
    
end

end

function RawFile=reading_engine(FileName)

RawFile=cell(0,1);

fid = fopen([FileName.fname,FileName.ext]);

iter=0;

is_block_comments_open=false;

while 1
    
    rawline = fgetl(fid);
    
    if ~ischar(rawline), break, end
    
    tokk=strtok(rawline);
    
    ibco=strcmp(tokk,'%{')||strcmp(tokk,'/*');
    
    if ibco 
        
        if is_block_comments_open
            
            error('nested block comments not allowed ')
            
        end
        
        is_block_comments_open=true;
        
    end
    
    iter=iter+1;
    
    if is_block_comments_open
        
        if strcmp(tokk,'%}')||strcmp(tokk,'*/')
            
            is_block_comments_open=false;
            
        end
        
        continue
        
    end
    
    rawline=parser.remove_comments(rawline);
    
    if all(isspace(rawline))
        
        continue
        
    end
    
    rawline={rawline,FileName.fname,iter}; %#ok<*AGROW>
    
    RawFile=[RawFile;rawline];
    
end

fclose(fid);

end
