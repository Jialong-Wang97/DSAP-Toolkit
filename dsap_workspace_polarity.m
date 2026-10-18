function polarity=dsap_workspace_polarity(fig,parent,bright,dark)
delete(parent.Children);done=false;polarity='';g=uigridlayout(parent,[2 2],'RowHeight',{'1x',44});
state=getappdata(fig,'WorkspaceState');runID=state.RunID;
ax=uiaxes(g);imshow(bright,[],'Parent',ax);title(ax,'亮血管增强');ax=uiaxes(g);imshow(dark,[],'Parent',ax);title(ax,'暗血管增强');
b=uibutton(g,'Text','使用亮血管增强','ButtonPushedFcn',@(~,~) choose('bright'));
d=uibutton(g,'Text','使用暗血管增强','ButtonPushedFcn',@(~,~) choose('dark'));
setappdata(fig,'DSAPWorkspacePolarity',struct('Bright',b,'Dark',d));drawnow;if ~done,uiwait(fig);end
dsap_task_control('check');
rmappdata(fig,'DSAPWorkspacePolarity');
 function choose(value)
  state=getappdata(fig,'WorkspaceState');if done||~strcmp(state.RunID,runID),return;end
  polarity=value;done=true;uiresume(fig);
  settings=getappdata(fig,'DSAPWorkspaceScientificSettings');settings.ContrastPolarity=value;setappdata(fig,'DSAPWorkspaceScientificSettings',settings);
 end
end
