function file=dsap_workspace_log_error(fig,exception,context)
% Diagnostic evidence contains data only, never graphics/callback closures.
folder=fullfile(fileparts(mfilename('fullpath')),'outputs','workspace_errors');
if ~isfolder(folder),mkdir(folder);end
record=struct('Identifier',exception.identifier,'Message',exception.message, ...
 'Stack',exception.stack,'Context',context,'Cancelled',dsap_task_control('cancelled'), ...
 'UTC',char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")));
if isgraphics(fig)&&isappdata(fig,'WorkspaceState')
 s=getappdata(fig,'WorkspaceState');record.RunID=s.RunID;record.SourceFile=s.SourceFile;
 setappdata(fig,'DSAPWorkspaceLastError',exception);
end
file=fullfile(folder,[char(java.util.UUID.randomUUID()) '.json']);
fid=fopen(file,'w','n','UTF-8');if fid>=0,c=onCleanup(@() fclose(fid));fprintf(fid,'%s',jsonencode(record,'PrettyPrint',true));end
fprintf(2,'%s\n',getReport(exception,'extended','hyperlinks','off'));
if isgraphics(fig),setappdata(fig,'DSAPWorkspaceLastErrorLog',file);end
end
