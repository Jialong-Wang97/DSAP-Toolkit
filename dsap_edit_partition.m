function [partition,cancelled]=dsap_edit_partition(reference,limits,current)
% One persistent nonmodal editor; closing child dialogs never disables it.
    partition=struct();cancelled=true;busy=false;accepted=false;history={};
    project=fileparts(mfilename('fullpath'));
    default_file=fullfile(project,'templates','default_partition_template.mat');
    box=dsap_partition_template('fitbox',reference,limits);
    template=dsap_partition_template('default');template_source='内置模板（请按当前影像调整）';
    if isfile(default_file)
        try
            loaded=load(default_file,'template');
            candidate_controls=dsap_partition_template('apply',loaded.template,box);
            dsap_partition_from_controls(candidate_controls.Outer,candidate_controls.Inner,size(reference),limits);
            template=loaded.template;template_source='已保存的默认模板（仍须人工确认）';
        catch
            template_source='默认模板不可用，已回到内置模板';
        end
    end
    initial=dsap_partition_template('apply',template,box);
    editing=nargin>=3;
    if editing
        initial=struct('Outer',current.OuterControlPoints,'Inner',current.InnerControlPoints);
        template_source='当前结果；R1 只允许外轮廓 mask 不变';
        if isfield(current,'TemplateFitBox'),box=current.TemplateFitBox;end
    end
    fig=figure('Name','调整皮层 / 皮层下分区 mask','NumberTitle','off','Color','w', ...
        'Position',[80 60 1230 850],'CloseRequestFcn',@cancel);
    cleanup=onCleanup(@() dsap_safe_delete(fig)); %#ok<NASGU>
    ax=axes(fig,'Position',[0.04 0.22 0.70 0.73]);
    imshow(reference,[],'Parent',ax);hold(ax,'on');
    overlay=imshow(zeros([size(reference),3]),'Parent',ax);overlay.AlphaData=0;
    overlay.HitTest='off';overlay.PickableParts='none';
    outer_line=plot(ax,nan,nan,'-','Color',[1 .85 0],'LineWidth',2);
    inner_line=plot(ax,nan,nan,'-','Color',[0 .8 1],'LineWidth',2);
    outer_line.HitTest='off';inner_line.HitTest='off';
    drawing=[0.5 limits.UpperRow-0.5 size(reference,2) limits.LowerRow-limits.UpperRow+1];
    outer=drawpolygon(ax,'Position',initial.Outer,'Color',[1 .85 0],'LineWidth',0.5, ...
        'FaceAlpha',0,'DrawingArea',drawing);
    inner=drawpolygon(ax,'Position',initial.Inner,'Color',[0 .8 1],'LineWidth',0.5, ...
        'FaceAlpha',0,'DrawingArea',drawing);
    outer.Deletable=false;inner.Deletable=false;
    ylim(ax,[limits.UpperRow-.5 limits.LowerRow+.5]);
    title(ax,{'黄色外轮廓：颅内范围；青色内轮廓：皮层下', ...
        '拖动控制点调整平滑曲线；拖动控制多边形可移动该轮廓'});
    status=uicontrol(fig,'Style','text','Units','normalized','Position',[.03 .145 .94 .065], ...
        'BackgroundColor','w','HorizontalAlignment','left','FontSize',11);
    uicontrol(fig,'Style','text','Units','normalized','Position',[.76 .83 .22 .12], ...
        'BackgroundColor','w','String',{'外围橙色带：皮层','内部蓝色区：皮层下', ...
        '这是二维几何分区，不是解剖图谱',template_source},'FontSize',10);
    target=uicontrol(fig,'Style','popupmenu','Units','normalized','Position',[.77 .77 .20 .045], ...
        'String',{'同时调整两个轮廓','仅外轮廓','仅内轮廓'});
    labels={'放大 5%','缩小 5%','左转 3°','右转 3°','左移','右移','上移','下移'};
    actions={@() transform(1.05,0,[0 0]),@() transform(1/1.05,0,[0 0]), ...
        @() transform(1,-3,[0 0]),@() transform(1,3,[0 0]), ...
        @() transform(1,0,[-1 0]),@() transform(1,0,[1 0]), ...
        @() transform(1,0,[0 -1]),@() transform(1,0,[0 1])};
    for k=1:8
        action=actions{k};
        uicontrol(fig,'Style','pushbutton','Units','normalized', ...
            'Position',[.77+.105*mod(k-1,2),.70-.058*floor((k-1)/2),.10,.048], ...
            'String',labels{k},'Callback',@(~,~) action());
    end
    button('撤销一次',[.77 .43 .20 .045],@undo);
    button('重置为内置模板',[.77 .37 .20 .045],@reset);
    button('载入分区模板…',[.77 .31 .20 .045],@load_template);
    save_default=uicontrol(fig,'Style','checkbox','Units','normalized','Position',[.76 .235 .22 .06], ...
        'BackgroundColor','w','String','确认时保存为默认模板','Value',0);
    confirm_label='分区 Draft 完成，进入总览';
    if editing,confirm_label='确认组织 ROI，更新曲线和参数';end
    button(confirm_label,[.15 .055 .43 .065],@confirm);
    button('取消本次分析',[.64 .055 .22 .065],@cancel);
    listeners=[addlistener(outer,'MovingROI',@(~,~) preview_lines()), ...
        addlistener(inner,'MovingROI',@(~,~) preview_lines()), ...
        addlistener(outer,'ROIMoved',@(~,~) changed()), ...
        addlistener(inner,'ROIMoved',@(~,~) changed())]; %#ok<NASGU>
    history={positions()};refresh();
    setappdata(fig,'DSAPPartitionEditor',struct('Outer',outer,'Inner',inner));
    drawnow;
    if isgraphics(fig)&&~accepted,uiwait(fig);end
    if isgraphics(fig)&&accepted,cancelled=false;end
    dsap_safe_delete(fig);

    function button(label,position,callback)
        uicontrol(fig,'Style','pushbutton','Units','normalized','Position',position,'String',label,'Callback',callback);
    end
    function p=positions()
        p=struct('Outer',outer.Position,'Inner',inner.Position);
    end
    function preview_lines()
        if busy||~isgraphics(fig),return;end
        o=dsap_partition_curve(outer.Position);i=dsap_partition_curve(inner.Position);
        set(outer_line,'XData',o(:,1),'YData',o(:,2));set(inner_line,'XData',i(:,1),'YData',i(:,2));
    end
    function refresh()
        if ~isgraphics(fig),return;end
        preview_lines();
        try
            candidate=dsap_partition_from_controls(outer.Position,inner.Position,size(reference),limits);
            rgb=zeros([size(reference),3],'single');
            rgb(:,:,1)=single(candidate.CortexMask);rgb(:,:,2)=.55*single(candidate.CortexMask)+.65*single(candidate.SubcortexMask);
            rgb(:,:,3)=single(candidate.SubcortexMask);
            overlay.CData=rgb;overlay.AlphaData=.25*single(candidate.OuterMask);
            status.String=sprintf('皮层 %d 像素；皮层下 %d 像素。确认后再剔除大血管 / AIF；自动明暗识别不会缩小轮廓。', ...
                nnz(candidate.CortexMask),nnz(candidate.SubcortexMask));status.ForegroundColor=[0 .35 0];
        catch exception
            overlay.AlphaData=0;status.String=exception.message;status.ForegroundColor=[.8 0 0];
        end
    end
    function changed()
        if busy,return;end
        history{end+1}=positions();if numel(history)>40,history(1)=[];end
        refresh();
    end
    function assign(p)
        previous=positions();
        busy=true;
        try
            outer.Position=p.Outer;inner.Position=p.Inner;
        catch exception
            outer.Position=previous.Outer;inner.Position=previous.Inner;
            busy=false;status.String=exception.message;return;
        end
        busy=false;changed();
    end
    function transform(scale,angle,delta)
        p=positions();choice=target.Value;
        if choice==1,fields={'Outer','Inner'};elseif choice==2,fields={'Outer'};else,fields={'Inner'};end
        center=mean(p.(fields{1}),1);rotation=[cosd(angle) -sind(angle);sind(angle) cosd(angle)];
        for name=fields
            p.(name{1})=(p.(name{1})-center)*rotation'*scale+center+delta*max(1,min(size(reference))/200);
        end
        assign(p);
    end
    function undo(~,~)
        if numel(history)<2,return;end
        history(end)=[];p=history{end};busy=true;outer.Position=p.Outer;inner.Position=p.Inner;busy=false;refresh();
    end
    function reset(~,~)
        assign(dsap_partition_template('apply',dsap_partition_template('default'),box));
    end
    function load_template(~,~)
        [file,folder]=uigetfile('*.mat','选择 partition_template.mat 或默认分区模板');
        if isequal(file,0),return;end
        try
            loaded=load(fullfile(folder,file),'template');
            p=dsap_partition_template('apply',loaded.template,box);
            dsap_partition_from_controls(p.Outer,p.Inner,size(reference),limits);
            assign(p);
        catch exception
            status.String=['模板未载入：' exception.message];status.ForegroundColor=[.8 0 0];
        end
    end
    function confirm(~,~)
        try
            candidate=dsap_partition_from_controls(outer.Position,inner.Position,size(reference),limits);
            if editing
                assert(isequal(candidate.OuterMask,current.OuterMask),'DSAP:R2Required', ...
                    '外轮廓 mask 已改变；Phase 2A 仅支持 R1，请撤销外轮廓变化。');
            end
            candidate.Confirmed=true;candidate.TemplateFitBox=box;
            candidate.Template=dsap_partition_template('savegeometry',candidate,box);
            if save_default.Value
                if ~isfolder(fileparts(default_file)),mkdir(fileparts(default_file));end
                template=candidate.Template;save(default_file,'template');
            end
            partition=candidate;accepted=true;uiresume(fig);
        catch exception
            status.String=['不能确认：' exception.message];status.ForegroundColor=[.8 0 0];
        end
    end
    function cancel(~,~)
        accepted=false;if isgraphics(fig),uiresume(fig);delete(fig);end
    end
end
