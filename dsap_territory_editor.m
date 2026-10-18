function f=dsap_territory_editor(sequence,reference,metadata,onApply)
% Isolated review editor. Every adoption is explicit; no auto-finalization.
if nargin<4,onApply=[];end
root=fileparts(mfilename('fullpath'));shape=size(reference);empty=struct('ACA_mask',false(shape),'MCA_mask',false(shape));
s=dsap_territory_state('new',empty,metadata);mode='browse';stroke=false;strokePatch=false(shape);points=[];polygon=[];polygonBase=[];
original=s;strokeMode='add';lastXY=[];applied=false;
screen=get(groot,'ScreenSize');windowSize=min([1180 850],screen(3:4)-[40 100]);
f=uifigure('Name','Automatic Vascular Territory Segmentation · 人工核对','Position',[screen(1:2)+[20 45] windowSize]);
g=uigridlayout(f,[3 2],'RowHeight',{48,'1x',65},'ColumnWidth',{'1x',290});
bar=uigridlayout(g,[1 5],'ColumnWidth',{100,110,170,150,'1x'},'Padding',0);bar.Layout.Column=[1 2];
view=uidropdown(bar,'Items',{'选择投照','AP','lateral'},'Value',metadata.view);
if isfield(metadata,'view_selection_required')&&metadata.view_selection_required,view.Value='选择投照';end
side=uidropdown(bar,'Items',{'未指定侧别','Left','Right'});
auto=uibutton(bar,'Text','自动识别 ACA / MCA','ButtonPushedFcn',@infer);
uibutton(bar,'Text','载入供血区记录','ButtonPushedFcn',@load_session);
uilabel(bar,'Text','黄色 ACA · 青色 MCA；必须核对类别、侧别及边界','WordWrap','on');
ax=uiaxes(g);ax.Layout.Row=2;ax.Layout.Column=1;im=imshow(reference,[],'Parent',ax);hold(ax,'on');
rgb=zeros([shape 3],'uint8');overlay=image(ax,rgb,'AlphaData',zeros(shape,'single'),'HitTest','off','PickableParts','none');axis(ax,'image');
cursor=plot(ax,nan,nan,'w-','LineWidth',1.25,'HitTest','off','PickableParts','none');
im.ButtonDownFcn=@begin_stroke;ax.ButtonDownFcn=@begin_stroke;
panel=uigridlayout(g,[15 2],'RowHeight',{90,20,25,28,30,30,30,30,30,30,48,34,34,0,'1x'},'RowSpacing',4,'Padding',5,'Scrollable','on');panel.Layout.Row=2;panel.Layout.Column=2;
layer=uilistbox(panel,'Items',s.Names,'ItemsData',1:6,'Value',1,'ValueChangedFcn',@(~,~) browse());layer.Layout.Column=[1 2];
uilabel(panel,'Text','ROI opacity');opacity=uislider(panel,'Limits',[0 1],'Value',.35,'ValueChangingFcn',@(~,e) render(e.Value),'ValueChangedFcn',@(~,~) render());opacity.Layout.Row=3;opacity.Layout.Column=[1 2];
uilabel(panel,'Text','Brush Size · 直径 px');radius=uieditfield(panel,'numeric','Limits',[1 200],'Value',10,'ValueChangedFcn',@brush_size_changed);
uibutton(panel,'Text','Brush 增加','ButtonPushedFcn',@(~,~) set_mode('add'));uibutton(panel,'Text','Eraser 擦除','ButtonPushedFcn',@(~,~) set_mode('erase'));
uibutton(panel,'Text','Polygon 增加','ButtonPushedFcn',@(~,~) new_polygon('add'));uibutton(panel,'Text','Polygon 擦除','ButtonPushedFcn',@(~,~) new_polygon('erase'));
uibutton(panel,'Text','边界点拖动','ButtonPushedFcn',@edit_boundary);uibutton(panel,'Text','应用边界','ButtonPushedFcn',@apply_polygon);
uibutton(panel,'Text','撤销','ButtonPushedFcn',@(~,~) history('undo'));uibutton(panel,'Text','重做','ButtonPushedFcn',@(~,~) history('redo'));
uibutton(panel,'Text','浏览 / 取消编辑','ButtonPushedFcn',@(~,~) browse());uibutton(panel,'Text','指定所选侧别','ButtonPushedFcn',@assign_side);
uibutton(panel,'Text','清空当前层','ButtonPushedFcn',@(~,~) patch(false(shape),'replace',struct('Tool','clear')));
uibutton(panel,'Text','交换 ACA / MCA 标签','ButtonPushedFcn',@(~,~) swap_labels());
review=uicheckbox(panel,'Text','已核对 ACA/MCA 标签、侧别与解剖位置','Value',false);review.Layout.Row=11;review.Layout.Column=[1 2];
uibutton(panel,'Text','保存审核结果','ButtonPushedFcn',@save_result);
apply=uibutton(panel,'Text','采用为 DSAP ROI','ButtonPushedFcn',@adopt);if isempty(onApply),apply.Enable='off';end
uibutton(panel,'Text','Reset · 恢复初始 ROI','ButtonPushedFcn',@(~,~) reset_masks());
uibutton(panel,'Text','Cancel · 放弃修改','ButtonPushedFcn',@(~,~) delete(f));
note=uilabel(g,'Text','尚未生成自动结果。点击自动识别，或载入同一病例的自动/人工修正记录。','WordWrap','on');note.Layout.Row=3;note.Layout.Column=[1 2];
f.WindowButtonMotionFcn=@move_stroke;f.WindowButtonUpFcn=@end_stroke;f.CloseRequestFcn=@(~,~) delete(f);publish();render();
 function publish
  setappdata(f,'DSAPTerritoryEditor',struct('State',s,'Axes',ax,'Layer',layer,'Opacity',opacity,'Review',review,'Apply',apply, ...
   'Patch',@patch,'Brush',@brush,'Undo',@() history('undo'),'Redo',@() history('redo'),'SetPrediction',@set_prediction, ...
   'AssignSide',@assign_value,'Adopt',@adopt,'Polygon',polygon,'Note',note,'Browse',@browse, ...
   'EditBoundary',@edit_boundary,'ApplyBoundary',@apply_polygon,'Reset',@reset_masks, ...
   'SetMode',@set_mode,'BrushSize',radius,'Cursor',cursor,'MoveCursor',@update_cursor, ...
   'Stroke',@stroke_path,'Applied',applied));
 end
 function render(varargin)
  alpha=opacity.Value;if ~isempty(varargin),alpha=varargin{1};end
  aca=s.Masks{1}|s.Masks{3}|s.Masks{5};mca=s.Masks{2}|s.Masks{4}|s.Masks{6};
  if stroke
   candidate=s.Masks{layer.Value};if strcmp(strokeMode,'add'),candidate=candidate|strokePatch;else,candidate=candidate&~strokePatch;end
   all=s.Masks;all{layer.Value}=candidate;aca=all{1}|all{3}|all{5};mca=all{2}|all{4}|all{6};
  end
  overlay.CData=uint8(cat(3,aca,aca|mca,mca))*255;overlay.AlphaData=single(alpha)*single(aca|mca);publish();
 end
 function changed
  review.Value=false;s.Confirmed=false;render();
 end
 function patch(value,operation,detail)
  if nargin<3,detail=struct();end
  s=dsap_territory_state('patch',s,layer.Value,logical(value),operation,detail);changed();
 end
 function brush(xy,operation,r)
  p=dsap_brush_patch(false(shape),xy,r);
  patch(p,operation,struct('Tool','brush','Points',xy,'Radius',r));
 end
 function set_mode(value),browse();mode=value;note.Text=['编辑模式：' value '；按住鼠标绘制。'];end
 function browse
  stroke=false;if ~isempty(polygon)&&isvalid(polygon),delete(polygon);end;polygon=[];mode='browse';cursor.Visible='off';render();
 end
 function begin_stroke(~,~)
  if ~ismember(mode,{'add','erase'}),return;end
  strokeMode=mode;if strcmp(f.SelectionType,'alt'),strokeMode='erase';end
  stroke=true;strokePatch=false(shape);points=[];move_stroke();
 end
 function move_stroke(varargin)
  xy=ax.CurrentPoint(1,1:2);update_cursor(xy);
  if ~stroke,return;end
  if xy(1)<1||xy(2)<1||xy(1)>shape(2)||xy(2)>shape(1),points=[];return;end
  path=xy;if ~isempty(points),n=max(2,ceil(norm(xy-points(end,:))/max(.5,radius.Value/4)));path=[linspace(points(end,1),xy(1),n)' linspace(points(end,2),xy(2),n)'];end
  strokePatch=dsap_brush_patch(strokePatch,path,radius.Value/2);
  points=[points;path];render();
 end
 function end_stroke(varargin)
  if ~stroke,return;end;stroke=false;patch(strokePatch,strokeMode,struct('Tool','brush','Points',points,'Radius',radius.Value/2));
 end
 function update_cursor(xy)
  lastXY=xy;
  if isempty(xy)||~ismember(mode,{'add','erase'})||xy(1)<1||xy(2)<1||xy(1)>shape(2)||xy(2)>shape(1)
   cursor.Visible='off';return;
  end
  theta=linspace(0,2*pi,65);cursor.XData=xy(1)+radius.Value/2*cos(theta);cursor.YData=xy(2)+radius.Value/2*sin(theta);cursor.Visible='on';
  if strcmp(mode,'erase')||(stroke&&strcmp(strokeMode,'erase')),cursor.Color=[1 .3 .3];else,cursor.Color=[1 1 1];end
 end
 function brush_size_changed(~,~)
  update_cursor(lastXY);
 end
 function stroke_path(xy,operation)
  % Test/controller entry uses exactly the same diameter and mask primitive.
  brush(xy,operation,radius.Value/2);
 end
 function reset_masks
  browse();s=original;changed();note.Text='已恢复初始 ROI；尚未应用。';
 end
 function new_polygon(operation)
  browse();try,polygon=drawpolygon(ax,'Color','m');mode=operation;polygonBase=[];note.Text='拖动顶点微调，然后点击应用边界。';publish();catch e,note.Text=e.message;end
 end
 function edit_boundary(~,~)
  browse();c=bwconncomp(s.Masks{layer.Value});if c.NumObjects==0,note.Text='当前层为空，可用 Polygon 增加。';return;end
  [~,j]=max(cellfun(@numel,c.PixelIdxList));component=false(shape);component(c.PixelIdxList{j})=true;b=bwboundaries(component,'noholes');p=b{1};p=p(1:max(1,ceil(size(p,1)/150)):end,:);
  polygonBase=struct('Remaining',s.Masks{layer.Value}&~component,'Holes',imfill(component,'holes')&~component);
  polygon=drawpolygon(ax,'Position',p(:,[2 1]),'Color','m');mode='boundary';note.Text='拖动最大连通区域的顶点；其他区域及原有孔洞保留。点击应用边界。';publish();
 end
 function apply_polygon(~,~)
  if isempty(polygon)||~isvalid(polygon),return;end
  vertices=polygon.Position;value=createMask(polygon,im);operation=mode;
  if strcmp(mode,'boundary'),value=polygonBase.Remaining|(value&~polygonBase.Holes);operation='replace';end
  browse();patch(value,operation,struct('Tool','polygon','Vertices',vertices));
 end
 function history(action),browse();s=dsap_territory_state(action,s);changed();end
 function assign_side(~,~),try,assign_value(side.Value);catch e,note.Text=e.message;end,end
 function assign_value(value),browse();s=dsap_territory_state('assign_side',s,value);if strcmp(value,'Left'),layer.Value=3;else,layer.Value=5;end;changed();end
 function swap_labels,browse();s=dsap_territory_state('swap_labels',s);changed();end
 function set_prediction(prediction,meta)
  browse();s=dsap_territory_state('new',prediction,meta);original=s;changed();note.Text='自动候选已生成。先核对 ACA/MCA 标签及侧别，再修改并确认；尚未进入分析。';
 end
 function infer(~,~)
  if ~isempty(s.History),note.Text='已有编辑，请先保存或新开窗口后再预测，避免覆盖修改。';return;end
  controls=findall(f,'-property','Enable');enabled=get(controls,'Enable');set(controls,'Enable','off');
  restoreControls=onCleanup(@() restore_controls(controls,enabled)); %#ok<NASGU>
  note.Text='正在运行独立供血区模型…关闭此窗口可取消。';drawnow;
  try
   meta=metadata;meta.view=view.Value;
   [p,meta]=dsap_territory_cached_predict(sequence,meta,fullfile(root,'vascular_segmentation','config.yaml'),@() ~isgraphics(f));
   if ~isgraphics(f),return;end;set_prediction(p,meta);
  catch e,fprintf(2,'%s\n',getReport(e,'extended','hyperlinks','off'));if isgraphics(f),note.Text=e.message;end
  end
  if isgraphics(f),auto.Enable='on';end
 end
 function reviewed
  assert(isempty(polygon)||~isvalid(polygon),'DSAP:TerritoryPendingEdit','请先应用边界或取消边界编辑。');
  end_stroke();browse();
  s=dsap_territory_state('confirm',s,review.Value);publish();
 end
 function save_result(~,~)
  try,reviewed();folder=uigetdir(root,'选择审核结果保存目录');if isequal(folder,0),return;end;folder=tempname(folder);dsap_territory_state('save',s,folder);note.Text=['已保存自动 mask、最终 mask 和完整编辑历史：' folder];catch e,note.Text=e.message;fprintf(2,'%s\n',getReport(e,'extended','hyperlinks','off'));end
 end
 function adopt(varargin)
  try
   reviewed();base=fullfile(root,'territory_results');if ~isfolder(base),mkdir(base);end;folder=tempname(base);dsap_territory_state('save',s,folder);
   onApply(s,folder);applied=true;
   if isgraphics(f),publish();note.Text='ROI 已应用';delete(f);end
  catch e
   s.Confirmed=false;publish();note.Text=['ROI 未应用：' e.message];
   fprintf(2,'%s\n',getReport(e,'extended','hyperlinks','off'));uialert(f,e.message,'ROI 未应用');
  end
 end
 function load_session(~,~)
    [name,folder]=uigetfile({'*.mat','Territory session (automatic or reviewed)'});if isequal(name,0),return;end
  try
   loaded=load(fullfile(folder,name),'territory_session');candidate=loaded.territory_session;
   assert(strcmp(candidate.Metadata.source_id,metadata.source_id)&&isequal(size(candidate.Masks{1}),shape),'DSAP:TerritorySource','Session belongs to a different image/source.');
   browse();s=candidate;original=s;changed();note.Text='已载入同一病例记录，请重新核对后采用。';
  catch e,note.Text=e.message;end
 end
end
function restore_controls(controls,values)
for k=1:numel(controls),if isgraphics(controls(k)),controls(k).Enable=values{k};end,end
end
