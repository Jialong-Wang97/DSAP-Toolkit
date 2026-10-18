function dsap_workspace_wait(fig,runID,completed)
% Wait for the transaction decision, not for unrelated figure uiresume calls.
while ~completed()
    assert(isgraphics(fig),'DSAP:Cancelled','工作区已关闭。');
    dsap_task_control('check');
    s=getappdata(fig,'WorkspaceState');
    assert(strcmp(s.RunID,runID),'DSAP:StaleDraft','当前草稿已不属于正在处理的病例。');
    pause(.05);
end
dsap_task_control('check');
end
