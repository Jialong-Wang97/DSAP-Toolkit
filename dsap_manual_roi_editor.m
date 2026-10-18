function f=dsap_manual_roi_editor(reference,initialMask,onConfirm,label,tool)
% Transactional presentation editor: only Confirm publishes a logical mask.
% Reuses the packaged GUI drawfreehand/createMask rasterization path.
if nargin<4,label='Manual ROI';end
if nargin<5,tool='Freehand';end
screen=get(groot,'ScreenSize');sz=round(screen(3:4).*[.85 .82]);
f=uifigure('Name',label,'Position',[screen(1:2)+(screen(3:4)-sz)/2 sz]);
g=uigridlayout(f,[3 1],'RowHeight',{'1x',36,28},'Padding',8);
ax=uiaxes(g);im=imshow(reference,[],'Parent',ax);hold(ax,'on');axis(ax,'image');
boundary=visboundaries(ax,initialMask,'Color','y');roi=[];working=initialMask;drawing=false;
initialPosition=[];preserved=[];
% Reuse the packaged draggable ROI object; untouched confirmation is exact.
components=bwconncomp(initialMask);
if components.NumObjects>0
 [~,largest]=max(cellfun(@numel,components.PixelIdxList));component=false(size(initialMask));component(components.PixelIdxList{largest})=true;
 edges=bwboundaries(component,'noholes');vertices=edges{1};vertices=vertices(1:max(1,ceil(size(vertices,1)/250)):end,[2 1]);
 roi=drawfreehand(ax,'Position',vertices,'Color','y','FaceAlpha',0);initialPosition=roi.Position;
 preserved=struct('Remaining',initialMask&~component,'Holes',imfill(component,'holes')&~component);
end
axtoolbar(ax,{'zoomin','zoomout','pan','restoreview'});ax.Toolbar.Visible='on';
bar=uigridlayout(g,[1 7],'ColumnWidth',{120,'1x',100,100,110,100,100},'Padding',0);
drawTool=uidropdown(bar,'Items',{'自由绘制','多边形','矩形','圆形','椭圆'}, ...
 'ItemsData',{'Freehand','Polygon','Rectangle','Circle','Ellipse'},'Value',tool);
drawButton=uibutton(bar,'Text','绘制 / 重画 ROI','ButtonPushedFcn',@draw_roi);
uibutton(bar,'Text','Zoom','ButtonPushedFcn',@(~,~) navigation('zoom'));
uibutton(bar,'Text','Pan','ButtonPushedFcn',@(~,~) navigation('pan'));
uibutton(bar,'Text','Fit / Reset View','ButtonPushedFcn',@(~,~) reset_view());
confirm=uibutton(bar,'Text','Confirm / 确认','ButtonPushedFcn',@accept);
uibutton(bar,'Text','Cancel / 取消','ButtonPushedFcn',@(~,~) delete(f));
note=uilabel(g,'Text','放大并平移到目标血管，再绘制 ROI；确认前主窗口保持原值。');
f.CloseRequestFcn=@(~,~) delete(f);f.WindowKeyPressFcn=@key;
reset_view();publish();
 function publish
  setappdata(f,'DSAPManualROIEditor',struct('Axes',ax,'Image',im,'Draw',drawButton, ...
   'Confirm',confirm,'DrawPath',@(p) draw_roi([],[],p),'WorkingMask',working, ...
   'ResetView',@reset_view,'Navigation',@navigation,'ROI',roi,'Tool',drawTool,'Note',note));
 end
 function navigation(value)
  zoom(f,'off');pan(f,'off');
  if strcmp(value,'zoom'),zoom(f,'on');else,pan(f,'on');end
 end
 function reset_view
  zoom(f,'off');pan(f,'off');ax.XLim=[.5 size(reference,2)+.5];ax.YLim=[.5 size(reference,1)+.5];
 end
 function draw_roi(~,~,varargin)
  if drawing,return;end
  drawing=true;zoom(f,'off');pan(f,'off');confirm.Enable='off';
  initialPosition=[];preserved=[];
  if ~isempty(roi)&&isvalid(roi),delete(roi);end
  try
   if ~isempty(varargin)
    roi=drawfreehand(ax,'Position',varargin{1},'Color','y','FaceAlpha',0);
   else
    switch drawTool.Value
     case 'Polygon',roi=drawpolygon(ax,'Color','y','FaceAlpha',0);
     case 'Rectangle',roi=drawrectangle(ax,'Color','y','FaceAlpha',0);
     case 'Circle',roi=drawcircle(ax,'Color','y','FaceAlpha',0);
     case 'Ellipse',roi=drawellipse(ax,'Color','y','FaceAlpha',0);
     otherwise,roi=drawfreehand(ax,'Color','y','FaceAlpha',0);
    end
   end
   if ~isgraphics(f),return;end
   if ~isempty(roi)&&isvalid(roi),working=createMask(roi,im);delete(boundary(isgraphics(boundary)));end
   note.Text='可拖动边界修正；Confirm 写回，Cancel 放弃本次修改。';
  catch e
   if ~isgraphics(f),return;end
   note.Text=e.message;fprintf(2,'%s\n',getReport(e,'extended','hyperlinks','off'));
  end
  drawing=false;confirm.Enable='on';publish();
 end
 function accept(~,~)
  if drawing,return;end
  try
   candidate=working;
   if ~isempty(roi)&&isvalid(roi)
    if isempty(initialPosition)||~isequal(roi.Position,initialPosition)
     candidate=createMask(roi,im);
     if ~isempty(preserved),candidate=preserved.Remaining|(candidate&~preserved.Holes);end
    end
   end
   assert(islogical(candidate)&&isequal(size(candidate),size(reference))&&nnz(candidate)>=3,'DSAP:ManualROI','ROI 至少需要 3 个像素。');
   onConfirm(candidate);if isgraphics(f),delete(f);end
  catch e
   note.Text=['未应用：' e.message];fprintf(2,'%s\n',getReport(e,'extended','hyperlinks','off'));
   uialert(f,e.message,'ROI 未应用');
  end
 end
 function key(~,e)
  if strcmp(e.Key,'escape'),delete(f);end
 end
end
