function dsap_workspace_style(parent)
% Apply shared typography once when a page is constructed, never on refresh.
t=dsap_theme;controls=findall(parent);
for k=1:numel(controls)
 c=controls(k);
 if isgraphics(c,'figure'),continue;end
 styled=isa(c,'matlab.ui.control.Label')||isa(c,'matlab.ui.control.Button')|| ...
  isa(c,'matlab.ui.control.NumericEditField')||isa(c,'matlab.ui.control.DropDown')|| ...
  isa(c,'matlab.ui.control.TextArea')||isa(c,'matlab.ui.control.ListBox')|| ...
  isa(c,'matlab.ui.control.Table')||isa(c,'matlab.ui.control.CheckBox')|| ...
  isa(c,'matlab.ui.control.EditField');
 if styled,c.FontName=t.Font;if c.FontSize<=12,c.FontSize=t.Body;end,end
 if isa(c,'matlab.ui.container.GridLayout')&&isequal(c.BackgroundColor,[.94 .94 .94])
  c.BackgroundColor=t.Surface;
 end
 if isa(c,'matlab.ui.container.Panel')
  c.BackgroundColor=t.Surface;
  if strcmp(c.BorderType,'line'),c.HighlightColor=t.Border;end
 end
 if isa(c,'matlab.ui.container.Tab'),c.BackgroundColor=t.Surface;end
 if isa(c,'matlab.ui.control.Button')
  c.BackgroundColor=t.SurfaceSecondary;c.FontColor=t.TextPrimary;
  if isappdata(c,'DSAPSidebarItem'),c.BackgroundColor=t.Sidebar;end
  if ismember(c.Text,{'确认并开始分析','确认 ROI 并开始分析','使用此序列','继续：ROI 设置','完整导出'})
   c.BackgroundColor=t.Primary;c.FontColor=t.Surface;
  end
 end
 if isa(c,'matlab.ui.control.Table')
  c.FontSize=t.Body;c.BackgroundColor=[t.Surface;t.SurfaceSecondary];
  c.ForegroundColor=t.TextPrimary;
 end
end
end
