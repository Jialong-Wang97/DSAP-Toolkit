function fig=dsap_workspace_geometry(action,workspace)
% Optional geometry window owned by the current Workspace case; read-only Core access.
fig=[];
switch action
 case 'refresh'
  if ~isappdata(workspace,'DSAPWorkspaceGeometryButton'),return;end
  b=getappdata(workspace,'DSAPWorkspaceGeometryButton');if ~isgraphics(b),return;end
  s=getappdata(workspace,'WorkspaceState');
  ready=~s.Busy&&s.Activity.ResultsReady&&isappdata(workspace,'DSAPResultOwnerId');
  if ready,b.Enable='on';else,b.Enable='off';end
 case 'open'
  s=getappdata(workspace,'WorkspaceState');
  assert(~s.Busy&&s.Activity.ResultsReady&&isappdata(workspace,'DSAPResultOwnerId'), ...
   'DSAP:GeometryNotReady','请等待当前病例分析结束后打开中心线工具。');
  if isappdata(workspace,'DSAPWorkspaceGeometryFigure')
   fig=getappdata(workspace,'DSAPWorkspaceGeometryFigure');
   if isgraphics(fig),figure(fig);return;end
  end
  owner=dsap_result_owner('get',getappdata(workspace,'DSAPResultOwnerId'));
  assert(~owner.Saving,'DSAP:GeometrySaveBusy','请等待核心结果保存完成。');
  if owner.Saved,source=owner.Folder;else,source=owner.Result;end
  fig=dsap_geometry(source);
  fig.Name='DSAP 当前病例 · 血管中心线 / 几何';
  setappdata(fig,'DSAPGeometryResultOwnerId',owner.Id);
  setappdata(workspace,'DSAPWorkspaceGeometryFigure',fig);
 case 'close'
  if isappdata(workspace,'DSAPWorkspaceGeometryFigure')
   fig=getappdata(workspace,'DSAPWorkspaceGeometryFigure');
   if isgraphics(fig),delete(fig);end
   rmappdata(workspace,'DSAPWorkspaceGeometryFigure');
  end
 otherwise,error('DSAP:GeometryWorkspaceAction','Unknown geometry Workspace action.');
end
end
