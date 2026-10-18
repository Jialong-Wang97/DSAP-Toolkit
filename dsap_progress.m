function fig = dsap_progress(fraction, message, name)
% Closing a progress window must cancel work, not merely hide the window.
    if dsap_workspace_bridge('active')
        dsap_workspace_bridge('stage',message);fig=[];return;
    end
    fig=waitbar(fraction,message,'Name',name, ...
        'CreateCancelBtn',@(~,~) dsap_task_control('cancel'));
    fig.CloseRequestFcn=@(~,~) dsap_task_control('cancel');
end
