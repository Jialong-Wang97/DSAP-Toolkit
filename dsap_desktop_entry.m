function dsap_desktop_entry(session_token, mode)
% Dedicated shortcut process; the independent controller stays responsive.
    assert(strcmp(session_token,getenv('DSAP_SESSION_TOKEN')),'启动会话不匹配。');
    if nargin>1 && strcmp(mode,'smoke')
        dsap_task_control('begin','off');
        fid=fopen(fullfile(fileparts(getenv('DSAP_CANCEL_FILE')),'ready'),'w');
        fprintf(fid,'%d',feature('getpid'));fclose(fid);
        try
            while true,dsap_task_control('check');pause(0.05);end
        catch ME
            dsap_task_control('finish');
            if ~strcmp(ME.identifier,'DSAP:Cancelled'),rethrow(ME);end
        end
        exit;
    end
    try
        workspace=dsap_workspace;
        waitfor(workspace);
    catch ME
        fprintf(2,'%s\n',getReport(ME,'extended','hyperlinks','off'));
    end
    exit;
end
