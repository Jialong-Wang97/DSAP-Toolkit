function choice=dsap_workspace_cave(fig,parent,reference,mask)
delete(parent.Children);done=false;choice='cancel';g=uigridlayout(parent,[2 3],'RowHeight',{'1x',44});
state=getappdata(fig,'WorkspaceState');runID=state.RunID;
ax=uiaxes(g);ax.Layout.Column=[1 3];imshow(reference,[],'Parent',ax);hold(ax,'on');visboundaries(ax,mask,'Color',[1 .2 .1]);title(ax,'CAVE · 只读质量检查');dsap_style_axes(ax);
a=uibutton(g,'Text','接受','ButtonPushedFcn',@(~,~) finish('accept'));
b=uibutton(g,'Text','标记异常并接受','ButtonPushedFcn',@(~,~) finish('flag'));
uibutton(g,'Text','取消','ButtonPushedFcn',@(~,~) finish('cancel'));
dsap_workspace_style(parent);setappdata(fig,'DSAPWorkspaceCAVE',struct('Accept',a,'Flag',b));drawnow;
dsap_workspace_wait(fig,runID,@is_done);
dsap_task_control('check');rmappdata(fig,'DSAPWorkspaceCAVE');delete(parent.Children);
 function finish(value)
  state=getappdata(fig,'WorkspaceState');if done||~strcmp(state.RunID,runID),return;end
  choice=value;done=true;if strcmp(value,'cancel'),dsap_task_control('cancel');end;uiresume(fig);
 end
 function value=is_done,value=done;end
end
