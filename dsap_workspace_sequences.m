function controls=dsap_workspace_sequences(parent,candidates,onUse,onBack,onChangeFolder)
% UI adapter for scan_dicom_folder_sequences' existing metadata/thumbnails.
t=dsap_theme;
if isappdata(parent,'DSAPSequenceCards')
 existing=getappdata(parent,'DSAPSequenceCards');
 if isequaln(existing.Candidates,candidates)&&isgraphics(existing.Use),controls=existing;return;end
end
delete(parent.Children);selected=[];
layout=uigridlayout(parent,[3 1],'RowHeight',{36,'1x',44});
status=uilabel(layout,'Text','请选择用于分析的序列；尚未采用任何影像。','WordWrap','on');
gallery=uigridlayout(layout,[ceil(numel(candidates)/3) 3], ...
 'RowHeight',repmat({260},1,ceil(numel(candidates)/3)),'Scrollable','on');
cards=gobjects(numel(candidates),1);images=gobjects(numel(candidates),1);axesList=images;
for k=1:numel(candidates)
 c=candidates(k);cards(k)=uipanel(gallery,'Title',sprintf('序列 %s · %s',c.SeriesNumberText,c.Plane),'BackgroundColor',t.Surface);
 card=uigridlayout(cards(k),[2 1],'RowHeight',{'1x',64},'Padding',4);
 ax=uiaxes(card);axesList(k)=ax;images(k)=imshow(c.Thumbnail,[],'Parent',ax);dsap_style_axes(ax);
 images(k).ButtonDownFcn=@(~,~) select(k);ax.ButtonDownFcn=@(~,~) select(k);
 b=uibutton(card,'Text',sprintf('%s\n%d 帧 · %d × %d · %.2f s', ...
  c.Description,c.FrameCount,c.Rows,c.Columns,c.DurationSeconds), ...
  'Tooltip',c.RelativePath,'ButtonPushedFcn',@(~,~) select(k));
end
bar=uigridlayout(layout,[1 4],'ColumnWidth',{110,130,'1x',160},'Padding',0);
back=uibutton(bar,'Text','返回','ButtonPushedFcn',@(~,~) onBack());
if nargin>=5,uibutton(bar,'Text','更换文件夹','ButtonPushedFcn',@(~,~) onChangeFolder());end
multiple=uicheckbox(bar,'Text','同一患者多序列','ValueChangedFcn',@change_mode);multiple.Layout.Column=3;
use=uibutton(bar,'Text','使用此序列','Enable','off','ButtonPushedFcn',@use_selected);use.Layout.Column=4;
dsap_workspace_style(layout);
controls=struct('Select',@select,'Use',use,'Back',back,'Multiple',multiple,'Images',images,'Axes',axesList,'Candidates',candidates,'Status',status);
setappdata(parent,'DSAPSequenceCards',controls);
 function select(index)
  assert(index>=1&&index<=numel(candidates));
  if multiple.Value
   if ismember(index,selected),selected(selected==index)=[];else,selected=sort([selected index]);end
  else,selected=index;end
  for j=1:numel(cards),cards(j).HighlightColor=t.Border;cards(j).BorderWidth=1;end
  for j=selected,cards(j).HighlightColor=t.Primary;cards(j).BorderWidth=2;end
  if multiple.Value
   status.Text=sprintf('已选择 %d 个序列；将逐个手绘 ROI、分析并统一汇总。再次点击可取消选择。',numel(selected));
   use.Text='分析所选序列';use.Enable='on';if isempty(selected),use.Enable='off';end
   return;
  end
  c=candidates(index);status.Text=sprintf('已选择序列 %s · %s · %s；点击“使用此序列”继续。',c.SeriesNumberText,c.Description,c.RelativePath);
  use.Enable='on';
 end
 function use_selected(~,~)
  assert(~isempty(selected),'DSAP:SequenceSelection','请先选择一个序列。');
  if multiple.Value,onUse({candidates(selected).FilePath});else,onUse(candidates(selected).FilePath);end
 end
 function change_mode(~,~)
  selected=[];use.Enable='off';use.Text='使用此序列';
  for j=1:numel(cards),cards(j).HighlightColor=t.Border;cards(j).BorderWidth=1;end
  status.Text='请点击需要分析的序列。';
 end
end
