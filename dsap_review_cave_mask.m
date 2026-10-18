function [mask,capillary,model,features,cancelled]=dsap_review_cave_mask(reference,aif,brain,scope,limits,model,features,draw_mask)
% Separate view for lifecycle testing. draw_mask is the existing ROI adapter.
    cancelled=false;added=false(size(aif));restored=added;
    preview=figure('Name','检查 CAVE 血管排除','NumberTitle','off','Color','w', ...
        'Position',[100 100 1200 650]);
    cleanup=onCleanup(@() dsap_safe_delete(preview)); %#ok<NASGU>
    layout=tiledlayout(preview,1,3,'Padding','compact','TileSpacing','compact');
    layout.Units='normalized';layout.Position=[.015 .17 .97 .78];
    axes_list=gobjects(1,3);for k=1:3,axes_list(k)=nexttile(layout);end
    while isgraphics(preview)
        dsap_task_control('check');
        [mask,capillary,model,features]=dsap_apply_cave_corrections(model,features,added,restored,scope,brain,aif);
        for k=1:3,cla(axes_list(k));imshow(reference,[],'Parent',axes_list(k));hold(axes_list(k),'on');end
        visboundaries(axes_list(1),scope,'Color',[1 .85 .1],'LineWidth',.7);
        visboundaries(axes_list(1),aif,'Color',[1 .4 0],'LineWidth',.7);
        title(axes_list(1),'原图：黄色范围、橙色 AIF');
        overlay(axes_list(2),mask,[0 .9 1],.6);
        title(axes_list(2),sprintf('CAVE 血管排除：%.1f%%',100*nnz(mask)/max(nnz(scope),1)));
        overlay(axes_list(3),capillary,[.1 1 .2],.35);
        title(axes_list(3),'保留组织：所选范围减血管与 AIF');
        for ax=axes_list,ylim(ax,[limits.UpperRow-.5 limits.LowerRow+.5]);end
        sgtitle(layout,'CAVE 动静脉并集（含细血管）｜可圈出误识别区域恢复为组织｜不使用中心线');
        choice=dsap_wait_for_review_choice(preview, ...
            '采用后青色区域将在全部帧的组织 TIC 和灌注统计中排除；关闭手绘子页会返回本页。', ...
            {'采用','accept';'增加排除','add';'恢复组织','restore';'重置','reset';'查看动静脉','av';'取消分析','cancel'});
        switch choice
            case 'accept'
                return;
            case {'add','restore'}
                [region,accepted]=draw_correction(reference,mask,scope,choice,draw_mask);
                if accepted
                    if strcmp(choice,'add'),added=added|region;restored=restored&~region;
                    else,restored=restored|region;added=added&~region;end
                end
            case 'reset'
                added=false(size(aif));restored=added;
            case 'av'
                child=figure('Name','CAVE 动静脉候选','NumberTitle','off','Color','w');
                ax=axes(child);imshow(reference,[],'Parent',ax);hold(ax,'on');
                overlay(ax,features.ArteryMask,[1 .1 .1],.6);
                overlay(ax,features.VeinMask,[.1 .35 1],.6);
                title(ax,'自动候选：红色动脉、蓝色静脉；未包括手动修改');
                ylim(ax,[limits.UpperRow-.5 limits.LowerRow+.5]);
            otherwise
                cancelled=true;return;
        end
    end
    cancelled=true;
end

function [region,accepted]=draw_correction(reference,mask,scope,operation,draw_mask)
    region=false(size(mask));accepted=false;
    child=figure('Name','CAVE 手动调整','NumberTitle','off','Color','w','Position',[140 80 900 760]);
    child.CloseRequestFcn=@(source,~) dsap_cancel_interactive_figure(source);
    cleanup=onCleanup(@() dsap_safe_delete(child)); %#ok<NASGU>
    ax=axes(child);imshow(reference,[],'Parent',ax);hold(ax,'on');
    overlay(ax,mask,[0 .9 1],.5);
    if strcmp(operation,'add'),label='圈出要增加排除的区域';else,label='圈出误识别血管，恢复为组织（AIF 仍排除）';end
    title(ax,{label,'平滑闭合曲线，双击结束；关闭本页则不采用本次绘制'});
    [candidate,~,status]=draw_mask(ax,'smoothfreehand',[1 .5 0]);
    if strcmp(status,'accepted')&&isgraphics(child)
        region=logical(candidate)&scope;accepted=any(region,'all');
    end
end

function overlay(ax,mask,color,alpha)
    rgb=reshape(color,1,1,3).*ones([size(mask) 3]);
    h=imshow(rgb,'Parent',ax);h.AlphaData=alpha*single(mask);
end
