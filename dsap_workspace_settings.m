function answer=dsap_workspace_settings(fig,parent,defaults,runID)
t=dsap_theme;delete(parent.Children);done=false;answer={};g=uigridlayout(parent,[7 2],'RowHeight',{45,44,44,44,34,55,'1x'},'ColumnWidth',{'1x','1x'},'Padding',t.PagePadding);
uilabel(g,'Text','采集参数','FontSize',t.PageTitle,'FontWeight','bold');uilabel(g,'Text','确认后的参数将写入科研结果。');
names={'备用帧率（仅无有效 FrameTimeVector 时使用）','预先丢弃帧数','基线帧数'};fields=gobjects(1,3);
for k=1:3,uilabel(g,'Text',names{k});fields(k)=uieditfield(g,'numeric','Value',str2double(defaults{k}));end
s=getappdata(fig,'WorkspaceState');label='准备 ROI 草稿';if s.Legacy,label='预览并确认已导入 ROI';end
enabled=true;if isappdata(fig,'DSAPROIautomationEnabled'),enabled=getappdata(fig,'DSAPROIautomationEnabled');end
automation=uicheckbox(g,'Text','启用 ROI 自动建议','Value',enabled,'Enable',onoff(~s.Legacy), ...
 'Tooltip','仅提供参考帧、AIF 和上下界建议，组织 ROI 继续手工定义。');
automation.Layout.Row=5;automation.Layout.Column=[1 2];
b=uibutton(g,'Text',label,'ButtonPushedFcn',@accept);b.Layout.Column=[1 2];
b.Layout.Row=6;
setappdata(fig,'DSAPWorkspaceSettings',struct('Fields',fields,'Continue',b,'Automation',automation));dsap_workspace_style(parent);drawnow;
dsap_workspace_wait(fig,runID,@is_done);
dsap_task_control('check');
rmappdata(fig,'DSAPWorkspaceSettings');
 function accept(~,~)
  state=getappdata(fig,'WorkspaceState');if done||~strcmp(state.RunID,runID),return;end
  answer=arrayfun(@(x) num2str(x.Value,16),fields,'UniformOutput',false);done=true;uiresume(fig);
  setappdata(fig,'DSAPWorkspaceScientificSettings',struct('FallbackFrameRate',fields(1).Value,'ManualDiscardedFrames',fields(2).Value,'BaselineFrames',fields(3).Value));
  setappdata(fig,'DSAPROIautomationEnabled',automation.Value);
 end
 function value=is_done,value=done;end
end
function value=onoff(flag),if flag,value='on';else,value='off';end,end
